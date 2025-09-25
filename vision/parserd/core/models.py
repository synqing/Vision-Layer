from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class Sensor:
    source: str
    frame: Optional[Dict[str, float]]
    text: Optional[str]
    confidence: Optional[float]


@dataclass
class Token:
    text: str
    bbox: List[float]
    confidence: float


@dataclass
class Metadata:
    raw: Dict[str, Any]


@dataclass
class PaneObservation:
    pane_id: str
    sensors: List[Sensor] = field(default_factory=list)
    tokens: List[Token] = field(default_factory=list)
    metadata: Metadata = field(default_factory=lambda: Metadata(raw={}))

    @property
    def structured_text(self) -> List[str]:
        return [s.text for s in self.sensors if s.text]

    @property
    def ocr_text(self) -> List[str]:
        return [t.text for t in self.tokens]

    def merged_lines(self) -> List[str]:
        if self.structured_text:
            return flatten_lines(self.structured_text)
        return flatten_lines(self.ocr_text)

    def has_structured(self) -> bool:
        return any(s.text for s in self.sensors)

    @classmethod
    def from_payload(cls, payload: Dict[str, Any]) -> "PaneObservation":
        sensors = []
        for item in payload.get("sensors", []):
            sensors.append(
                Sensor(
                    source=item.get("source", "unknown"),
                    frame=item.get("frame"),
                    text=item.get("text"),
                    confidence=item.get("confidence"),
                )
            )
        tokens = []
        for tok in payload.get("ocr", {}).get("tokens", []):
            tokens.append(
                Token(
                    text=tok.get("text", ""),
                    bbox=tok.get("bbox", []),
                    confidence=float(tok.get("confidence", 0.0)),
                )
            )
        metadata = Metadata(raw=payload.get("metadata", {}))
        return cls(pane_id=payload.get("pane", ""), sensors=sensors, tokens=tokens, metadata=metadata)

    @classmethod
    def choose_best(cls, observations: List["PaneObservation"]) -> "PaneObservation":
        if not observations:
            return cls(pane_id="", sensors=[], tokens=[])
        observations_sorted = sorted(
            observations,
            key=lambda obs: (
                1 if obs.has_structured() else 0,
                sum(tok.confidence for tok in obs.tokens)
            ),
            reverse=True,
        )
        best = observations_sorted[0]
        best.pane_id = best.pane_id or observations[0].pane_id
        return best


def flatten_lines(lines: List[str]) -> List[str]:
    out: List[str] = []
    for line in lines:
        if line is None:
            continue
        parts = str(line).split("\n")
        for part in parts:
            stripped = part.strip()
            if stripped:
                out.append(stripped)
    return out

