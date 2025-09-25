from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    warnings = _find_int(text, r"(\d+)\s+warnings?")
    errors = _find_int(text, r"(\d+)\s+errors?")
    last_target = None
    m = re.search(r"\bTarget\s+([\w.-]+)", text, flags=re.I)
    if m:
        last_target = m.group(1)
    build_time_s = _find_int(text, r"(\d+(?:\.\d+)?)\s*s(?:ec(?:onds)?)?\b")
    facts = {"terminal": {}}
    if warnings is not None: facts["terminal"]["warnings"] = warnings
    if errors is not None: facts["terminal"]["errors"] = errors
    if last_target: facts["terminal"]["last_target"] = last_target
    if build_time_s is not None: facts["terminal"]["build_time_s"] = float(build_time_s)
    filled = sum(1 for x in [warnings, errors, last_target, build_time_s] if x)
    conf = 0.9 if filled >= 2 else 0.0
    return facts, conf


def _find_int(text: str, pattern: str):
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return float(m.group(1)) if "." in m.group(1) else int(m.group(1))
    except Exception:
        return None
