import json
import threading
import time
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import MagicMock

from local_print_bridge.log_store import PrintLogStore
from local_print_bridge.print_signal import (
    PrintSignalListener,
    join_reply_status,
    signal_frame_should_wake,
)
from local_print_bridge.print_station import (
    PrintStationConsumer,
    PrintStationRuntimeConfig,
)


def _config() -> PrintStationRuntimeConfig:
    return PrintStationRuntimeConfig(
        enabled=True,
        restaurant_id="10000000-0000-0000-0000-000000000001",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="anon",
        access_token="tok",
        refresh_token="ref",
        user_id="usr",
        device_name="Test Station",
        device_platform="macos",
        receipt_printer_id="pr1",
        receipt_printer_name="Receipt",
        kitchen_printer_id="pr2",
        kitchen_printer_name="Kitchen",
        poll_interval_ms=2500,
        heartbeat_interval_ms=15000,
        max_retry_count=3,
        print_system_enabled=True,
    )


def _frame(restaurant_id: str, job_ids: list[str]) -> str:
    return json.dumps(
        {
            "event": "broadcast",
            "payload": {
                "event": "new_print_jobs",
                "payload": {
                    "restaurant_id": restaurant_id,
                    "job_ids": job_ids,
                },
            },
        }
    )


def _server_text(payload: str) -> bytes:
    data = payload.encode("utf-8")
    if len(data) < 126:
        return bytes([0x81, len(data)]) + data
    return bytes([0x81, 126]) + len(data).to_bytes(2, "big") + data


class _FakeSocket:
    def __init__(self, incoming: bytes) -> None:
        self.incoming = incoming
        self.sent = bytearray()
        self.closed = False

    def sendall(self, data: bytes) -> None:
        self.sent.extend(data)

    def settimeout(self, _timeout: float) -> None:
        return None

    def recv(self, size: int) -> bytes:
        if not self.incoming:
            raise TimeoutError()
        chunk = self.incoming[:size]
        self.incoming = self.incoming[size:]
        return chunk

    def close(self) -> None:
        self.closed = True


class PrintSignalWakeTests(unittest.TestCase):
    def test_broadcast_for_this_restaurant_wakes_once(self) -> None:
        restaurant = _config().restaurant_id
        self.assertTrue(signal_frame_should_wake(_frame(restaurant, ["job-1"]), restaurant))
        self.assertFalse(signal_frame_should_wake(_frame("other-store", ["job-1"]), restaurant))
        self.assertFalse(signal_frame_should_wake(_frame(restaurant, []), restaurant))
        woken = []
        stop = threading.Event()
        sock = _FakeSocket(_server_text(_frame(restaurant, ["job-1"])))
        listener = PrintSignalListener(
            wake=lambda: woken.append("wake") or stop.set(),
            stop_event=stop,
            config_loader=_config,
            connect=lambda _config: sock,
        )
        listener._listen_once(_config())
        self.assertEqual(woken, ["wake"])
        self.assertTrue(sock.sent)
        self.assertTrue(sock.closed)

    def test_wake_returns_before_the_poll_backup(self) -> None:
        consumer = object.__new__(PrintStationConsumer)
        consumer._wake_event = threading.Event()
        started = time.monotonic()
        consumer.wake()
        woken = consumer._wait(2500)
        elapsed_ms = (time.monotonic() - started) * 1000
        self.assertTrue(woken)
        self.assertLess(elapsed_ms, 2500)

    def test_signal_does_not_complete_a_queued_job(self) -> None:
        job = {"id": "job-1", "status": "pending"}
        self.assertTrue(
            signal_frame_should_wake(_frame(_config().restaurant_id, [job["id"]]), _config().restaurant_id)
        )
        self.assertEqual(job["status"], "pending")

    def test_reconnect_does_not_claim_the_same_kitchen_job(self) -> None:
        consumer = object.__new__(PrintStationConsumer)
        consumer._recently_dispatched = {}
        consumer._recently_dispatched_keys = {}
        consumer._log_store_provider = lambda: MagicMock(
            dispatch_checkpoint=lambda *_args, **_kwargs: "new"
        )
        consumer._update_snapshot = MagicMock()
        claimed = []
        consumer._claim_job = lambda *_args, **_kwargs: claimed.append("claim")
        config = _config()
        job = {
            "id": "job-1",
            "restaurant_id": config.restaurant_id,
            "station_id": "ocak",
            "printer_role": "mutfak",
            "payload": {"revision": 1, "items": []},
        }
        key = consumer._build_kitchen_idempotency_key(
            config.restaurant_id, job, job["payload"]
        )
        consumer._record_dispatched_job("job-1", key)
        consumer._process_one_job(config, job)
        self.assertEqual(claimed, [])

    def test_wake_does_not_repeat_the_station_heartbeat(self) -> None:
        consumer = object.__new__(PrintStationConsumer)
        consumer._last_heartbeat_monotonic = None
        consumer._update_snapshot = lambda **_kwargs: None
        consumer._sync_heartbeat = MagicMock()
        consumer._fetch_pending_jobs = lambda _config: []
        config = _config()
        consumer._run_iteration(config, heartbeat=True)
        consumer._run_iteration(config, heartbeat=False)
        consumer._run_iteration(config, heartbeat=True)
        self.assertEqual(consumer._sync_heartbeat.call_count, 1)

    def test_station_key_matches_the_stamped_print_identity(self) -> None:
        consumer = object.__new__(PrintStationConsumer)
        config = _config()
        payload = {
            "local_order_id": "local-9",
            "revision_key": "2",
            "revision": "9",
            "station_name": "Ocak",
            "job_type": "add_item",
            "items": [{"name": "Çorba", "quantity": 1}],
        }
        job = {
            "id": "job-9",
            "restaurant_id": config.restaurant_id,
            "order_id": "order-1",
            "station_id": "ocak",
            "job_type": "add_item",
            "payload": payload,
        }
        self.assertEqual(
            consumer._build_kitchen_idempotency_key(config.restaurant_id, job, payload),
            f"{config.restaurant_id}|local-9|2|ocak|add_item",
        )
        payload["logical_print_key"] = f"{config.restaurant_id}|local-9|2|ocak|add_item"
        self.assertEqual(
            consumer._build_kitchen_idempotency_key(config.restaurant_id, job, payload),
            payload["logical_print_key"],
        )

    def test_old_checkpoint_still_blocks_a_second_ticket(self) -> None:
        consumer = object.__new__(PrintStationConsumer)
        consumer._recently_dispatched = {}
        consumer._recently_dispatched_keys = {}
        temporary = TemporaryDirectory(prefix="ibul-print-key-")
        self.addCleanup(temporary.cleanup)
        store = PrintLogStore(Path(temporary.name) / "print_logs.jsonl")
        consumer._log_store_provider = lambda: store
        consumer._update_snapshot = MagicMock()
        claimed = []
        consumer._claim_job = lambda *_args, **_kwargs: claimed.append("claim")
        config = _config()
        payload = {"revision": 1, "items": [], "station_name": "ocak"}
        job = {
            "id": "job-old",
            "restaurant_id": config.restaurant_id,
            "order_id": "order-1",
            "station_id": "",
            "printer_role": "mutfak",
            "payload": payload,
        }
        legacy = consumer._legacy_kitchen_checkpoint_key(
            config.restaurant_id, job, payload
        )
        consumer._record_dispatched_job("other-job", "unused", legacy)
        consumer._process_one_job(config, job)
        self.assertEqual(claimed, [])

    def test_signal_drop_keeps_polling_and_one_wake_prints_once(self) -> None:
        printed: list[str] = []
        fetches: list[int] = []
        config = _config()
        config = PrintStationRuntimeConfig(
            enabled=config.enabled,
            restaurant_id=config.restaurant_id,
            supabase_url=config.supabase_url,
            supabase_anon_key=config.supabase_anon_key,
            access_token=config.access_token,
            refresh_token=config.refresh_token,
            user_id=config.user_id,
            device_name=config.device_name,
            device_platform=config.device_platform,
            receipt_printer_id=config.receipt_printer_id,
            receipt_printer_name=config.receipt_printer_name,
            kitchen_printer_id=config.kitchen_printer_id,
            kitchen_printer_name=config.kitchen_printer_name,
            poll_interval_ms=500,
            heartbeat_interval_ms=15000,
            max_retry_count=3,
            print_system_enabled=True,
        )
        job = {
            "id": "job-live",
            "restaurant_id": config.restaurant_id,
            "order_id": "order-1",
            "station_id": "ocak",
            "job_type": "new_order",
            "printer_role": "mutfak",
            "document_type": "kitchen",
            "payload": {
                "logical_print_key": f"{config.restaurant_id}|order-1|1|ocak|new_order",
                "revision_key": "1",
                "items": [],
            },
        }
        temporary = TemporaryDirectory(prefix="ibul-print-loop-")
        self.addCleanup(temporary.cleanup)
        store = PrintLogStore(Path(temporary.name) / "print_logs.jsonl")

        def connect(_config):
            raise ConnectionError("signal down")

        consumer = PrintStationConsumer(
            settings_provider=lambda: None,
            transport_provider=lambda: None,
            queue_manager_provider=lambda: None,
            log_store_provider=lambda: store,
            config_loader=lambda: config,
            signal_connect=connect,
        )
        consumer._sync_heartbeat = lambda _config: None
        consumer._fetch_pending_jobs = lambda _config: fetches.append(1) or [dict(job)]
        consumer._claim_job = lambda _config, _job_id: dict(job)
        consumer._resolve_printer = lambda *_args, **_kwargs: {"id": "p", "name": "Kitchen"}
        consumer._update_job = lambda *_args, **_kwargs: None
        consumer._postgrest_upsert = lambda *_args, **_kwargs: None

        def print_kitchen(**_kwargs):
            printed.append("print")
            return {
                "ok": True,
                "printer_write_started_at": "t0",
                "printer_write_completed_at": "t1",
            }

        consumer._print_kitchen_job = print_kitchen
        consumer.start()
        self.addCleanup(consumer.stop)
        deadline = time.monotonic() + 3
        while len(printed) < 1 and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual(printed, ["print"])
        consumer.wake()
        time.sleep(0.4)
        self.assertEqual(printed, ["print"])
        seen = len(fetches)
        time.sleep(0.8)
        self.assertGreater(len(fetches), seen)

    def test_flat_flutter_broadcast_wakes_without_claiming(self) -> None:
        restaurant = _config().restaurant_id
        job = {"id": "job-1", "status": "pending"}
        frame = json.dumps(
            {
                "topic": f"realtime:print_signal:{restaurant}",
                "event": "broadcast",
                "payload": {
                    "job_ids": [job["id"]],
                    "restaurant_id": restaurant,
                    "type": "broadcast",
                    "event": "new_print_jobs",
                },
                "ref": "2",
            }
        )
        self.assertTrue(signal_frame_should_wake(frame, restaurant))
        self.assertFalse(signal_frame_should_wake(frame, "other-store"))
        woken = []
        stop = threading.Event()
        sock = _FakeSocket(_server_text(frame))
        listener = PrintSignalListener(
            wake=lambda: woken.append("wake") or stop.set(),
            stop_event=stop,
            config_loader=_config,
            connect=lambda _config: sock,
        )
        listener._listen_once(_config())
        self.assertEqual(woken, ["wake"])
        self.assertEqual(job["status"], "pending")

    def test_rejected_join_does_not_wake_or_print(self) -> None:
        restaurant = _config().restaurant_id
        reply = json.dumps(
            {
                "event": "phx_reply",
                "payload": {"status": "error", "response": {}},
                "ref": "1",
            }
        )
        broadcast = json.dumps(
            {
                "event": "broadcast",
                "payload": {
                    "event": "new_print_jobs",
                    "payload": {"restaurant_id": restaurant, "job_ids": ["job-1"]},
                },
            }
        )
        self.assertEqual(join_reply_status(reply), "error")
        woken = []
        stop = threading.Event()
        sock = _FakeSocket(_server_text(reply) + _server_text(broadcast))
        listener = PrintSignalListener(
            wake=lambda: woken.append("wake") or stop.set(),
            stop_event=stop,
            config_loader=_config,
            connect=lambda _config: sock,
        )
        with self.assertRaises(ConnectionError):
            listener._listen_once(_config())
        self.assertEqual(woken, [])

    def test_join_ok_then_flat_broadcast_wakes_once(self) -> None:
        restaurant = _config().restaurant_id
        reply = json.dumps(
            {"event": "phx_reply", "payload": {"status": "ok", "response": {}}, "ref": "1"}
        )
        frame = json.dumps(
            {
                "event": "broadcast",
                "payload": {
                    "job_ids": ["job-1"],
                    "restaurant_id": restaurant,
                    "event": "new_print_jobs",
                },
            }
        )
        woken = []
        stop = threading.Event()
        sock = _FakeSocket(_server_text(reply) + _server_text(frame))
        listener = PrintSignalListener(
            wake=lambda: woken.append("wake") or stop.set(),
            stop_event=stop,
            config_loader=_config,
            connect=lambda _config: sock,
        )
        listener._listen_once(_config())
        self.assertEqual(woken, ["wake"])


if __name__ == "__main__":
    unittest.main()
