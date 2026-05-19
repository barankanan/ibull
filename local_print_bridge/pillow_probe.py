from __future__ import annotations

import sys
from typing import Any


def probe_pillow(*, reload: bool = False) -> dict[str, Any]:
    """Runtime Pillow availability check (not cached at bridge import time only)."""
    if reload:
        import importlib

        if "PIL" in sys.modules:
            importlib.reload(sys.modules["PIL"])
        for name in list(sys.modules):
            if name == "PIL" or name.startswith("PIL."):
                importlib.reload(sys.modules[name])

    try:
        from PIL import Image  # noqa: PLC0415

        version = getattr(Image, "__version__", None)
        module_file = getattr(Image, "__file__", None)
        return {
            "pillow_available": True,
            "pillow_version": str(version) if version is not None else None,
            "pillow_module": str(module_file) if module_file else None,
            "import_error": None,
            "python_executable": sys.executable,
            "python_version": sys.version.split()[0],
        }
    except ImportError as exc:
        return {
            "pillow_available": False,
            "pillow_version": None,
            "pillow_module": None,
            "import_error": str(exc),
            "python_executable": sys.executable,
            "python_version": sys.version.split()[0],
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "pillow_available": False,
            "pillow_version": None,
            "pillow_module": None,
            "import_error": f"{type(exc).__name__}: {exc}",
            "python_executable": sys.executable,
            "python_version": sys.version.split()[0],
        }
