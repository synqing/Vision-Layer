Testing Harness
===============

1. Populate fixtures
   - Drop PNG frames in `tests/fixtures/<PANE_ID>/` captured via `visiond` or ScreenCaptureKit.
   - Store expected parser outputs in `tests/golden/<PANE_ID>/` (JSON files) to enable regression checks.

2. Smoke test
   - Ensure `visiond` and `parserd` are running (`scripts/run_all.sh`).
   - Execute `tests/test_runner.sh` for endpoint health checks.

3. Extending coverage
   - Add parser unit tests by comparing `parserd` outputs against golden facts.
   - Record latency/perf data by replaying fixtures through `parserd` and summarising capture→facts latency.

All test scripts assume 127.0.0.1 bindings and local-only services.
