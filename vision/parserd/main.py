import os
import json
import asyncio
from datetime import datetime, timezone
from pathlib import Path
from aiohttp import web

from parserd.core.config import Config
from parserd.core.vision_client import VisionClient
from parserd.core.delta import DeltaEngine
from parserd.core.emit import emit_webhook, stream_sse, stream_jsonseq
from parserd.core.validate import Validator
from parserd.core.models import PaneObservation
from parserd.parsers import PARSERS


ROOT = Path(__file__).resolve().parents[2]
cfg = Config(ROOT)

with open(cfg.schemas_dir / "facts.schema.json", "r", encoding="utf-8") as f:
    FACTS_SCHEMA = json.load(f)
with open(cfg.schemas_dir / "brief.schema.json", "r", encoding="utf-8") as f:
    BRIEF_SCHEMA = json.load(f)

validator = Validator(FACTS_SCHEMA, BRIEF_SCHEMA)
delta_engine = DeltaEngine()

vision_client = VisionClient(port=int(cfg.visiond.get("bind_port", 8765)))


def log_stage(stage: str, pane: str, **fields):
    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "stage": stage,
        "pane": pane,
    }
    entry.update(fields)
    print(json.dumps(entry), flush=True)


async def capture_with_multi_read(pane_id: str) -> PaneObservation:
    target_cfg = cfg.targets.get(pane_id, {}) if isinstance(cfg.targets, dict) else {}
    passes = int(target_cfg.get("multi_read_n", 1) or 1)
    passes = max(1, min(passes, cfg.parserd.get("voting", {}).get("max_passes", 3)))
    observations = []
    for _ in range(passes):
        obs = await vision_client.capture_once(pane_id)
        observations.append(obs)
        if obs.has_structured():
            break
    return PaneObservation.choose_best(observations)


async def analyze_once(request: web.Request):
    data = await request.json()
    pane_id = data.get("pane_id")
    if pane_id not in cfg.targets:
        return web.json_response({"error": "unknown pane_id"}, status=404)

    observation = await capture_with_multi_read(pane_id)
    parser = PARSERS.get(pane_id)
    if not parser:
        return web.json_response({"error": "no parser"}, status=404)

    facts, confidence = parser(observation, cfg.parserd.get("limits", {}))
    log_stage("parse", pane_id, confidence=confidence)
    try:
        validator.validate_facts(facts)
    except Exception:
        pass
    return web.json_response({
        "facts": facts,
        "confidence": confidence,
        "observation": {
            "structured": observation.structured_text,
            "ocr": observation.ocr_text,
            "metadata": observation.metadata.raw,
        }
    })


async def watch(request: web.Request):
    data = await request.json()
    pane_id = data.get("pane_id")
    fps = int(data.get("fps", cfg.parserd.get("watch_defaults_fps", 2)))
    mode = cfg.parserd.get("emit", {}).get("mode", "sse")
    q: asyncio.Queue[str] = asyncio.Queue(maxsize=100)

    async def producer():
        try:
            while True:
                observation = await capture_with_multi_read(pane_id)
                parser = PARSERS.get(pane_id)
                if not parser:
                    await asyncio.sleep(1.0 / max(1, fps))
                    continue
                facts, confidence = parser(observation, cfg.parserd.get("limits", {}))
                brief = make_brief(pane_id, facts, confidence)
                if brief["delta"] and confidence >= cfg.parserd.get("emit", {}).get("min_confidence", 0.97):
                    await q.put(json.dumps(brief, separators=(",", ":")))
                    log_stage("emit", pane_id, confidence=confidence, ops=len(brief["delta"]))
                await asyncio.sleep(1.0 / max(1, fps))
        except asyncio.CancelledError:
            pass

    task = asyncio.create_task(producer())
    request.app["tasks"].add(task)
    if mode == "jsonseq":
        resp = await stream_jsonseq(request, q)
    else:
        resp = await stream_sse(request, q)
    task.cancel()
    request.app["tasks"].discard(task)
    return resp


def make_brief(pane: str, facts: dict, confidence: float) -> dict:
    patch = delta_engine.patch(pane, facts)
    brief = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "pane": pane,
        "delta": patch,
        "confidence": float(confidence),
    }
    try:
        validator.validate_brief(brief)
    except Exception:
        pass
    return brief


async def healthz(_: web.Request):
    return web.json_response({"status": "ok"})


def build_app() -> web.Application:
    app = web.Application()
    app.add_routes([
        web.get("/healthz", healthz),
        web.post("/analyze_once", analyze_once),
        web.post("/watch", watch),
    ])
    app["tasks"] = set()
    return app


def main():
    port = int(cfg.parserd.get("bind_port", 8876))
    web.run_app(build_app(), host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
