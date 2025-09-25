#!/usr/bin/env bash
set -euo pipefail

echo "[metrics] pipe log stream into this script; press Ctrl+C to stop"
stdbuf -oL jq -r 'select(.stage != null) | [.ts, .stage, (.pane // "-"), (.confidence // .capture_latency_ms // .latency_ms // ""), (.ocr_engine // ""), (.ops // "")] | @tsv'
