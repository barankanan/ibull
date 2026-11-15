"""No hardware or live database. Crash evidence lives in a temporary existing log."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from local_print_bridge.log_store import PrintLogStore
from local_print_bridge.tests.audit_print_ack_failures import fixture


class DispatchCheckpointTests(unittest.TestCase):
    def setUp(self):
        temporary = TemporaryDirectory(prefix="ibul-evidence-")
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / "print.jsonl"
        self.store = PrintLogStore(self.path)

    def test_crash_after_reservation_survives_restart(self):
        self.assertEqual(self.store.dispatch_checkpoint(['job:1'], phase='reserved'), 'new')
        reopened = PrintLogStore(self.path)
        self.assertEqual(reopened.dispatch_checkpoint(['job:1'], phase='reserved'), 'unknown')

    def test_competing_instances_reserve_once(self):
        with ThreadPoolExecutor(max_workers=8) as pool:
            states = list(pool.map(lambda _: PrintLogStore(self.path).dispatch_checkpoint(
                ['job:race'], phase='reserved'), range(8)))
        self.assertEqual(states.count('new'), 1)
        self.assertEqual(states.count('unknown'), 7)

    def test_corrupt_evidence_blocks_dispatch(self):
        self.path.write_text('{broken')
        with self.assertRaises(ValueError):
            self.store.dispatch_checkpoint(['job:1'], phase='reserved')

    def test_fsync_failure_cannot_authorize_dispatch(self):
        with patch('local_print_bridge.log_store.os.fsync', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                self.store.dispatch_checkpoint(['job:1'], phase='reserved')

    def test_proven_not_sent_allows_existing_usb_recovery(self):
        self.store.dispatch_checkpoint(['job:1'], phase='reserved')
        self.store.dispatch_checkpoint(['job:1'], phase='not_sent')
        self.assertEqual(self.store.dispatch_checkpoint(['job:1'], phase='reserved'), 'new')

    def test_manual_token_allows_one_reviewed_attempt(self):
        consumer, config, job, updates = fixture(dispatch_error=TimeoutError('uncertain'))
        consumer._process_one_job(config, job)
        consumer._process_one_job(config, job)
        self.assertEqual(consumer._print_kitchen_job.call_count, 1)
        job['payload']['manual_reprint_token'] = 'operator-reviewed-1'
        consumer._print_kitchen_job.side_effect = None
        consumer._process_one_job(config, job)
        consumer._process_one_job(config, job)
        self.assertEqual(consumer._print_kitchen_job.call_count, 2)
        self.assertFalse(any(u.get('status') == 'pending' for u in updates))

    def test_different_job_not_suppressed_by_completed_job(self):
        self.store.dispatch_checkpoint(['job:1'], phase='completed')
        self.assertEqual(self.store.dispatch_checkpoint(['job:2'], phase='reserved'), 'new')
