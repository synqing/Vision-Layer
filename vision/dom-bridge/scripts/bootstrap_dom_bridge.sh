#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

npm run bootstrap

mkdir -p "${USER_DATA_DIR:-./user-data}"

echo "Bootstrap complete. Next:"
echo "1) Copy .env.example to .env and adjust as needed."
echo "2) Run: npm run login   # to sign into GitHub in a headful browser"
echo "3) Run: npm start       # to start the bridge on 127.0.0.1"
