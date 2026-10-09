from __future__ import annotations

import os
from pathlib import Path

APP_NAME = "Auralis"


def app_data_dir() -> Path:
    override = os.environ.get("AURALIS_DATA_DIR")
    if override:
        root = Path(override).expanduser().resolve()
    elif os.name == "nt":
        root = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local")) / APP_NAME
    elif os.environ.get("ANDROID_ARGUMENT"):
        root = Path.home() / ".auralis"
    else:
        root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "auralis"
    root.mkdir(parents=True, exist_ok=True)
    return root


def ensure_dirs() -> dict[str, Path]:
    root = app_data_dir()
    dirs = {
        "root": root,
        "books": root / "books",
        "covers": root / "covers",
        "models": root / "models",
        "audio_cache": root / "audio-cache",
        "translation_cache": root / "translation-cache",
    }
    for path in dirs.values():
        path.mkdir(parents=True, exist_ok=True)
    return dirs
