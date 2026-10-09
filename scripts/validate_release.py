from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

required = [
    "LICENSE",
    "README.md",
    "RELEASE_NOTES.md",
    "VERSION",
    "pyproject.toml",
    "pysidedeploy.spec",
    ".github/workflows/android.yml",
    ".github/workflows/windows.yml",
    ".github/workflows/linux.yml",
    ".github/workflows/release.yml",
    "packaging/windows/Auralis.iss",
    "packaging/flatpak/io.github.darimarchive_glitch.Auralis.yml",
    "packaging/flatpak/io.github.darimarchive_glitch.Auralis.desktop",
    "packaging/flatpak/io.github.darimarchive_glitch.Auralis.metainfo.xml",
    "packaging/flatpak/io.github.darimarchive_glitch.Auralis.svg",
]

missing = [path for path in required if not (ROOT / path).exists()]
if missing:
    raise SystemExit("Missing release files: " + ", ".join(missing))

version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
if not re.fullmatch(r"\d+\.\d+\.\d+(?:-(?:rc|beta|alpha)\d+)?", version):
    raise SystemExit(f"Invalid VERSION: {version}")

project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
pep440 = version.replace("-rc", "rc").replace("-beta", "b").replace("-alpha", "a")
if project["project"]["version"] != pep440:
    raise SystemExit(
        f"pyproject version {project['project']['version']} does not match VERSION {version}"
    )

init_text = (ROOT / "src/auralis/__init__.py").read_text(encoding="utf-8")
if f'__version__ = "{version}"' not in init_text:
    raise SystemExit("auralis.__version__ does not match VERSION")

print(f"Auralis {version}: release layout OK")
sys.exit(0)
