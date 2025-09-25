from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    detected_edges = _find_int(text, r"(\d+)\s+edges?")
    period_us = _find_float(text, r"(\d+(?:\.\d+)?)\s*us")
    duty_pct = _find_float(text, r"(\d+(?:\.\d+)?)%\s*duty")
    facts = {"logic": {}}
    if detected_edges is not None: facts["logic"]["detected_edges"] = detected_edges
    if period_us is not None: facts["logic"]["period_us"] = period_us
    if duty_pct is not None: facts["logic"]["duty_pct"] = duty_pct
    filled = sum(1 for x in [detected_edges, period_us, duty_pct] if x is not None)
    conf = 0.85 if filled >= 2 else 0.0
    return facts, conf


def _find_int(text: str, pattern: str):
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return int(m.group(1))
    except Exception:
        return None


def _find_float(text: str, pattern: str):
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return float(m.group(1))
    except Exception:
        return None
