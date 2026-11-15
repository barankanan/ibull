"""Offline fault injection against real consumer/queue methods; no printer/server.

Run from repo: python3 -m local_print_bridge.tests.audit_print_ack_failures
FAIL results intentionally block rollout; mocks represent dispatch, never paper.
"""
import json
from pathlib import Path
from unittest.mock import MagicMock
import tempfile

from local_print_bridge.print_station import PrintStationConsumer, PrintStationRuntimeConfig
from local_print_bridge.queue_manager import PrintQueueManager
from local_print_bridge.log_store import PrintLogStore


_temporary = tempfile.TemporaryDirectory(prefix="ibul-print-audit-")
_next_fixture = 0


def fixture(dispatch_error=None, ack_failures=0, log_store=None):
    global _next_fixture
    _next_fixture += 1
    consumer = object.__new__(PrintStationConsumer)
    consumer._recently_dispatched = {}
    consumer._recently_dispatched_keys = {}
    log_store = log_store or PrintLogStore(Path(_temporary.name)/f"{_next_fixture}.jsonl")
    consumer._log_store_provider = lambda: log_store
    consumer.snapshot = lambda: {"claimedCount": 0, "completedCount": 0}
    consumer._update_snapshot = MagicMock()
    job = {"id": "fixture-job", "retry_count": 0, "document_type": "kitchen",
           "payload": {"order_id": "fixture-order", "items": [{"name": "Soup", "quantity": 1}]}}
    consumer._claim_job = MagicMock(return_value=job)
    consumer._resolve_printer = MagicMock(return_value={"id": "mock-printer"})
    consumer._postgrest_upsert = MagicMock()
    consumer._print_kitchen_job = MagicMock(
        side_effect=dispatch_error,
        return_value={"ok": True, "printer_write_started_at": "2026-10-30T10:00:00Z",
                      "printer_write_completed_at": "2026-10-30T10:00:01Z"})
    updates = []
    remaining = ack_failures

    def update(_config, _id, fields):
        nonlocal remaining
        updates.append(fields)
        if fields.get("status") == "completed" and remaining:
            remaining -= 1
            raise ConnectionError("injected completion ACK failure")

    consumer._update_job = update
    config = PrintStationRuntimeConfig(
        enabled=True, restaurant_id="fixture", supabase_url="http://localhost:54321",
        supabase_anon_key="fake", access_token="fake", refresh_token="fake", user_id="fake",
        device_name="isolated-mock", device_platform="macos", receipt_printer_id="fake",
        receipt_printer_name="fake", kitchen_printer_id="fake", kitchen_printer_name="fake",
        poll_interval_ms=1000, heartbeat_interval_ms=10000, max_retry_count=3,
        print_system_enabled=True)
    return consumer, config, job, updates


def main():
    results = []

    def record(name, ok, detail):
        results.append({"name": name, "status": "PASS" if ok else "FAIL", "detail": detail})

    for failures in (1, 2):
        consumer, config, job, updates = fixture(ack_failures=failures)
        consumer._process_one_job(config, job)
        consumer._process_one_job(config, job)
        record(f"successful dispatch / {failures} failed completion ACK(s)",
               all(u.get("status") != "pending" for u in updates)
               and consumer._print_kitchen_job.call_count == 1,
               "No pending reset; same-process duplicate suppressed. If both ACKs fail DB remains printing; durable reservation retained; failed DB ACKs cannot authorize replay.")

    for label in ("timeout after possible byte write", "log exception after possible spool acceptance"):
        consumer, config, job, updates = fixture(dispatch_error=TimeoutError(label))
        consumer._process_one_job(config, job)
        consumer._process_one_job(config, job)
        record(label, not any(u.get("status") == "pending" for u in updates),
               f"statuses={[u.get('status') for u in updates]}; simulated dispatch calls={consumer._print_kitchen_job.call_count}; physical outcome unknown")

    consumer, config, job, updates = fixture()
    consumer._update_job = MagicMock(side_effect=ConnectionError("pre-dispatch status failed"))
    try:
        consumer._process_one_job(config, job)
    except ConnectionError:
        pass
    record("printing-state update failure before dispatch", consumer._print_kitchen_job.call_count == 0,
           "No bytes dispatched in this path; a claimed job can remain stuck.")

    calls = 0

    def uncertain_transport():
        nonlocal calls
        calls += 1
        if calls == 1:
            raise TimeoutError("timeout after possible byte write")
        return "spool accepted"

    try:
        PrintQueueManager().run_job(printer_key="mock", printer_name="mock", transport_type="tcp",
            document_type="kitchen", job_name="mock", execute=uncertain_transport,
            is_transient_error=consumer._is_transient_transport_error, max_retries=1)
    except TimeoutError:
        pass  # expected unknown outcome; must not become a second transport call
    record("queue retry of ambiguous transient transport failure", calls == 1,
           f"transport calls={calls}; predicate used by caller decides whether ambiguous errors can be retried")
    consumer, config, job, updates = fixture()
    consumer._record_dispatched_job(job["id"])
    restarted, _, _, _ = fixture(log_store=PrintLogStore(consumer._log_store_provider().path))
    record("durable duplicate evidence across process restart",
           restarted._is_duplicate_job(job["id"]),
           "Fresh consumer reads the same existing print log and suppresses duplicate; no printer contact.")
    target = Path(__file__).resolve().parents[2] / "docs/preprod/restaurant_security_20261030/print_results.json"
    target.write_text(json.dumps({"scope": "offline mocks; no physical paper observation", "results": results}, indent=2)+"\n")
    for r in results:
        print(f"{r['status']} {r['name']}: {r['detail']}")
    return int(any(r["status"] == "FAIL" for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
