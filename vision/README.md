Vision Layer — ScreenCaptureKit + AX/DOM Co-Sensor
=================================================

Components
----------
- **visiond-swift** — macOS daemon (Swift/NIO) anchored on ScreenCaptureKit. It resolves panes via Accessibility (AX) / Playwright DOM, captures window frames, computes perceptual hashes, and exposes structured captures over HTTP.
- **parserd** — Python service that pulls captures, fuses structured text with OCR tokens, parses deterministic facts, and emits JSON Patch deltas via webhook, SSE, or JSON Text Sequences.
- **hammerspoon** — optional Lua helper for deterministic window tiling.
- **schemas & config** — JSON Schemas (Draft 2020-12) validating `targets.json`, fact payloads, and brief deltas, plus runtime configuration for both daemons.
- **scripts & tests** — bootstrap/run/metrics helpers and fixture scaffolding for every pane.

Setup (macOS 14+)
-----------------
1. `bash vision/scripts/bootstrap_mac.sh`
   - installs Xcode CLT, Python venv, Playwright Chromium, optional Tesseract, and builds the Swift binary.
2. Grant Screen Recording permission to the terminal/Xcode hosting `visiond` (see `vision/scripts/permissions.md`).
3. (Optional) run a DOM bridge exposing Playwright locators on `$DOM_BRIDGE_PORT` for GitHub panes.

Configuration
-------------
- `config/targets.json` — per-pane capture instructions (mode: `ax` | `dom` | `pixel`) with bundle IDs, locators, and optional pixel offsets. Validated by `schemas/targets.schema.json`.
- `config/visiond.json` — ScreenCaptureKit stream/screenshot parameters, OCR languages + fallback, AX/DOM polling cadence, and perceptual hashing knobs.
- `config/parserd.json` — emission mode, confidence thresholds, voting behavior, Playwright options, and field limits.
- Environment overrides: `VISIOND_PORT`, `PARSERD_PORT`, `OA_WEBHOOK_URL`, `OCR_LANGS`, `FALLBACK_OCR`, `DOM_BRIDGE_PORT`.

Running the stack
-----------------
```
bash vision/scripts/run_all.sh
```
Starts `visiond` and `parserd`, waits for `/healthz`, and keeps both in the foreground. Use `vision/scripts/demo_once.sh` to sweep `/analyze_once` across all panes.

HTTP surface (127.0.0.1)
-----------------------
- `POST /capture_once` (visiond): `{ "pane_id": "CI_SUMMARY" }` → sensors + OCR tokens + optional PNG payload.
- `GET /healthz` (visiond & parserd): per-pane fps, mean/p95 latency, engine mix, emit counts.
- `POST /analyze_once` (parserd): `{ "pane_id": "PR_BANNER" }` → `{ facts, confidence, observation }`.
- `POST /watch` (parserd): `{ "pane_id": "IDE_TERMINAL", "fps": 2 }` → JSON Text Sequence (default) or SSE stream of briefs.

Observability
-------------
- Both daemons print structured JSON logs with `stage ∈ {capture, locate, vision, tesseract, parse, emit}`.
- `/healthz` aggregates per-stage counts, mean/p95 latency, and approximate FPS.
- Pipe the log stream into `vision/scripts/tail_metrics.sh` to monitor stage metrics in real time.

Testing & Fixtures
------------------
- Populate PNG fixtures under `tests/fixtures/<pane>/` and goldens under `tests/golden/<pane>/` for regression work.
- `tests/test_runner.sh` performs basic health checks; extend with parser assertions as fixtures accumulate.
- Add field-accuracy and latency assertions once real data is available.

Next Steps
----------
- Capture multi-theme fixtures (light/dark, zoom 0.9–1.1) for all panes.
- Expand the DOM bridge to guarantee GitHub locator coverage.
- Configure OA webhook delivery via `config/parserd.json` or `$OA_WEBHOOK_URL`.
