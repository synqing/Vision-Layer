from typing import Tuple, Dict, Any

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines()).lower()
    status = None
    if any(s in text.lower() for s in ["all checks have passed", "checks passed", "success"]):
        status = "passing"
    elif "failing" in text.lower() or "failed" in text.lower():
        status = "failing"
    elif "queued" in text.lower():
        status = "queued"
    elif "running" in text.lower():
        status = "running"

    checks_total = None
    checks_failed = None
    failed_names = []

    facts = {"ci": {}}
    if status:
        facts["ci"]["status"] = status
    if checks_total is not None:
        facts["ci"]["checks_total"] = checks_total
    if checks_failed is not None:
        facts["ci"]["checks_failed"] = checks_failed
    if failed_names:
        facts["ci"]["failed_names"] = failed_names[:8]

    conf = 0.99 if status else 0.0
    return facts, conf
