from __future__ import annotations

import base64
from dataclasses import replace
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import threading
import time
from logging.handlers import RotatingFileHandler
from urllib.parse import parse_qs, urlparse

from .config import BridgeSettings, EscPosProfile, resolve_escpos_profile, write_env_file
from .diagnostics import build_diagnostics
from .document import DocumentPayloadError, EscPosDocumentRenderer
from .kitchen import KitchenRenderer
from .log_store import PrintLogStore
from .models import KitchenPayload, PayloadError, ReceiptPayload
from .network_transport import NetworkTcpTransport
from .printers import PrinterRecord, dedupe_printers, discover_windows_printers
from .pillow_probe import probe_pillow
from .print_station import (
    PrintStationConsumer,
    build_print_station_queue_status,
    build_test_receipt_payload,
)
from .queue_manager import PrintQueueManager
from .raster import (
    BundledFontMissingError,
    KitchenBitmapRenderer,
    RasterEscPosEncoder,
    ReceiptBitmapRenderer,
    bundled_mono_font_status,
    resolve_bundled_mono_font_path,
    warm_font_cache,
)
from .receipt import ReceiptRenderer
from .runtime_paths import bridge_env_path, bridge_server_log_path
from .transport import CupsRawTransport, TransportError
from .usb_transport import UsbDirectTransport
from .windows_transport import WindowsSpoolTransport, _import_win32print


LOGGER = logging.getLogger("local_print_bridge")

# Protects atomic hot-reload of PrintBridgeHandler class-level state.
_STATE_LOCK = threading.Lock()
_AUTOSTART_LABEL = "com.ibul.localprint"


def _git_commit_short() -> str:
    try:
        root = Path(__file__).resolve().parent.parent
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(root),
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            return (result.stdout or "").strip()
    except Exception:
        pass
    return ""


def _app_mode() -> str:
    # PyInstaller sets sys.frozen; python source runs do not.
    if getattr(sys, "frozen", False):
        return "packaged"
    return "python"


def _build_info() -> dict[str, object]:
    try:
        from . import receipt as _receipt
        from . import raster as _raster
        from . import kitchen as _kitchen
    except Exception:
        _receipt = None
        _raster = None
        _kitchen = None
    info: dict[str, object] = {
        "bridge_version": "dev",
        "build_time": _PROCESS_STARTED_AT,
        "git_commit": _git_commit_short() or "",
        "app_mode": _app_mode(),
        "python_executable": sys.executable,
        "python_version": platform.python_version(),
        "server_path": str(Path(__file__).resolve()),
        "receipt_path": str(Path(getattr(_receipt, "__file__", "") or "")),
        "raster_path": str(Path(getattr(_raster, "__file__", "") or "")),
        "kitchen_path": str(Path(getattr(_kitchen, "__file__", "") or "")),
    }
    return info


_PROCESS_STARTED_AT = datetime.now().astimezone().isoformat()
_BUILD_INFO = _build_info()


def _runtime_diagnostics() -> dict[str, object]:
    pillow = probe_pillow(reload=True)
    return {
        **pillow,
        "build": dict(_BUILD_INFO),
    }


def _error_response(exc: Exception, **extra: object) -> dict[str, object]:
    error_code = extra.pop("errorCode", None)
    if error_code is None and hasattr(exc, "error_code"):
        error_code = getattr(exc, "error_code", None)
    payload: dict[str, object] = {
        "ok": False,
        "error": str(exc),
        **_runtime_diagnostics(),
    }
    if error_code:
        payload["error_code"] = error_code
        payload["errorCode"] = error_code
    payload.update(extra)
    return payload


def _request_turkish_guarantee_mode(body: dict[str, object] | None) -> bool:
    raw = body or {}
    mode = str(raw.get("turkish_print_mode") or "").strip().lower()
    if mode in {"turkish_guarantee", "guarantee"}:
        return True
    return raw.get("turkish_guarantee_mode") is True


def _request_turkish_print_mode_label(body: dict[str, object] | None) -> str:
    raw = body or {}
    explicit = str(raw.get("turkish_print_mode") or "").strip()
    if explicit:
        return explicit
    if raw.get("turkish_guarantee_mode") is True:
        return "turkish_guarantee"
    return "text"


def _guess_paper_width(name: str) -> int:
    """Infer paper width (mm) from a USB product string or CUPS queue label."""
    n = (name or "").lower()
    if "58" in n:
        return 58
    if any(x in n for x in ("80", "tm-t20", "tm-t88", "tm-u", "rp80", "pos80")):
        return 80
    return 80  # safe default — text wraps rather than truncates


def _parse_hex_int(value: object) -> int | None:
    if value is None:
        return None
    raw = str(value).strip().lower()
    if not raw:
        return None
    if raw.startswith("0x"):
        raw = raw[2:]
    try:
        return int(raw, 16)
    except ValueError:
        return None


def _parse_port(value: object) -> int | None:
    if value is None:
        return None
    try:
        parsed = int(str(value).strip())
    except ValueError:
        return None
    return parsed if parsed > 0 else None


def _reload_handlers(settings: BridgeSettings) -> None:
    """Atomically swap all class-level handler state (call under _STATE_LOCK)."""
    new_transport = _SmartTransport(settings)
    new_renderer = ReceiptRenderer(settings)
    new_kitchen = KitchenRenderer(settings)
    new_document = EscPosDocumentRenderer(settings)
    new_receipt_bitmap = ReceiptBitmapRenderer(settings)
    new_kitchen_bitmap = KitchenBitmapRenderer(settings)
    new_raster_encoder = RasterEscPosEncoder(settings)
    with _STATE_LOCK:
        PrintBridgeHandler.settings = settings
        PrintBridgeHandler.transport = new_transport  # type: ignore[assignment]
        PrintBridgeHandler.renderer = new_renderer
        PrintBridgeHandler.kitchen_renderer = new_kitchen
        PrintBridgeHandler.document_renderer = new_document
        PrintBridgeHandler.receipt_bitmap_renderer = new_receipt_bitmap
        PrintBridgeHandler.kitchen_bitmap_renderer = new_kitchen_bitmap
        PrintBridgeHandler.raster_encoder = new_raster_encoder


class _SmartTransport:
    """Routes print jobs to the correct transport based on config and per-request overrides.

    Transport selection priority:
      1. Per-request ``target_host`` / ``target_port`` fields (network TCP override)
      2. Global ``transport_mode`` from BridgeSettings:
         - ``network``  → NetworkTcpTransport (settings.network_host:network_port)
         - ``usb``      → UsbDirectTransport only
         - ``cups``     → CupsRawTransport only
         - ``auto``     → USB first, fall back to CUPS
    """

    def __init__(self, settings: BridgeSettings) -> None:
        self._settings = settings
        self._spool = (
            WindowsSpoolTransport(settings.printer_queue)
            if platform.system().lower() == "windows"
            else CupsRawTransport(settings)
        )
        self._usb: UsbDirectTransport | None = None
        self._network: NetworkTcpTransport | None = None

        mode = settings.transport_mode
        if mode in {"auto", "usb", "cups"} and platform.system().lower() != "windows":
            self._usb = UsbDirectTransport(
                vendor_id=settings.usb_vendor_id,
                product_id=settings.usb_product_id,
            )
        if mode == "network" and settings.network_host:
            self._network = NetworkTcpTransport(
                host=settings.network_host,
                port=settings.network_port,
            )

    def health(self) -> dict[str, object]:
        mode = self._settings.transport_mode
        result: dict[str, object] = {"mode": mode}
        if mode == "network":
            result["network"] = (
                self._network.health() if self._network
                else {"ok": False, "reason": "PRINT_BRIDGE_NETWORK_HOST not configured."}
            )
            return result
        if mode == "cups" or self._usb is None:
            return self._spool.health()
        result["usb"] = self._usb.health()
        if mode == "auto":
            result["spool"] = self._spool.health()
        return result

    def discover(self) -> dict[str, object]:
        """Aggregate discovered devices from all active transports.

        Returns::

            {
                "usb":    [ {vendor_id, product_id, manufacturer, product, ...}, ... ],
                "cups":   [ {type, queue, label, detail}, ... ],
                "network": [],   # Network printers must be entered manually.
            }
        """
        mode = self._settings.transport_mode
        usb_devices: list[dict[str, object]] = []
        spool_printers: list[dict[str, object]] = []
        windows_printers: list[dict[str, object]] = []

        if self._usb is not None:
            try:
                usb_devices = [d.as_dict() for d in UsbDirectTransport.discover()]
            except Exception:  # noqa: BLE001
                pass

        if mode in {"auto", "cups"}:
            try:
                spool_printers = self._spool.discover()
            except Exception:  # noqa: BLE001
                pass

        if platform.system().lower() == "windows":
            windows_printers = spool_printers or discover_windows_printers()

        combined = dedupe_printers([*usb_devices, *spool_printers, *windows_printers])

        return {
            "printers": combined,
            "usb": usb_devices,
            "cups": [p for p in spool_printers if p.get("backend") == "cups"],
            "windows": [p for p in combined if p.get("backend") == "windows-spool"],
            "network": [],
        }

    def resolve_printer(
        self,
        *,
        selected_printer: dict[str, object] | None = None,
        printer_id: str | None = None,
        printer_name: str | None = None,
    ) -> dict[str, object] | None:
        if selected_printer:
            return selected_printer
        if not printer_id and not printer_name:
            return None
        discovered = self.discover().get("printers", [])
        if not isinstance(discovered, list):
            return None
        for printer in discovered:
            if not isinstance(printer, dict):
                continue
            if printer_id:
                current_id = str(printer.get("id") or "").strip()
                if current_id.lower() == str(printer_id).strip().lower():
                    return dict(printer)
            if printer_name:
                needle = str(printer_name).strip().lower()
                name = str(printer.get("name") or printer.get("displayName") or "").strip().lower()
                queue = str(printer.get("queue") or printer.get("queueName") or "").strip().lower()
                if needle in {name, queue} or needle == f"windows:{queue}":
                    return dict(printer)
        return None

    def print_bytes(
        self,
        payload: bytes,
        *,
        job_name: str,
        target_host: str | None = None,
        target_port: int | None = None,
        selected_printer: dict[str, object] | None = None,
    ) -> object:
        # Per-request network override (e.g. print to a specific IP from the job payload)
        if target_host:
            port = target_port or 9100
            LOGGER.info(
                "smart-router: per-request network TCP → %s:%d (%s)",
                target_host,
                port,
                job_name,
            )
            net = NetworkTcpTransport(host=target_host, port=port)
            return net.print_bytes(payload, job_name=job_name)

        if selected_printer:
            backend = str(selected_printer.get("backend") or "").strip().lower()
            queue = str(
                selected_printer.get("queue")
                or selected_printer.get("queueName")
                or selected_printer.get("name")
                or selected_printer.get("displayName")
                or ""
            ).strip()
            if backend == "windows-spool":
                return WindowsSpoolTransport(queue).print_bytes(payload, job_name=job_name)
            if backend == "cups":
                temp_settings = replace(self._settings, printer_queue=queue)
                return CupsRawTransport(temp_settings).print_bytes(payload, job_name=job_name)
            if backend == "usb-direct":
                vendor_id = _parse_hex_int(
                    selected_printer.get("vendorId", selected_printer.get("vid"))
                )
                product_id = _parse_hex_int(
                    selected_printer.get("productId", selected_printer.get("pid"))
                )
                return UsbDirectTransport(
                    vendor_id=vendor_id,
                    product_id=product_id,
                ).print_bytes(payload, job_name=job_name)
            if backend == "network-tcp":
                host = str(selected_printer.get("host") or "").strip()
                port = _parse_port(selected_printer.get("port")) or 9100
                if host:
                    return NetworkTcpTransport(host=host, port=port).print_bytes(
                        payload,
                        job_name=job_name,
                    )

        mode = self._settings.transport_mode

        if mode == "network":
            if self._network is None:
                raise TransportError(
                    "Transport mode is 'network' but PRINT_BRIDGE_NETWORK_HOST is not configured."
                )
            return self._network.print_bytes(payload, job_name=job_name)

        if mode == "cups" or self._usb is None:
            return self._spool.print_bytes(payload, job_name=job_name)

        # USB first (auto | usb)
        try:
            return self._usb.print_bytes(payload, job_name=job_name)
        except TransportError as exc:
            if mode == "usb":
                raise
            LOGGER.warning("USB direct failed, falling back to system spooler: %s", exc)
        return self._spool.print_bytes(payload, job_name=job_name)


def build_test_payload() -> ReceiptPayload:
    return ReceiptPayload.from_dict(
        {
            "store_name": "ÇAĞRI RESTORAN",
            "branch": "TÜRKÇE TESTİ",
            "phone": "0326 000 00 00",
            "table_no": "12",
            "datetime": datetime.now().astimezone().isoformat(),
            "items": [
                {
                    "name": "ÇĞİÖŞÜ çğıöşü Iİ ıi",
                    "qty": 1,
                    "total": "1.00",
                    "price": "1.00",
                },
                {
                    "name": "İğne, Şiş, Çorba, Kuzu Şiş, Karışık, Adisyon",
                    "qty": 1,
                    "total": "1.00",
                    "price": "1.00",
                    "note": "ğ Ğ ş Ş ı İ ç Ç ö Ö ü Ü",
                },
            ],
            "subtotal": "2.00",
            "discount": "0.00",
            "grand_total": "2.00",
            "footer_note": "Türkçe karakter testi",
        }
    )


def build_short_safe_test_payload() -> ReceiptPayload:
    """Minimal single-ticket payload to avoid endless output / driver quirks."""
    return ReceiptPayload.from_dict(
        {
            "store_name": "IBUL",
            "branch": "KISA TEST",
            "table_no": "1",
            "datetime": datetime.now().astimezone().isoformat(),
            "items": [
                {
                    "name": "TEST",
                    "qty": 1,
                    "total": "0.00",
                    "price": "0.00",
                }
            ],
            "subtotal": "0.00",
            "discount": "0.00",
            "grand_total": "0.00",
            "footer_note": "Kısa test",
        }
    )


def _platform_key() -> str:
    current = platform.system().lower()
    if current == "windows":
        return "windows"
    if current == "darwin":
        return "macos"
    return current or "unknown"


def _bridge_root_dir() -> Path:
    return Path(__file__).resolve().parent.parent


def _bridge_env_path() -> Path:
    return bridge_env_path(default_relative_to=Path(__file__))


def _macos_launch_agent_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"{_AUTOSTART_LABEL}.plist"


def _windows_startup_script_path() -> Path:
    app_data = os.getenv("APPDATA", "").strip()
    if not app_data:
        return Path.home() / "AppData" / "Roaming" / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Startup" / "ibul-local-print.cmd"
    return (
        Path(app_data)
        / "Microsoft"
        / "Windows"
        / "Start Menu"
        / "Programs"
        / "Startup"
        / "ibul-local-print.cmd"
    )


def _windows_startup_script(python_executable: str, bridge_root: Path) -> str:
    return (
        "@echo off\r\n"
        f'cd /d "{bridge_root}"\r\n'
        f'"{python_executable}" -m local_print_bridge\r\n'
    )


def _macos_launch_agent_plist(python_executable: str, bridge_root: Path) -> str:
    stdout_log = "/tmp/ibul-local-print.log"
    stderr_log = "/tmp/ibul-local-print.error.log"
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>{_AUTOSTART_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>{python_executable}</string>
    <string>-m</string>
    <string>local_print_bridge</string>
  </array>
  <key>WorkingDirectory</key>
  <string>{bridge_root}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>{stdout_log}</string>
  <key>StandardErrorPath</key>
  <string>{stderr_log}</string>
</dict>
</plist>'''


def _windows_registry_autostart_enabled() -> bool | None:
    if platform.system().lower() != "windows":
        return None
    try:
        import winreg  # noqa: PLC0415

        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
        ) as key:
            winreg.QueryValueEx(key, "IbulLocalPrintBridge")
        return True
    except OSError:
        return False


def _autostart_state(platform_name: str) -> dict[str, object]:
    if platform_name == "macos":
        path = _macos_launch_agent_path()
        return {
            "supported": True,
            "enabled": path.exists(),
            "path": str(path),
            "mode": "launch_agent",
        }
    if platform_name == "windows":
        path = _windows_startup_script_path()
        return {
            "supported": True,
            "enabled": path.exists(),
            "path": str(path),
            "mode": "startup_script",
        }
    return {
        "supported": False,
        "enabled": False,
        "path": None,
        "mode": None,
    }


def _enable_autostart(platform_name: str) -> tuple[bool, str, str | None, dict[str, object]]:
    python_executable = sys.executable or "python3"
    bridge_root = _bridge_root_dir()

    if platform_name == "macos":
        path = _macos_launch_agent_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            _macos_launch_agent_plist(python_executable, bridge_root),
            encoding="utf-8",
        )
        try:
            uid = str(os.getuid())
            subprocess.run(
                ["launchctl", "bootstrap", f"gui/{uid}", str(path)],
                capture_output=True,
                text=True,
                check=False,
            )
            subprocess.run(
                ["launchctl", "kickstart", "-k", f"gui/{uid}/{_AUTOSTART_LABEL}"],
                capture_output=True,
                text=True,
                check=False,
            )
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("setup autostart macOS activate warning: %s", exc)
        return (
            True,
            "Aktif",
            None,
            {"autostart": _autostart_state(platform_name)},
        )

    if platform_name == "windows":
        path = _windows_startup_script_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            _windows_startup_script(python_executable, bridge_root),
            encoding="utf-8",
        )
        return (
            True,
            "Aktif",
            None,
            {"autostart": _autostart_state(platform_name)},
        )

    return (False, "Pasif", "platform_not_supported", {"autostart": _autostart_state(platform_name)})


def _disable_autostart(platform_name: str) -> tuple[bool, str, str | None, dict[str, object]]:
    if platform_name == "macos":
        path = _macos_launch_agent_path()
        try:
            if path.exists():
                uid = str(os.getuid())
                subprocess.run(
                    ["launchctl", "bootout", f"gui/{uid}", str(path)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                path.unlink(missing_ok=True)
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("setup autostart macOS deactivate warning: %s", exc)
        return (
            True,
            "Pasif",
            None,
            {"autostart": _autostart_state(platform_name)},
        )

    if platform_name == "windows":
        path = _windows_startup_script_path()
        path.unlink(missing_ok=True)
        return (
            True,
            "Pasif",
            None,
            {"autostart": _autostart_state(platform_name)},
        )

    return (False, "Pasif", "platform_not_supported", {"autostart": _autostart_state(platform_name)})


def _setup_payload(
    *,
    step: str,
    status: str,
    message: str,
    error_code: str | None = None,
    action_required: str | None = None,
    platform_name: str | None = None,
    ok: bool | None = None,
    **extra: object,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "ok": ok if ok is not None else error_code is None,
        "step": step,
        "status": status,
        "message": message,
        "errorCode": error_code,
        "platform": platform_name or _platform_key(),
        "actionRequired": action_required,
    }
    payload.update(extra)
    return payload


def _collect_setup_snapshot(
    *,
    settings: BridgeSettings,
    transport: _SmartTransport,
) -> dict[str, object]:
    platform_name = _platform_key()
    actual_health = transport.health()
    discovered = transport.discover()
    printers = discovered.get("printers", [])
    if not isinstance(printers, list):
        printers = []

    cups_available = bool(shutil.which("lp"))
    cups_status = "available" if cups_available else "missing"
    pywin32_available = _import_win32print() is not None if platform_name == "windows" else False
    windows_inventory_ok = True
    if platform_name == "windows":
        try:
            discover_windows_printers()
        except Exception:  # noqa: BLE001
            windows_inventory_ok = False

    driver_missing = any(str(p.get("errorCode") or "") == "driver_missing" for p in printers)
    printer_offline = any(
        str(p.get("statusLevel") or "") == "error"
        and str(p.get("errorCode") or "") in {"printer_unavailable", "driver_missing"}
        for p in printers
    )

    bridge_installed = _bridge_env_path().exists() or _bridge_root_dir().joinpath("local_print_bridge").exists()
    bridge_running = True

    if platform_name == "windows":
        checks = [
            {
                "key": "bridge_installed",
                "label": "Bridge kurulu",
                "ok": bridge_installed,
                "status": "ready" if bridge_installed else "setup_required",
                "message": "Yazıcı servisi kurulu." if bridge_installed else "Yazıcı servisi kurulmalı.",
            },
            {
                "key": "bridge_running",
                "label": "Bridge çalışıyor",
                "ok": bridge_running,
                "status": "ready" if bridge_running else "bridge_not_running",
                "message": "Yazıcı servisi açık." if bridge_running else "Yazıcı servisi kapalı.",
            },
            {
                "key": "pywin32",
                "label": "Windows baskı bileşeni",
                "ok": pywin32_available,
                "status": "ready" if pywin32_available else "setup_required",
                "message": "Windows baskı bileşeni hazır." if pywin32_available else "Windows baskı bileşeni eksik.",
            },
            {
                "key": "spooler",
                "label": "Windows yazıcı erişimi",
                "ok": windows_inventory_ok,
                "status": "ready" if windows_inventory_ok else "bridge_not_running",
                "message": "Windows yazıcı listesi okunabildi." if windows_inventory_ok else "Windows yazıcı listesi okunamadı.",
            },
        ]
    else:
        checks = [
            {
                "key": "bridge_installed",
                "label": "Bridge kurulu",
                "ok": bridge_installed,
                "status": "ready" if bridge_installed else "setup_required",
                "message": "Yazıcı servisi kurulu." if bridge_installed else "Yazıcı servisi kurulmalı.",
            },
            {
                "key": "bridge_running",
                "label": "Bridge çalışıyor",
                "ok": bridge_running,
                "status": "ready" if bridge_running else "bridge_not_running",
                "message": "Yazıcı servisi açık." if bridge_running else "Yazıcı servisi kapalı.",
            },
            {
                "key": "cups",
                "label": "macOS baskı sistemi",
                "ok": cups_available,
                "status": "ready" if cups_available else "setup_required",
                "message": "macOS baskı sistemi hazır." if cups_available else "macOS baskı sistemi bulunamadı.",
            },
        ]

    if driver_missing:
        status = "driver_missing"
        message = "Windows yazıcı sürücüsü eksik. Yazıcı önce işletim sistemine kurulmalı."
        error_code = "driver_missing"
        action_required = "driver_help"
    elif not bridge_installed:
        status = "setup_required"
        message = "Yazıcı servisi kurulmalı."
        error_code = "bridge_install_required"
        action_required = "install_bridge"
    elif not bridge_running:
        status = "bridge_not_running"
        message = "Yazıcı servisi kapalı."
        error_code = "bridge_not_running"
        action_required = "start_bridge"
    elif printer_offline:
        status = "printer_offline"
        message = "Yazıcı çevrimdışı veya hazır değil."
        error_code = "printer_offline"
        action_required = "check_printer"
    elif not printers:
        status = "setup_required"
        message = "Yazıcı bulunamadı. Kurulum gerekli."
        error_code = "printer_not_found"
        action_required = "detect_printer"
    else:
        status = "ready"
        message = "Sistem yazıcı kurulumuna hazır."
        error_code = None
        action_required = "detect_printer"

    return {
        "platform": platform_name,
        "status": status,
        "message": message,
        "errorCode": error_code,
        "actionRequired": action_required,
        "checks": checks,
        "printers": printers,
        "health": actual_health,
        "bridgeInstalled": bridge_installed,
        "bridgeRunning": bridge_running,
        "autostart": _autostart_state(platform_name),
        "settings": settings.as_dict(),
        "dependencies": {
            "pywin32": pywin32_available,
            "cups": cups_status,
        },
    }


def _auto_setup_bridge(
    *,
    settings: BridgeSettings,
    transport: _SmartTransport,
) -> tuple[HTTPStatus, dict[str, object]]:
    try:
        discovered = transport.discover()
    except Exception as exc:  # noqa: BLE001
        LOGGER.exception("Setup: discover failed")
        return (
            HTTPStatus.INTERNAL_SERVER_ERROR,
            _setup_payload(
                step="install",
                status="bridge_not_running",
                message="Sistem kontrolü tamamlanamadı.",
                error_code="discover_failed",
                action_required="retry",
                ok=False,
                technicalDetails={"error": str(exc)},
            ),
        )

    printers = discovered.get("printers", [])
    if not isinstance(printers, list):
        printers = []
    if any(str(p.get("errorCode") or "") == "driver_missing" for p in printers):
        return (
            HTTPStatus.CONFLICT,
            _setup_payload(
                step="install",
                status="driver_missing",
                message="Windows yazıcı sürücüsü eksik. Yazıcı önce işletim sistemine kurulmalı.",
                error_code="driver_missing",
                action_required="driver_help",
                ok=False,
                printers=printers,
            ),
        )

    usb_devices = discovered.get("usb", [])
    cups_queues = discovered.get("cups", [])
    windows_printers = discovered.get("windows", [])

    if not usb_devices and not cups_queues and not windows_printers:
        return (
            HTTPStatus.NOT_FOUND,
            _setup_payload(
                step="install",
                status="setup_required",
                message="Yazıcı bulunamadı. Yazıcının açık ve bağlı olduğundan emin olun.",
                error_code="printer_not_found",
                action_required="connect_printer",
                ok=False,
                printers=[],
            ),
        )

    if usb_devices:
        device = usb_devices[0]
        product_name = device.get("product") or device.get("manufacturer") or "USB Yazıcı"
        paper_width = _guess_paper_width(str(product_name))
        env_updates = {
            "PRINT_BRIDGE_TRANSPORT": "auto",
            "PRINT_BRIDGE_USB_VENDOR_ID": str(device.get("vid", "")),
            "PRINT_BRIDGE_USB_PRODUCT_ID": str(device.get("pid", "")),
            "PRINT_BRIDGE_PAPER_WIDTH_MM": str(paper_width),
            "PRINT_BRIDGE_CHARS_PER_LINE": "32" if paper_width <= 58 else "48",
        }
        detected = {
            "type": "usb-direct",
            "name": product_name,
            "paper_width_mm": paper_width,
            "vid": device.get("vid"),
            "pid": device.get("pid"),
        }
    elif windows_printers:
        printer = windows_printers[0]
        queue = str(printer.get("queue") or printer.get("name") or "Windows Printer")
        paper_width = _guess_paper_width(queue)
        env_updates = {
            "PRINT_BRIDGE_TRANSPORT": "cups",
            "PRINT_BRIDGE_PRINTER_QUEUE": queue,
            "PRINT_BRIDGE_PAPER_WIDTH_MM": str(paper_width),
            "PRINT_BRIDGE_CHARS_PER_LINE": "32" if paper_width <= 58 else "48",
        }
        detected = {
            "type": "windows-spool",
            "name": queue,
            "paper_width_mm": paper_width,
            "queue": queue,
        }
    else:
        queue_info = cups_queues[0]
        queue = str(queue_info.get("queue") or "")
        label = queue_info.get("name") or queue_info.get("label") or queue
        paper_width = _guess_paper_width(str(label))
        env_updates = {
            "PRINT_BRIDGE_TRANSPORT": "cups",
            "PRINT_BRIDGE_PRINTER_QUEUE": queue,
            "PRINT_BRIDGE_PAPER_WIDTH_MM": str(paper_width),
            "PRINT_BRIDGE_CHARS_PER_LINE": "32" if paper_width <= 58 else "48",
        }
        detected = {
            "type": "cups",
            "name": label,
            "paper_width_mm": paper_width,
            "queue": queue,
        }

    try:
        write_env_file(env_updates)
        new_settings = BridgeSettings.from_env()
        _reload_handlers(new_settings)
    except Exception as exc:  # noqa: BLE001
        LOGGER.exception("Setup: config write/reload failed")
        return (
            HTTPStatus.INTERNAL_SERVER_ERROR,
            _setup_payload(
                step="install",
                status="bridge_not_running",
                message="Kurulum tamamlanamadı.",
                error_code="configure_failed",
                action_required="retry",
                ok=False,
                technicalDetails={"error": str(exc)},
            ),
        )

    LOGGER.info("Auto-setup complete: %s", detected)
    return (
        HTTPStatus.OK,
        _setup_payload(
            step="install",
            status="ready",
            message="Yazıcı servisi hazırlandı.",
            action_required="detect_printer",
            detected=detected,
            settings=new_settings.as_dict(),
        ),
    )


def _release_usb_printers() -> tuple[HTTPStatus, dict[str, object]]:
    if platform.system().lower() != "darwin":
        return (
            HTTPStatus.BAD_REQUEST,
            {
                "ok": False,
                "error": "USB printer release is only supported on macOS.",
                "platform": _platform_key(),
            },
        )

    try:
        result = subprocess.run(
            ["killall", "-USR1", "cupsd"],
            capture_output=True,
            text=True,
            check=False,
        )
    except Exception as exc:  # noqa: BLE001
        LOGGER.exception("USB printer release failed")
        return (
            HTTPStatus.INTERNAL_SERVER_ERROR,
            {
                "ok": False,
                "error": f"Failed to restart cupsd: {exc}",
                "platform": _platform_key(),
            },
        )

    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()
    if result.returncode != 0:
        LOGGER.warning(
            "USB printer release returned non-zero exit code=%s stderr=%s",
            result.returncode,
            stderr or "-",
        )
        return (
            HTTPStatus.INTERNAL_SERVER_ERROR,
            {
                "ok": False,
                "error": stderr or stdout or "killall -USR1 cupsd failed.",
                "exit_code": result.returncode,
                "platform": _platform_key(),
            },
        )

    time.sleep(0.5)
    LOGGER.info("USB printer release requested via cupsd restart")
    payload: dict[str, object] = {
        "ok": True,
        "released": True,
        "platform": _platform_key(),
        "command": "killall -USR1 cupsd",
        "wait_ms": 500,
    }
    if stdout:
        payload["stdout"] = stdout
    if stderr:
        payload["stderr"] = stderr
    return (
        HTTPStatus.OK,
        payload,
    )


class PrintBridgeHandler(BaseHTTPRequestHandler):
    server_version = "IBULPrintBridge/0.1"

    settings = BridgeSettings.from_env()
    renderer = ReceiptRenderer(settings)
    kitchen_renderer = KitchenRenderer(settings)
    document_renderer = EscPosDocumentRenderer(settings)
    receipt_bitmap_renderer = ReceiptBitmapRenderer(settings)
    kitchen_bitmap_renderer = KitchenBitmapRenderer(settings)
    raster_encoder = RasterEscPosEncoder(settings)
    transport: _SmartTransport = _SmartTransport(settings)  # type: ignore[assignment]
    log_store = PrintLogStore()
    queue_manager = PrintQueueManager()
    print_station_consumer: PrintStationConsumer | None = None
    _test_guard_lock = threading.Lock()
    _test_guard_last_sent_at: dict[str, float] = {}

    def do_OPTIONS(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return
        self._send_json(HTTPStatus.NO_CONTENT, None)

    def do_GET(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return

        request_path = self._request_path()

        if request_path == "/health":
            self._handle_health()
            return
        if request_path == "/queue/status":
            self._handle_queue_status()
            return
        if request_path == "/diagnostics":
            self._handle_diagnostics()
            return
        if request_path == "/warmup":
            self._handle_warmup()
            return
        if request_path == "/printers":
            self._handle_printers()
            return
        if request_path == "/print/logs":
            self._handle_print_logs()
            return
        if request_path == "/print/logs/recent":
            self._handle_recent_print_logs()
            return
        if request_path == "/discover":
            self._handle_discover()
            return
        if request_path == "/setup/status":
            self._handle_setup_status()
            return
        if request_path == "/setup/prerequisites":
            self._handle_setup_prerequisites()
            return
        if request_path == "/setup/driver-help":
            self._handle_setup_driver_help()
            return
        if request_path == "/spool/snapshot":
            self._handle_spool_snapshot()
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "Not found."})

    def do_POST(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return

        request_path = self._request_path()

        if request_path == "/print/test":
            self._handle_print_test()
            return
        if request_path == "/print/test/turkish":
            self._handle_print_turkish_test()
            return
        if request_path == "/print/test/turkish-encoding":
            self._handle_print_turkish_encoding_calibration()
            return
        if request_path == "/print":
            self._handle_print()
            return
        if request_path == "/print/receipt":
            self._handle_print_receipt()
            return
        if request_path == "/print/kitchen":
            self._handle_print_kitchen()
            return
        if request_path == "/queue/clear":
            self._handle_queue_clear()
            return
        if request_path == "/system/release-usb-printers":
            self._handle_release_usb_printers()
            return
        if request_path == "/setup":
            self._handle_setup()
            return
        if request_path == "/configure":
            self._handle_configure()
            return
        if request_path == "/configure/print-station":
            self._handle_configure_print_station()
            return
        if request_path == "/setup/install":
            self._handle_setup_install()
            return
        if request_path == "/setup/start":
            self._handle_setup_start()
            return
        if request_path == "/setup/enable-autostart":
            self._handle_enable_autostart()
            return
        if request_path == "/setup/disable-autostart":
            self._handle_disable_autostart()
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "Not found."})

    def _handle_queue_clear(self) -> None:
        body = self._maybe_read_json_body() or {}
        queue = str(body.get("queue") or self.settings.printer_queue or "").strip()
        if not queue:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"ok": False, "errorCode": "queue_missing", "error": "CUPS kuyruğu seçili değil."},
            )
            return
        try:
            status = None
            if hasattr(self.transport, "_spool") and hasattr(self.transport._spool, "clear_queue"):
                result = self.transport._spool.clear_queue(queue)
                status = result.get("queue_status") if isinstance(result, dict) else None
            else:
                result = {"ok": False, "error": "CUPS spool transport not available."}
            self._send_json(
                HTTPStatus.OK if result.get("ok") else HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "ok": bool(result.get("ok")),
                    "queue": queue,
                    "result": result,
                    "queue_status": status,
                },
            )
        except Exception as exc:  # pragma: no cover
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "errorCode": "queue_clear_failed", "error": str(exc)},
            )

    def log_message(self, format: str, *args: object) -> None:
        LOGGER.info("%s - %s", self.address_string(), format % args)

    def _handle_spool_snapshot(self) -> None:
        from urllib.parse import parse_qs, urlparse

        from .windows_transport import peek_windows_spool_jobs

        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        printer_name = str(
            (params.get("printer_name") or params.get("queue") or [""])[0]
        ).strip()
        if not printer_name:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {
                    "ok": False,
                    "errorCode": "printer_name_required",
                    "error": "printer_name query parameter is required.",
                },
            )
            return
        if platform.system().lower() != "windows":
            self._send_json(
                HTTPStatus.OK,
                {
                    "ok": False,
                    "printer_name": printer_name,
                    "reason": "windows_only",
                },
            )
            return
        snapshot = peek_windows_spool_jobs(printer_name)
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": snapshot.get("ok") is True,
                "printer_name": printer_name,
                **snapshot,
            },
        )

    def _handle_health(self) -> None:
        queue_summary = self.queue_manager.summary()
        pillow = probe_pillow(reload=True)
        platform_name = platform.system().lower()
        setup_platform = (
            "macos"
            if platform_name == "darwin"
            else "windows"
            if platform_name == "windows"
            else platform_name
        )
        autostart = _autostart_state(setup_platform)
        autostart_enabled = autostart.get("enabled") is True
        if setup_platform == "windows":
            registry_autostart = _windows_registry_autostart_enabled()
            if registry_autostart is True:
                autostart_enabled = True
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "service": "ibul-local-print-bridge",
                "build": _BUILD_INFO,
                "bridge_version": str(_BUILD_INFO.get("bridge_version") or "dev"),
                "pillow_available": pillow.get("pillow_available") is True,
                "pillow_version": pillow.get("pillow_version"),
                "pillow_module": pillow.get("pillow_module"),
                "pillow_import_error": pillow.get("import_error"),
                "python_executable": pillow.get("python_executable") or sys.executable,
                "python_version": pillow.get("python_version") or platform.python_version(),
                "default_queue": self.settings.printer_queue,
                "service_mode": _app_mode(),
                "autostart_enabled": autostart_enabled,
                "transport_mode": self.settings.transport_mode,
                "printer_queue": self.settings.printer_queue,
                "paper_width_mm": self.settings.paper_width_mm,
                "chars_per_line": self.settings.chars_per_line,
                "encoding": self.settings.encoding,
                "codepage": self.settings.codepage,
                "render_mode": self.settings.render_mode,
                "bundled_font": bundled_mono_font_status(),
                "raster_chunk_height": self.settings.raster_chunk_height,
                "network_host": self.settings.network_host or None,
                "network_port": self.settings.network_port,
                "allowed_origins": list(self.settings.allowed_origins),
                "printer": self.transport.health(),
                "queue": queue_summary,
                "print_station": self._queue_status_payload(),
                "log_count": self.log_store.count(),
            },
        )

    def _handle_queue_status(self) -> None:
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "queue": self._queue_status_payload(),
            },
        )

    def _request_printer_backend(self, body: dict[str, object] | None) -> str:
        raw_body = body or {}
        embedded = raw_body.get("printer")
        if isinstance(embedded, dict):
            backend = str(embedded.get("backend") or "").strip().lower()
            if backend:
                return backend
        return str(raw_body.get("printer_backend") or "").strip().lower()

    def _request_printer_queue(self, body: dict[str, object] | None) -> str:
        raw_body = body or {}
        embedded = raw_body.get("printer")
        if isinstance(embedded, dict):
            queue = str(
                embedded.get("queue")
                or embedded.get("queueName")
                or embedded.get("name")
                or embedded.get("displayName")
                or ""
            ).strip()
            if queue:
                return queue
        return str(
            raw_body.get("printer_queue")
            or raw_body.get("queueName")
            or raw_body.get("printer_name")
            or raw_body.get("printerName")
            or ""
        ).strip()

    def _log_print_test_request(
        self,
        *,
        raw_body: dict[str, object] | None,
        selected_printer: dict[str, object] | None,
    ) -> None:
        body = raw_body or {}
        embedded_printer = body.get("printer") if isinstance(body.get("printer"), dict) else None
        printer_id = str(body.get("printer_id") or body.get("printerId") or "").strip() or "-"
        printer_name = str(
            body.get("printer_name")
            or body.get("printerName")
            or body.get("printer_queue")
            or body.get("queueName")
            or ""
        ).strip() or "-"
        request_backend = self._request_printer_backend(body) or "-"
        request_queue = self._request_printer_queue(body) or "-"
        vendor_id = str(body.get("vendorId") or body.get("vendor_id") or "").strip() or "-"
        product_id = str(body.get("productId") or body.get("product_id") or "").strip() or "-"
        render_mode = str(body.get("render_mode") or "").strip() or "-"
        codepage = str(body.get("codepage") or "").strip() or "-"
        document_type = str(body.get("document_type") or "test").strip() or "test"
        spool_mode = str(body.get("spool_mode") or "RAW").strip() or "RAW"
        LOGGER.info(
            "flutter-request-payload: printer_id=%s printer_name=%s embedded_printer=%s backend=%s queue=%s vendorId=%s productId=%s render_mode=%s codePage=%s document_type=%s spool_mode=%s",
            printer_id,
            printer_name,
            json.dumps(embedded_printer, ensure_ascii=False, sort_keys=True)
            if embedded_printer is not None
            else "-",
            request_backend,
            request_queue,
            vendor_id,
            product_id,
            render_mode,
            codepage,
            document_type,
            spool_mode,
        )
        selected_backend = str(selected_printer.get("backend") or "").strip().lower() if selected_printer else ""
        selected_queue = str(
            selected_printer.get("queue")
            or selected_printer.get("queueName")
            or selected_printer.get("name")
            or selected_printer.get("displayName")
            or ""
        ).strip() if selected_printer else ""
        LOGGER.info(
            "bridge-selected-backend: received_printer_id=%s received_printer_name=%s selected_backend=%s selected_queue=%s transport=%s",
            printer_id,
            printer_name,
            selected_backend or "-",
            selected_queue or "-",
            "USB" if selected_backend == "usb-direct" else "CUPS" if selected_backend == "cups" else selected_backend or "-",
        )

    def _handle_diagnostics(self) -> None:
        diagnostics = build_diagnostics(
            settings=self.settings,
            transport=self.transport,
            queue_summary=self.queue_manager.summary(),
            log_count=self.log_store.count(),
        )
        self._send_json(HTTPStatus.OK, diagnostics)

    def _handle_warmup(self) -> None:
        """GET /warmup — full pipeline warm-up for cold-start elimination.

        Exercises every lazy-init path so the first real print has zero
        cold-start penalty:
          1. Font cache pre-load (all kitchen ticket sizes)
          2. USB endpoint verification / re-warm
          3. Dummy Pillow render (exercises Image.new + ImageDraw)
          4. Renderer instance construction
        Returns timing breakdown so the Dart hub can log readiness.
        """
        import time as _time

        timings: dict[str, int] = {}
        t0 = _time.monotonic()

        # 1. Font cache
        t1 = _time.monotonic()
        try:
            fonts_loaded = warm_font_cache()
        except Exception as exc:
            LOGGER.warning("warmup: font cache failed: %s", exc)
            fonts_loaded = -1
        timings["font_cache_ms"] = int((_time.monotonic() - t1) * 1000)

        # 2. USB endpoint verify / re-warm
        t2 = _time.monotonic()
        usb_ok = False
        try:
            _warm_usb_endpoint(self.transport)
            usb_ok = True
        except Exception as exc:
            LOGGER.warning("warmup: USB re-warm failed: %s", exc)
        timings["usb_warm_ms"] = int((_time.monotonic() - t2) * 1000)

        # 3. Dummy Pillow render (tiny 8×8 image)
        t3 = _time.monotonic()
        pillow_ok = False
        try:
            from PIL import Image as _Img, ImageDraw as _Draw

            img = _Img.new("1", (8, 8), color=1)
            draw = _Draw.Draw(img)
            draw.text((0, 0), "X", fill=0)
            _ = img.tobytes("raw", "1")
            pillow_ok = True
        except Exception as exc:
            LOGGER.warning("warmup: Pillow render failed: %s", exc)
        timings["pillow_warm_ms"] = int((_time.monotonic() - t3) * 1000)

        # 4. Renderer instances (ensures class-level caches are valid)
        t4 = _time.monotonic()
        try:
            _ = self.kitchen_bitmap_renderer
            _ = self.raster_encoder
        except Exception:
            pass
        timings["renderer_check_ms"] = int((_time.monotonic() - t4) * 1000)

        timings["total_warmup_ms"] = int((_time.monotonic() - t0) * 1000)

        LOGGER.info(
            "warmup: fonts_loaded=%d usb_ok=%s pillow_ok=%s timings=%s",
            fonts_loaded,
            usb_ok,
            pillow_ok,
            timings,
        )
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "warmed": True,
                "fonts_loaded": fonts_loaded,
                "usb_ok": usb_ok,
                "pillow_ok": pillow_ok,
                "timings": timings,
            },
        )

    def _handle_printers(self) -> None:
        try:
            result = self.transport.discover()
            printers = result.get("printers", [])
            self._send_json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "count": len(printers) if isinstance(printers, list) else 0,
                    "printers": printers if isinstance(printers, list) else [],
                    "queue": self.queue_manager.summary(),
                },
            )
        except Exception as exc:  # pragma: no cover
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": str(exc)},
            )

    def _handle_print_logs(self) -> None:
        entries = self.log_store.read_all()
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "count": len(entries),
                "logs": entries,
            },
        )

    def _handle_recent_print_logs(self) -> None:
        query = self._query_params()
        limit_raw = query.get("limit", ["50"])
        try:
            limit = max(1, min(200, int(limit_raw[0])))
        except (TypeError, ValueError):
            limit = 50
        entries = self.log_store.read_recent(limit=limit)
        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "count": len(entries),
                "logs": entries,
            },
        )

    def _handle_discover(self) -> None:
        try:
            result = self.transport.discover()
            printers = result.get("printers", [])
            usb_devices = result.get("usb", [])
            cups_queues = result.get("cups", [])
            total = len(printers) if isinstance(printers, list) else len(usb_devices) + len(cups_queues)
            self._send_json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "count": total,
                    "printers": printers,
                    "devices": usb_devices,   # legacy field — USB only, kept for compat
                    "usb": usb_devices,
                    "cups": cups_queues,
                    "windows": result.get("windows", []),
                    "network": [],
                },
            )
        except Exception as exc:  # pragma: no cover
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": str(exc)},
            )

    def _handle_print_test(self) -> None:
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi şu anda kapalı. Yazıcı Ayarları > Baskı Sistemi > Aç butonunu kullanın.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        raw_body = dict(self._maybe_read_json_body() or {})
        test_mode = str(raw_body.get("test_mode") or raw_body.get("mode") or "escpos_short").strip().lower()
        if test_mode in {"escpos_short", "escpos_text", "escpos", "raw", "text"}:
            raw_body["render_mode"] = "text"
            raw_body.setdefault("test_mode", "escpos_short")
        elif test_mode in {"bitmap", "image", "turkish"}:
            raw_body["render_mode"] = "image"
        payload = build_short_safe_test_payload() if test_mode == "escpos_short" else build_test_payload()
        target_host, target_port = self._extract_target(raw_body)
        selected_printer = self._resolve_selected_printer(raw_body)
        self._log_print_test_request(
            raw_body=raw_body,
            selected_printer=selected_printer,
        )
        printer_id, _printer_name, transport_type = self._printer_identity(
            selected_printer=selected_printer,
            settings=self.settings,
            target_host=target_host,
            target_port=target_port,
        )
        guard_key = f"{transport_type}:{printer_id}:{test_mode}"
        now = time.monotonic()
        with self._test_guard_lock:
            last = self._test_guard_last_sent_at.get(guard_key, 0.0)
            if now - last < 5.0:
                self._send_json(
                    HTTPStatus.TOO_MANY_REQUESTS,
                    {
                        "ok": False,
                        "errorCode": "duplicate_test_suppressed",
                        "error": "Test çok sık gönderildi. 5 saniye bekleyip tekrar deneyin.",
                        "cooldown_seconds": 5,
                    },
                )
                return
            self._test_guard_last_sent_at[guard_key] = now
        selected_backend = ""
        if selected_printer:
            selected_backend = str(selected_printer.get("backend") or "").strip().lower()
        fast_test = test_mode in {"escpos_short", "escpos_text", "escpos", "raw", "text"} and (
            selected_backend == "windows-spool" or selected_backend == ""
        )
        self._submit_receipt(
            payload,
            job_name="ibul-test-receipt" if test_mode != "bitmap" else "ibul-test-bitmap",
            raw_request=raw_body,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
            require_physical_confirmation=not fast_test,
        )

    def _handle_print_turkish_encoding_calibration(self) -> None:
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi şu anda kapalı.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        raw_body = dict(self._maybe_read_json_body() or {})
        raw_body["render_mode"] = "text"
        raw_body.setdefault("test_mode", "turkish_encoding")
        encoding = str(raw_body.get("encoding") or "cp857").strip()
        codepage_raw = raw_body.get("code_page", raw_body.get("codepage"))
        try:
            codepage = int(codepage_raw) if codepage_raw is not None else 13
        except (TypeError, ValueError):
            codepage = 13
        label = str(raw_body.get("label") or f"{encoding} / ESC t {codepage}").strip()
        sample_lines = raw_body.get("sample_lines")
        if isinstance(sample_lines, list) and sample_lines:
            lines_tuple = tuple(str(line) for line in sample_lines if str(line).strip())
        else:
            from .receipt import TURKISH_TEST_LINES

            lines_tuple = TURKISH_TEST_LINES
        candidates_raw = raw_body.get("candidates")
        combined = raw_body.get("combined") is True or str(
            raw_body.get("calibration_mode") or ""
        ).strip().lower() in {"combined", "sheet", "all"}
        target_host, target_port = self._extract_target(raw_body)
        selected_printer = self._resolve_selected_printer(raw_body)
        self._log_print_test_request(
            raw_body=raw_body,
            selected_printer=selected_printer,
        )
        profile, effective_settings = self._resolve_request_profile(
            {
                **raw_body,
                "encoding": encoding,
                "codepage": codepage,
                "printer_encoding": encoding,
                "printer_code_page": codepage,
            },
            job_name="ibul-turkish-encoding-calibration",
        )
        from .receipt import (
            render_turkish_encoding_calibration_ticket,
            render_turkish_encoding_combined_calibration_ticket,
        )

        calibration_mode = "single"
        candidate_count = 1
        if combined or (
            isinstance(candidates_raw, list) and len(candidates_raw) > 0
        ):
            candidates: list[dict[str, object]] = []
            if isinstance(candidates_raw, list):
                for entry in candidates_raw:
                    if isinstance(entry, dict):
                        candidates.append(dict(entry))
            if not candidates:
                candidates = [
                    {
                        "index": index + 1,
                        "encoding": encoding,
                        "code_page": codepage,
                        "line": f"[{index + 1}] {encoding} / ESC t {codepage}: {lines_tuple[0]}",
                    }
                ]
            test_line = str(raw_body.get("test_line") or lines_tuple[0]).strip()
            raw_bytes, unsupported_chars = render_turkish_encoding_combined_calibration_ticket(
                effective_settings,
                candidates=candidates,
                test_line=test_line,
            )
            text_length = sum(len(str(c.get("line") or "")) for c in candidates)
            label = "combined_turkish_encoding"
            calibration_mode = "combined"
            candidate_count = len(candidates)
        else:
            raw_bytes, unsupported_chars = render_turkish_encoding_calibration_ticket(
                effective_settings,
                encoding=profile.encoding,
                codepage=profile.codepage or codepage,
                label=label,
                sample_lines=lines_tuple,
            )
            text_length = len("".join(lines_tuple))
        _, printer_name_log, _ = self._printer_identity(
            selected_printer=selected_printer,
            settings=effective_settings,
            target_host=target_host,
            target_port=target_port,
        )
        if unsupported_chars:
            LOGGER.warning(
                "turkish_encoding_unsupported: printer_name=%s encoding=%s codepage=%s "
                "unsupported_chars=%s bytes_sent=%d",
                printer_name_log,
                profile.encoding,
                profile.codepage,
                "".join(unsupported_chars),
                len(raw_bytes),
            )
        self._submit_bytes(
            raw_bytes,
            job_name="ibul-turkish-encoding-calibration",
            profile=profile,
            settings=effective_settings,
            raw_request=raw_body,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
            document_type="test",
            require_physical_confirmation=False,
            extra_response={
                "render_mode": "text",
                "encoding": profile.encoding,
                "codepage": profile.codepage,
                "codepage_command": f"ESC t {profile.codepage or codepage}",
                "text_length": text_length,
                "calibration_label": label,
                "calibration_mode": calibration_mode,
                "candidate_count": candidate_count,
                "unsupported_chars": unsupported_chars,
            },
        )

    def _handle_print_turkish_test(self) -> None:
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi şu anda kapalı. Yazıcı Ayarları > Baskı Sistemi > Aç butonunu kullanın.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        raw_body = self._maybe_read_json_body() or {}
        payload = build_test_payload()
        raw_body["render_mode"] = "image"
        raw_body["test_mode"] = str(raw_body.get("test_mode") or "bitmap")
        target_host, target_port = self._extract_target(raw_body)
        selected_printer = self._resolve_selected_printer(raw_body)
        self._log_print_test_request(
            raw_body=raw_body,
            selected_printer=selected_printer,
        )
        self._submit_receipt(
            payload,
            job_name="ibul-turkish-bitmap-test",
            raw_request=raw_body,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
            require_physical_confirmation=True,
        )

    def _handle_print(self) -> None:
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi kapalı. Sipariş kaydedilir ancak fiş yazdırılmaz.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        try:
            raw_payload = self._read_json_body()
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "Invalid JSON body."})
            return
        except PayloadError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
            return

        target_host, target_port = self._extract_target(raw_payload)
        selected_printer = self._resolve_selected_printer(raw_payload)

        if "raw_base64" in raw_payload or "raw" in raw_payload:
            raw_value = raw_payload.get("raw_base64", raw_payload.get("raw"))
            try:
                raw_bytes = base64.b64decode(str(raw_value), validate=True)
            except (ValueError, TypeError) as exc:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": f"`raw_base64` is not valid base64: {exc}"},
                )
                return
            profile, effective_settings = self._resolve_request_profile(
                raw_payload,
                job_name=str(raw_payload.get("job_name") or "ibul-raw-print"),
            )
            self._submit_bytes(
                raw_bytes,
                job_name=str(raw_payload.get("job_name") or "ibul-raw-print"),
                profile=profile,
                settings=effective_settings,
                raw_request=raw_payload,
                target_host=target_host,
                target_port=target_port,
                selected_printer=selected_printer,
                extra_response={"render_mode": "raw"},
            )
            return

        if "raw_hex" in raw_payload:
            raw_hex = str(raw_payload.get("raw_hex") or "").strip().replace(" ", "")
            try:
                raw_bytes = bytes.fromhex(raw_hex)
            except ValueError as exc:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": f"`raw_hex` is not valid hexadecimal: {exc}"},
                )
                return
            profile, effective_settings = self._resolve_request_profile(
                raw_payload,
                job_name=str(raw_payload.get("job_name") or "ibul-raw-print"),
            )
            self._submit_bytes(
                raw_bytes,
                job_name=str(raw_payload.get("job_name") or "ibul-raw-print"),
                profile=profile,
                settings=effective_settings,
                raw_request=raw_payload,
                target_host=target_host,
                target_port=target_port,
                selected_printer=selected_printer,
                extra_response={"render_mode": "raw"},
            )
            return

        if "document" in raw_payload:
            try:
                profile, effective_settings = self._resolve_request_profile(
                    raw_payload,
                    job_name=str(raw_payload.get("job_name") or "ibul-document-print"),
                )
                raw_bytes = EscPosDocumentRenderer(effective_settings).render(raw_payload["document"])
            except DocumentPayloadError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                return
            self._submit_bytes(
                raw_bytes,
                job_name=str(raw_payload.get("job_name") or "ibul-document-print"),
                profile=profile,
                settings=effective_settings,
                raw_request=raw_payload,
                target_host=target_host,
                target_port=target_port,
                selected_printer=selected_printer,
                extra_response={"render_mode": "document"},
            )
            return

        if "receipt" in raw_payload:
            try:
                receipt_body = raw_payload["receipt"]
                if isinstance(receipt_body, dict):
                    LOGGER.info(
                        "[BRIDGE_RECEIPT_TABLE_LABEL] wrapped.raw.table_no=%s wrapped.raw.table_number=%s "
                        "wrapped.raw.area_table_number=%s wrapped.raw.table_area_name=%s wrapped.raw.area_name=%s "
                        "wrapped.raw.display_table_label=%s wrapped.raw.table_display_name=%s wrapped.raw.table_name=%s",
                        receipt_body.get("table_no", ""),
                        receipt_body.get("table_number", ""),
                        receipt_body.get("area_table_number", ""),
                        receipt_body.get("table_area_name", ""),
                        receipt_body.get("area_name", ""),
                        receipt_body.get("display_table_label", ""),
                        receipt_body.get("table_display_name", ""),
                        receipt_body.get("table_name", ""),
                    )
                payload = ReceiptPayload.from_dict(receipt_body)
            except PayloadError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                return
            LOGGER.info(
                "[BRIDGE_RECEIPT_TABLE_LABEL] wrapped.parsed.table_no=%s wrapped.parsed.table_name=%s wrapped.parsed.table_area_name=%s",
                payload.table_no,
                payload.table_name,
                payload.table_area_name,
            )
            self._submit_receipt(
                payload,
                job_name=str(raw_payload.get("job_name") or f"adisyon-masa-{payload.table_no}"),
                raw_request=raw_payload,
                target_host=target_host,
                target_port=target_port,
                selected_printer=selected_printer,
            )
            return

        if "kitchen" in raw_payload:
            kitchen_body = raw_payload.get("kitchen")
            if isinstance(kitchen_body, dict):
                merged = {**raw_payload, **kitchen_body}
                try:
                    payload = KitchenPayload.from_dict(merged)
                except PayloadError as exc:
                    self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                    return
                self._handle_direct_kitchen_print(
                    payload,
                    raw_payload=raw_payload,
                    target_host=target_host,
                    target_port=target_port,
                    selected_printer=selected_printer,
                )
                return

        if self._looks_like_receipt_payload(raw_payload):
            try:
                payload = ReceiptPayload.from_dict(raw_payload)
            except PayloadError as exc:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
                return
            LOGGER.info(
                "[BRIDGE_RECEIPT_TABLE_LABEL] flat.parsed.table_no=%s flat.parsed.table_name=%s flat.parsed.table_area_name=%s",
                payload.table_no,
                payload.table_name,
                payload.table_area_name,
            )
            self._submit_receipt(
                payload,
                job_name=str(raw_payload.get("job_name") or f"adisyon-masa-{payload.table_no}"),
                raw_request=raw_payload,
                target_host=target_host,
                target_port=target_port,
                selected_printer=selected_printer,
            )
            return

        self._send_json(
            HTTPStatus.BAD_REQUEST,
            {
                "ok": False,
                "error": (
                    "Request must include one of: raw_base64, raw_hex, document, receipt, "
                    "kitchen, or a flat receipt payload."
                ),
            },
        )

    def _handle_print_receipt(self) -> None:
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi şu anda kapalı. Siparişler alınır ancak fişler otomatik yazdırılmaz.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        try:
            raw_payload = self._read_json_body()
            LOGGER.info(
                "[RECEIPT_REQUEST_HEADER_TOTAL] "
                "raw.receipt_printed_at=%s raw.printed_at=%s raw.order_created_at=%s raw.created_at=%s "
                "raw.date_time=%s raw.datetime=%s raw.grand_total=%s raw.total_amount=%s raw.total=%s raw.subtotal=%s "
                "raw.items_count=%s raw.first_item=%s",
                raw_payload.get("receipt_printed_at", ""),
                raw_payload.get("printed_at", ""),
                raw_payload.get("order_created_at", ""),
                raw_payload.get("created_at", ""),
                raw_payload.get("date_time", ""),
                raw_payload.get("datetime", ""),
                raw_payload.get("grand_total", ""),
                raw_payload.get("total_amount", ""),
                raw_payload.get("total", ""),
                raw_payload.get("subtotal", ""),
                len(raw_payload.get("items") or []) if isinstance(raw_payload.get("items"), list) else 0,
                (raw_payload.get("items") or [None])[0] if isinstance(raw_payload.get("items"), list) else None,
            )
            payload = ReceiptPayload.from_dict(raw_payload)
        except PayloadError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
            return
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "Invalid JSON body."})
            return
        LOGGER.info(
            "[RECEIPT_PARSE_HEADER_TOTAL] parsed.date_time=%s parsed.receipt_datetime=%s parsed.grand_total=%s parsed.items_count=%s",
            payload.date_time.isoformat() if getattr(payload, "date_time", None) else "-",
            payload.date_time.strftime("%d.%m.%Y %H:%M") if getattr(payload, "date_time", None) else "-",
            getattr(getattr(payload, "totals", None), "grand_total", None),
            len(getattr(payload, "items", []) or []),
        )

        LOGGER.info(
            "[BRIDGE_RECEIPT_TABLE_LABEL] "
            "raw.table_no=%s raw.table_number=%s raw.area_table_number=%s "
            "raw.table_area_name=%s raw.area_name=%s raw.display_table_label=%s "
            "raw.table_display_name=%s raw.table_name=%s",
            raw_payload.get("table_no", ""),
            raw_payload.get("table_number", ""),
            raw_payload.get("area_table_number", ""),
            raw_payload.get("table_area_name", ""),
            raw_payload.get("area_name", ""),
            raw_payload.get("display_table_label", ""),
            raw_payload.get("table_display_name", ""),
            raw_payload.get("table_name", ""),
        )
        LOGGER.info(
            "[BRIDGE_RECEIPT_TABLE_LABEL] "
            "parsed.table_no=%s parsed.table_name=%s parsed.table_area_name=%s",
            payload.table_no,
            payload.table_name,
            payload.table_area_name,
        )

        job_name = f"adisyon-masa-{payload.table_no}"
        target_host = raw_payload.get("target_host") or None
        target_port = raw_payload.get("target_port")
        if isinstance(target_port, str):
            target_port = int(target_port) if target_port.isdigit() else None
        selected_printer = self._resolve_selected_printer(raw_payload)
        self._submit_receipt(
            payload,
            job_name=job_name,
            raw_request=raw_payload,
            target_host=str(target_host) if target_host else None,
            target_port=int(target_port) if target_port else None,
            selected_printer=selected_printer,
        )

    def _handle_print_kitchen(self) -> None:
        """Handle POST /print/kitchen — mutfak fişi (kitchen ticket)."""
        if not self.settings.print_system_enabled:
            self._send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {
                    "ok": False,
                    "error": "Baskı sistemi şu anda kapalı. Siparişler alınır ancak fişler otomatik yazdırılmaz.",
                    "errorCode": "print_system_disabled",
                    "print_system_enabled": False,
                },
            )
            return
        try:
            raw_payload = self._read_json_body()
            LOGGER.info(
                "[KITCHEN_REQUEST_HEADER] "
                "raw.printed_at=%s raw.kitchen_printed_at=%s raw.order_created_at=%s raw.created_at=%s "
                "raw.date_time=%s raw.datetime=%s raw.daily_order_no=%s raw.table_name=%s raw.display_table_label=%s",
                raw_payload.get("printed_at", ""),
                raw_payload.get("kitchen_printed_at", ""),
                raw_payload.get("order_created_at", ""),
                raw_payload.get("created_at", ""),
                raw_payload.get("date_time", ""),
                raw_payload.get("datetime", ""),
                raw_payload.get("daily_order_no", ""),
                raw_payload.get("table_name", ""),
                raw_payload.get("display_table_label", ""),
            )
            payload = KitchenPayload.from_dict(raw_payload)
        except PayloadError as exc:
            LOGGER.warning("Kitchen payload error: %s", exc)
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
            return
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "Invalid JSON body."})
            return
        target_host, target_port = self._extract_target(raw_payload)
        selected_printer = self._resolve_selected_printer(raw_payload)
        self._handle_direct_kitchen_print(
            payload,
            raw_payload=raw_payload,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
        )

    def _handle_release_usb_printers(self) -> None:
        status, payload = _release_usb_printers()
        self._send_json(status, payload)

    def _handle_setup(self) -> None:
        status, payload = _auto_setup_bridge(
            settings=self.settings,
            transport=self.transport,
        )
        self._send_json(status, payload)

    def _handle_setup_status(self) -> None:
        snapshot = _collect_setup_snapshot(
            settings=self.settings,
            transport=self.transport,
        )
        self._send_json(
            HTTPStatus.OK,
            _setup_payload(
                step="system_check",
                status=str(snapshot.get("status") or "setup_required"),
                message=str(snapshot.get("message") or "Sistem kontrol edildi."),
                error_code=snapshot.get("errorCode") if isinstance(snapshot.get("errorCode"), str) else None,
                action_required=snapshot.get("actionRequired") if isinstance(snapshot.get("actionRequired"), str) else None,
                platform_name=str(snapshot.get("platform") or _platform_key()),
                checks=snapshot.get("checks"),
                printers=snapshot.get("printers"),
                bridgeInstalled=snapshot.get("bridgeInstalled"),
                bridgeRunning=snapshot.get("bridgeRunning"),
                autostart=snapshot.get("autostart"),
                technicalDetails={
                    "health": snapshot.get("health"),
                    "settings": snapshot.get("settings"),
                    "dependencies": snapshot.get("dependencies"),
                },
            ),
        )

    def _handle_setup_prerequisites(self) -> None:
        snapshot = _collect_setup_snapshot(
            settings=self.settings,
            transport=self.transport,
        )
        self._send_json(
            HTTPStatus.OK,
            _setup_payload(
                step="prerequisites",
                status=str(snapshot.get("status") or "setup_required"),
                message="Sistem gereksinimleri kontrol edildi.",
                error_code=snapshot.get("errorCode") if isinstance(snapshot.get("errorCode"), str) else None,
                action_required=snapshot.get("actionRequired") if isinstance(snapshot.get("actionRequired"), str) else None,
                platform_name=str(snapshot.get("platform") or _platform_key()),
                checks=snapshot.get("checks"),
                dependencies=snapshot.get("dependencies"),
                autostart=snapshot.get("autostart"),
                printers=snapshot.get("printers"),
            ),
        )

    def _handle_setup_driver_help(self) -> None:
        platform_name = _platform_key()
        if platform_name == "windows":
            payload = _setup_payload(
                step="driver_help",
                status="driver_missing",
                message="Windows yazıcı sürücüsü eksik. Yazıcı önce işletim sistemine kurulmalı.",
                error_code="driver_missing",
                action_required="install_driver",
                ok=False,
                helpTitle="Windows yazıcı sürücüsü gerekli",
                helpSteps=[
                    "Yazıcıyı önce Windows ayarlarından normal şekilde kurun.",
                    "Yazıcının Aygıtlar ve Yazıcılar listesinde göründüğünü doğrulayın.",
                    "Gerekirse üreticinin resmi sürücüsünü yükleyin.",
                    "Kurulumdan sonra bu ekrandan yeniden kontrol edin.",
                ],
            )
        else:
            payload = _setup_payload(
                step="driver_help",
                status="setup_required",
                message="macOS tarafında yazıcının Sistem Ayarları > Yazıcılar bölümünde görünmesi gerekir.",
                error_code=None,
                action_required="check_printer_setup",
                helpTitle="macOS yazıcı görünürlüğü",
                helpSteps=[
                    "Yazıcının macOS üzerinde kurulu ve görünür olduğundan emin olun.",
                    "Yazıcı listede görünmüyorsa önce işletim sistemi seviyesinde ekleyin.",
                    "Daha sonra bu ekrandan tekrar yazıcı taraması yapın.",
                ],
            )
        self._send_json(HTTPStatus.OK, payload)

    def _handle_setup_install(self) -> None:
        status, payload = _auto_setup_bridge(
            settings=self.settings,
            transport=self.transport,
        )
        self._send_json(status, payload)

    def _handle_setup_start(self) -> None:
        snapshot = _collect_setup_snapshot(
            settings=self.settings,
            transport=self.transport,
        )
        response = {
            "ok": True,
            "status": "started",
            "message": "Yazıcı servisi çalışıyor.",
            "details": {
                "platform": _platform_key(),
                "snapshot": snapshot,
            },
        }
        try:
            _warm_usb_endpoint(self.transport)
            response["details"]["warmup"] = "ok"
        except Exception as exc:  # noqa: BLE001
            response["ok"] = False
            response["status"] = "failed"
            response["message"] = "Yazıcı servisi başlatma doğrulaması başarısız oldu."
            response["details"]["warmup"] = str(exc)
        self._send_json(HTTPStatus.OK, response)

    def _handle_enable_autostart(self) -> None:
        platform_name = _platform_key()
        ok, status_label, error_code, extra = _enable_autostart(platform_name)
        self._send_json(
            HTTPStatus.OK if ok else HTTPStatus.BAD_REQUEST,
            _setup_payload(
                step="autostart",
                status="ready" if ok else "setup_required",
                message=f"Otomatik başlatma durumu: {status_label}.",
                error_code=error_code,
                action_required=None if ok else "manual_setup",
                platform_name=platform_name,
                ok=ok,
                **extra,
            ),
        )

    def _handle_disable_autostart(self) -> None:
        platform_name = _platform_key()
        ok, status_label, error_code, extra = _disable_autostart(platform_name)
        self._send_json(
            HTTPStatus.OK if ok else HTTPStatus.BAD_REQUEST,
            _setup_payload(
                step="autostart",
                status="ready" if ok else "setup_required",
                message=f"Otomatik başlatma durumu: {status_label}.",
                error_code=error_code,
                action_required=None if ok else "manual_setup",
                platform_name=platform_name,
                ok=ok,
                **extra,
            ),
        )

    # _CONFIGURE_FIELD_MAP maps the JSON keys Flutter sends to env-var names.
    _CONFIGURE_FIELD_MAP: dict[str, str] = {
        "transport_mode": "PRINT_BRIDGE_TRANSPORT",
        "printer_queue": "PRINT_BRIDGE_PRINTER_QUEUE",
        "paper_width_mm": "PRINT_BRIDGE_PAPER_WIDTH_MM",
        "chars_per_line": "PRINT_BRIDGE_CHARS_PER_LINE",
        "encoding": "PRINT_BRIDGE_ENCODING",
        "codepage": "PRINT_BRIDGE_CODEPAGE",
        "render_mode": "PRINT_BRIDGE_RENDER_MODE",
        "raster_chunk_height": "PRINT_BRIDGE_RASTER_CHUNK_HEIGHT",
        "cut_mode": "PRINT_BRIDGE_CUT_MODE",
        "usb_vendor_id": "PRINT_BRIDGE_USB_VENDOR_ID",
        "usb_product_id": "PRINT_BRIDGE_USB_PRODUCT_ID",
        "network_host": "PRINT_BRIDGE_NETWORK_HOST",
        "network_port": "PRINT_BRIDGE_NETWORK_PORT",
    }

    _PRINT_STATION_FIELD_MAP: dict[str, str] = {
        "enabled": "PRINT_STATION_ENABLED",
        "restaurant_id": "PRINT_STATION_RESTAURANT_ID",
        "supabase_url": "PRINT_STATION_SUPABASE_URL",
        "supabase_anon_key": "PRINT_STATION_SUPABASE_ANON_KEY",
        "access_token": "PRINT_STATION_ACCESS_TOKEN",
        "refresh_token": "PRINT_STATION_REFRESH_TOKEN",
        "user_id": "PRINT_STATION_USER_ID",
        "device_name": "PRINT_STATION_DEVICE_NAME",
        "device_platform": "PRINT_STATION_DEVICE_PLATFORM",
        "adisyon_printer_id": "PRINT_STATION_RECEIPT_PRINTER_ID",
        "adisyon_printer_name": "PRINT_STATION_RECEIPT_PRINTER_NAME",
        "kitchen_printer_id": "PRINT_STATION_KITCHEN_PRINTER_ID",
        "kitchen_printer_name": "PRINT_STATION_KITCHEN_PRINTER_NAME",
        "poll_interval_ms": "PRINT_STATION_POLL_INTERVAL_MS",
        "heartbeat_interval_ms": "PRINT_STATION_HEARTBEAT_INTERVAL_MS",
        "max_retry_count": "PRINT_STATION_MAX_RETRY_COUNT",
        "bridge_transport_mode": "PRINT_BRIDGE_TRANSPORT",
        "bridge_printer_queue": "PRINT_BRIDGE_PRINTER_QUEUE",
        "bridge_usb_vendor_id": "PRINT_BRIDGE_USB_VENDOR_ID",
        "bridge_usb_product_id": "PRINT_BRIDGE_USB_PRODUCT_ID",
        "print_system_enabled": "PRINT_SYSTEM_ENABLED",
    }

    def _handle_configure(self) -> None:
        """POST /configure — update bridge settings at runtime without a restart.

        Accepts a JSON object with any subset of the fields in
        ``_CONFIGURE_FIELD_MAP``.  Writes changes to the .env file (persists
        across restarts) and hot-reloads the bridge in-process.
        """
        try:
            body = self._read_json_body()
        except Exception:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "Invalid JSON body."})
            return

        env_updates: dict[str, str] = {}
        for field, env_key in self._CONFIGURE_FIELD_MAP.items():
            if field in body and body[field] is not None:
                env_updates[env_key] = str(body[field])

        if not env_updates:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "No recognised fields provided."})
            return

        try:
            write_env_file(env_updates)
            new_settings = BridgeSettings.from_env()
            _reload_handlers(new_settings)
        except Exception as exc:
            LOGGER.exception("Configure: write/reload failed")
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"ok": False, "error": str(exc)})
            return

        LOGGER.info("Runtime configure applied: %s", list(env_updates.keys()))
        self._send_json(HTTPStatus.OK, {"ok": True, "settings": new_settings.as_dict()})

    def _handle_configure_print_station(self) -> None:
        try:
            body = self._read_json_body()
        except Exception:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"ok": False, "error": "Invalid JSON body."},
            )
            return

        env_updates: dict[str, str] = {}
        for field, env_key in self._PRINT_STATION_FIELD_MAP.items():
            if field in body and body[field] is not None:
                env_updates[env_key] = str(body[field])

        if not env_updates:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"ok": False, "error": "No recognised print-station fields provided."},
            )
            return

        try:
            write_env_file(env_updates)
            consumer = self.print_station_consumer
            if consumer is not None:
                consumer.wake()
        except Exception as exc:
            LOGGER.exception("Configure print station failed")
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": str(exc)},
            )
            return

        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "queue": self._queue_status_payload(),
            },
        )

    def _queue_status_payload(self) -> dict[str, object]:
        base = build_print_station_queue_status()
        consumer = self.print_station_consumer
        if consumer is None:
            base["runtime"] = {"running": False, "status": "not_started"}
            return base
        base["runtime"] = consumer.snapshot()
        return base

    def _handle_direct_kitchen_print(
        self,
        payload: KitchenPayload,
        *,
        raw_payload: dict[str, object],
        target_host: str | None,
        target_port: int | None,
        selected_printer: dict[str, object] | None,
    ) -> None:
        import time as _time

        t_start = _time.monotonic()
        job_name = f"mutfak-masa-{payload.table_no}-{payload.order_no}"
        item_count = len(payload.items)
        if not payload.items:
            LOGGER.warning(
                "WARN_EMPTY_ITEMS: job=%s area=%s job_type=%s table=%s order=%s "
                "ACTION=printing_header_only_no_items",
                job_name,
                payload.area_name or "-",
                payload.job_type,
                payload.table_no,
                payload.order_no,
            )
        LOGGER.info(
            "Kitchen ticket: job=%s area=%s items=%d job_type=%s",
            job_name,
            payload.area_name or "-",
            item_count,
            payload.job_type,
        )
        profile, effective_settings = self._resolve_request_profile(
            raw_payload,
            job_name=job_name,
        )
        render_mode = self._resolve_render_mode(raw_payload)
        t_render_start = _time.monotonic()
        try:
            if render_mode == "image":
                image = self.kitchen_bitmap_renderer.render(payload)
                rasterized = self.raster_encoder.encode(image)
                raster_render_ms = int((_time.monotonic() - t_render_start) * 1000)
                LOGGER.info(
                    "kitchen-raster: job=%s printer=%s width_px=%d height_px=%d "
                    "chunk_count=%d raster_render_ms=%d items=%d area=%s guarantee=%s",
                    job_name,
                    effective_settings.printer_queue or "<usb-direct>",
                    rasterized.width_px,
                    rasterized.height_px,
                    rasterized.chunk_count,
                    raster_render_ms,
                    item_count,
                    payload.area_name or "-",
                    effective_settings.turkish_guarantee_mode,
                )
                extra: dict[str, object] = {
                    "render_mode": "image",
                    "raster_render_ms": raster_render_ms,
                    "render_ms": raster_render_ms,
                    "width_px": rasterized.width_px,
                    "height_px": rasterized.height_px,
                    "chunk_count": rasterized.chunk_count,
                    "item_count": item_count,
                    "turkish_print_mode": _request_turkish_print_mode_label(raw_payload),
                }
                if effective_settings.turkish_guarantee_mode:
                    try:
                        extra["bundled_font_path"] = resolve_bundled_mono_font_path(
                            bold=False
                        )
                    except BundledFontMissingError:
                        extra["bundled_font_path"] = "missing"
                self._submit_bytes(
                    rasterized.data,
                    job_name=job_name,
                    profile=profile,
                    settings=effective_settings,
                    raw_request=raw_payload,
                    target_host=target_host,
                    target_port=target_port,
                    selected_printer=selected_printer,
                    extra_response={
                        **extra,
                        "total_request_ms": int((_time.monotonic() - t_start) * 1000),
                    },
                )
                return
            raw_bytes = KitchenRenderer(effective_settings).render(payload)
        except BundledFontMissingError as exc:
            LOGGER.error("kitchen-raster bundled font missing: %s", exc)
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                _error_response(exc, errorCode="bundled_font_missing"),
            )
            return
        except Exception as exc:  # pragma: no cover - defensive guard
            LOGGER.exception("Kitchen render failed: %s", exc)
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                _error_response(exc, errorCode="kitchen_render_failed"),
            )
            return
        render_ms = int((_time.monotonic() - t_render_start) * 1000)
        LOGGER.info(
            "kitchen-text: job=%s render_ms=%d bytes=%d items=%d area=%s",
            job_name,
            render_ms,
            len(raw_bytes),
            item_count,
            payload.area_name or "-",
        )
        self._submit_bytes(
            raw_bytes,
            job_name=job_name,
            profile=profile,
            settings=effective_settings,
            raw_request=raw_payload,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
            extra_response={
                "render_mode": "text",
                "render_ms": render_ms,
                "item_count": item_count,
                "total_request_ms": int((_time.monotonic() - t_start) * 1000),
            },
        )

    def _looks_like_receipt_payload(self, raw_payload: dict[str, object]) -> bool:
        keys = raw_payload.keys()
        return "items" in keys and (
            "store_name" in keys or "storeName" in keys or "table_no" in keys or "tableNo" in keys
        )

    def _printer_identity(
        self,
        *,
        selected_printer: dict[str, object] | None,
        settings: BridgeSettings,
        target_host: str | None,
        target_port: int | None,
    ) -> tuple[str, str, str]:
        if selected_printer:
            printer_id = str(selected_printer.get("id") or "selected-printer")
            printer_name = str(
                selected_printer.get("name")
                or selected_printer.get("displayName")
                or selected_printer.get("queue")
                or selected_printer.get("queueName")
                or printer_id
            )
            transport_type = str(selected_printer.get("backend") or settings.transport_mode)
            return printer_id, printer_name, transport_type
        if target_host:
            return (
                f"network:{target_host}:{target_port or 9100}",
                f"{target_host}:{target_port or 9100}",
                "network-tcp",
            )
        queue_name = settings.printer_queue or "<default>"
        backend = "windows-spool" if platform.system().lower() == "windows" else "cups"
        return f"{backend}:{queue_name}", queue_name, backend

    def _is_transient_transport_error(self, exc: Exception) -> bool:
        text = str(exc).lower()
        transient_markers = (
            "temporarily",
            "timed out",
            "timeout",
            "resource busy",
            "device busy",
            "connection reset",
            "broken pipe",
            "try again",
            "temporarily unavailable",
            "transport endpoint",
        )
        return any(marker in text for marker in transient_markers)

    def _submit_receipt(
        self,
        payload: ReceiptPayload,
        *,
        job_name: str,
        raw_request: dict[str, object] | None = None,
        target_host: str | None = None,
        target_port: int | None = None,
        selected_printer: dict[str, object] | None = None,
        document_type: str = "receipt",
        require_physical_confirmation: bool = False,
    ) -> None:
        import time as _time

        render_mode = self._resolve_render_mode(raw_request)
        try:
            profile, effective_settings = self._resolve_request_profile(
                raw_request,
                job_name=job_name,
            )
            render_mode = effective_settings.render_mode
            if render_mode == "image":
                t_render = _time.monotonic()
                image = ReceiptBitmapRenderer(effective_settings).render(payload)
                rasterized = RasterEscPosEncoder(effective_settings).encode(image)
                raster_render_ms = int((_time.monotonic() - t_render) * 1000)
                LOGGER.info(
                    "receipt-raster: job=%s printer=%s width_px=%d height_px=%d "
                    "chunk_count=%d raster_render_ms=%d guarantee=%s",
                    job_name,
                    effective_settings.printer_queue or "<usb-direct>",
                    rasterized.width_px,
                    rasterized.height_px,
                    rasterized.chunk_count,
                    raster_render_ms,
                    effective_settings.turkish_guarantee_mode,
                )
                extra: dict[str, object] = {
                    "render_mode": "image",
                    "width_px": rasterized.width_px,
                    "height_px": rasterized.height_px,
                    "chunk_count": rasterized.chunk_count,
                    "raster_render_ms": raster_render_ms,
                    "turkish_print_mode": _request_turkish_print_mode_label(raw_request),
                }
                if effective_settings.turkish_guarantee_mode:
                    try:
                        extra["bundled_font_path"] = resolve_bundled_mono_font_path(
                            bold=False
                        )
                    except BundledFontMissingError:
                        extra["bundled_font_path"] = "missing"
                self._submit_bytes(
                    rasterized.data,
                    job_name=job_name,
                    profile=profile,
                    settings=effective_settings,
                    raw_request=raw_request,
                    target_host=target_host,
                    target_port=target_port,
                    selected_printer=selected_printer,
                    document_type=document_type,
                    require_physical_confirmation=require_physical_confirmation,
                    extra_response=extra,
                )
                return
            raw_bytes = ReceiptRenderer(effective_settings).render(payload)
        except BundledFontMissingError as exc:
            LOGGER.error("receipt-raster bundled font missing: %s", exc)
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                _error_response(
                    exc,
                    errorCode="bundled_font_missing",
                    render_mode="image",
                    document_type=document_type,
                ),
            )
            return
        except Exception as exc:  # pragma: no cover - defensive guard
            LOGGER.exception("Unexpected receipt rendering failure")
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                _error_response(
                    exc,
                    errorCode="render_failed",
                    render_mode=render_mode,
                    document_type=document_type,
                ),
            )
            return
        self._submit_bytes(
            raw_bytes,
            job_name=job_name,
            profile=profile,
            settings=effective_settings,
            raw_request=raw_request,
            target_host=target_host,
            target_port=target_port,
            selected_printer=selected_printer,
            document_type=document_type,
            require_physical_confirmation=require_physical_confirmation,
            extra_response={"render_mode": "text"},
        )

    def _submit_bytes(
        self,
        raw_bytes: bytes,
        *,
        job_name: str,
        profile: EscPosProfile,
        settings: BridgeSettings,
        raw_request: dict[str, object] | None = None,
        target_host: str | None = None,
        target_port: int | None = None,
        selected_printer: dict[str, object] | None = None,
        document_type: str = "raw",
        require_physical_confirmation: bool = False,
        extra_response: dict[str, object] | None = None,
    ) -> None:
        import time as _time

        t0 = _time.monotonic()
        printer_id, printer_name, transport_type = self._printer_identity(
            selected_printer=selected_printer,
            settings=settings,
            target_host=target_host,
            target_port=target_port,
        )
        # Pre-flight: detect CUPS queue busy/stuck before submitting.
        queue_snapshot: dict[str, object] | None = None
        try:
            raw_request = raw_request or {}
            selected_backend = self._request_printer_backend(raw_request).strip().lower()
            selected_queue = self._request_printer_queue(raw_request).strip()
        except Exception:
            selected_backend = ""
            selected_queue = ""
        if transport_type in {"cups", "windows-spool"} or selected_backend == "cups":
            # Only meaningful for CUPS on macOS/Linux. Best-effort, never 500.
            try:
                queue_name = selected_queue or settings.printer_queue or ""
                if hasattr(self.transport, "_spool") and hasattr(self.transport._spool, "queue_status"):
                    queue_snapshot = self.transport._spool.queue_status(queue_name)
                elif hasattr(self.transport, "queue_status"):
                    queue_snapshot = self.transport.queue_status(queue_name)  # type: ignore[attr-defined]
            except Exception as exc:  # pragma: no cover
                LOGGER.warning("queue-status preflight failed: %s", exc)
                queue_snapshot = None
            if isinstance(queue_snapshot, dict) and queue_snapshot.get("queue_has_active_job") is True:
                queue_status = str(queue_snapshot.get("queue_status") or "").strip().lower()
                error_code = "cups_queue_stuck" if queue_status == "stuck" else "cups_queue_busy"
                self._send_json(
                    HTTPStatus.CONFLICT,
                    {
                        "ok": False,
                        "errorCode": error_code,
                        "error": "Yazıcı kuyruğunda bekleyen işler var. Önce kuyruğu temizleyin.",
                        "queue_status": queue_snapshot.get("queue_status") or "stuck",
                        "queue_has_active_job": True,
                        "active_job_id": queue_snapshot.get("active_job_id"),
                        "active_job_ids": queue_snapshot.get("active_job_ids") or [],
                        "queue_message": queue_snapshot.get("queue_message"),
                        "suggested_action": "clear_queue",
                    },
                )
                return
        try:
            queue_result, result = self.queue_manager.run_job(
                printer_key=printer_id,
                printer_name=printer_name,
                transport_type=transport_type,
                document_type=document_type,
                job_name=job_name,
                execute=lambda: self.transport.print_bytes(
                    raw_bytes,
                    job_name=job_name,
                    target_host=target_host,
                    target_port=target_port,
                    selected_printer=selected_printer,
                ),
                is_transient_error=self._is_transient_transport_error,
                max_retries=1,
            )
        except TransportError as exc:
            elapsed_ms = int((_time.monotonic() - t0) * 1000)
            log_entry = self.log_store.build_entry(
                printer_id=printer_id,
                printer_name=printer_name,
                transport_type=transport_type,
                document_type=document_type,
                success=False,
                duration_ms=elapsed_ms,
                error_details=str(exc),
                queue_status="failed",
                job_name=job_name,
                metadata={"selectedPrinter": selected_printer or {}},
            )
            self.log_store.append(log_entry)
            LOGGER.exception(
                "bridge-physical-result: selected_backend=%s selected_queue=%s actual_backend=%s bytes_sent=%s exit_code=%s queue_status=failed error=%s elapsed_ms=%d",
                str(selected_printer.get("backend") or transport_type) if selected_printer else transport_type,
                str(
                    selected_printer.get("queue")
                    or selected_printer.get("queueName")
                    or selected_printer.get("name")
                    or selected_printer.get("displayName")
                    or settings.printer_queue
                    or "-"
                ) if selected_printer else settings.printer_queue or "-",
                "-",
                "0",
                "-",
                exc,
                elapsed_ms,
            )
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "ok": False,
                    "error": str(exc),
                    "queue_status": "failed",
                    "printer": selected_printer or {"id": printer_id, "name": printer_name},
                },
            )
            return
        except Exception as exc:  # pragma: no cover - defensive guard
            elapsed_ms = int((_time.monotonic() - t0) * 1000)
            log_entry = self.log_store.build_entry(
                printer_id=printer_id,
                printer_name=printer_name,
                transport_type=transport_type,
                document_type=document_type,
                success=False,
                duration_ms=elapsed_ms,
                error_details=str(exc),
                queue_status="failed",
                job_name=job_name,
                metadata={"selectedPrinter": selected_printer or {}},
            )
            self.log_store.append(log_entry)
            LOGGER.exception(
                "bridge-physical-result: selected_backend=%s selected_queue=%s actual_backend=%s bytes_sent=%s exit_code=%s queue_status=failed error=%s elapsed_ms=%d",
                str(selected_printer.get("backend") or transport_type) if selected_printer else transport_type,
                str(
                    selected_printer.get("queue")
                    or selected_printer.get("queueName")
                    or selected_printer.get("name")
                    or selected_printer.get("displayName")
                    or settings.printer_queue
                    or "-"
                ) if selected_printer else settings.printer_queue or "-",
                "-",
                "0",
                "-",
                exc,
                elapsed_ms,
            )
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": f"Unexpected print failure: {exc}"},
            )
            return

        elapsed_ms = int((_time.monotonic() - t0) * 1000)
        printer_write_started_at = queue_result.started_at
        printer_write_completed_at = queue_result.completed_at
        result_metadata = dict(getattr(result, "metadata", {}) or {})
        selected_backend = (
            str(selected_printer.get("backend") or transport_type).strip().lower()
            if selected_printer
            else str(transport_type).strip().lower()
        )
        selected_queue = (
            str(
                selected_printer.get("queue")
                or selected_printer.get("queueName")
                or selected_printer.get("name")
                or selected_printer.get("displayName")
                or settings.printer_queue
                or ""
            ).strip()
            if selected_printer
            else settings.printer_queue or ""
        )
        actual_backend = str(
            result_metadata.get("actual_backend") or transport_type
        ).strip().lower()
        lp_exit_code = result_metadata.get("lp_exit_code")
        lp_command = str(result_metadata.get("lp_command") or "").strip()
        lp_output = str(result_metadata.get("lp_output") or "").strip()
        used_fallback = bool(
            (raw_request or {}).get("used_fallback")
            or result_metadata.get("used_fallback")
        )
        fallback_reason = str(
            (raw_request or {}).get("fallback_reason")
            or result_metadata.get("fallback_reason")
            or ""
        ).strip()
        transport_mismatch = bool(
            selected_backend
            and actual_backend
            and selected_backend != actual_backend
        )
        physical_confirmation = actual_backend != "cups"
        confirmation_status = "confirmed" if physical_confirmation else "cups_accepted_unverified"
        physical_confirmation_message = (
            ""
            if physical_confirmation
            else "CUPS işi kabul etti ama fiziksel baskı doğrulanamadı. Yazıcı kuyruğunu ve macOS yazıcı durumunu kontrol edin."
        )
        warnings: list[str] = []
        if not physical_confirmation:
            warnings.append(
                "CUPS işi kabul etti; fiziksel baskı macOS tarafından doğrulanamadı"
            )
        if transport_mismatch:
            if used_fallback:
                if fallback_reason:
                    warnings.append(
                        f"Bridge fallback backend kullandı ({fallback_reason})."
                    )
                else:
                    warnings.append("Bridge fallback backend kullandı.")
            else:
                warnings.append(
                    f"Seçilen backend {selected_backend or '-'} ama bridge {actual_backend or '-'} kullandı."
                )

        # Post-flight: For CUPS test prints, lp exit_code=0 does not guarantee progress.
        # If the queue remains "stuck" shortly after submit, report cups_queue_stuck and do not
        # treat this as a success.
        if actual_backend == "cups" and require_physical_confirmation:
            queue_name = selected_queue or settings.printer_queue or ""
            post_snapshot: dict[str, object] | None = None
            try:
                for _ in range(4):
                    if hasattr(self.transport, "_spool") and hasattr(self.transport._spool, "queue_status"):
                        post_snapshot = self.transport._spool.queue_status(queue_name)
                    time.sleep(0.5)
                    if isinstance(post_snapshot, dict):
                        status = str(post_snapshot.get("queue_status") or "").strip().lower()
                        if status in {"printing", "idle"}:
                            break
                if isinstance(post_snapshot, dict):
                    status = str(post_snapshot.get("queue_status") or "").strip().lower()
                    if post_snapshot.get("queue_has_active_job") is True and status == "stuck":
                        LOGGER.warning(
                            "cups-postflight-stuck: queue=%s job=%s lp_command=%s lp_output=%s active_job_ids=%s",
                            queue_name or "-",
                            job_name,
                            lp_command or "-",
                            lp_output or "-",
                            post_snapshot.get("active_job_ids") or [],
                        )
                        self._send_json(
                            HTTPStatus.CONFLICT,
                            {
                                "ok": False,
                                "errorCode": "cups_queue_stuck",
                                "error": "CUPS işi kabul etti ama kuyruk ilerlemiyor. Önce kuyruğu temizleyin.",
                                "queue_status": post_snapshot.get("queue_status") or "stuck",
                                "queue_has_active_job": True,
                                "active_job_id": post_snapshot.get("active_job_id"),
                                "active_job_ids": post_snapshot.get("active_job_ids") or [],
                                "queue_message": post_snapshot.get("queue_message"),
                                "suggested_action": "clear_queue",
                                "printer": selected_printer or {"id": printer_id, "name": printer_name},
                                "lp_command": lp_command or None,
                                "lp_output": lp_output or None,
                            },
                        )
                        return
            except Exception as exc:  # noqa: BLE001
                LOGGER.warning("cups-postflight-check-failed: %s", exc)
        log_entry = self.log_store.build_entry(
            printer_id=printer_id,
            printer_name=printer_name,
            transport_type=transport_type,
            document_type=document_type,
            success=True,
            duration_ms=elapsed_ms,
            queue_status=queue_result.final_status,
            queue_wait_ms=queue_result.queue_wait_ms,
            retry_count=queue_result.retry_count,
            job_name=job_name,
            backend_job_id=getattr(result, "job_id", None),
            metadata={
                "selectedPrinter": selected_printer or {},
                "bytesLength": len(raw_bytes),
                "encoding": profile.encoding,
                "codepage": profile.codepage,
            },
        )
        self.log_store.append(log_entry)
        LOGGER.info(
            "print-submit: job=%s selected_encoding=%s selected_code_page=%s "
            "bytes_length=%d printer=%s transport_ms=%d",
            job_name,
            profile.encoding,
            profile.codepage if profile.codepage is not None else "-",
            len(raw_bytes),
            settings.printer_queue or "-",
            elapsed_ms,
        )
        render_mode_log = str(
            (extra_response or {}).get("render_mode")
            or (raw_request or {}).get("render_mode")
            or document_type
        )
        spool_mode_log = str((raw_request or {}).get("spool_mode") or "-")
        text_length_log = (extra_response or {}).get("text_length")
        if text_length_log is None:
            text_length_log = (raw_request or {}).get("text_length")
        unsupported_chars_log = (extra_response or {}).get("unsupported_chars")
        if unsupported_chars_log:
            LOGGER.warning(
                "bridge-physical-result-encoding: printer_name=%s encoding=%s codepage=%s "
                "unsupported_chars=%s bytes_sent=%d",
                printer_name,
                profile.encoding,
                profile.codepage if profile.codepage is not None else "-",
                "".join(unsupported_chars_log)
                if isinstance(unsupported_chars_log, list)
                else str(unsupported_chars_log),
                result.bytes_sent,
            )
        flow_type_log = str((raw_request or {}).get("flow_type") or "-")
        printer_id_log = str(
            (raw_request or {}).get("printer_id")
            or (selected_printer or {}).get("id")
            or "-"
        )
        endpoint_log = str((raw_request or {}).get("endpoint") or document_type)
        esc_t_log = profile.codepage if profile.codepage is not None else "-"
        esc_r_log = profile.esc_r if profile.esc_r is not None else "-"
        LOGGER.info(
            "bridge-physical-result: flow_type=%s printer_id=%s printer_name=%s endpoint=%s "
            "render_mode=%s spool_mode=%s encoding=%s codepage=%s esc_t_value=%s esc_r_value=%s "
            "codepage_command=ESC t %s bytes_sent=%d text_length=%s unsupported_chars=%s "
            "selected_backend=%s selected_queue=%s actual_backend=%s "
            "exit_code=%s queue_status=%s physical_confirmation=%s",
            flow_type_log,
            printer_id_log,
            printer_name,
            endpoint_log,
            render_mode_log,
            spool_mode_log,
            profile.encoding,
            esc_t_log,
            esc_t_log,
            esc_r_log,
            esc_t_log,
            result.bytes_sent,
            text_length_log if text_length_log is not None else "-",
            "".join(unsupported_chars_log)
            if isinstance(unsupported_chars_log, list)
            else (unsupported_chars_log or "-"),
            selected_backend or "-",
            selected_queue or "-",
            actual_backend or "-",
            lp_exit_code if lp_exit_code is not None else "-",
            queue_result.final_status,
            "true" if physical_confirmation else "false",
        )
        response: dict[str, object] = {
            "ok": True,
            "job_id": result.job_id,
            "printer_queue": settings.printer_queue,
            "bytes_sent": result.bytes_sent,
            "transport_output": result.raw_output,
            "lp_command": lp_command or None,
            "lp_output": lp_output or None,
            "selected_backend": selected_backend,
            "selected_queue": selected_queue,
            "actual_backend": actual_backend,
            "lp_exit_code": lp_exit_code,
            "encoding": profile.encoding,
            "codepage": profile.codepage,
            "encoding_warnings": list(profile.warnings),
            "printer_write_started_at": printer_write_started_at,
            "printer_write_completed_at": printer_write_completed_at,
            "transport_ms": elapsed_ms,
            "bytes_length": len(raw_bytes),
            "queue_job_id": queue_result.queue_job_id,
            "queue_status": queue_result.final_status,
            "queue_wait_ms": queue_result.queue_wait_ms,
            "retry_count": queue_result.retry_count,
            "document_type": document_type,
            "transport_type": transport_type,
            "physical_confirmation": physical_confirmation,
            "physical_confirmation_message": physical_confirmation_message,
            "confirmation_status": confirmation_status,
            "used_fallback": used_fallback,
            "fallback_reason": fallback_reason,
            "transport_mismatch": transport_mismatch,
            "backend_match_expected": used_fallback,
        }
        if isinstance(queue_snapshot, dict):
            response["queue_has_active_job"] = queue_snapshot.get("queue_has_active_job")
            response["active_job_id"] = queue_snapshot.get("active_job_id")
            response["active_job_ids"] = queue_snapshot.get("active_job_ids") or []
            response["queue_message"] = queue_snapshot.get("queue_message")
            response["queue_status_snapshot"] = queue_snapshot.get("queue_status")
            response["suggested_action"] = queue_snapshot.get("suggested_action")
        if warnings:
            response["warning"] = " ".join(warnings)
        if selected_printer:
            response["printer"] = selected_printer
        else:
            response["printer"] = {
                "id": printer_id,
                "name": printer_name,
                "backend": transport_type,
            }
        if result_metadata:
            response["printer_name"] = (
                result_metadata.get("printer_name") or selected_queue or printer_name
            )
            response["spool_mode"] = result_metadata.get("spool_mode") or "RAW"
            if result_metadata.get("spool_jobs_after_print") is not None:
                response["spool_jobs_after_print"] = result_metadata.get("spool_jobs_after_print")
            if result_metadata.get("spool_latest_job_id") is not None:
                response["spool_latest_job_id"] = result_metadata.get("spool_latest_job_id")
            if result_metadata.get("spool_active_job_ids") is not None:
                response["spool_active_job_ids"] = result_metadata.get("spool_active_job_ids")
            if result_metadata.get("spool_snapshot") is not None:
                response["spool_snapshot"] = result_metadata.get("spool_snapshot")
        if extra_response:
            response.update(extra_response)
        raster_render_ms = (extra_response or {}).get("raster_render_ms")
        if isinstance(raster_render_ms, (int, float)):
            spool_write_ms = elapsed_ms
            response["spool_write_ms"] = spool_write_ms
            response["total_dispatch_ms"] = int(raster_render_ms) + spool_write_ms
        elif extra_response and extra_response.get("render_ms") is not None:
            response["total_dispatch_ms"] = int(extra_response.get("render_ms", 0)) + elapsed_ms
        response["turkish_print_mode"] = _request_turkish_print_mode_label(raw_request)
        if settings.turkish_guarantee_mode:
            try:
                response["bundled_font_path"] = resolve_bundled_mono_font_path(bold=False)
            except BundledFontMissingError:
                response["bundled_font_path"] = "missing"
        LOGGER.info(
            "bridge-dispatch-timing: job=%s render_mode=%s turkish_print_mode=%s "
            "raster_render_ms=%s spool_write_ms=%s total_dispatch_ms=%s bundled_font_path=%s",
            job_name,
            response.get("render_mode", "-"),
            response.get("turkish_print_mode", "-"),
            response.get("raster_render_ms", "-"),
            response.get("spool_write_ms", elapsed_ms),
            response.get("total_dispatch_ms", elapsed_ms),
            response.get("bundled_font_path", "-"),
        )
        self._send_json(HTTPStatus.OK, response)

    def _resolve_request_profile(
        self,
        raw_request: dict[str, object] | None,
        *,
        job_name: str,
    ) -> tuple[EscPosProfile, BridgeSettings]:
        requested = raw_request or {}
        try:
            base_profile = self.settings.escpos_profile()
        except Exception as exc:  # defensive: never 500 due to missing settings attrs
            LOGGER.warning(
                "bridge-config defaulted: missing/invalid escpos_profile for job=%s error=%s",
                job_name,
                exc,
            )
            base_profile = EscPosProfile(
                encoding="cp857",
                codepage=857,
                warnings=("Bridge config eksik/uyumsuz. Varsayılan ESC/POS profil kullanıldı.",),
            )
        req_encoding = requested.get("printer_encoding", requested.get("encoding"))
        req_codepage = requested.get(
            "printer_code_page",
            requested.get(
                "printer_codepage",
                requested.get("code_page", requested.get("codepage")),
            ),
        )
        req_esc_r = requested.get(
            "esc_r_value",
            requested.get("printer_esc_r", requested.get("esc_r")),
        )
        profile_verified = requested.get("encoding_profile_verified")
        profile_missing = requested.get("encoding_profile_missing")

        # Determine payload_source for logging
        if req_encoding is not None or req_codepage is not None:
            payload_source = "request"
        else:
            payload_source = "env"
            LOGGER.warning(
                "encoding_profile_missing: job=%s printer_encoding/codepage absent in payload",
                job_name,
            )

        if profile_missing is True or (
            profile_verified is False and req_encoding is None and req_codepage is None
        ):
            LOGGER.warning(
                "encoding_profile_missing: job=%s verified=%s payload_source=%s",
                job_name,
                profile_verified,
                payload_source,
            )

        profile = resolve_escpos_profile(
            req_encoding,
            req_codepage,
            req_esc_r,
            default_profile=base_profile,
        )
        render_mode = self._resolve_render_mode(requested)
        guarantee_mode = _request_turkish_guarantee_mode(requested)
        effective_settings = replace(
            self.settings,
            encoding=profile.encoding,
            codepage=profile.codepage,
            esc_r=profile.esc_r,
            render_mode=render_mode,
            turkish_guarantee_mode=guarantee_mode,
        )
        self._log_print_profile(job_name=job_name, profile=profile, payload_source=payload_source)
        return profile, effective_settings

    def _log_print_profile(
        self,
        *,
        job_name: str,
        profile: EscPosProfile,
        payload_source: str = "env",
        bytes_length: int | None = None,
        printer_queue: str | None = None,
    ) -> None:
        queue = printer_queue or self.settings.printer_queue or "-"
        bytes_info = f" bytes_length={bytes_length}" if bytes_length is not None else ""
        if profile.warnings:
            LOGGER.warning(
                "print-profile warning: job=%s selected_encoding=%s selected_code_page=%s "
                "payload_source=%s printer=%s%s "
                "requested_encoding=%s requested_codepage=%s warnings=%s",
                job_name,
                profile.encoding,
                profile.codepage if profile.codepage is not None else "-",
                payload_source,
                queue,
                bytes_info,
                profile.requested_encoding or "-",
                profile.requested_codepage if profile.requested_codepage is not None else "-",
                " | ".join(profile.warnings),
            )
        else:
            LOGGER.info(
                "print-profile: job=%s selected_encoding=%s selected_code_page=%s "
                "payload_source=%s printer=%s%s",
                job_name,
                profile.encoding,
                profile.codepage if profile.codepage is not None else "-",
                payload_source,
                queue,
                bytes_info,
            )

    def _extract_target(
        self,
        body: dict[str, object] | None,
    ) -> tuple[str | None, int | None]:
        raw_body = body or {}
        target_host = raw_body.get("target_host")
        raw_target_port = raw_body.get("target_port")
        target_port = None
        if raw_target_port is not None:
            try:
                target_port = int(raw_target_port)
            except (TypeError, ValueError):
                target_port = None
        return (str(target_host) if target_host else None, target_port)

    def _resolve_selected_printer(
        self,
        body: dict[str, object] | None,
    ) -> dict[str, object] | None:
        raw_body = body or {}
        embedded = raw_body.get("printer")
        printer_data = dict(embedded) if isinstance(embedded, dict) else None
        printer_id = str(raw_body.get("printer_id") or raw_body.get("printerId") or "").strip()
        printer_name = str(
            raw_body.get("printer_name")
            or raw_body.get("printerName")
            or raw_body.get("printer_queue")
            or raw_body.get("queueName")
            or ""
        ).strip()
        vendor_id = raw_body.get("vendorId", raw_body.get("vendor_id"))
        product_id = raw_body.get("productId", raw_body.get("product_id"))

        resolver = getattr(self.transport, "resolve_printer", None)
        selected = None
        if callable(resolver):
            selected = resolver(
                selected_printer=printer_data,
                printer_id=printer_id or None,
                printer_name=printer_name or None,
            )
        if selected:
            return selected

        parsed_vendor = _parse_hex_int(vendor_id)
        parsed_product = _parse_hex_int(product_id)
        if parsed_vendor is not None or parsed_product is not None:
            return PrinterRecord(
                id=(
                    f"usb:{parsed_vendor or 0:04x}:{parsed_product or 0:04x}:manual"
                ),
                name=printer_name or "USB Printer",
                vendor_id=f"0x{parsed_vendor:04x}" if parsed_vendor is not None else None,
                product_id=f"0x{parsed_product:04x}" if parsed_product is not None else None,
                connection_type="usb",
                backend="usb-direct",
            ).as_dict()

        if printer_name and platform.system().lower() == "windows":
            return PrinterRecord(
                id=f"windows:{printer_name}",
                name=printer_name,
                connection_type="usb",
                backend="windows-spool",
                queue=printer_name,
            ).as_dict()
        if printer_name:
            return PrinterRecord(
                id=f"cups:{printer_name}",
                name=printer_name,
                connection_type="usb",
                backend="cups",
                queue=printer_name,
            ).as_dict()
        return None

    def _resolve_render_mode(self, body: dict[str, object] | None) -> str:
        raw_body = body or {}
        if _request_turkish_guarantee_mode(raw_body):
            return "image"
        test_mode = str(raw_body.get("test_mode") or raw_body.get("mode") or "").strip().lower()
        if test_mode in {"escpos_short", "escpos_text", "escpos", "raw", "text"}:
            return "text"
        if test_mode in {"bitmap", "image", "turkish", "turkish_guarantee"}:
            return "image"
        raw = raw_body.get("render_mode")
        if raw is not None:
            normalized = str(raw).strip().lower()
            if normalized in {"image", "raster_text", "raster"}:
                return "image"
            if normalized == "text":
                return "text"
            if normalized in {"escpos_short", "escpos_text", "escpos", "raw"}:
                return "text"
        return self.settings.render_mode

    def _maybe_read_json_body(self) -> dict[str, object]:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            return {}
        raw_body = self.rfile.read(content_length)
        if not raw_body:
            return {}
        return json.loads(raw_body.decode("utf-8"))

    def _read_json_body(self) -> dict[str, object]:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        if not raw_body:
            raise PayloadError("Request body is required.")
        return json.loads(raw_body.decode("utf-8"))

    def _request_path(self) -> str:
        return urlparse(self.path).path

    def _query_params(self) -> dict[str, list[str]]:
        return parse_qs(urlparse(self.path).query)

    def _origin_allowed(self, origin: str) -> bool:
        return origin in self.settings.allowed_origins

    def _send_json(self, status: HTTPStatus, payload: dict[str, object] | None) -> None:
        body = b""
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

        self.send_response(status.value)
        origin = self.headers.get("Origin")
        if origin and self._origin_allowed(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            # Send PNA header on OPTIONS preflights that request it, and also
            # unconditionally on all OPTIONS responses so Chrome's pre-check
            # for Private Network Access always succeeds from allowed origins.
            if self.command == "OPTIONS" or self.headers.get(
                "Access-Control-Request-Private-Network", ""
            ).lower() == "true":
                self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")
        self.send_header("Access-Control-Max-Age", "600")
        if body:
            self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)


def _warm_usb_endpoint(transport: _SmartTransport) -> None:
    """Pre-warm USB endpoint cache at startup to eliminate cold-start latency."""
    usb_t = transport._usb
    if usb_t is None:
        return
    try:
        from . import usb_transport as _usb_mod
        usb = _usb_mod._import_usb()
        if usb is None:
            return
        dev = usb_t._find_device(usb)
        if dev is None:
            LOGGER.info("USB warm-up: no device found (will retry on first print)")
            return
        usb_t._prepare_cached_endpoint(usb, dev)
        LOGGER.info(
            "USB warm-up: endpoint cached vid=0x%04x pid=0x%04x bus=%s addr=%s",
            dev.idVendor, dev.idProduct, dev.bus, dev.address,
        )
    except Exception as exc:
        LOGGER.warning("USB warm-up failed (non-fatal): %s", exc)


def _configure_logging() -> None:
    log_path = bridge_server_log_path()
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    file_handler = RotatingFileHandler(
        log_path,
        maxBytes=2 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    handlers: list[logging.Handler] = [file_handler]
    if sys.stdout is not None and getattr(sys.stdout, "isatty", lambda: False)():
        stream_handler = logging.StreamHandler(sys.stdout)
        stream_handler.setFormatter(formatter)
        handlers.append(stream_handler)

    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.handlers.clear()
    for handler in handlers:
        root_logger.addHandler(handler)


def _warm_runtime_assets(transport: _SmartTransport) -> None:
    # Warm-up runs after the HTTP listener binds so /health is reachable fast.
    _warm_usb_endpoint(transport)

    try:
        import time as _time

        t0 = _time.monotonic()
        fonts_loaded = warm_font_cache()
        font_ms = int((_time.monotonic() - t0) * 1000)
        LOGGER.info("Font cache warm-up: %d fonts loaded in %dms", fonts_loaded, font_ms)
    except Exception as exc:
        LOGGER.warning("Font cache warm-up failed (non-fatal): %s", exc)

    try:
        from PIL import Image as _Img, ImageDraw as _Draw
        import time as _time

        t0 = _time.monotonic()
        _img = _Img.new("1", (8, 8), color=1)
        _draw = _Draw.Draw(_img)
        _draw.text((0, 0), "X", fill=0)
        _ = _img.tobytes("raw", "1")
        pillow_ms = int((_time.monotonic() - t0) * 1000)
        LOGGER.info("Pillow warm-up: %dms", pillow_ms)
    except Exception as exc:
        LOGGER.warning("Pillow warm-up failed (non-fatal): %s", exc)


def serve() -> None:
    _configure_logging()
    settings = BridgeSettings.from_env()
    PrintBridgeHandler.settings = settings
    PrintBridgeHandler.renderer = ReceiptRenderer(settings)
    PrintBridgeHandler.kitchen_renderer = KitchenRenderer(settings)
    PrintBridgeHandler.document_renderer = EscPosDocumentRenderer(settings)
    PrintBridgeHandler.receipt_bitmap_renderer = ReceiptBitmapRenderer(settings)
    PrintBridgeHandler.kitchen_bitmap_renderer = KitchenBitmapRenderer(settings)
    PrintBridgeHandler.raster_encoder = RasterEscPosEncoder(settings)
    PrintBridgeHandler.transport = _SmartTransport(settings)  # type: ignore[assignment]
    PrintBridgeHandler.print_station_consumer = PrintStationConsumer(
        settings_provider=lambda: PrintBridgeHandler.settings,
        transport_provider=lambda: PrintBridgeHandler.transport,
        queue_manager_provider=lambda: PrintBridgeHandler.queue_manager,
        log_store_provider=lambda: PrintBridgeHandler.log_store,
    )

    server = ThreadingHTTPServer((settings.host, settings.port), PrintBridgeHandler)
    LOGGER.info(
        "Local print bridge listening on http://%s:%s (transport=%s queue=%s)",
        settings.host,
        settings.port,
        settings.transport_mode,
        settings.printer_queue or "<unset>",
    )

    warmup_thread = threading.Thread(
        target=_warm_runtime_assets,
        args=(PrintBridgeHandler.transport,),
        daemon=True,
        name="ibul-print-bridge-warmup",
    )
    warmup_thread.start()
    PrintBridgeHandler.print_station_consumer.start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        LOGGER.info("Shutting down local print bridge")
    finally:
        if PrintBridgeHandler.print_station_consumer is not None:
            PrintBridgeHandler.print_station_consumer.stop()
        server.server_close()


if __name__ == "__main__":
    serve()
