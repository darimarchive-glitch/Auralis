from pathlib import Path
import sys

# Desktop installs the package normally; Android bundles the source tree directly.
# Keep src/ importable in both cases.
ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from auralis.main import main

if __name__ == "__main__":
    raise SystemExit(main())
