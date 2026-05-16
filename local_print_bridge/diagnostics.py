from __future__ import annotations

import platform
import shutil
from typing import Any

from .config import BridgeSettings
from .printers import discover_windows_printers
from .usb_transport import _import_usb
from .windows_transport import _import_win32print


def _check_pillow() -> dict[str, object]:
    try:
        import PIL  # noqa: F401, PLC0415

        return {"ok": True, "detail": "Pillow available"}
    except ImportError:
        return {"ok": False, "detail": "Pillow missing"}


def _check_pyusb() -> dict[str, object]:
    usb = _import_usb()
    if usb is None:
        return {"ok": False, "detail": "pyusb missing"}
    return {"ok": True, "detail": "pyusb available"}


def _check_pywin32() -> dict[str, object]:
    if platform.system().lower() != "windows":
        return {"ok": False, "detail": "Not running on Windows"}
    module = _import_win32print()
    if module is None:
        return {"ok": False, "detail": "pywin32 missing"}
    return {"ok": True, "detail": "pywin32 available"}


def _check_cups() -> dict[str, object]:
    lp_path = shutil.which("lp")
    lpstat_path = shutil.which("lpstat")
    return {
        "ok": bool(lp_path),
        "lp": lp_path,
        "lpstat": lpstat_path,
        "detail": "CUPS commands available" if lp_path else "CUPS lp command missing",
    }


def available_transports(settings: BridgeSettings) -> list[str]:
    transports = ["network-tcp"]
    os_name = platform.system().lower()
    if os_name == "windows":
        transports.append("windows-spool")
    else:
        transports.append("cups")
    if _import_usb() is not None:
        transports.append("usb-direct")
    if settings.transport_mode not in transports:
        transports.append(settings.transport_mode)
    return sorted(set(transports))


def build_diagnostics(
    *,
    settings: BridgeSettings,
    transport,
    queue_summary: dict[str, object],
    log_count: int,
) -> dict[str, Any]:
    printer_inventory = transport.discover()
    printers = printer_inventory.get("printers", [])
    os_name = platform.system()
    diagnostics: dict[str, Any] = {
        "ok": True,
        "os": {
            "system": os_name,
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "python": platform.python_version(),
        },
        "bridge": {
            "transportMode": settings.transport_mode,
            "availableTransports": available_transports(settings),
            "printerCount": len(printers) if isinstance(printers, list) else 0,
            "queue": queue_summary,
            "logCount": log_count,
        },
        "dependencies": {
            "pillow": _check_pillow(),
            "pyusb": _check_pyusb(),
            "pywin32": _check_pywin32(),
        },
        "systemServices": {
            "cups": _check_cups(),
            "windowsSpooler": {
                "ok": os_name.lower() == "windows",
                "detail": (
                    "Windows printer inventory reachable"
                    if os_name.lower() != "windows" or discover_windows_printers() is not None
                    else "Windows printer inventory unavailable"
                ),
            },
        },
        "printers": printers if isinstance(printers, list) else [],
    }
    return diagnostics
