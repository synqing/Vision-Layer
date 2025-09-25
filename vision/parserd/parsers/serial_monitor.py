from typing import Tuple, Dict, Any
import re

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    lines = observation.merged_lines()
    text = " ".join(lines)
    port = None
    connected = None
    last_line = None
    error_count = None
    m = re.search(r"(tty\.[\w-]+|cu\.[\w-]+)", text)
    if m:
        port = m.group(1)
    if "connected" in text.lower():
        connected = True
    if "disconnected" in text.lower():
        connected = False
    if lines:
        last_line = lines[-1][:160]
    m = re.search(r"(\d+)\s+errors?", text, flags=re.I)
    if m:
        error_count = int(m.group(1))
    facts = {"serial": {}}
    if port: facts["serial"]["port"] = port
    if connected is not None: facts["serial"]["connected"] = connected
    if last_line: facts["serial"]["last_line"] = last_line
    if error_count is not None: facts["serial"]["error_count"] = error_count
    conf = 0.85 if port or last_line else 0.0
    return facts, conf
