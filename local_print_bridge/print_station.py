from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import json
import logging
import os
import platform
import subprocess
import threading
import time
from typing import Any, Callable
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from .config import BridgeSettings, EscPosProfile, write_env_file
from .kitchen import KitchenRenderer
from .log_store import PrintLogStore
from .models import KitchenPayload, ReceiptItem, ReceiptPayload, ReceiptTotals
from .queue_manager import PrintQueueManager
from .raster import (
    KitchenBitmapRenderer,
    RasterEscPosEncoder,
    ReceiptBitmapRenderer,
)
from .receipt import ReceiptRenderer
LOGGER = logging.getLogger("local_print_bridge.print_station")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _utc_now_iso() -> str:
    return _utc_now().isoformat()


def check_queue_health(queue_name: str) -> None:
    try:
        result = subprocess.run(
            ["lpstat", "-p", queue_name],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if "disabled" in result.stdout.lower() or "paused" in result.stdout.lower():
            subprocess.run(["cupsenable", queue_name], check=True)
            LOGGER.info("Enabled CUPS queue %s", queue_name)
    except Exception as exc:  # noqa: BLE001
        LOGGER.warning("Failed to check/enable CUPS queue %s: %s", queue_name, exc)


@dataclass(frozen=True)
class PrintStationRuntimeConfig:
    enabled: bool
    restaurant_id: str
    supabase_url: str
    supabase_anon_key: str
    access_token: str
    refresh_token: str
    user_id: str
    device_name: str
    device_platform: str
    receipt_printer_id: str
    receipt_printer_name: str
    kitchen_printer_id: str
    kitchen_printer_name: str
    poll_interval_ms: int
    heartbeat_interval_ms: int
    max_retry_count: int
    print_system_enabled: bool

    @property
    def ready(self) -> bool:
        return (
            self.enabled
            and bool(self.restaurant_id)
            and bool(self.supabase_url)
            and bool(self.supabase_anon_key)
            and bool(self.refresh_token)
        )


def load_print_station_runtime_config() -> PrintStationRuntimeConfig:
    def _text(name: str) -> str:
        return os.getenv(name, "").strip()

    def _bool(name: str) -> bool:
        raw = _text(name).lower()
        return raw in {"1", "true", "yes", "on"}

    def _int(name: str, fallback: int, minimum: int) -> int:
        raw = _text(name)
        try:
            value = int(raw) if raw else fallback
        except ValueError:
            value = fallback
        return max(minimum, value)

    return PrintStationRuntimeConfig(
        enabled=_bool("PRINT_STATION_ENABLED"),
        restaurant_id=_text("PRINT_STATION_RESTAURANT_ID"),
        supabase_url=_text("PRINT_STATION_SUPABASE_URL"),
        supabase_anon_key=_text("PRINT_STATION_SUPABASE_ANON_KEY"),
        access_token=_text("PRINT_STATION_ACCESS_TOKEN"),
        refresh_token=_text("PRINT_STATION_REFRESH_TOKEN"),
        user_id=_text("PRINT_STATION_USER_ID"),
        device_name=_text("PRINT_STATION_DEVICE_NAME"),
        device_platform=_text("PRINT_STATION_DEVICE_PLATFORM"),
        receipt_printer_id=_text("PRINT_STATION_RECEIPT_PRINTER_ID"),
        receipt_printer_name=_text("PRINT_STATION_RECEIPT_PRINTER_NAME"),
        kitchen_printer_id=_text("PRINT_STATION_KITCHEN_PRINTER_ID"),
        kitchen_printer_name=_text("PRINT_STATION_KITCHEN_PRINTER_NAME"),
        poll_interval_ms=_int("PRINT_STATION_POLL_INTERVAL_MS", 2500, 500),
        heartbeat_interval_ms=_int(
            "PRINT_STATION_HEARTBEAT_INTERVAL_MS",
            15000,
            3000,
        ),
        max_retry_count=_int("PRINT_STATION_MAX_RETRY_COUNT", 5, 0),
        print_system_enabled=_bool("PRINT_SYSTEM_ENABLED"),
    )


class PrintStationConsumer:
    def __init__(
        self,
        *,
        settings_provider: Callable[[], BridgeSettings],
        transport_provider: Callable[[], Any],
        queue_manager_provider: Callable[[], PrintQueueManager],
        log_store_provider: Callable[[], PrintLogStore],
    ) -> None:
        self._settings_provider = settings_provider
        self._transport_provider = transport_provider
        self._queue_manager_provider = queue_manager_provider
        self._log_store_provider = log_store_provider
        self._stop_event = threading.Event()
        self._wake_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()
        self._recently_dispatched: dict[str, datetime] = {}
        self._recently_dispatched_keys: dict[str, datetime] = {}
        self._snapshot: dict[str, Any] = {
            "enabled": False,
            "running": False,
            "status": "idle",
            "restaurantId": "",
            "lastPollAt": None,
            "lastHeartbeatAt": None,
            "lastCompletedAt": None,
            "lastError": None,
            "claimedCount": 0,
            "completedCount": 0,
        }

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._wake_event.clear()
        self._thread = threading.Thread(
            target=self._run_loop,
            daemon=True,
            name="ibul-print-station-consumer",
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        self._wake_event.set()

    def wake(self) -> None:
        self._wake_event.set()

    def snapshot(self) -> dict[str, object]:
        with self._lock:
            return dict(self._snapshot)

    def _update_snapshot(self, **updates: object) -> None:
        with self._lock:
            self._snapshot.update(updates)

    def _cleanup_recently_dispatched(self) -> None:
        now = _utc_now()
        expiry = now - timedelta(minutes=15)
        self._recently_dispatched = {
            job_id: claimed_at
            for job_id, claimed_at in self._recently_dispatched.items()
            if claimed_at >= expiry
        }
        self._recently_dispatched_keys = {
            key: claimed_at
            for key, claimed_at in self._recently_dispatched_keys.items()
            if claimed_at >= expiry
        }

    def _build_kitchen_idempotency_key(self, restaurant_id: str, job: dict[str, Any], payload: dict[str, Any]) -> str:
        restaurant_id = str(job.get("restaurant_id") or restaurant_id).strip()
        order_id = str(job.get("order_id") or payload.get("order_id") or "").strip()
        station_id = str(job.get("station_id") or payload.get("station_id") or "").strip()
        station_name = str(payload.get("station_name") or payload.get("kitchen_ticket_header") or "").strip().lower()
        station_key = station_id if station_id else (station_name if station_name else "general")
        
        # Read positive int logic for revision
        raw_revision = payload.get("revision") or job.get("revision") or payload.get("order_revision") or "1"
        try:
            revision = int(raw_revision)
            if revision <= 0:
                revision = 1
        except (ValueError, TypeError):
            revision = 1
            
        items = payload.get("items")
        if not isinstance(items, list) or not items:
            items_hash = "no_items"
        else:
            normalized_items = []
            for item in items:
                if not isinstance(item, dict):
                    continue
                
                # Read positive int logic for quantity
                raw_qty = item.get("quantity") or 1
                try:
                    qty = int(raw_qty)
                    if qty <= 0:
                        qty = 1
                except (ValueError, TypeError):
                    qty = 1
                    
                normalized_items.append({
                    "product_id": str(item.get("product_id") or "").strip(),
                    "name": str(item.get("name") or "").strip(),
                    "display_label": str(item.get("display_label") or "").strip(),
                    "quantity": qty,
                    "station_id": str(item.get("station_id") or "").strip(),
                    "station_name": str(item.get("station_name") or "").strip(),
                    "amount_label": str(item.get("amount_label") or "").strip(),
                    "note": str(item.get("note") or "").strip(),
                })
            # Sort items by JSON representation
            normalized_items.sort(key=lambda x: json.dumps(x, separators=(',', ':'), sort_keys=True))
            items_hash = json.dumps(normalized_items, separators=(',', ':'), sort_keys=True)
        
        return f"{restaurant_id}|{order_id}|{station_key}|{revision}|{items_hash}"

    def _is_duplicate_job(self, job_id: str, idempotency_key: str = "") -> bool:
        self._cleanup_recently_dispatched()
        if job_id in self._recently_dispatched:
            return True
        if idempotency_key and idempotency_key in self._recently_dispatched_keys:
            return True
        return False

    def _record_dispatched_job(self, job_id: str, idempotency_key: str = "") -> None:
        now = _utc_now()
        self._recently_dispatched[job_id] = now
        if idempotency_key:
            self._recently_dispatched_keys[idempotency_key] = now

    def _run_loop(self) -> None:
        LOGGER.info("print-station consumer thread started")
        self._update_snapshot(running=True, status="starting")
        while not self._stop_event.is_set():
            config = load_print_station_runtime_config()
            self._update_snapshot(
                enabled=config.enabled,
                restaurantId=config.restaurant_id,
                status="waiting_config" if not config.ready else "polling",
            )
            if not config.ready:
                self._wait(config.poll_interval_ms)
                continue
            if not config.print_system_enabled:
                self._update_snapshot(status="print_system_disabled")
                try:
                    self._pause_pending_jobs(config)
                except Exception as exc:  # noqa: BLE001
                    LOGGER.warning("pause pending jobs failed: %s", exc)
                self._wait(config.poll_interval_ms)
                continue
            try:
                self._run_iteration(config)
            except Exception as exc:  # noqa: BLE001
                LOGGER.exception("print-station iteration failed")
                self._update_snapshot(status="error", lastError=str(exc))
            self._wait(config.poll_interval_ms)
        self._update_snapshot(running=False, status="stopped")
        LOGGER.info("print-station consumer thread stopped")

    def _pause_pending_jobs(self, config: PrintStationRuntimeConfig) -> None:
        """When print system is disabled, ensure pending jobs do not auto-print later."""
        jobs = self._fetch_pending_jobs(config)
        if not jobs:
            return
        now = _utc_now_iso()
        for job in jobs:
            job_id = str(job.get("id") or "").strip()
            if not job_id:
                continue
            # Do not claim/print; just mark paused.
            self._update_job(
                config,
                job_id,
                {
                    "status": "paused_by_operator",
                    "last_attempt_at": now,
                    "last_error": "Baskı sistemi kapalı. Fiş yazdırılmadı.",
                },
            )

    def _wait(self, poll_interval_ms: int) -> None:
        self._wake_event.wait(timeout=max(0.2, poll_interval_ms / 1000))
        self._wake_event.clear()

    def _run_iteration(self, config: PrintStationRuntimeConfig) -> None:
        self._update_snapshot(lastPollAt=_utc_now_iso(), status="polling")
        self._sync_heartbeat(config)
        jobs = self._fetch_pending_jobs(config)
        if not jobs:
            return
        for job in jobs:
            if self._stop_event.is_set():
                return
            self._process_one_job(config, job)

    def _sync_heartbeat(self, config: PrintStationRuntimeConfig) -> None:
        payload = {
            "restaurant_id": config.restaurant_id,
            "bridge_enabled": True,
            "bridge_status": "online",
            "device_name": config.device_name or "Ibul Print Station",
            "device_platform": config.device_platform or platform.system().lower(),
            "adisyon_printer_id": config.receipt_printer_id or None,
            "adisyon_printer_name": config.receipt_printer_name or None,
            "kitchen_printer_id": config.kitchen_printer_id or None,
            "kitchen_printer_name": config.kitchen_printer_name or None,
            "last_seen_at": _utc_now_iso(),
            "last_error": None,
            "updated_at": _utc_now_iso(),
        }
        self._postgrest_upsert(
            config,
            "restaurant_print_station_configs",
            payload,
        )
        self._update_snapshot(lastHeartbeatAt=payload["last_seen_at"])

    def _fetch_pending_jobs(
        self,
        config: PrintStationRuntimeConfig,
    ) -> list[dict[str, Any]]:
        path = (
            "print_jobs"
            "?select=id,retry_count,document_type,printer_role,payload,status,created_at"
            f"&restaurant_id=eq.{urlparse.quote(config.restaurant_id, safe='')}"
            "&status=eq.pending"
            "&order=created_at.asc"
            "&limit=20"
        )
        data = self._request_json(config, "GET", self._rest_url(config, path))
        if not isinstance(data, list):
            return []
        return [item for item in data if isinstance(item, dict)]

    def _process_one_job(
        self,
        config: PrintStationRuntimeConfig,
        job: dict[str, Any],
    ) -> None:
        job_id = str(job.get("id") or "").strip()
        if not job_id:
            return
        payload = job.get("payload")
        if not isinstance(payload, dict):
            payload = {}
        
        printer_role = str(
            job.get("printer_role")
            or payload.get("printer_role")
            or "mutfak"
        ).strip().lower()
        
        idempotency_key = ""
        if printer_role != "adisyon":
            idempotency_key = self._build_kitchen_idempotency_key(config.restaurant_id, job, payload)
        
        if self._is_duplicate_job(job_id, idempotency_key):
            LOGGER.warning(
                "duplicate print job suppressed: job_id=%s idempotency_key=%s",
                job_id,
                idempotency_key,
            )
            return
        claimed = self._claim_job(config, job_id)
        if not claimed:
            return
        payload = claimed.get("payload")
        if not isinstance(payload, dict):
            payload = {}
        printer_role = str(
            claimed.get("printer_role")
            or payload.get("printer_role")
            or "mutfak"
        ).strip().lower()
        document_type = str(
            claimed.get("document_type")
            or payload.get("document_type")
            or ("receipt" if printer_role == "adisyon" else "kitchen")
        ).strip().lower()
        LOGGER.info(
            "print-station job received: job_id=%s document_type=%s printer_role=%s",
            job_id,
            document_type,
            printer_role,
        )
        self._update_snapshot(
            claimedCount=int(self.snapshot().get("claimedCount") or 0) + 1,
            status="processing",
        )
        selected_printer = self._resolve_printer(config, printer_role, payload)
        LOGGER.info(
            "print-station printer selected: job_id=%s printer_role=%s printer=%s",
            job_id,
            printer_role,
            selected_printer.get("name") or selected_printer.get("id") or "-",
        )
        dispatch_started_at = _utc_now_iso()
        self._update_job(
            config,
            job_id,
            {
                "status": "printing",
                "dispatch_started_at": dispatch_started_at,
                "last_attempt_at": dispatch_started_at,
                "claimed_by": config.device_name or "Ibul Print Station",
                "last_error": None,
            },
        )

        try:
            if document_type == "receipt":
                bridge_result = self._print_receipt_job(
                    payload=payload,
                    selected_printer=selected_printer,
                )
            else:
                bridge_result = self._print_kitchen_job(
                    payload=payload,
                    selected_printer=selected_printer,
                )
            completed_at = _utc_now_iso()
            self._record_dispatched_job(job_id, idempotency_key)
            self._update_job(
                config,
                job_id,
                {
                    "status": "completed",
                    "printed_at": completed_at,
                    "completed_at": completed_at,
                    "printer_write_started_at": bridge_result.get(
                        "printer_write_started_at",
                    ),
                    "printer_write_completed_at": bridge_result.get(
                        "printer_write_completed_at",
                    ),
                    "last_error": None,
                },
            )
            self._postgrest_upsert(
                config,
                "restaurant_print_station_configs",
                {
                    "restaurant_id": config.restaurant_id,
                    "bridge_enabled": True,
                    "bridge_status": "online",
                    "last_seen_at": _utc_now_iso(),
                    "last_job_received_at": dispatch_started_at,
                    "last_job_completed_at": completed_at,
                    "last_error": None,
                    "updated_at": completed_at,
                },
            )
            self._update_snapshot(
                completedCount=int(self.snapshot().get("completedCount") or 0) + 1,
                lastCompletedAt=completed_at,
                lastError=None,
                status="idle",
            )
            LOGGER.info("print-station job success: job_id=%s", job_id)
        except Exception as exc:  # noqa: BLE001
            retry_count = int(job.get("retry_count") or 0) + 1
            error_text = str(exc)
            is_retryable = retry_count <= config.max_retry_count
            next_status = "pending" if is_retryable else "failed"
            self._update_job(
                config,
                job_id,
                {
                    "status": next_status,
                    "retry_count": retry_count,
                    "last_error": error_text,
                    "completed_at": None if is_retryable else _utc_now_iso(),
                },
            )
            self._postgrest_upsert(
                config,
                "restaurant_print_station_configs",
                {
                    "restaurant_id": config.restaurant_id,
                    "bridge_enabled": True,
                    "bridge_status": "online",
                    "last_seen_at": _utc_now_iso(),
                    "last_error": error_text,
                    "updated_at": _utc_now_iso(),
                },
            )
            self._update_snapshot(status="error", lastError=error_text)
            LOGGER.error(
                "print-station job failure: job_id=%s retry=%s error=%s",
                job_id,
                retry_count,
                error_text,
            )

    def _claim_job(
        self,
        config: PrintStationRuntimeConfig,
        job_id: str,
    ) -> dict[str, Any] | None:
        claimed_at = _utc_now_iso()
        path = (
            "print_jobs"
            f"?id=eq.{urlparse.quote(job_id, safe='')}"
            "&status=eq.pending"
        )
        result = self._request_json(
            config,
            "PATCH",
            self._rest_url(config, path),
            body={
                "status": "claimed",
                "claimed_at": claimed_at,
                "claimed_by": config.device_name or "Ibul Print Station",
            },
            headers={"Prefer": "return=representation"},
            allow_empty=True,
        )
        if not isinstance(result, list) or not result:
            return None
        first = result[0]
        return first if isinstance(first, dict) else None

    def _print_receipt_job(
        self,
        *,
        payload: dict[str, Any],
        selected_printer: dict[str, Any],
    ) -> dict[str, Any]:
        receipt_payload = ReceiptPayload.from_dict(payload)
        return self._submit_receipt(
            payload=receipt_payload,
            selected_printer=selected_printer,
            job_name=f"adisyon-masa-{receipt_payload.table_no}",
            document_type="receipt",
        )

    def _print_kitchen_job(
        self,
        *,
        payload: dict[str, Any],
        selected_printer: dict[str, Any],
    ) -> dict[str, Any]:
        kitchen_payload = KitchenPayload.from_dict(payload)
        order_no = kitchen_payload.order_no or "job"
        return self._submit_kitchen(
            payload=kitchen_payload,
            selected_printer=selected_printer,
            job_name=f"mutfak-masa-{kitchen_payload.table_no}-{order_no}",
        )

    def _submit_receipt(
        self,
        *,
        payload: ReceiptPayload,
        selected_printer: dict[str, Any],
        job_name: str,
        document_type: str,
    ) -> dict[str, Any]:
        settings = self._settings_provider()
        render_mode = settings.render_mode
        profile = settings.escpos_profile()
        if render_mode == "image":
            image = ReceiptBitmapRenderer(settings).render(payload)
            rasterized = RasterEscPosEncoder(settings).encode(image)
            raw_bytes = rasterized.data
        else:
            raw_bytes = ReceiptRenderer(settings).render(payload)
        return self._submit_bytes(
            raw_bytes=raw_bytes,
            profile=profile,
            settings=settings,
            selected_printer=selected_printer,
            job_name=job_name,
            document_type=document_type,
        )

    def _submit_kitchen(
        self,
        *,
        payload: KitchenPayload,
        selected_printer: dict[str, Any],
        job_name: str,
    ) -> dict[str, Any]:
        settings = self._settings_provider()
        render_mode = settings.render_mode
        profile = settings.escpos_profile()
        if render_mode == "image":
            image = KitchenBitmapRenderer(settings).render(payload)
            rasterized = RasterEscPosEncoder(settings).encode(image)
            raw_bytes = rasterized.data
        else:
            raw_bytes = KitchenRenderer(settings).render(payload)
        return self._submit_bytes(
            raw_bytes=raw_bytes,
            profile=profile,
            settings=settings,
            selected_printer=selected_printer,
            job_name=job_name,
            document_type="kitchen",
        )

    def _submit_bytes(
        self,
        *,
        raw_bytes: bytes,
        profile: EscPosProfile,
        settings: BridgeSettings,
        selected_printer: dict[str, Any],
        job_name: str,
        document_type: str,
    ) -> dict[str, Any]:
        queue_manager = self._queue_manager_provider()
        log_store = self._log_store_provider()
        transport = self._transport_provider()
        printer_id, printer_name, transport_type = self._printer_identity(
            selected_printer=selected_printer,
            settings=settings,
        )
        if transport_type == "cups" and settings.printer_queue:
            check_queue_health(settings.printer_queue)
        started = time.monotonic()
        queue_result, result = queue_manager.run_job(
            printer_key=printer_id,
            printer_name=printer_name,
            transport_type=transport_type,
            document_type=document_type,
            job_name=job_name,
            execute=lambda: transport.print_bytes(
                raw_bytes,
                job_name=job_name,
                selected_printer=selected_printer,
            ),
            is_transient_error=self._is_transient_transport_error,
            max_retries=1,
        )
        duration_ms = int((time.monotonic() - started) * 1000)
        log_store.append(
            log_store.build_entry(
                printer_id=printer_id,
                printer_name=printer_name,
                transport_type=transport_type,
                document_type=document_type,
                success=True,
                duration_ms=duration_ms,
                queue_status=queue_result.final_status,
                queue_wait_ms=queue_result.queue_wait_ms,
                retry_count=queue_result.retry_count,
                job_name=job_name,
                backend_job_id=getattr(result, "job_id", None),
                metadata={
                    "selectedPrinter": selected_printer,
                    "bytesLength": len(raw_bytes),
                    "encoding": profile.encoding,
                    "codepage": profile.codepage,
                },
            ),
        )
        return {
            "ok": True,
            "job_id": getattr(result, "job_id", ""),
            "printer_write_started_at": queue_result.started_at,
            "printer_write_completed_at": queue_result.completed_at,
            "transport_ms": duration_ms,
        }

    def _resolve_printer(
        self,
        config: PrintStationRuntimeConfig,
        printer_role: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        embedded_printer = payload.get("printer")
        if isinstance(embedded_printer, dict) and embedded_printer:
            return embedded_printer

        payload_printer_id = str(payload.get("printer_id") or "").strip()
        payload_printer_name = str(
            payload.get("printer_name")
            or payload.get("printer_queue")
            or payload.get("queueName")
            or "",
        ).strip()

        if printer_role == "adisyon":
            printer_id = payload_printer_id or config.receipt_printer_id
            printer_name = payload_printer_name or config.receipt_printer_name
        else:
            # Kitchen/station jobs must prefer the printer resolved during
            # Eşleştirme. Falling back to the global kitchen printer is only a
            # safety net when the job payload does not carry a printer yet.
            printer_id = payload_printer_id or config.kitchen_printer_id
            printer_name = payload_printer_name or config.kitchen_printer_name

        printer_id = str(printer_id or "").strip()
        printer_name = str(printer_name or "").strip()

        transport = self._transport_provider()
        resolver = getattr(transport, "resolve_printer", None)
        if callable(resolver):
            resolved = resolver(
                selected_printer=None,
                printer_id=printer_id or None,
                printer_name=printer_name or None,
            )
            if isinstance(resolved, dict):
                return resolved

        if printer_name:
            backend = (
                "windows-spool"
                if platform.system().lower() == "windows"
                else "cups"
            )
            return {
                "id": f"{backend}:{printer_name}",
                "name": printer_name,
                "queue": printer_name,
                "backend": backend,
            }

        return {}

    def _printer_identity(
        self,
        *,
        selected_printer: dict[str, Any],
        settings: BridgeSettings,
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
            transport_type = str(
                selected_printer.get("backend") or settings.transport_mode
            )
            return printer_id, printer_name, transport_type
        queue_name = settings.printer_queue or "<default>"
        backend = (
            "windows-spool" if platform.system().lower() == "windows" else "cups"
        )
        return f"{backend}:{queue_name}", queue_name, backend

    def _is_transient_transport_error(self, exc: Exception) -> bool:
        text = str(exc).lower()
        return any(
            marker in text
            for marker in (
                "temporarily",
                "timed out",
                "timeout",
                "resource busy",
                "device busy",
                "connection reset",
                "broken pipe",
                "try again",
            )
        )

    def _update_job(
        self,
        config: PrintStationRuntimeConfig,
        job_id: str,
        fields: dict[str, Any],
    ) -> None:
        path = f"print_jobs?id=eq.{urlparse.quote(job_id, safe='')}"
        self._request_json(
            config,
            "PATCH",
            self._rest_url(config, path),
            body=fields,
            allow_empty=True,
        )

    def _postgrest_upsert(
        self,
        config: PrintStationRuntimeConfig,
        table: str,
        payload: dict[str, Any],
    ) -> None:
        self._request_json(
            config,
            "POST",
            self._rest_url(
                config,
                f"{table}?on_conflict=restaurant_id",
            ),
            body=payload,
            headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
            allow_empty=True,
        )

    def _rest_url(self, config: PrintStationRuntimeConfig, path: str) -> str:
        base = config.supabase_url.rstrip("/")
        return f"{base}/rest/v1/{path}"

    def _request_json(
        self,
        config: PrintStationRuntimeConfig,
        method: str,
        url: str,
        *,
        body: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        allow_empty: bool = False,
        retry_auth: bool = True,
    ) -> Any:
        req_headers = {
            "apikey": config.supabase_anon_key,
            "Authorization": f"Bearer {config.access_token}",
            "Accept": "application/json",
        }
        if body is not None:
            req_headers["Content-Type"] = "application/json"
        if headers:
            req_headers.update(headers)

        raw_body = None
        if body is not None:
            raw_body = json.dumps(body, ensure_ascii=False).encode("utf-8")

        request = urlrequest.Request(
            url,
            data=raw_body,
            headers=req_headers,
            method=method.upper(),
        )
        try:
            with urlrequest.urlopen(request, timeout=15) as response:
                raw = response.read().decode("utf-8").strip()
        except urlerror.HTTPError as exc:
            if exc.code in {401, 403} and retry_auth and self._refresh_access_token(config):
                refreshed = load_print_station_runtime_config()
                return self._request_json(
                    refreshed,
                    method,
                    url,
                    body=body,
                    headers=headers,
                    allow_empty=allow_empty,
                    retry_auth=False,
                )
            details = exc.read().decode("utf-8", errors="ignore")
            raise RuntimeError(
                f"Supabase request failed ({exc.code}) {method} {url}: {details}"
            ) from exc
        except urlerror.URLError as exc:
            raise RuntimeError(f"Supabase request failed: {exc}") from exc

        if not raw:
            return {} if allow_empty else None
        return json.loads(raw)

    def _refresh_access_token(self, config: PrintStationRuntimeConfig) -> bool:
        auth_url = (
            f"{config.supabase_url.rstrip('/')}/auth/v1/token?grant_type=refresh_token"
        )
        payload = json.dumps({"refresh_token": config.refresh_token}).encode("utf-8")
        request = urlrequest.Request(
            auth_url,
            data=payload,
            headers={
                "apikey": config.supabase_anon_key,
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urlrequest.urlopen(request, timeout=15) as response:
                raw = response.read().decode("utf-8")
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("print-station token refresh failed: %s", exc)
            return False
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            LOGGER.error("print-station token refresh returned invalid JSON")
            return False
        access_token = str(data.get("access_token") or "").strip()
        refresh_token = str(data.get("refresh_token") or "").strip()
        if not access_token or not refresh_token:
            LOGGER.error("print-station token refresh returned incomplete payload")
            return False
        write_env_file(
            {
                "PRINT_STATION_ACCESS_TOKEN": access_token,
                "PRINT_STATION_REFRESH_TOKEN": refresh_token,
            },
        )
        LOGGER.info("print-station access token refreshed")
        return True


def build_print_station_queue_status() -> dict[str, object]:
    config = load_print_station_runtime_config()
    return {
        "enabled": config.enabled,
        "ready": config.ready,
        "printSystemEnabled": config.print_system_enabled,
        "print_system_enabled": config.print_system_enabled,
        "restaurantId": config.restaurant_id or None,
        "deviceName": config.device_name or None,
        "devicePlatform": config.device_platform or None,
        "adisyonPrinterName": config.receipt_printer_name or None,
        "kitchenPrinterName": config.kitchen_printer_name or None,
        "pollIntervalMs": config.poll_interval_ms,
        "heartbeatIntervalMs": config.heartbeat_interval_ms,
        "maxRetryCount": config.max_retry_count,
    }


def build_test_receipt_payload(*, title: str, table_label: str) -> ReceiptPayload:
    items = [
        ReceiptItem(
            name=title,
            quantity=Decimal("1"),
            line_total=Decimal("0"),
            unit_price=Decimal("0"),
        ),
    ]
    return ReceiptPayload(
        store_name="IBUL PRINT STATION",
        branch="TEST",
        phone="-",
        table_no=table_label,
        date_time=datetime.now().astimezone(),
        items=items,
        totals=ReceiptTotals(
            subtotal=Decimal("0"),
            discount=Decimal("0"),
            service_charge=Decimal("0"),
            grand_total=Decimal("0"),
        ),
        currency="TRY",
        footer_note="Merkezi yazici testi",
    )
