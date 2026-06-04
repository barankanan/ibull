from __future__ import annotations

from dataclasses import dataclass
import json
import platform
import re
import subprocess
from typing import Any

from .windows_printer_profile import classify_windows_printer


_VID_PID_RE = re.compile(r"(?:VID|vid)[_:\-]?([0-9a-fA-F]{4}).*?(?:PID|pid)[_:\-]?([0-9a-fA-F]{4})")


def _normalize_hex_id(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.lower().startswith("0x"):
        text = text[2:]
    try:
        parsed = int(text, 16)
    except ValueError:
        return None
    return f"0x{parsed:04x}"


def _extract_vid_pid(*values: Any) -> tuple[str | None, str | None]:
    for value in values:
        if value is None:
            continue
        match = _VID_PID_RE.search(str(value))
        if match:
            return (f"0x{match.group(1).lower()}", f"0x{match.group(2).lower()}")
    return (None, None)


def infer_connection_type(*, device_uri: str | None = None, port_name: str | None = None) -> str:
    uri = (device_uri or "").strip().lower()
    port = (port_name or "").strip().lower()
    if uri.startswith(("socket://", "ipp://", "ipps://", "lpd://", "dnssd://", "mdns://", "smb://")):
        return "network"
    if uri.startswith(("usb://", "parallel:", "serial:")):
        return "usb"
    if port.startswith(("ip_", "tcp", "socket", "wsd", "http")):
        return "network"
    if port.startswith(("usb", "dot4", "lpt", "com")):
        return "usb"
    return "usb"


@dataclass(frozen=True)
class PrinterRecord:
    id: str
    name: str
    connection_type: str
    backend: str
    vendor_id: str | None = None
    product_id: str | None = None
    queue: str | None = None
    host: str | None = None
    port: int | None = None
    status: str | None = None
    detail: str | None = None
    device_uri: str | None = None
    is_default: bool = False
    status_level: str = "ready"
    status_message: str | None = None
    error_code: str | None = None
    warning_code: str | None = None
    driver_name: str | None = None
    port_name: str | None = None
    metadata: dict[str, object] | None = None

    def as_dict(self) -> dict[str, object]:
        data: dict[str, object] = {
            "id": self.id,
            "name": self.name,
            "vendorId": self.vendor_id,
            "productId": self.product_id,
            "connectionType": self.connection_type,
            "backend": self.backend,
            "transportType": self.backend,
            "isDefault": self.is_default,
            "statusLevel": self.status_level,
            "statusMessage": self.status_message or "",
            "ready": self.status_level == "ready",
        }
        if self.queue:
            data["queue"] = self.queue
        if self.host:
            data["host"] = self.host
        if self.port is not None:
            data["port"] = self.port
        if self.status:
            data["status"] = self.status
        if self.detail:
            data["detail"] = self.detail
        if self.device_uri:
            data["deviceUri"] = self.device_uri
        if self.vendor_id:
            data["vid"] = self.vendor_id
        if self.product_id:
            data["pid"] = self.product_id
        if self.error_code:
            data["errorCode"] = self.error_code
        if self.warning_code:
            data["warningCode"] = self.warning_code
        if self.driver_name:
            data["driverName"] = self.driver_name
            data["driver_name"] = self.driver_name
        if self.port_name:
            data["portName"] = self.port_name
            data["port_name"] = self.port_name
        if self.metadata:
            data["metadata"] = self.metadata
        if self.metadata and self.metadata.get("operatorTier"):
            data["operatorTier"] = self.metadata.get("operatorTier")
            data["isPosCandidate"] = self.metadata.get("isPosCandidate")
            data["recommended"] = self.metadata.get("recommended")
            if self.metadata.get("selectionWarning"):
                data["selectionWarning"] = self.metadata.get("selectionWarning")
        return data


def dedupe_printers(records: list[dict[str, object]]) -> list[dict[str, object]]:
    seen: set[str] = set()
    unique: list[dict[str, object]] = []
    for record in records:
        record_id = str(record.get("id") or "")
        if not record_id or record_id in seen:
            continue
        seen.add(record_id)
        unique.append(record)
    return unique


def annotate_duplicate_physical_printers(
    records: list[dict[str, object]],
) -> list[dict[str, object]]:
    groups: dict[str, list[dict[str, object]]] = {}

    def _looks_like_pos58(record: dict[str, object]) -> bool:
        vid = _normalize_hex_id(record.get("vendorId") or record.get("vid")) or ""
        pid = _normalize_hex_id(record.get("productId") or record.get("pid")) or ""
        if vid == "0x0416" and pid == "0x5011":
            return True
        text = " ".join(
            str(
                record.get(key) or ""
            )
            for key in ("id", "name", "queue", "displayName", "product", "manufacturer")
        ).lower()
        return "pos58" in text or "pos-58" in text or "stmicroelectronics" in text

    def _group_key(record: dict[str, object]) -> str | None:
        if not _looks_like_pos58(record):
            return None
        vid = _normalize_hex_id(record.get("vendorId") or record.get("vid")) or ""
        pid = _normalize_hex_id(record.get("productId") or record.get("pid")) or ""
        if vid and pid:
            return f"pos58:{vid}:{pid}"
        text = " ".join(
            str(record.get(key) or "")
            for key in ("name", "queue", "displayName", "product", "manufacturer")
        ).lower()
        normalized = re.sub(r"[^a-z0-9]+", " ", text)
        normalized = re.sub(r"\b(usb|printer|queue|cups|direct|stmicroelectronics)\b", " ", normalized)
        normalized = re.sub(r"\s+", " ", normalized).strip()
        return f"pos58:{normalized or 'unknown'}"

    for record in records:
        key = _group_key(record)
        if key is None:
            continue
        groups.setdefault(key, []).append(record)

    for key, group in groups.items():
        if len(group) < 2:
            continue
        backends = {
            str(record.get("backend") or record.get("transportType") or "").strip().lower()
            for record in group
        }
        if "cups" not in backends or "usb-direct" not in backends:
            continue
        for record in group:
            backend = str(
                record.get("backend") or record.get("transportType") or ""
            ).strip().lower()
            record["duplicatePhysicalPrinter"] = True
            record["duplicateGroupKey"] = key
            record["duplicateBackends"] = ["cups", "usb-direct"]
            record["recommendedBackend"] = "cups"
            record["recommended"] = backend == "cups"
            if backend == "cups":
                record["backendStatusLabel"] = "CUPS: Onerilen"
                if not str(record.get("statusMessage") or "").strip():
                    record["statusMessage"] = "CUPS kuyrugu POS-58 adisyon icin onerilir."
            elif backend == "usb-direct":
                record["backendStatusLabel"] = "USB Direct: Kilitli / CUPS tutuyor olabilir"
                record["statusLevel"] = (
                    "error"
                    if str(record.get("statusLevel") or "").strip().lower() == "error"
                    else "warning"
                )
                if not str(record.get("statusMessage") or "").strip():
                    record["statusMessage"] = (
                        "Bu yazici macOS tarafindan tutuluyor olabilir. "
                        "Adisyon icin CUPS yolunu kullanmaniz onerilir."
                    )
    return records


def discover_windows_printers() -> list[dict[str, object]]:
    if platform.system().lower() != "windows":
        return []

    script = r"""
$spool = @()
try {
  $spool = Get-CimInstance Win32_Printer |
    Select-Object Name, PortName, DriverName, PrinterStatus, WorkOffline, Default, DeviceID, Availability, ExtendedPrinterStatus, DetectedErrorState, PrinterState
} catch {
  $spool = @()
}

$pnp = @()
try {
  $pnp = Get-CimInstance Win32_PnPEntity |
    Where-Object {
      $_.PNPClass -eq 'Printer' -or
      $_.PNPDeviceID -like 'USBPRINT*' -or
      $_.PNPDeviceID -like 'USB\\VID_*'
    } |
    Select-Object Name, PNPDeviceID
} catch {
  $pnp = @()
}

[pscustomobject]@{
  spool = $spool
  pnp = $pnp
} | ConvertTo-Json -Compress -Depth 4
"""
    creationflags = 0
    if hasattr(subprocess, "CREATE_NO_WINDOW"):
        creationflags = subprocess.CREATE_NO_WINDOW  # type: ignore[attr-defined]

    try:
        result = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-NonInteractive",
                "-WindowStyle",
                "Hidden",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                script,
            ],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
            creationflags=creationflags,
        )
    except (OSError, subprocess.SubprocessError):
        return []

    if result.returncode != 0 or not result.stdout.strip():
        return []

    try:
        decoded = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []

    spool_items = decoded.get("spool") or []
    pnp_items = decoded.get("pnp") or []
    if isinstance(spool_items, dict):
        spool_items = [spool_items]
    if isinstance(pnp_items, dict):
        pnp_items = [pnp_items]

    pnp_name_map: dict[str, tuple[str | None, str | None]] = {}
    for item in pnp_items:
        if not isinstance(item, dict):
            continue
        name = str(item.get("Name") or "").strip().lower()
        vid, pid = _extract_vid_pid(item.get("PNPDeviceID"), item.get("Name"))
        if name:
            pnp_name_map[name] = (vid, pid)

    printers: list[dict[str, object]] = []
    for item in spool_items:
        if not isinstance(item, dict):
            continue
        name = str(item.get("Name") or item.get("DeviceID") or "").strip()
        if not name:
            continue
        port_name = str(item.get("PortName") or "").strip()
        normalized_name = name.lower()
        vendor_id, product_id = pnp_name_map.get(normalized_name, (None, None))
        if vendor_id is None and product_id is None:
            for pnp_name, ids in pnp_name_map.items():
                if normalized_name in pnp_name or pnp_name in normalized_name:
                    vendor_id, product_id = ids
                    break

        connection_type = infer_connection_type(port_name=port_name)
        offline = bool(item.get("WorkOffline"))
        driver_name = str(item.get("DriverName") or "").strip()
        printer_status_raw = str(item.get("PrinterStatus") or "").strip()
        extended_status_raw = str(item.get("ExtendedPrinterStatus") or "").strip()
        detected_error_state_raw = str(item.get("DetectedErrorState") or "").strip()
        availability_raw = str(item.get("Availability") or "").strip()

        status = "online"
        status_level = "ready"
        status_message = "Yazıcı hazır."
        error_code = None
        warning_code = None

        if not driver_name:
            status = "driver_missing"
            status_level = "error"
            error_code = "driver_missing"
            status_message = "Windows sürücüsü eksik veya yazıcıyla eşleşmemiş."
        elif offline:
            status = "offline"
            status_level = "error"
            error_code = "printer_unavailable"
            status_message = "Yazıcı Windows'ta kurulu ama çevrimdışı veya kullanılamıyor."
        elif printer_status_raw not in {"", "3", "4"}:
            status = "warning"
            status_level = "warning"
            warning_code = "printer_status_warning"
            status_message = (
                "Windows yazıcı durumu olağan dışı görünüyor. "
                "Test fişi ile doğrulayın."
            )
        elif extended_status_raw not in {"", "2", "3"} or detected_error_state_raw not in {"", "2", "0"}:
            status = "warning"
            status_level = "warning"
            warning_code = "spooler_warning"
            status_message = "Spooler yazıcı için uyarı bildiriyor. Test baskısı önerilir."

        profile = classify_windows_printer(
            name=name,
            driver_name=driver_name,
            port_name=port_name,
            base_status_level=status_level,
            base_status_message=status_message,
        )
        status_level = profile.status_level
        status_message = profile.status_message
        warning_code = profile.warning_code or warning_code
        metadata = {
            "printerStatus": printer_status_raw or None,
            "extendedPrinterStatus": extended_status_raw or None,
            "detectedErrorState": detected_error_state_raw or None,
            "availability": availability_raw or None,
            **profile.as_metadata(),
        }
        printers.append(
            PrinterRecord(
                id=f"windows:{name}",
                name=name,
                vendor_id=vendor_id,
                product_id=product_id,
                connection_type=connection_type,
                backend="windows-spool",
                queue=name,
                detail=(
                    f"Port={port_name or '-'} Driver={item.get('DriverName') or '-'} "
                    f"Status={item.get('PrinterStatus') or '-'} "
                    f"Extended={extended_status_raw or '-'} ErrorState={detected_error_state_raw or '-'}"
                ),
                status=status,
                is_default=bool(item.get("Default")),
                status_level=status_level,
                status_message=status_message,
                error_code=error_code,
                warning_code=warning_code,
                driver_name=driver_name or None,
                port_name=port_name or None,
                metadata=metadata,
            ).as_dict()
        )

    return printers
