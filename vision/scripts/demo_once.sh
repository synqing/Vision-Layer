#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT=${PARSERD_PORT:-8876}

PANES=(
  CI_SUMMARY CI_LOGS_DETAIL CHECKS_LIST PR_BANNER PR_DIFF_SUMMARY PR_THREAD_SUMMARY
  IDE_PROBLEMS IDE_TERMINAL BUILD_ARTIFACTS_CONSOLE HIL_CHART HIL_LOGS SERIAL_MONITOR
  LOGIC_ANALYZER LED_CAMERA_MONITOR
)

for p in "${PANES[@]}"; do
  echo "[demo] analyze_once $p"
  curl -s -X POST "http://127.0.0.1:${PORT}/analyze_once" -H 'Content-Type: application/json' -d "{\"pane_id\":\"$p\"}" | jq .
done

