"""In-process claim and quarantine proof. No printer and no live port."""
from __future__ import annotations

import tempfile
import threading
from pathlib import Path

from .job_quarantine import arm_quarantine, auto_claim_decision
from .lan_pilot import accept_and_queue
from .local_store import LocalRestaurantStore


def run_claim_quarantine_selftest() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        path = root / "lan.sqlite"
        store = LocalRestaurantStore(path)
        saved = accept_and_queue(
            store,
            {
                "local_order_id": "selftest-ocak-firin",
                "restaurant_id": "test-restoran",
                "table_number": 41,
                "table_label": "Test Masasi",
                "waiter_name": "Test Garson",
                "items": [
                    {"name": "Izgara", "quantity": 1, "unit_price": 10, "station_id": "ocak"},
                    {"name": "Sutlac", "quantity": 1, "unit_price": 12, "station_id": "firin"},
                ],
            },
            printer_host="127.0.0.1",
            printer_port=9,
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
        if len([item for item in results if item is not None]) != 1:
            return 2
        check = LocalRestaurantStore(path)
        try:
            firin = [job for job in check._jobs("selftest-ocak-firin") if ":firin:" in job["id"]]
            if firin[0]["status"] != "queued":
                return 3
            check.mark_print(firin[0]["id"], "uncertain")
            if check.claim_queued_job(firin[0]["id"]) is not None:
                return 4
        finally:
            check.close()
        arm_quarantine(root)
        (root / "job_quarantine.json").unlink()
        if auto_claim_decision({"id": "new", "status": "pending"}, root=root).allow:
            return 5
        if auto_claim_decision({"id": "old", "status": "printing"}, root=root).allow:
            return 6
    print("ISOLATED_SELFTEST claim_quarantine ok")
    return 0
