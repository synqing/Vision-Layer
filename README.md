Vision Layer — Deterministic Ground Truth for Autopilot
======================================================

Purpose
-------
- Provide a hands-off, deterministic “vision” substrate that reads CI/PR/HIL/IDE panes and emits tiny, typed facts for the orchestrator. No clicking, no heuristics — just facts and JSON Patch deltas that gate automation.

System Objective
----------------
- End-to-end firmware autopilot for K1-09: task intake → agentic coding → CI → HIL → merge, with human override only. Reliability comes from gates: compile/tests, HIL proofs, and this Vision layer’s ground truth.

Control Plane (30k ft)
----------------------
- Task intake → structured issue spec
- Orchestrator (n8n) fans out, loops on failures, applies merge policy
- CI runs (PlatformIO, static checks, size budget)
- HIL: flash → serial/logic/camera → metrics
- Vision layer (this repo): AX/DOM first, OCR second; emits RFC-6902 JSON Patch deltas and optional RFC-7464 JSON-seq stream

Hard Constraints
----------------
- Sensors: macOS Accessibility (AX) for native panes; Playwright DOM for web UIs. OCR (Apple Vision) is fallback only.
- Capture: ScreenCaptureKit (stream or still). Avoid CGWindow APIs.
- Geometry mapping: Use per-frame attachments: ContentRect (points), ScaleFactor (display scale), ContentScale (backing scale). This yields visible rect and stable crop pixels on retina/multi-display systems.
- Parsing: deterministic regex/state machines → typed facts → JSON Patch deltas; stream via JSON Text Sequences when tailing.

Covered Panes (examples)
------------------------
- CI: `CI_SUMMARY`, `CHECKS_LIST`, `CI_LOGS_DETAIL` (DOM)
- PR: `PR_BANNER`, `PR_DIFF_SUMMARY`, `PR_THREAD_SUMMARY` (DOM)
- IDE: `IDE_PROBLEMS`, `IDE_TERMINAL` (AX)
- HIL: `HIL_CHART`, `HIL_LOGS` (DOM/native as applicable)

Data Path (deterministic, low latency)
--------------------------------------
- Locate
  - AX: traverse `AXUIElement` tree, read roles/titles, get `kAXFrame`
  - DOM: Playwright locators (`getByRole`, `getByTestId`). `locator.boundingBox()` is viewport-relative or null when hidden
- Capture
  - Stream (`SCStream`) or still (`SCScreenshotManager`) with `SCContentFilter(SCWindow)`
  - Read per-frame attachments: ContentRect, ScaleFactor, ContentScale
- Map DOM/AX → pixels (per frame)
  - Given DOM bbox in CSS px and viewport {Wv,Hv}, and SCK visible rect {Vx,Vy,Vw,Vh} in pixels:
    - `sx = Vw/Wv`, `sy = Vh/Hv`
    - `crop.x = Vx + bbox.x * sx`, `crop.y = Vy + bbox.y * sy`
    - `crop.w = bbox.width * sx`, `crop.h = bbox.height * sy`
- Read Text (fallback)
  - Apple Vision `VNRecognizeTextRequest` with explicit languages, `.accurate`, and tuned `minimumTextHeight`
- Parse → facts → deltas
  - Source-specific parsers generate typed facts; emit RFC-6902 patches only on change; optional RFC-7464 streaming
- Confidence & debouncing
  - Fuse confidence: `min(structured_conf, ocr_conf, parse_score)`; only multi-read when confidence dips or AX/DOM disagrees with OCR

Why This Is Robust
------------------
- ScreenCaptureKit replaces deprecated CGWindow and supplies per-frame geometry
- Playwright locators stabilize DOM reads; bbox semantics are documented
- OCR is local and used only when structure is unavailable
- JSON Patch + JSON-seq keep OA bandwidth minimal and traceable

Repository Layout
-----------------
- `vision/visiond-swift` — Swift daemon using ScreenCaptureKit to resolve panes, map geometry, capture frames, and serve HTTP
- `vision/dom-bridge` — Playwright-based DOM bridge that returns stable viewport bboxes and text for web panes
- `vision/parserd` — Python service that fuses AX/DOM/OCR, parses deterministic facts, and emits JSON Patch/JSON-seq
- `vision/schemas` — JSON Schemas validating targets and fact payloads
- `vision/tests` — fixtures, goldens, and a smoke test harness

Quick Start (macOS 14+)
-----------------------
- Bootstrap
  - `bash vision/scripts/bootstrap_mac.sh`
  - Grant Screen Recording and Accessibility permissions (see `vision/scripts/permissions.md`)
- DOM auth (optional, for GitHub panes)
  - `cd vision/dom-bridge && ./scripts/bootstrap_dom_bridge.sh && npm run login`
- Run the stack
  - `bash vision/scripts/run_all.sh`

Operational Endpoints
---------------------
- `visiond` (Swift)
  - `GET /healthz` — stream status: fps, latency, engine mix
  - `POST /capture_once {pane_id}` — returns sensors + OCR tokens + optional PNG
- `parserd` (Python)
  - `GET /healthz` — parse/emit metrics
  - `POST /analyze_once {pane_id}` — returns `{facts, confidence, observation}`
  - `POST /watch {pane_id,fps}` — JSON Text Sequence (default) or SSE stream of deltas

Emission Format
---------------
- Facts: typed, source-specific fields (e.g., `ci.status`, `pr.mergeable`)
- Deltas: RFC-6902 JSON Patch, emitted only when fields change
- Streaming: RFC-7464 JSON Text Sequences for tailing and low-latency orchestration

Development Notes
-----------------
- Prefer AX/DOM over OCR; treat OCR as a last resort
- Use role/test-id locators before raw CSS/text to resist UI drift
- Capture fixtures for light/dark themes and minor zoom variations (0.9–1.1) to harden parsers

What’s Next
-----------
- Expand pane coverage with fixtures and goldens
- Wire OA webhook (`OA_WEBHOOK_URL`) and merge gating policies
- Add CI to lint Swift/Python/Node and to replay fixtures for regression

See Also
--------
- `vision/README.md` for component-level details and local APIs
- `docs/architecture.md` for diagrams and data-path specifics

License
-------
- Apache License 2.0. See `LICENSE` and `NOTICE`.
