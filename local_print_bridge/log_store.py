from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
from pathlib import Path
import threading
from typing import Any

from .runtime_paths import bridge_print_log_path


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class PrintLogEntry:
    timestamp: str
    printer_id: str
    printer_name: str
    transport_type: str
    document_type: str
    success: bool
    duration_ms: int
    error_details: str = ""
    queue_status: str = ""
    queue_wait_ms: int = 0
    retry_count: int = 0
    job_name: str = ""
    backend_job_id: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


class PrintLogStore:
    def __init__(self, path: Path | None = None) -> None:
        self._path = path or bridge_print_log_path()
        self._disabled = False
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
        except OSError:
            # In sandboxed/unit-test environments the default path might not be writable.
            # Logging must never crash the print bridge.
            self._disabled = True
        self._lock = threading.Lock()

    @property
    def path(self) -> Path:
        return self._path

    def append(self, entry: PrintLogEntry) -> None:
        if self._disabled:
            return
        line = json.dumps(entry.as_dict(), ensure_ascii=False)
        with self._lock:
            try:
                with self._path.open("a", encoding="utf-8") as handle:
                    handle.write(line + "\n")
            except OSError:
                # Do not crash printing due to log write failures.
                self._disabled = True

    def read_all(self) -> list[dict[str, Any]]:
        if self._disabled:
            return []
        if not self._path.is_file():
            return []
        with self._lock:
            try:
                lines = self._path.read_text(encoding="utf-8").splitlines()
            except OSError:
                self._disabled = True
                return []
        entries: list[dict[str, Any]] = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                decoded = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(decoded, dict):
                entries.append(decoded)
        return entries

    def read_recent(self, limit: int = 50) -> list[dict[str, Any]]:
        items = self.read_all()
        return items[-max(1, limit):]

    def count(self) -> int:
        return len(self.read_all())

    def build_entry(
        self,
        *,
        printer_id: str,
        printer_name: str,
        transport_type: str,
        document_type: str,
        success: bool,
        duration_ms: int,
        error_details: str = "",
        queue_status: str = "",
        queue_wait_ms: int = 0,
        retry_count: int = 0,
        job_name: str = "",
        backend_job_id: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> PrintLogEntry:
        return PrintLogEntry(
            timestamp=_utc_now_iso(),
            printer_id=printer_id,
            printer_name=printer_name,
            transport_type=transport_type,
            document_type=document_type,
            success=success,
            duration_ms=duration_ms,
            error_details=error_details,
            queue_status=queue_status,
            queue_wait_ms=queue_wait_ms,
            retry_count=retry_count,
            job_name=job_name,
            backend_job_id=backend_job_id,
            metadata=metadata or {},
        )
