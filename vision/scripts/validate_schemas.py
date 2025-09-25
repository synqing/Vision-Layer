#!/usr/bin/env python3
import json
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator
except Exception as e:
    print("jsonschema is required (pip install jsonschema)", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parents[2]
schemas_dir = ROOT / 'vision' / 'schemas'
config_dir = ROOT / 'vision' / 'config'

def load_json(path: Path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)

def validate_targets():
    schema = load_json(schemas_dir / 'targets.schema.json')
    data = load_json(config_dir / 'targets.json')
    v = Draft202012Validator(schema)
    errors = sorted(v.iter_errors(data), key=lambda e: e.path)
    if errors:
        for e in errors:
            loc = "/".join([str(p) for p in e.path])
            print(f"targets.json: {loc}: {e.message}", file=sys.stderr)
        return False
    return True

def validate_json_files():
    ok = True
    for p in config_dir.glob('*.json'):
        try:
            load_json(p)
        except Exception as e:
            print(f"Invalid JSON: {p.name}: {e}", file=sys.stderr)
            ok = False
    return ok

def main():
    ok = True
    ok &= validate_json_files()
    ok &= validate_targets()
    sys.exit(0 if ok else 1)

if __name__ == '__main__':
    main()

