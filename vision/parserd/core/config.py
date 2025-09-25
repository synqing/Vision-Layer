import os
import json
from pathlib import Path


class Config:
    def __init__(self, root: Path):
        self.root = root
        self.config_dir = root / "vision" / "config"
        self.schemas_dir = root / "vision" / "schemas"

        self.visiond = self._load_json(self.config_dir / "visiond.json")
        self.parserd = self._load_json(self.config_dir / "parserd.json")
        self.targets = self._load_json(self.config_dir / "targets.json")

        # Env overrides
        if os.getenv("VISIOND_PORT"):
            self.visiond["bind_port"] = int(os.getenv("VISIOND_PORT"))
        if os.getenv("PARSERD_PORT"):
            self.parserd["bind_port"] = int(os.getenv("PARSERD_PORT"))
        if os.getenv("OA_WEBHOOK_URL"):
            self.parserd.setdefault("emit", {})["webhook_url"] = os.getenv("OA_WEBHOOK_URL")
        if os.getenv("OCR_LANGS"):
            langs = [s.strip() for s in os.getenv("OCR_LANGS").split(",") if s.strip()]
            self.visiond.setdefault("ocr", {})["languages"] = langs
        if os.getenv("FALLBACK_OCR"):
            self.visiond.setdefault("ocr", {})["fallback"] = os.getenv("FALLBACK_OCR").lower() == "on"

    def _load_json(self, path: Path):
        if path.exists():
            with path.open("r", encoding="utf-8") as f:
                return json.load(f)
        return {}
