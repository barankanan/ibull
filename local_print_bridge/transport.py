from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from .config import BridgeSettings


class TransportError(RuntimeError):
    """Raised when the local print transport cannot submit a job."""


@dataclass(frozen=True)
class PrintResult:
    job_id: str | None
    raw_output: str
    bytes_sent: int


class CupsRawTransport:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.lp_path = shutil.which("lp")
        self.lpstat_path = shutil.which("lpstat")

    def health(self) -> dict[str, object]:
        if not self.lp_path:
            return {
                "ok": False,
                "transport": "cups-lp-raw",
                "reason": "`lp` command not found on this Mac.",
            }
        if not self.settings.printer_queue:
            return {
                "ok": False,
                "transport": "cups-lp-raw",
                "reason": "PRINT_BRIDGE_PRINTER_QUEUE is not configured.",
            }
        if not self.settings.healthcheck_queue:
            return {
                "ok": True,
                "transport": "cups-lp-raw",
                "queue": self.settings.printer_queue,
                "queue_check": "skipped",
            }
        if not self.lpstat_path:
            return {
                "ok": True,
                "transport": "cups-lp-raw",
                "queue": self.settings.printer_queue,
                "queue_check": "lpstat-unavailable",
            }

        result = subprocess.run(
            [self.lpstat_path, "-p", self.settings.printer_queue],
            capture_output=True,
            text=True,
            check=False,
        )
        ok = result.returncode == 0
        details = (result.stdout or result.stderr).strip()
        return {
            "ok": ok,
            "transport": "cups-lp-raw",
            "queue": self.settings.printer_queue,
            "queue_check": "ok" if ok else "failed",
            "details": details,
        }

    def print_bytes(self, payload: bytes, *, job_name: str) -> PrintResult:
        if not self.lp_path:
            raise TransportError("`lp` command is not available on this system.")
        if not self.settings.printer_queue:
            raise TransportError("PRINT_BRIDGE_PRINTER_QUEUE must be configured before printing.")

        temp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                prefix="ibul-receipt-",
                suffix=".bin",
                delete=False,
            ) as handle:
                handle.write(payload)
                handle.flush()
                temp_path = Path(handle.name)

            result = subprocess.run(
                [
                    self.lp_path,
                    "-d",
                    self.settings.printer_queue,
                    "-o",
                    "raw",
                    "-t",
                    job_name,
                    str(temp_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            output = (result.stdout or result.stderr).strip()
            if result.returncode != 0:
                raise TransportError(output or "Failed to submit print job to CUPS.")
            return PrintResult(
                job_id=self._extract_job_id(output),
                raw_output=output,
                bytes_sent=len(payload),
            )
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)

    def _extract_job_id(self, output: str) -> str | None:
        match = re.search(r"request id is ([^ ]+)", output)
        return match.group(1) if match else None
