from __future__ import annotations

import os
from pathlib import Path


def app_data_dir() -> Path:
    override = os.environ.get("AURALIS_DATA_DIR")
    if override:
        root = Path(override).expanduser().resolve()
    else:
        try:
            from PySide6.QtCore import QStandardPaths
            value = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppDataLocation)
            root = Path(value) if value else Path.home() / ".local" / "share" / "Auralis"
        except Exception:
            root = Path.home() / ".local" / "share" / "Auralis"
    root.mkdir(parents=True, exist_ok=True)
    return root


def ensure_layout(root: Path | None = None) -> dict[str, Path]:
    root = root or app_data_dir()
    items = {
        "root": root,
        "books": root / "books",
        "covers": root / "covers",
        "models": root / "models",
        "audio_cache": root / "audio-cache",
        "tmp": root / "tmp",
    }
    for key, path in items.items():
        if key != "root":
            path.mkdir(parents=True, exist_ok=True)
    return items
