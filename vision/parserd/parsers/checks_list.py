from typing import Tuple, Dict, Any, List

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    tokens = observation.merged_lines()
    items: List[Dict[str, Any]] = []
    # Placeholder: collect first 10 distinct lines as names
    seen = set()
    for t in tokens:
        s = t.strip()
        if not s or s in seen:
            continue
        seen.add(s)
        items.append({"name": s, "status": "unknown", "duration_s": None})
        if len(items) >= 10:
            break
    facts = {"checks": items}
    conf = 0.0 if not items else 0.6
    return facts, conf
