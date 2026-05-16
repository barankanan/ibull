from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
import threading
import time
import uuid
from typing import Callable


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class QueueExecutionResult:
    queue_job_id: str
    final_status: str
    duration_ms: int
    queue_wait_ms: int
    retry_count: int
    started_at: str
    completed_at: str


@dataclass
class _QueuedJob:
    id: str
    printer_key: str
    printer_name: str
    transport_type: str
    document_type: str
    job_name: str
    enqueued_at: float
    queued_at_iso: str
    started_at: float | None = None
    started_at_iso: str | None = None
    completed_at: float | None = None
    completed_at_iso: str | None = None
    status: str = "queued"
    retry_count: int = 0
    error_details: str = ""


class PrintQueueManager:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._condition = threading.Condition(self._lock)
        self._queues: dict[str, deque[str]] = {}
        self._active: dict[str, str | None] = {}
        self._jobs: dict[str, _QueuedJob] = {}
        self._recent: deque[dict[str, object]] = deque(maxlen=200)

    def run_job(
        self,
        *,
        printer_key: str,
        printer_name: str,
        transport_type: str,
        document_type: str,
        job_name: str,
        execute: Callable[[], object],
        is_transient_error: Callable[[Exception], bool],
        max_retries: int = 1,
    ) -> tuple[QueueExecutionResult, object]:
        queue_job_id = f"queue-{uuid.uuid4().hex[:12]}"
        enqueued_at = time.monotonic()
        queued_job = _QueuedJob(
            id=queue_job_id,
            printer_key=printer_key,
            printer_name=printer_name,
            transport_type=transport_type,
            document_type=document_type,
            job_name=job_name,
            enqueued_at=enqueued_at,
            queued_at_iso=_utc_now_iso(),
        )

        with self._condition:
            queue = self._queues.setdefault(printer_key, deque())
            queue.append(queue_job_id)
            self._jobs[queue_job_id] = queued_job

            while True:
                is_first = queue and queue[0] == queue_job_id
                no_active = self._active.get(printer_key) in {None, queue_job_id}
                if is_first and no_active:
                    self._active[printer_key] = queue_job_id
                    break
                self._condition.wait()

            queued_job.started_at = time.monotonic()
            queued_job.started_at_iso = _utc_now_iso()
            queued_job.status = "printing"

        queue_wait_ms = int((queued_job.started_at - enqueued_at) * 1000)

        last_exc: Exception | None = None
        result: object | None = None
        start_exec = queued_job.started_at
        for attempt in range(max_retries + 1):
            try:
                result = execute()
                queued_job.retry_count = attempt
                queued_job.status = "completed"
                last_exc = None
                break
            except Exception as exc:  # noqa: BLE001
                last_exc = exc
                queued_job.retry_count = attempt
                if attempt >= max_retries or not is_transient_error(exc):
                    queued_job.status = "failed"
                    queued_job.error_details = str(exc)
                    break
                time.sleep(min(0.35 * (attempt + 1), 1.0))

        completed_at = time.monotonic()
        queued_job.completed_at = completed_at
        queued_job.completed_at_iso = _utc_now_iso()
        duration_ms = int((completed_at - start_exec) * 1000)

        with self._condition:
            queue = self._queues.get(printer_key, deque())
            if queue and queue[0] == queue_job_id:
                queue.popleft()
            else:
                try:
                    queue.remove(queue_job_id)
                except ValueError:
                    pass
            self._active[printer_key] = None
            self._recent.appendleft(
                {
                    "queueJobId": queue_job_id,
                    "printerKey": printer_key,
                    "printerName": printer_name,
                    "transportType": transport_type,
                    "documentType": document_type,
                    "status": queued_job.status,
                    "queueWaitMs": queue_wait_ms,
                    "durationMs": duration_ms,
                    "retryCount": queued_job.retry_count,
                    "queuedAt": queued_job.queued_at_iso,
                    "startedAt": queued_job.started_at_iso,
                    "completedAt": queued_job.completed_at_iso,
                    "errorDetails": queued_job.error_details,
                }
            )
            self._jobs.pop(queue_job_id, None)
            self._condition.notify_all()

        queue_result = QueueExecutionResult(
            queue_job_id=queue_job_id,
            final_status=queued_job.status,
            duration_ms=duration_ms,
            queue_wait_ms=queue_wait_ms,
            retry_count=queued_job.retry_count,
            started_at=queued_job.started_at_iso or queued_job.queued_at_iso,
            completed_at=queued_job.completed_at_iso or queued_job.queued_at_iso,
        )
        if last_exc is not None:
            raise last_exc
        return queue_result, result

    def summary(self) -> dict[str, object]:
        with self._lock:
            queue_depths = {
                printer_key: len(queue)
                for printer_key, queue in self._queues.items()
                if len(queue) > 0
            }
            active_jobs = {
                printer_key: job_id
                for printer_key, job_id in self._active.items()
                if job_id
            }
            return {
                "activePrinters": len(active_jobs),
                "queueDepthByPrinter": queue_depths,
                "recentJobs": list(self._recent)[:20],
            }
