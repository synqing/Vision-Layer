from typing import Tuple, Dict, Any

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    lines = observation.merged_lines()
    last_event = lines[-1].strip()[:120] if lines else None
    last_error_signature = None
    for ln in reversed(lines):
        if "error" in ln.lower():
            last_error_signature = ln.strip()[:160]
            break
    uptime_s = None
    facts = {"hil_logs": {}}
    if last_event: facts["hil_logs"]["last_event"] = last_event
    if last_error_signature: facts["hil_logs"]["last_error_signature"] = last_error_signature
    if uptime_s is not None: facts["hil_logs"]["uptime_s"] = uptime_s
    conf = 0.8 if last_event else 0.0
    return facts, conf
