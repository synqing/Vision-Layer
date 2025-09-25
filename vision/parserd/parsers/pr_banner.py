from typing import Tuple, Dict, Any

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    mergeable = None
    if "blocked" in text.lower():
        mergeable = "blocked"
    elif any(k in text.lower() for k in ["clean", "can be merged", "able to merge"]):
        mergeable = "clean"
    elif any(k in text.lower() for k in ["dirty", "conflict"]):
        mergeable = "dirty"
    required_reviews = None
    labels = []

    facts = {"pr": {}}
    if mergeable: facts["pr"]["mergeable"] = mergeable
    if required_reviews is not None: facts["pr"]["required_reviews"] = required_reviews
    if labels: facts["pr"]["labels"] = labels[:16]
    conf = 0.98 if mergeable else 0.0
    return facts, conf
