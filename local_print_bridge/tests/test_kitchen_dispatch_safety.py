"""Concurrent claim, quarantine, and kitchen render without a printer."""
from __future__ import annotations

import os
import tempfile
import threading
import unittest
from pathlib import Path

from local_print_bridge.config import BridgeSettings
from local_print_bridge.job_quarantine import arm_quarantine, auto_claim_decision
from local_print_bridge.kitchen import KitchenRenderer
from local_print_bridge.lan_pilot import accept_and_queue
from local_print_bridge.local_store import LocalRestaurantStore
from local_print_bridge.models import KitchenPayload


def _order() -> dict:
    return {
        "local_order_id": "dispatch-ocak-firin",
        "restaurant_id": "test-restoran",
        "table_number": 41,
        "table_label": "Test Masası",
        "waiter_name": "Test Garson",
        "items": [
            {
                "name": "Izgara Köfte",
                "quantity": 1,
                "unit_price": 10,
                "station_id": "ocak",
                "note": "Az pişmiş, soğansız",
            },
            {
                "name": "Fırın Sütlaç",
                "quantity": 2,
                "unit_price": 12,
                "station_id": "firin",
                "note": "Şekerli",
            },
        ],
    }


class KitchenDispatchSafetyTests(unittest.TestCase):
    def test_two_consumers_cannot_claim_the_same_job(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "lan.sqlite"
            store = LocalRestaurantStore(path)
            saved = accept_and_queue(
                store,
                _order(),
                printer_host="192.168.10.100",
                printer_port=9100,
                deliver=False,
            )
            store.close()
            ocak_id = next(job for job in saved["print_job_ids"] if job.endswith(":ocak:rev1"))
            results: list[dict | None] = []

            def claim() -> None:
                local = LocalRestaurantStore(path)
                try:
                    results.append(local.claim_queued_job(ocak_id))
                finally:
                    local.close()

            threads = [threading.Thread(target=claim) for _ in range(2)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            winners = [item for item in results if item is not None]
            self.assertEqual(len(winners), 1)
            self.assertEqual(winners[0]["station_id"], "ocak")
            check = LocalRestaurantStore(path)
            firin = [job for job in check._jobs("dispatch-ocak-firin") if ":firin:" in job["id"]]
            self.assertEqual(firin[0]["status"], "queued")
            check.close()

    def test_uncertain_and_quarantine_are_not_selected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "lan.sqlite"
            store = LocalRestaurantStore(path)
            saved = accept_and_queue(
                store,
                _order(),
                printer_host="192.168.10.100",
                printer_port=9100,
                deliver=False,
            )
            firin_id = next(job for job in saved["print_job_ids"] if ":firin:" in job)
            store.mark_print(firin_id, "uncertain")
            self.assertIsNone(store.claim_queued_job(firin_id))
            arm_quarantine(root)
            (root / "job_quarantine.json").unlink()
            decision = auto_claim_decision(
                {"id": saved["print_job_ids"][0], "status": "pending"},
                root=root,
            )
            self.assertFalse(decision.allow)
            historical = auto_claim_decision(
                {"id": "old-printing", "status": "printing"},
                root=root,
            )
            self.assertFalse(historical.allow)
            store.close()

    def test_kitchen_escpos_renders_both_stations_at_80mm(self) -> None:
        env_path = Path(tempfile.mkdtemp()) / "bridge.env"
        env_path.write_text(
            "PRINT_BRIDGE_PAPER_WIDTH_MM=80\nPRINT_BRIDGE_CHARS_PER_LINE=48\n",
            encoding="utf-8",
        )
        previous = os.environ.get("PRINT_BRIDGE_ENV_FILE")
        os.environ["PRINT_BRIDGE_ENV_FILE"] = str(env_path)
        try:
            settings = BridgeSettings.from_env()
        finally:
            if previous is None:
                os.environ.pop("PRINT_BRIDGE_ENV_FILE", None)
            else:
                os.environ["PRINT_BRIDGE_ENV_FILE"] = previous
        self.assertEqual(settings.paper_width_mm, 80)
        self.assertEqual(settings.chars_per_line, 48)
        renderer = KitchenRenderer(settings)
        for station, name in (("ocak", "Izgara Köfte"), ("firin", "Fırın Sütlaç")):
            payload = KitchenPayload.from_dict(
                {
                    "title": "MUTFAK",
                    "store_name": "İBUL SATICI",
                    "order_no": "dispatch-ocak-firin",
                    "table_no": "41",
                    "table_name": "Test Masası",
                    "area_name": station,
                    "job_type": "new_order",
                    "datetime": "2026-11-11T22:40:00+03:00",
                    "items": [
                        {
                            "name": name,
                            "quantity": 1 if station == "ocak" else 2,
                            "note": "Az pişmiş, soğansız" if station == "ocak" else "Şekerli",
                        }
                    ],
                }
            )
            raw = renderer.render(payload)
            text = raw.decode("cp857", errors="replace")
            self.assertGreater(len(raw), 20)
            self.assertIn(station.upper(), text.upper())
            self.assertIn("Test Masası", text)
            self.assertIn("dispatch-ocak-firin", text)
            self.assertIn("11.11.2026", text)
            self.assertIn("Not:", text)


if __name__ == "__main__":
    unittest.main()
