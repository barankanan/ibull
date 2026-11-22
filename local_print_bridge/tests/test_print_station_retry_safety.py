import unittest
from unittest.mock import MagicMock
from pathlib import Path
from tempfile import TemporaryDirectory
from local_print_bridge.log_store import PrintLogStore
from local_print_bridge.print_station import PrintStationConsumer, PrintStationRuntimeConfig


class PrintStationRetrySafetyTests(unittest.TestCase):
    def test_printed_job_never_resets_to_pending_on_db_status_update_failure(self):
        """Kör otomatik tekrar baskıyı önleme testi:
        Fiziksel baskı yazıcıya başarıyla iletildikten sonra PostgREST/DB durum güncellemesi
        hata verirse, print_station bu işi ASLA 'pending' durumuna almamalıdır.
        """
        consumer = object.__new__(PrintStationConsumer)
        consumer._recently_dispatched = {}
        consumer._recently_dispatched_keys = {}
        temporary = TemporaryDirectory(prefix="ibul-ack-test-")
        self.addCleanup(temporary.cleanup)
        store = PrintLogStore(Path(temporary.name)/"print_logs.jsonl")
        consumer._log_store_provider = lambda: store
        consumer.snapshot = lambda: {"claimedCount": 0, "completedCount": 0}
        consumer._update_snapshot = MagicMock()
        consumer._claim_job = MagicMock(return_value={"id": "job-123"})
        consumer._resolve_printer = MagicMock(return_value={"id": "pr1", "name": "Kitchen Printer"})
        consumer._record_dispatched_job = MagicMock()
        consumer._postgrest_upsert = MagicMock()

        # Fiziksel baskı başarılı
        consumer._print_kitchen_job = MagicMock(return_value={
            "ok": True,
            "printer_write_started_at": "2026-10-30T18:00:00Z",
            "printer_write_completed_at": "2026-10-30T18:00:01Z",
        })

        updates = []
        def mock_update_job(config, job_id, update_dict):
            updates.append(update_dict)
            # 'completed' yazmaya çalışırken ilk denemede ağ/veritabanı hatası simülasyonu
            err_str = str(update_dict.get("last_error") or "")
            if update_dict.get("status") == "completed" and "Baskı yapıldı ancak" not in err_str:
                raise ConnectionError("Supabase network timeout on status update")

        consumer._update_job = mock_update_job

        config = PrintStationRuntimeConfig(
            enabled=True,
            restaurant_id="10000000-0000-0000-0000-000000000001",
            supabase_url="http://localhost:54321",
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
            poll_interval_ms=1000,
            heartbeat_interval_ms=10000,
            max_retry_count=3,
            print_system_enabled=True,
        )

        job = {
            "id": "job-123",
            "retry_count": 0,
            "document_type": "kitchen",
            "printer_role": "kitchen",
            "payload": {"table_no": "1", "order_no": "101", "items": []},
        }

        consumer._process_one_job(config, job)

        # Kontrol: Güncelleme geçmişinde hiçbir zaman 'pending' olmamalı!
        statuses = [u.get("status") for u in updates]
        self.assertIn("printing", statuses)
        self.assertNotIn("pending", statuses, "Baskı yapılmış iş ASLA 'pending' durumuna geri alınamaz!")

        # Final denemesinde status 'completed' olmalı ve error_text kaydedilmeli
        last_update = updates[-1]
        self.assertEqual(last_update.get("status"), "completed")
        self.assertIn("Baskı yapıldı ancak DB güncellemesi başarısız oldu", last_update.get("last_error", ""))
        self.assertEqual(consumer._record_dispatched_job.call_count, 1)

    def _consumer(self, updates, *, fail_completed_always=False):
        consumer = object.__new__(PrintStationConsumer)
        consumer._recently_dispatched = {}
        consumer._recently_dispatched_keys = {}
        consumer.snapshot = lambda: {"claimedCount": 0, "completedCount": 0}
        consumer._update_snapshot = MagicMock()
        consumer._claim_job = MagicMock(return_value={"id": "job-123"})
        consumer._resolve_printer = MagicMock(return_value={"id": "pr1", "name": "Kitchen Printer"})
        consumer._postgrest_upsert = MagicMock()
        consumer._print_kitchen_job = MagicMock(return_value={"ok": True})

        def update_job(config, job_id, update_dict):
            updates.append(update_dict)
            if fail_completed_always and update_dict.get("status") == "completed":
                raise ConnectionError("network down")

        consumer._update_job = update_job
        return consumer

    def _config(self):
        return PrintStationRuntimeConfig(
            enabled=True,
            restaurant_id="10000000-0000-0000-0000-000000000001",
            supabase_url="http://localhost:54321",
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
            poll_interval_ms=1000,
            heartbeat_interval_ms=10000,
            max_retry_count=3,
            print_system_enabled=True,
        )

    _JOB = {
        "id": "job-123",
        "retry_count": 0,
        "document_type": "kitchen",
        "printer_role": "kitchen",
        "payload": {"table_no": "1", "order_no": "101", "items": []},
    }

    def test_heartbeat_failure_after_print_never_requeues_the_job(self):
        updates = []
        consumer = self._consumer(updates)
        consumer._postgrest_upsert = MagicMock(side_effect=ConnectionError("heartbeat down"))

        consumer._process_one_job(self._config(), dict(self._JOB))

        self.assertEqual([u.get("status") for u in updates], ["printing", "completed"])
        self.assertEqual(consumer._print_kitchen_job.call_count, 1)

    def test_persistent_status_failure_after_print_does_not_raise_or_requeue(self):
        updates = []
        consumer = self._consumer(updates, fail_completed_always=True)

        consumer._process_one_job(self._config(), dict(self._JOB))

        self.assertNotIn("pending", [u.get("status") for u in updates])
        self.assertNotIn("failed", [u.get("status") for u in updates])
        # Same job offered again in this process: suppressed, not reprinted.
        consumer._process_one_job(self._config(), dict(self._JOB))
        self.assertEqual(consumer._print_kitchen_job.call_count, 1)

    def test_printer_failure_still_requeues_for_retry(self):
        updates = []
        consumer = self._consumer(updates)
        consumer._print_kitchen_job = MagicMock(side_effect=OSError("printer offline"))

        consumer._process_one_job(self._config(), dict(self._JOB))

        self.assertEqual(updates[-1].get("status"), "pending")
        self.assertEqual(updates[-1].get("retry_count"), 1)
        self.assertEqual(consumer._recently_dispatched, {})
