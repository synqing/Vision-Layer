import aiohttp
import logging
from typing import Any, Dict

from .models import PaneObservation


class VisionClient:
    def __init__(self, host: str = "127.0.0.1", port: int = 8765):
        self.base = f"http://{host}:{port}"

    async def capture_once(self, pane_id: str) -> PaneObservation:
        url = f"{self.base}/capture_once"
        payload: Dict[str, Any] = {"pane_id": pane_id}
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                    if resp.status != 200:
                        logging.warning("capture_once failed: %s", resp.status)
                        return PaneObservation(pane_id=pane_id)
                    data = await resp.json()
                    return PaneObservation.from_payload(data)
        except Exception as exc:  # noqa: BLE001
            logging.exception("capture_once error: %s", exc)
        return PaneObservation(pane_id=pane_id)

