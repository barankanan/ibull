"""Local print bridge package for single-printer ESC/POS receipts."""

from __future__ import annotations

import sys
from pathlib import Path


_LOCAL_DEPS = Path(__file__).with_name(".deps")
if _LOCAL_DEPS.is_dir():
    deps_path = str(_LOCAL_DEPS)
    if deps_path not in sys.path:
        sys.path.insert(0, deps_path)
