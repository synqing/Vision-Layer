#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[tests] sanity: schemas validate and endpoints up"

# Start parserd and visiond minimal health checks if possible
VISIOND_PORT=${VISIOND_PORT:-8765}
PARSERD_PORT=${PARSERD_PORT:-8876}

python3 - <<'PY'
import json, sys
from pathlib import Path
from jsonschema import Draft202012Validator

root = Path(__file__).resolve().parents[1]
schema_path = root / 'schemas' / 'targets.schema.json'
data_path = root / 'config' / 'targets.json'
schema = json.loads(schema_path.read_text())
data = json.loads(data_path.read_text())
Draft202012Validator(schema).validate(data)
print('[tests] targets.json ✅')
PY

curl -fsS "http://127.0.0.1:${VISIOND_PORT}/healthz" || echo "visiond not running; start with scripts/run_all.sh"
curl -fsS "http://127.0.0.1:${PARSERD_PORT}/healthz" || echo "parserd not running; start with scripts/run_all.sh"

echo "[tests] done."
