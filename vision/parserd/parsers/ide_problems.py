from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    lines = observation.merged_lines()
    file = None
    line = None
    msg = None
    for ln in lines:
        m = re.search(r"([\w./-]+):(\d+):\s*(.*)", ln)
        if m:
            file, line, msg = m.group(1), int(m.group(2)), m.group(3).strip()
            break
    facts = {"ide": {"top_error": {}}}
    if file: facts["ide"]["top_error"]["file"] = file
    if line is not None: facts["ide"]["top_error"]["line"] = line
    if msg: facts["ide"]["top_error"]["msg"] = msg
    conf = 0.95 if file and line and msg else 0.0
    return facts, conf
