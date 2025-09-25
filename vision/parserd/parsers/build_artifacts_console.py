from typing import Tuple, Dict, Any, List

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    items: List[Dict[str, Any]] = []
    for s in observation.merged_lines():
        if "." in s and len(s.split()) == 1:
            items.append({"name": s, "size_bytes": None, "ready": None})
            if len(items) >= 12:
                break
    facts = {"artifacts": {"items": items}}
    conf = 0.5 if items else 0.0
    return facts, conf
