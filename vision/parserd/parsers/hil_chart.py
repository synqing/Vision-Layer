from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    fps_avg = _find_float(text, r"fps\s*avg\s*:?\s*(\d+(?:\.\d+)?)")
    fps_p95 = _find_float(text, r"p95\s*:?\s*(\d+(?:\.\d+)?)")
    drops_pct = _find_float(text, r"drops?\s*:?\s*(\d+(?:\.\d+)?)%")
    sync_offset_ms = _find_float(text, r"sync\s*offset\s*:?\s*(\-?\d+(?:\.\d+)?)\s*ms")
    facts = {"hil": {}}
    if fps_avg is not None: facts["hil"]["fps_avg"] = fps_avg
    if fps_p95 is not None: facts["hil"]["fps_p95"] = fps_p95
    if drops_pct is not None: facts["hil"]["drops_pct"] = drops_pct
    if sync_offset_ms is not None: facts["hil"]["sync_offset_ms"] = sync_offset_ms
    filled = sum(1 for x in [fps_avg, fps_p95, drops_pct, sync_offset_ms] if x is not None)
    conf = 0.9 if filled >= 2 else 0.0
    return facts, conf


def _find_float(text: str, pattern: str):
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return float(m.group(1))
    except Exception:
        return None
