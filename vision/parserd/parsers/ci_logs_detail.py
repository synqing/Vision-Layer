from typing import Tuple, Dict, Any

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    lines = observation.merged_lines()
    job = None
    step = None
    last_error_signature = None
    duration_s = None
    retry_count = None

    # Simple heuristics
    for ln in lines[-10:]:
        if "error" in ln.lower():
            last_error_signature = ln.strip()[:160]
            break

    facts = {"ci_logs": {}}
    if job: facts["ci_logs"]["job"] = job
    if step: facts["ci_logs"]["step"] = step
    if last_error_signature: facts["ci_logs"]["last_error_signature"] = last_error_signature
    if duration_s is not None: facts["ci_logs"]["duration_s"] = duration_s
    if retry_count is not None: facts["ci_logs"]["retry_count"] = retry_count
    conf = 0.95 if last_error_signature else 0.0
    return facts, conf
