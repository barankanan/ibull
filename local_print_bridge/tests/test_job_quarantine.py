"""Historical jobs stay out of the automatic claim path across restarts."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from local_print_bridge.job_quarantine import (
    auto_claim_decision,
    kitchen_job_plan,
    load_quarantine,
    remember_quarantine,
)


class JobQuarantineTests(unittest.TestCase):
    def test_historical_statuses_are_not_claimed(self) -> None:
        for status in (
            "printing",
            "claimed",
            "failed",
            "paused_by_operator",
            "outcome_unknown",
        ):
            decision = auto_claim_decision({"id": f"old-{status}", "status": status})
            self.assertFalse(decision.allow)
            self.assertTrue(decision.reason.startswith("historical_status:"))

    def test_quarantine_survives_a_new_process_store(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            remember_quarantine(
                job_id="4f261624-c20b-4911-a578-f8a028d9d858",
                idempotency_key="rest|order|1|ocak|new_order",
                root=root,
            )
            reloaded = load_quarantine(root)
            self.assertIn("4f261624-c20b-4911-a578-f8a028d9d858", reloaded["job_ids"])
            decision = auto_claim_decision(
                {
                    "id": "4f261624-c20b-4911-a578-f8a028d9d858",
                    "status": "pending",
                    "payload": {"logical_print_key": "rest|order|1|ocak|new_order"},
                },
                root=root,
            )
            self.assertFalse(decision.allow)
            self.assertEqual(decision.reason, "quarantined_job_id")

    def test_new_kitchen_job_is_single_and_ignores_history(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            remember_quarantine(job_id="historical-printing", root=root)
            issued: set[str] = set()
            first = kitchen_job_plan(
                restaurant_id="rest",
                order_id="test-order-ocak-1",
                revision="1",
                station_id="ocak",
                printer_mac="02:80:fb:94:2a:f4",
                issued=issued,
                root=root,
            )
            second = kitchen_job_plan(
                restaurant_id="rest",
                order_id="test-order-ocak-1",
                revision="1",
                station_id="ocak",
                printer_mac="02:80:fb:94:2a:f4",
                issued=issued,
                root=root,
            )
            self.assertIsNotNone(first)
            assert first is not None
            self.assertEqual(first["copies"], 1)
            self.assertFalse(first["historical_selected"])
            self.assertEqual(first["printer_mac"], "02:80:fb:94:2a:f4")
            self.assertIsNone(second)
            historical = auto_claim_decision(
                {"id": "historical-printing", "status": "pending"},
                root=root,
            )
            self.assertFalse(historical.allow)

    def test_quarantine_file_loss_stops_auto_claim(self) -> None:
        from local_print_bridge.job_quarantine import arm_quarantine

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            arm_quarantine(root)
            (root / "job_quarantine.json").unlink()
            decision = auto_claim_decision(
                {"id": "brand-new", "status": "pending"},
                root=root,
            )
            self.assertFalse(decision.allow)
            self.assertEqual(decision.reason, "quarantine_store_missing")
        decision = auto_claim_decision(
            {
                "id": "brand-new",
                "status": "pending",
                "created_at": "2020-01-01T00:00:00Z",
            }
        )
        self.assertTrue(decision.allow)


if __name__ == "__main__":
    unittest.main()
