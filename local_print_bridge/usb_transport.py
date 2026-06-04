"""macOS / Linux USB direct transport for ESC/POS printers.

Writes raw bytes to the USB bulk-OUT endpoint without any CUPS queue.
Works on macOS where `lpadmin -m raw` is no longer supported.

Prerequisites (macOS):
    brew install libusb
    pip install pyusb

The PRINT_BRIDGE_TRANSPORT environment variable controls behaviour:
    auto  — try USB first, fall back to CUPS (default)
    usb   — USB only; error if not available
    cups  — CUPS only (legacy behaviour)
"""
from __future__ import annotations

import logging
import threading
from dataclasses import dataclass

from .transport import PrintResult, TransportError

LOGGER = logging.getLogger("local_print_bridge.usb")

_PRINTER_CLASS = 7  # USB Printer class code


def _import_usb():
    """Return the usb package or None when pyusb is not installed."""
    try:
        import usb.core  # noqa: PLC0415
        import usb.util  # noqa: PLC0415

        return usb
    except ImportError:
        return None


def _is_printer_iface(dev) -> bool:
    """Return True if the device exposes at least one Printer-class interface."""
    try:
        for cfg in dev:
            for intf in cfg:
                if intf.bInterfaceClass == _PRINTER_CLASS:
                    return True
    except Exception:  # noqa: BLE001
        pass
    return False


@dataclass(frozen=True)
class UsbDeviceInfo:
    vendor_id: int
    product_id: int
    manufacturer: str
    product: str
    serial: str
    bus: int
    address: int

    @property
    def vid_pid(self) -> str:
        return f"{self.vendor_id:04x}:{self.product_id:04x}"

    def as_dict(self) -> dict[str, object]:
        return {
            "id": (
                f"usb:{self.vendor_id:04x}:{self.product_id:04x}:"
                f"{self.bus}:{self.address}:{self.serial or '-'}"
            ),
            "name": self.product or self.manufacturer or self.vid_pid,
            "vendorId": f"0x{self.vendor_id:04x}",
            "productId": f"0x{self.product_id:04x}",
            "connectionType": "usb",
            "backend": "usb-direct",
            "transportType": "usb-direct",
            "vid": f"0x{self.vendor_id:04x}",
            "pid": f"0x{self.product_id:04x}",
            "vid_pid": self.vid_pid,
            "vendor_id": self.vendor_id,
            "product_id": self.product_id,
            "manufacturer": self.manufacturer,
            "product": self.product,
            "serial": self.serial,
            "bus": self.bus,
            "address": self.address,
            "status": "online",
            "statusLevel": "ready",
            "statusMessage": "USB yazıcı hazır.",
            "ready": True,
        }


class UsbDirectTransport:
    """Write ESC/POS bytes directly to a USB printer without CUPS.

    Pass ``vendor_id`` and/or ``product_id`` to target a specific device;
    omit both for auto-discovery (first Printer-class USB device found).
    """

    def __init__(
        self,
        *,
        vendor_id: int | None = None,
        product_id: int | None = None,
        timeout_ms: int = 5000,
    ) -> None:
        self._vendor_id = vendor_id
        self._product_id = product_id
        self._timeout_ms = timeout_ms
        # Cached USB device + endpoint for fast repeated prints.
        self._cached_dev = None
        self._cached_ep_out = None
        self._cached_intf_num: int | None = None
        self._cached_bus: int | None = None
        self._cached_address: int | None = None
        self._write_lock = threading.Lock()

    # ── discovery ─────────────────────────────────────────────────────

    @staticmethod
    def discover() -> list[UsbDeviceInfo]:
        """Return info about every USB device that has a Printer-class interface."""
        usb = _import_usb()
        if usb is None:
            return []
        results: list[UsbDeviceInfo] = []
        try:
            all_devs = list(usb.core.find(find_all=True) or [])
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("USB discover error: %s", exc)
            return []
        for dev in all_devs:
            if not _is_printer_iface(dev):
                continue
            mfr = prd = ser = ""
            try:
                mfr = usb.util.get_string(dev, dev.iManufacturer) if dev.iManufacturer else ""
            except Exception:  # noqa: BLE001
                pass
            try:
                prd = usb.util.get_string(dev, dev.iProduct) if dev.iProduct else ""
            except Exception:  # noqa: BLE001
                pass
            try:
                ser = (
                    usb.util.get_string(dev, dev.iSerialNumber)
                    if dev.iSerialNumber
                    else ""
                )
            except Exception:  # noqa: BLE001
                pass
            results.append(
                UsbDeviceInfo(
                    vendor_id=dev.idVendor,
                    product_id=dev.idProduct,
                    manufacturer=mfr,
                    product=prd,
                    serial=ser,
                    bus=dev.bus,
                    address=dev.address,
                )
            )
        return results

    # ── health ────────────────────────────────────────────────────────

    def health(self) -> dict[str, object]:
        usb = _import_usb()
        if usb is None:
            return {
                "ok": False,
                "transport": "usb-direct",
                "reason": "pyusb not installed",
                "fix": "brew install libusb && pip install pyusb",
            }
        dev = self._find_device(usb)
        if dev is None:
            found = self.discover()
            return {
                "ok": False,
                "transport": "usb-direct",
                "reason": "Target USB printer not found",
                "target_vid": f"0x{self._vendor_id:04x}" if self._vendor_id else "auto",
                "target_pid": f"0x{self._product_id:04x}" if self._product_id else "auto",
                "discovered": [d.as_dict() for d in found],
            }
        return {
            "ok": True,
            "transport": "usb-direct",
            "vid": f"0x{dev.idVendor:04x}",
            "pid": f"0x{dev.idProduct:04x}",
            "bus": dev.bus,
            "address": dev.address,
        }

    # ── printing ──────────────────────────────────────────────────────

    def print_bytes(self, payload: bytes, *, job_name: str = "ibul-print") -> PrintResult:
        usb = _import_usb()
        if usb is None:
            raise TransportError(
                "pyusb is not installed. Run: brew install libusb && pip install pyusb"
            )
        dev = self._find_device(usb)
        if dev is None:
            raise TransportError(
                "No USB printer found. Verify the printer is powered on and connected. "
                "Call GET /discover to list detected USB printers."
            )
        return self._write(usb, dev, payload, job_name=job_name)

    # ── internals ─────────────────────────────────────────────────────

    def _find_device(self, usb):
        try:
            if self._vendor_id and self._product_id:
                return usb.core.find(idVendor=self._vendor_id, idProduct=self._product_id)
            if self._vendor_id:
                return usb.core.find(idVendor=self._vendor_id)
            # Auto: first device with a Printer-class interface
            for dev in usb.core.find(find_all=True) or []:
                if _is_printer_iface(dev):
                    return dev
            return None
        except Exception as exc:  # noqa: BLE001
            LOGGER.warning("USB find_device error: %s", exc)
            return None

    def _write(self, usb, dev, payload: bytes, *, job_name: str) -> PrintResult:
        LOGGER.info(
            "USB print start: job=%s vid=0x%04x pid=0x%04x bytes=%d",
            job_name,
            dev.idVendor,
            dev.idProduct,
            len(payload),
        )
        with self._write_lock:
            try:
                cached_match = (
                    self._cached_dev is not None
                    and self._cached_ep_out is not None
                    and self._cached_bus == dev.bus
                    and self._cached_address == dev.address
                )
                if cached_match:
                    cached_dev = self._cached_dev
                    ep_out = self._cached_ep_out
                    LOGGER.debug("USB reusing cached endpoint for job=%s", job_name)
                else:
                    cached_dev, ep_out = self._prepare_cached_endpoint(usb, dev)

                chunk_size = 16384
                written = 0
                for offset in range(0, len(payload), chunk_size):
                    chunk = payload[offset : offset + chunk_size]
                    ep_out.write(chunk, timeout=self._timeout_ms)
                    written += len(chunk)

                LOGGER.info(
                    "USB print done: job=%s bytes=%d vid=0x%04x pid=0x%04x",
                    job_name,
                    written,
                    cached_dev.idVendor,
                    cached_dev.idProduct,
                )
                return PrintResult(
                    job_id=(
                        f"usb-{cached_dev.idVendor:04x}{cached_dev.idProduct:04x}"
                        f"-b{cached_dev.bus}a{cached_dev.address}"
                    ),
                    raw_output=(
                        f"USB direct: {written} bytes → "
                        f"0x{cached_dev.idVendor:04x}:0x{cached_dev.idProduct:04x}"
                    ),
                    bytes_sent=written,
                    metadata={
                        "actual_backend": "usb-direct",
                        "usb_vendor_id": f"0x{cached_dev.idVendor:04x}",
                        "usb_product_id": f"0x{cached_dev.idProduct:04x}",
                        "usb_bus": cached_dev.bus,
                        "usb_address": cached_dev.address,
                    },
                )
            except TransportError:
                self._invalidate_cache(usb)
                raise
            except Exception as exc:  # noqa: BLE001
                self._invalidate_cache(usb)
                raise TransportError(f"USB write failed: {exc}") from exc

    def _prepare_cached_endpoint(self, usb, dev):
        self._invalidate_cache(usb)
        try:
            if dev.is_kernel_driver_active(0):
                dev.detach_kernel_driver(0)
        except (AttributeError, NotImplementedError, Exception):  # noqa: BLE001
            pass

        try:
            dev.set_configuration()
        except Exception:  # noqa: BLE001
            pass

        cfg = dev.get_active_configuration()
        intf = usb.util.find_descriptor(cfg, bInterfaceClass=_PRINTER_CLASS)
        if intf is None:
            intf = cfg[(0, 0)]

        try:
            usb.util.claim_interface(dev, intf.bInterfaceNumber)
        except usb.core.USBError as exc:
            raise TransportError(
                f"Cannot claim USB interface: {exc}. "
                "If CUPS is holding the device, restart it: sudo killall -USR1 cupsd",
                code="usb_interface_claim_denied",
                details={
                    "suggested_backend": "cups",
                    "recommended_backend": "cups",
                    "operator_message": (
                        "Bu yazıcı macOS tarafından tutuluyor. "
                        "Adisyon için CUPS yolunu kullanmanız önerilir."
                    ),
                    "usb_claim_error": str(exc),
                },
            ) from exc

        ep_out = usb.util.find_descriptor(
            intf,
            custom_match=lambda e: (
                usb.util.endpoint_direction(e.bEndpointAddress)
                == usb.util.ENDPOINT_OUT
                and usb.util.endpoint_type(e.bmAttributes)
                == usb.util.ENDPOINT_TYPE_BULK
            ),
        )
        if ep_out is None:
            raise TransportError("No bulk-OUT endpoint found on USB printer interface.")

        self._cached_dev = dev
        self._cached_ep_out = ep_out
        self._cached_intf_num = intf.bInterfaceNumber
        self._cached_bus = dev.bus
        self._cached_address = dev.address
        LOGGER.debug(
            "USB cached endpoint prepared bus=%s address=%s intf=%s",
            dev.bus,
            dev.address,
            intf.bInterfaceNumber,
        )
        return dev, ep_out

    def _invalidate_cache(self, usb=None) -> None:
        """Clear cached device/endpoint so next print does a fresh setup."""
        if usb is not None and self._cached_dev is not None and self._cached_intf_num is not None:
            try:
                usb.util.release_interface(self._cached_dev, self._cached_intf_num)
            except Exception:  # noqa: BLE001
                pass
            try:
                usb.util.dispose_resources(self._cached_dev)
            except Exception:  # noqa: BLE001
                pass
        self._cached_dev = None
        self._cached_ep_out = None
        self._cached_intf_num = None
        self._cached_bus = None
        self._cached_address = None
