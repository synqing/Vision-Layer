from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    text = " ".join(observation.merged_lines())
    files_changed = _find_int(text, r"(\d+)\s+files?\s+changed")
    insertions = _find_int(text, r"(\d+)\s+insertions?")
    deletions = _find_int(text, r"(\d+)\s+deletions?")
    risk = None
    if files_changed is not None:
        if files_changed <= 3 and (insertions or 0) < 50 and (deletions or 0) < 50:
            risk = "low"
        elif files_changed <= 10 and (insertions or 0) < 300:
            risk = "med"
        else:
            risk = "high"
    facts = {"diff": {}}
    if files_changed is not None: facts["diff"]["files_changed"] = files_changed
    if insertions is not None: facts["diff"]["insertions"] = insertions
    if deletions is not None: facts["diff"]["deletions"] = deletions
    if risk: facts["diff"]["risk"] = risk
    filled = sum(1 for k in [files_changed, insertions, deletions, risk] if k is not None)
    conf = 0.9 if filled >= 3 else 0.0
    return facts, conf


def _find_int(text: str, pattern: str):
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    try:
        return int(m.group(1))
    except Exception:
        return None
