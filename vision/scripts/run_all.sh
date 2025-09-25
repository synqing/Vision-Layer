#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export VISIOND_PORT=${VISIOND_PORT:-8765}
export PARSERD_PORT=${PARSERD_PORT:-8876}

echo "[run] starting visiond (port $VISIOND_PORT)"
"$ROOT_DIR/visiond-swift/bin/visiond" &
VISIOND_PID=$!

sleep 1
echo "[run] starting parserd (port $PARSERD_PORT)"
"$ROOT_DIR/parserd/bin/parserd" &
PARSERD_PID=$!

echo "[run] health checks"
curl -fsS "http://127.0.0.1:${VISIOND_PORT}/healthz" || true
curl -fsS "http://127.0.0.1:${PARSERD_PORT}/healthz" || true

cleanup() {
  echo "[run] stopping..."
  kill $PARSERD_PID $VISIOND_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[run] running (press Ctrl+C to stop)"
wait

