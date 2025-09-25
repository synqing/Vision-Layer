from typing import Tuple, Dict, Any

from ..core.models import PaneObservation


def parse(observation: PaneObservation, limits: Dict[str, Any]) -> Tuple[Dict[str, Any], float]:
    # Placeholder: relies on upstream image analysis; pass through until implemented.
    facts = {"camera": {"frame_brightness": None, "dominant_hue_deg": None}}
    conf = 0.0
    return facts, conf
