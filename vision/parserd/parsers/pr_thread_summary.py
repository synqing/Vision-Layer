from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    unresolved = _find_int(text, r"(\d+)\s+unresolved")
    requested_reviewers = []
    facts = {"threads": {}}
    if unresolved is not None:
        facts["threads"]["unresolved_count"] = unresolved
    if requested_reviewers:
        facts["threads"]["requested_reviewers"] = requested_reviewers[:8]
    conf = 0.9 if unresolved is not None else 0.0
    return facts, conf


def _find_int(text: str, pattern: str):
    import re
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return int(m.group(1))
    except Exception:
        return None
