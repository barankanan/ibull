from __future__ import annotations

from dataclasses import dataclass, field
import logging
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from .config import BridgeSettings
from .printers import PrinterRecord, infer_connection_type

LOGGER = logging.getLogger("local_print_bridge.transport")


class TransportError(RuntimeError):
    """Raised when the local print transport cannot submit a job."""

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        details: dict[str, object] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.details = details or {}


@dataclass(frozen=True)
class PrintResult:
    job_id: str | None
    raw_output: str
    bytes_sent: int
    metadata: dict[str, object] = field(default_factory=dict)


class CupsRawTransport:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.lp_path = shutil.which("lp") or self._find_system_command("lp")
        self.lpstat_path = shutil.which("lpstat") or self._find_system_command("lpstat")

    def _find_system_command(self, name: str) -> str | None:
        path = Path(f"/usr/bin/{name}")
        return str(path) if path.exists() else None

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
        if self.lpstat_path and not self._queue_exists():
            raise TransportError(
                f"Configured CUPS queue '{self.settings.printer_queue}' was not found. "
                "Run `lpstat -p` to list available queues and update PRINT_BRIDGE_PRINTER_QUEUE."
            )

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
            command = [
                self.lp_path,
                "-d",
                self.settings.printer_queue,
                "-o",
                "raw",
                "-t",
                job_name,
                str(temp_path),
            ]
            if result.returncode == 0:
                LOGGER.info(
                    "cups-print-result: queue=%s backend=cups bytes_sent=%d exit_code=%d job_name=%s output=%s",
                    self.settings.printer_queue,
                    len(payload),
                    result.returncode,
                    job_name,
                    output or "-",
                )
            if result.returncode != 0:
                LOGGER.error(
                    "cups-print-result: queue=%s backend=cups bytes_sent=%d exit_code=%d job_name=%s output=%s",
                    self.settings.printer_queue,
                    len(payload),
                    result.returncode,
                    job_name,
                    output or "-",
                )
                raise TransportError(
                    output
                    and f"CUPS lp failed (exit_code={result.returncode}): {output}"
                    or f"CUPS lp failed (exit_code={result.returncode})."
                )
            return PrintResult(
                job_id=self._extract_job_id(output),
                raw_output=output,
                bytes_sent=len(payload),
                metadata={
                    "actual_backend": "cups",
                    "selected_queue": self.settings.printer_queue,
                    "lp_exit_code": result.returncode,
                    "lp_command": " ".join(command),
                    "lp_output": output,
                },
            )
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)

    def queue_status(self, queue_name: str | None = None) -> dict[str, object]:
        """
        Best-effort queue status snapshot for UX.

        Returns:
        - queue_has_active_job (bool)
        - active_job_id (str|None)
        - active_job_ids (list[str])
        - queue_status (str)   [idle|printing|stuck|disabled|unknown|lpstat_unavailable]
        - queue_message (str)
        - suggested_action (str|None)
        """
        queue = (queue_name or self.settings.printer_queue or "").strip()
        if not queue:
            return {
                "queue_has_active_job": False,
                "active_job_id": None,
                "active_job_ids": [],
                "queue_status": "unknown",
                "queue_message": "CUPS kuyruğu seçili değil.",
                "suggested_action": None,
            }
        if not self.lpstat_path:
            return {
                "queue_has_active_job": False,
                "active_job_id": None,
                "active_job_ids": [],
                "queue_status": "lpstat_unavailable",
                "queue_message": "lpstat bulunamadı. Kuyruk durumu doğrulanamadı.",
                "suggested_action": None,
            }

        def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )

        try:
            p_result = _run([self.lpstat_path, "-p", queue])
            p_out = (p_result.stdout or p_result.stderr or "").strip()
            p_low = p_out.lower()
            disabled = "disabled" in p_low or "paused" in p_low
            printing = "printing" in p_low or "yazdır" in p_low or "yazdir" in p_low

            o_result = _run([self.lpstat_path, "-o", queue])
            o_out = (o_result.stdout or o_result.stderr or "").strip()
            active_job_ids: list[str] = []
            for line in o_out.splitlines():
                txt = line.strip()
                if not txt:
                    continue
                # Typical: "QUEUE-177 username ...", localized variants still start with job id.
                first = txt.split(None, 1)[0].strip()
                if first:
                    active_job_ids.append(first)
            active_job_id = active_job_ids[0] if active_job_ids else None
            has_job = bool(active_job_ids)

            if disabled:
                return {
                    "queue_has_active_job": has_job,
                    "active_job_id": active_job_id,
                    "active_job_ids": active_job_ids,
                    "queue_status": "disabled",
                    "queue_message": "Yazıcı kuyruğu devre dışı/paused görünüyor. CUPS kuyruğunu etkinleştirin.",
                    "suggested_action": "enable_queue",
                }
            if has_job and printing:
                return {
                    "queue_has_active_job": True,
                    "active_job_id": active_job_id,
                    "active_job_ids": active_job_ids,
                    "queue_status": "printing",
                    "queue_message": "Yazıcı kuyruğunda aktif/bekleyen işler görünüyor.",
                    "suggested_action": "clear_queue",
                }
            if has_job:
                return {
                    "queue_has_active_job": True,
                    "active_job_id": active_job_id,
                    "active_job_ids": active_job_ids,
                    "queue_status": "stuck",
                    "queue_message": "Yazıcı kuyruğunda bekleyen işler var (CUPS bekliyor olabilir).",
                    "suggested_action": "clear_queue",
                }
            return {
                "queue_has_active_job": False,
                "active_job_id": None,
                "active_job_ids": [],
                "queue_status": "idle",
                "queue_message": "Kuyruk boş.",
                "suggested_action": None,
            }
        except Exception as exc:  # noqa: BLE001
            return {
                "queue_has_active_job": False,
                "active_job_id": None,
                "active_job_ids": [],
                "queue_status": "unknown",
                "queue_message": f"Kuyruk durumu okunamadı: {exc}",
                "suggested_action": None,
            }

    def clear_queue(self, queue_name: str | None = None) -> dict[str, object]:
        queue = (queue_name or self.settings.printer_queue or "").strip()
        if not queue:
            return {"ok": False, "error": "CUPS kuyruğu seçili değil."}

        def _run(args: list[str]) -> dict[str, object]:
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=False,
                timeout=8,
            )
            return {
                "command": " ".join(args),
                "exit_code": result.returncode,
                "stdout": (result.stdout or "").strip(),
                "stderr": (result.stderr or "").strip(),
            }

        cancel_path = shutil.which("cancel") or self._find_system_command("cancel")
        cupsenable_path = shutil.which("cupsenable") or self._find_system_command("cupsenable")
        cupsaccept_path = shutil.which("cupsaccept") or self._find_system_command("cupsaccept")
        if not cancel_path or not cupsenable_path or not cupsaccept_path:
            return {
                "ok": False,
                "error": "CUPS komutları bulunamadı (cancel/cupsenable/cupsaccept).",
                "available": {
                    "cancel": bool(cancel_path),
                    "cupsenable": bool(cupsenable_path),
                    "cupsaccept": bool(cupsaccept_path),
                },
            }

        steps = [
            _run([cancel_path, "-a", queue]),
            _run([cupsenable_path, queue]),
            _run([cupsaccept_path, queue]),
        ]
        status = self.queue_status(queue)
        ok = all(int(step.get("exit_code", 1)) == 0 for step in steps)
        return {
            "ok": ok,
            "queue": queue,
            "steps": steps,
            "queue_status": status,
        }

    def discover(self) -> list[dict[str, object]]:
        """Return a list of available CUPS printer queues on this system.

        Uses ``lpstat -p --no-header`` (falls back to ``lpstat -p``) to list
        all queues.  Returns an empty list when ``lpstat`` is unavailable.
        """
        if not self.lpstat_path:
            return []
        try:
            device_result = subprocess.run(
                [self.lpstat_path, "-v"],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
            device_uri_by_queue: dict[str, str] = {}
            for line in (device_result.stdout or "").splitlines():
                txt = line.strip()
                # English: "device for TM_T20: usb://..."
                # Localized output may use a phrase such as "Canon_E410_series için aygıt: usb://..."
                m = re.match(r"^device\s+for\s+([^:]+):\s+(.+)$", txt)
                if m:
                    device_uri_by_queue[m.group(1).strip()] = m.group(2).strip()
                    continue
                if ":" not in txt:
                    continue
                queue_part, uri_part = txt.split(":", 1)
                queue_name = queue_part.split(None, 1)[0].strip()
                if queue_name and uri_part.strip():
                    device_uri_by_queue[queue_name] = uri_part.strip()

            result = subprocess.run(
                [self.lpstat_path, "-p"],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
            queues: list[dict[str, object]] = []
            for line in (result.stdout or "").splitlines():
                if line.startswith((" ", "\t")):
                    continue
                txt = line.strip()
                # English: "printer YAZICI_1 is idle.  enabled since ..."
                # Localized macOS output can start with the queue name instead:
                # "Canon_E410_series yazıcısı, ..."
                queue_name = None
                m = re.match(r"^printer\s+(\S+)", txt)
                if m:
                    queue_name = m.group(1)
                elif txt.lower().startswith("device"):
                    queue_name = None
                else:
                    parts = txt.split(None, 1)
                    if parts:
                        queue_name = parts[0]

                if not queue_name:
                    continue

                device_uri = device_uri_by_queue.get(queue_name, "")
                queues.append(
                        PrinterRecord(
                            id=f"cups:{queue_name}",
                            name=queue_name,
                            vendor_id=None,
                            product_id=None,
                            connection_type=infer_connection_type(device_uri=device_uri),
                            backend="cups",
                            queue=queue_name,
                            detail=line.strip(),
                            device_uri=device_uri or None,
                            status="online",
                            status_level="ready",
                            status_message="CUPS kuyruğu hazır.",
                        ).as_dict()
                    )
            return queues
        except Exception:  # noqa: BLE001
            return []

    def _queue_exists(self) -> bool:
        if not self.lpstat_path:
            return True
        try:
            result = subprocess.run(
                [self.lpstat_path, "-p", self.settings.printer_queue],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
            return result.returncode == 0
        except Exception:  # noqa: BLE001
            return False

    def _extract_job_id(self, output: str) -> str | None:
        match = re.search(r"request id is ([^ ]+)", output)
        return match.group(1) if match else None
