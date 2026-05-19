from __future__ import annotations

import platform
from typing import Any

from .printers import discover_windows_printers
from .transport import PrintResult, TransportError


def peek_windows_spool_jobs(printer_name: str) -> dict[str, object]:
    """Return a lightweight snapshot of jobs visible in the Windows spooler."""
    win32print = _import_win32print()
    if win32print is None or not printer_name.strip():
        return {
            "ok": False,
            "printer_name": printer_name,
            "job_count": 0,
            "active_job_ids": [],
            "reason": "pywin32_unavailable",
        }
    handle = None
    try:
        handle = win32print.OpenPrinter(printer_name)
        jobs = win32print.EnumJobs(handle, 0, -1, 1)
        job_ids = [int(job.get("JobId", 0)) for job in jobs if isinstance(job, dict)]
        return {
            "ok": True,
            "printer_name": printer_name,
            "job_count": len(job_ids),
            "active_job_ids": job_ids,
            "latest_job_id": job_ids[-1] if job_ids else None,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "ok": False,
            "printer_name": printer_name,
            "job_count": 0,
            "active_job_ids": [],
            "reason": str(exc),
        }
    finally:
        if handle is not None:
            try:
                win32print.ClosePrinter(handle)
            except Exception:  # noqa: BLE001
                pass


def _import_win32print():
    try:
        import win32print  # type: ignore[import-not-found]  # noqa: PLC0415

        return win32print
    except ImportError:
        return None


class WindowsSpoolTransport:
    def __init__(self, printer_name: str | None) -> None:
        self.printer_name = (printer_name or "").strip()

    @staticmethod
    def supported() -> bool:
        return platform.system().lower() == "windows"

    def health(self) -> dict[str, object]:
        if not self.supported():
            return {
                "ok": False,
                "transport": "windows-spool",
                "reason": "Windows spool transport is only available on Windows.",
            }
        if not self.printer_name:
            return {
                "ok": False,
                "transport": "windows-spool",
                "reason": "PRINT_BRIDGE_PRINTER_QUEUE must contain the Windows printer name.",
            }
        printers = discover_windows_printers()
        match = next((p for p in printers if p.get("queue") == self.printer_name), None)
        if match is None:
            return {
                "ok": False,
                "transport": "windows-spool",
                "printer": self.printer_name,
                "reason": "Configured Windows printer not found.",
            }
        return {
            "ok": match.get("statusLevel") == "ready",
            "transport": "windows-spool",
            "printer": self.printer_name,
            "status": match.get("status") or "unknown",
            "statusLevel": match.get("statusLevel") or "unknown",
            "statusMessage": match.get("statusMessage") or "",
            "errorCode": match.get("errorCode"),
            "warningCode": match.get("warningCode"),
            "detail": match.get("detail") or "",
        }

    def discover(self) -> list[dict[str, object]]:
        return discover_windows_printers()

    def print_bytes(self, payload: bytes, *, job_name: str) -> PrintResult:
        if not self.supported():
            raise TransportError("Windows spool transport is only available on Windows.")
        if not self.printer_name:
            raise TransportError("Windows printer name is not configured.")

        win32print = _import_win32print()
        if win32print is None:
            raise TransportError(
                "pywin32 missing: install it with `pip install pywin32` on Windows."
            )

        handle = None
        doc_id = None
        total_written = 0
        try:
            handle = win32print.OpenPrinter(self.printer_name)
            doc_id = win32print.StartDocPrinter(handle, 1, (job_name, None, "RAW"))
            win32print.StartPagePrinter(handle)
            view = memoryview(payload)
            while total_written < len(payload):
                written = win32print.WritePrinter(handle, view[total_written:])
                if written <= 0:
                    raise TransportError(
                        "Windows RAW spooler rejected the job (WritePrinter returned 0 bytes)."
                    )
                total_written += written
            win32print.EndPagePrinter(handle)
            win32print.EndDocPrinter(handle)
        except Exception as exc:  # noqa: BLE001
            raise TransportError(self._format_error(exc)) from exc
        finally:
            if handle is not None:
                try:
                    win32print.ClosePrinter(handle)
                except Exception:  # noqa: BLE001
                    pass

        spool_snapshot = peek_windows_spool_jobs(self.printer_name)
        return PrintResult(
            job_id=str(doc_id) if doc_id is not None else None,
            raw_output=f"Windows spool RAW -> {self.printer_name}",
            bytes_sent=total_written,
            metadata={
                "actual_backend": "windows-spool",
                "selected_queue": self.printer_name,
                "printer_name": self.printer_name,
                "spool_mode": "RAW",
                "document_type": "test",
                "spool_jobs_after_print": spool_snapshot.get("job_count"),
                "spool_latest_job_id": spool_snapshot.get("latest_job_id"),
                "spool_active_job_ids": spool_snapshot.get("active_job_ids") or [],
                "spool_snapshot": spool_snapshot,
            },
        )

    def _format_error(self, exc: Exception) -> str:
        message = str(exc).strip()
        lowered = message.lower()
        if "specified printer has been deleted" in lowered or "1801" in lowered:
            return f"Windows printer '{self.printer_name}' is no longer available."
        if "invalid printer name" in lowered:
            return f"Windows printer '{self.printer_name}' was not found."
        if "driver" in lowered:
            return (
                f"Windows driver problem for '{self.printer_name}'. "
                "Reinstall or repair the printer driver."
            )
        if "access is denied" in lowered:
            return (
                f"Windows spooler rejected RAW printing for '{self.printer_name}' "
                "because access was denied."
            )
        if "offline" in lowered or "not ready" in lowered:
            return f"Windows printer '{self.printer_name}' is offline or not ready."
        return f"Windows RAW print failed for '{self.printer_name}': {message}"
