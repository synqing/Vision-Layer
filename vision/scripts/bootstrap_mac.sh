#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[bootstrap] Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[bootstrap] Installing Homebrew";
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "[bootstrap] Optional: tesseract"
if ! command -v tesseract >/dev/null 2>&1; then
  brew install tesseract || true
fi

echo "[bootstrap] Python venv + deps"
python3 -m venv "$ROOT_DIR/parserd/.venv"
source "$ROOT_DIR/parserd/.venv/bin/activate"
pip install --upgrade pip
pip install -r "$ROOT_DIR/parserd/requirements.txt"

echo "[bootstrap] Build Swift (release)"
pushd "$ROOT_DIR/visiond-swift" >/dev/null
swift build -c release
popd >/dev/null

echo "[bootstrap] Done"

