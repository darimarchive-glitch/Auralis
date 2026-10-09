from pathlib import Path
import tomllib

import auralis


ROOT = Path(__file__).resolve().parents[1]


def test_version_files_are_consistent():
    public_version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    pyproject = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    package_version = pyproject["project"]["version"]

    assert auralis.__version__ == public_version
    assert package_version == public_version.replace("-rc", "rc")
