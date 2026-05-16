from __future__ import annotations

import http.client
from http import HTTPStatus
import json
import os
import tempfile
import threading
import unittest

from local_print_bridge.config import BridgeSettings
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.server import PrintBridgeHandler


class _FakeSpool:
    def __init__(self, ok: bool = True) -> None:
        self.ok = ok
        self.calls: list[str] = []

    def clear_queue(self, queue: str) -> dict[str, object]:
        self.calls.append(queue)
        if self.ok:
            return {"ok": True, "queue_status": "cleared", "queue": queue}
        return {"ok": False, "error": "clear failed", "queue_status": "failed", "queue": queue}


class _FakeTransportWithSpool:
    def __init__(self, spool: _FakeSpool) -> None:
        self._spool = spool

    def health(self) -> dict[str, object]:
        return {"ok": True, "transport": "fake"}

    def discover(self) -> dict[str, object]:
        return {"printers": [], "usb": [], "cups": [], "windows": [], "network": []}


class QueueErrorTests(unittest.TestCase):
    def setUp(self) -> None:
        self._previous_env_file = os.environ.get("PRINT_BRIDGE_ENV_FILE")
        self._previous_data_dir = os.environ.get("PRINT_BRIDGE_DATA_DIR")
        temp_data_dir = tempfile.TemporaryDirectory(prefix="ibul-bridge-data-")
        self._temp_data_dir_obj = temp_data_dir
        os.environ["PRINT_BRIDGE_DATA_DIR"] = temp_data_dir.name
        temp_env = tempfile.NamedTemporaryFile(prefix="bridge-test-", suffix=".env", delete=False)
        temp_env.close()
        self._temp_env_path = temp_env.name
        os.environ["PRINT_BRIDGE_ENV_FILE"] = self._temp_env_path

        self.spool = _FakeSpool(ok=True)
        self.transport = _FakeTransportWithSpool(self.spool)
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=0,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="image",
            raster_chunk_height=256,
            allowed_origins=("http://localhost",),
            healthcheck_queue=False,
            print_system_enabled=True,
            cut_mode="partial",
            transport_mode="auto",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="",
            network_port=9100,
        )
        PrintBridgeHandler.settings = self.settings
        PrintBridgeHandler.renderer = ReceiptRenderer(self.settings)
        PrintBridgeHandler.transport = self.transport

        from http.server import ThreadingHTTPServer

        self.server = ThreadingHTTPServer((self.settings.host, 0), PrintBridgeHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.port = self.server.server_port

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        try:
            os.unlink(self._temp_env_path)
        except FileNotFoundError:
            pass
        if self._previous_env_file is None:
            os.environ.pop("PRINT_BRIDGE_ENV_FILE", None)
        else:
            os.environ["PRINT_BRIDGE_ENV_FILE"] = self._previous_env_file
        if self._previous_data_dir is None:
            os.environ.pop("PRINT_BRIDGE_DATA_DIR", None)
        else:
            os.environ["PRINT_BRIDGE_DATA_DIR"] = self._previous_data_dir
        self._temp_data_dir_obj.cleanup()

    def test_queue_clear_requires_queue(self) -> None:
        PrintBridgeHandler.settings = BridgeSettings(
            **{**self.settings.__dict__, "printer_queue": ""}
        )
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request(
            "POST",
            "/queue/clear",
            body=json.dumps({}),
            headers={"Content-Type": "application/json"},
        )
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, HTTPStatus.BAD_REQUEST)
        self.assertEqual(body.get("errorCode"), "queue_missing")

    def test_queue_clear_calls_spool_clear_queue(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request(
            "POST",
            "/queue/clear",
            body=json.dumps({"queue": "Thermal58"}),
            headers={"Content-Type": "application/json"},
        )
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, HTTPStatus.OK)
        self.assertTrue(body.get("ok"))
        self.assertEqual(self.spool.calls, ["Thermal58"])

    def test_queue_clear_surfaces_failure(self) -> None:
        self.transport._spool.ok = False
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request(
            "POST",
            "/queue/clear",
            body=json.dumps({"queue": "Thermal58"}),
            headers={"Content-Type": "application/json"},
        )
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, HTTPStatus.INTERNAL_SERVER_ERROR)
        self.assertFalse(body.get("ok"))


if __name__ == "__main__":
    unittest.main()

