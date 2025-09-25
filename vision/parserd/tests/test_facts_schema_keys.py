import json
import jsonschema
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "schemas" / "facts.schema.json").read_text())


def validate(instance):
    jsonschema.validate(instance=instance, schema=SCHEMA)


def test_minimal_ci_schema_ok():
    facts = {"ci": {"status": "queued", "checks_total": 5}}
    validate(facts)


def test_ide_top_error_required_fields():
    good = {"ide": {"top_error": {"file": "src/main.cpp", "line": 42, "msg": "oops"}}}
    validate(good)

    bad = {"ide": {"top_error": {"file": "src/main.cpp", "msg": "oops"}}}
    try:
        validate(bad)
    except jsonschema.ValidationError:
        pass
    else:
        assert False, "line is required in ide.top_error"

