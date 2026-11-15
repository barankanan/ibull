import json
import socket
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import tempfile

from local_print_bridge.lan_pairing import lan_bridge_decision
from local_print_bridge.lan_pilot import accept_and_queue, flush_sync
from local_print_bridge.local_store import LocalRestaurantStore


class _MockPrinter(threading.Thread):
    def __init__(self) -> None:
        super().__init__(daemon=True)
        self.payloads: list[bytes] = []
        self._server = socket.socket()
        self._server.bind(("127.0.0.1", 0))
        self._server.listen(4)
        self.port = self._server.getsockname()[1]
        self._stop = threading.Event()

    def run(self) -> None:
        self._server.settimeout(0.2)
        while not self._stop.is_set():
            try:
                conn, _addr = self._server.accept()
            except socket.timeout:
                continue
            with conn:
                chunks = []
                while True:
                    data = conn.recv(4096)
                    if not data:
                        break
                    chunks.append(data)
                self.payloads.append(b"".join(chunks))

    def close(self) -> None:
        self._stop.set()
        self._server.close()


class _SyncHandler(BaseHTTPRequestHandler):
    seen: list[dict] = []

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8"))
        type(self).seen.append(body)
        raw = b'{"ok":true}'
        self.send_response(200)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, _format: str, *_args: object) -> None:
        return


class LanPilotTests(unittest.TestCase):
    def test_offline_order_survives_restart_and_syncs_once(self) -> None:
        printer = _MockPrinter()
        printer.start()
        timings: dict[str, float] = {}
        try:
            with tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / "lan.sqlite"
                store = LocalRestaurantStore(path)
                first = accept_and_queue(
                    store,
                    _order("order-1", table=8, name="Cay", price=25),
                    printer_host="127.0.0.1",
                    printer_port=printer.port,
                    deliver=True,
                )
                self.assertTrue(first["saved"])
                self.assertFalse(first["duplicate"])
                self.assertEqual(first["print_status"], "sent")
                self.assertEqual(first["total_cents"], 2500)
                timings["accept_ms"] = float(first["accept_ms"])
                timings["db_ms"] = float(first["db_ms"])
                timings["printer_ms"] = float(first["printer_ms"])
                self.assertIn(b"Cay", printer.payloads[0])

                cut = flush_sync(store, "http://127.0.0.1:9")
                self.assertEqual(cut["synced"], 0)
                self.assertEqual(cut["pending"], 1)
                second = accept_and_queue(
                    store,
                    _order("order-2", table=71, name="Corba", price=40, station="ocak"),
                    printer_host="127.0.0.1",
                    printer_port=printer.port,
                    deliver=True,
                )
                self.assertEqual(second["print_status"], "sent")
                self.assertIn(b"[ocak]", printer.payloads[1])
                replay = accept_and_queue(
                    store,
                    _order("order-1", table=8, name="Cay", price=25),
                    printer_host="127.0.0.1",
                    printer_port=printer.port,
                    deliver=True,
                )
                self.assertTrue(replay["duplicate"])
                self.assertEqual(len(printer.payloads), 2)
                store.close()

                reopened = LocalRestaurantStore(path)
                self.assertEqual(reopened.order_count(), 2)
                self.assertEqual(reopened.restaurant_id(), "rest-1")
                saved = reopened.get_order("order-1")
                assert saved is not None
                self.assertEqual(saved["order"]["total_cents"], 2500)

                sync_server = ThreadingHTTPServer(("127.0.0.1", 0), _SyncHandler)
                thread = threading.Thread(target=sync_server.serve_forever, daemon=True)
                thread.start()
                try:
                    url = f"http://127.0.0.1:{sync_server.server_address[1]}"
                    done = flush_sync(reopened, url)
                    timings["sync_ms"] = float(done["sync_ms"])
                    self.assertEqual(done["synced"], 2)
                    self.assertEqual(done["pending"], 0)
                    again = flush_sync(reopened, url)
                    self.assertEqual(again["synced"], 0)
                    self.assertEqual(len(_SyncHandler.seen), 2)
                finally:
                    sync_server.shutdown()
                with self.assertRaises(ValueError):
                    flush_sync(reopened, "https://ihmixxzqnpamcwmrfibx.supabase.co")
                reopened.close()
        finally:
            printer.close()
        self.assertGreater(timings["accept_ms"], 0)
        self.assertLess(timings["db_ms"], 500)
        print("LAN_PILOT_TIMINGS", json.dumps(timings))

    def test_two_stations_queue_once_without_printing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = LocalRestaurantStore(Path(tmp) / "lan.sqlite")
            body = {
                "local_order_id": "e2e-ocak-firin-1",
                "restaurant_id": "test-restoran",
                "table_number": 41,
                "table_label": "Test Masasi",
                "waiter_name": "Test Garson",
                "items": [
                    {"name": "Test Ocak", "quantity": 1, "unit_price": 10, "station_id": "ocak"},
                    {"name": "Test Firin", "quantity": 1, "unit_price": 12, "station_id": "firin"},
                ],
            }
            first = accept_and_queue(
                store,
                body,
                printer_host="192.168.10.100",
                printer_port=9100,
                deliver=False,
            )
            self.assertFalse(first["duplicate"])
            self.assertEqual(first["station_ids"], ["ocak", "firin"])
            self.assertEqual(len(first["print_job_ids"]), 2)
            self.assertFalse(first["printed"])
            second = accept_and_queue(
                store,
                body,
                printer_host="192.168.10.100",
                printer_port=9100,
                deliver=False,
            )
            self.assertTrue(second["duplicate"])
            self.assertEqual(len(store._jobs("e2e-ocak-firin-1")), 2)
            store.close()
            reopened = LocalRestaurantStore(Path(tmp) / "lan.sqlite")
            self.assertEqual(len(reopened._jobs("e2e-ocak-firin-1")), 2)
            reopened.close()

    def test_lan_client_still_cannot_open_the_bridge(self) -> None:
        self.assertEqual(
            lan_bridge_decision("/lan/v1/orders", loopback=False, authorization="Bearer x"),
            "loopback_only",
        )

    def test_client_total_cannot_override_line_prices(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = LocalRestaurantStore(Path(tmp) / "lan.sqlite")
            body = _order("order-3", table=8, name="Cay", price=12)
            body["total"] = 1
            with self.assertRaises(ValueError):
                accept_and_queue(
                    store,
                    body,
                    printer_host="127.0.0.1",
                    printer_port=9,
                    deliver=False,
                )
            self.assertEqual(store.order_count(), 0)
            accept_and_queue(
                store,
                _order("order-3", table=8, name="Cay", price=12),
                printer_host="127.0.0.1",
                printer_port=9,
                deliver=False,
            )
            changed = _order("order-3", table=8, name="Cay", price=99)
            with self.assertRaises(ValueError):
                accept_and_queue(
                    store,
                    changed,
                    printer_host="127.0.0.1",
                    printer_port=9,
                    deliver=False,
                )
            self.assertEqual(store.order_count(), 1)
            store.close()


def _order(
    order_id: str,
    *,
    table: int,
    name: str,
    price: float,
    station: str = "mutfak",
) -> dict:
    return {
        "local_order_id": order_id,
        "restaurant_id": "rest-1",
        "table_number": table,
        "table_label": f"Masa {table}",
        "waiter_name": "Ayse",
        "items": [
            {
                "name": name,
                "quantity": 1,
                "unit_price": price,
                "station_id": station,
            }
        ],
    }


if __name__ == "__main__":
    unittest.main()
