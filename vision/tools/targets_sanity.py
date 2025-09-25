#!/usr/bin/env python3
"""
Lightweight sanity checks for vision/config/targets.json against schemas/brief.schema.json.

- Ensures every pane_id in targets.json is present in brief.schema pane enum
- Validates required keys per mode (ax/dom/pixel)
- Checks numeric bounds for multi_read_n and pixel_offset
"""

import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
targets = json.loads((ROOT/"config"/"targets.json").read_text())
brief_schema = json.loads((ROOT/"schemas"/"brief.schema.json").read_text())

# Extract allowed panes from schema enum
props = brief_schema.get("properties", {})
pane_enum = set(props.get("pane", {}).get("enum", []))
errors = []

def err(msg):
    errors.append(msg)

def check_target(pane_id, spec):
    if pane_id not in pane_enum:
        err(f"pane_id '{pane_id}' not in brief.schema pane enum")

    mode = spec.get("mode")
    if mode not in {"ax", "dom", "pixel"}:
        err(f"{pane_id}: invalid mode '{mode}'")

    # Required fields by mode
    if mode == "ax":
        ax = spec.get("ax") or {}
        if not ax.get("role"):
            err(f"{pane_id}: ax.role required")
    elif mode == "dom":
        dom = spec.get("dom") or {}
        if not (dom.get("locator") or dom.get("testid") or (dom.get("role") and dom.get("name"))):
            err(f"{pane_id}: dom locator/testid or role+name required")

    # multi_read_n
    mrn = spec.get("multi_read_n", 2)
    if not isinstance(mrn, int) or mrn < 1 or mrn > 5:
        err(f"{pane_id}: multi_read_n must be int in [1,5]")

    # pixel_offset (optional)
    po = spec.get("pixel_offset")
    if po:
        for k in ("dx","dy","w","h"):
            if k not in po or not isinstance(po[k], (int,float)):
                err(f"{pane_id}: pixel_offset.{k} missing or not number")

for pid, spec in targets.items():
    check_target(pid, spec)

if errors:
    print("targets_sanity: FAIL")
    for e in errors: print(" -", e)
    sys.exit(1)
else:
    print("targets_sanity: OK")

