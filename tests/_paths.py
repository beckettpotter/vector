"""Imported by every test so it can find tools/ and sim/."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
for sub in ("tools", "sim"):
    p = str(ROOT / sub)
    if p not in sys.path:
        sys.path.insert(0, p)
