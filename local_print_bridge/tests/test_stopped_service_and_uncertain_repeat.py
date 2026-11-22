"""Acceptance: a stopped service sends nothing; an uncertain ticket is not
reprinted by itself and is never reported as printed."""

from __future__ import annotations

import json
import os
import socket
import tempfile
import threading
import unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer

from local_print_bridge import server as bridge_server
from local_print_bridge.config import BridgeSettings
from local_print_bridge.network_transport import PHASE_WRITE, TcpTransportError
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.server import PrintBridgeHandler
from local_print_bridge.tests.test_kitchen_path_timing import _TcpSinkTransport


class _Sink:
    """A fake printer: counts every byte that reaches port 9100."""

    def __init__(self) -> None:
        self.received = bytearray()
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._socket.bind(("127.0.0.1", 0))
        self._socket.listen(4)
        self.port = self._socket.getsockname()[1]
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def _loop(self) -> None:
        self._socket.settimeout(0.2)
        while not self._stop.is_set():
            try:
                conn, _addr = self._socket.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            with conn:
                while True:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    self.received.extend(chunk)

    def close(self) -> None:
        self._stop.set()
        self._socket.close()
        self._thread.join(timeout=2)


class _WriteFails:
    """A transport whose send fails after writing began."""

    def __init__(self) -> None:
        self.calls = 0

    def print_bytes(self, raw_bytes, **_kwargs):
        self.calls += 1
        error = TcpTransportError("tcp_write_failed", "connection reset while writing")
        error.phase = PHASE_WRITE
        raise error

    def __getattr__(self, name):  # health / discover used by other endpoints
        raise AttributeError(name)


class StoppedServiceAndUncertainRepeatTests(unittest.TestCase):
    def setUp(self) -> None:
        with bridge_server._HTTP_PRINT_IDEM_LOCK:
            bridge_server._HTTP_PRINT_RECENT_JOBS.clear()
            bridge_server._HTTP_PRINT_UNCERTAIN_KEYS.clear()
        self._env = {
            key: os.environ.get(key)
            for key in ("PRINT_BRIDGE_ENV_FILE", "PRINT_BRIDGE_DATA_DIR")
        }
        self._data = tempfile.TemporaryDirectory(prefix="ibul-accept-")
        env_file = tempfile.NamedTemporaryFile(suffix=".env", delete=False)
        env_file.close()
        self._env_file = env_file.name
        os.environ["PRINT_BRIDGE_DATA_DIR"] = self._data.name
        os.environ["PRINT_BRIDGE_ENV_FILE"] = self._env_file
        self.sink = _Sink()
        self._saved = (
            PrintBridgeHandler.settings,
            PrintBridgeHandler.renderer,
            PrintBridgeHandler.transport,
        )
        self.server = None

    def tearDown(self) -> None:
        if self.server is not None:
            self.server.shutdown()
            self.server.server_close()
        self.sink.close()
        (
            PrintBridgeHandler.settings,
            PrintBridgeHandler.renderer,
            PrintBridgeHandler.transport,
        ) = self._saved
        for key, value in self._env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        os.unlink(self._env_file)
        self._data.cleanup()

    def _start(self, *, enabled: bool, transport) -> None:
        settings = BridgeSettings(
            host="127.0.0.1",
            port=0,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="text",
            raster_chunk_height=256,
            allowed_origins=("http://127.0.0.1",),
            healthcheck_queue=False,
            print_system_enabled=enabled,
            cut_mode="partial",
            transport_mode="tcp",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="127.0.0.1",
            network_port=self.sink.port,
        )
        PrintBridgeHandler.settings = settings
        PrintBridgeHandler.renderer = ReceiptRenderer(settings)
        PrintBridgeHandler.transport = transport
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), PrintBridgeHandler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def _post(self, path: str, body: dict) -> tuple[int, dict]:
        connection = HTTPConnection("127.0.0.1", self.server.server_port, timeout=10)
        connection.request(
            "POST",
            path,
            body=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"},
        )
        response = connection.getresponse()
        payload = json.loads(response.read() or b"{}")
        connection.close()
        return response.status, payload

    def _kitchen(self, key: str) -> dict:
        return {
            "document_type": "kitchen",
            "job_type": "new_order",
            "store_name": "DESTINA",
            "daily_order_no": 1,
            "table_number": 2,
            "print_job_id": key,
            "logical_print_key": key,
            "target_host": "127.0.0.1",
            "target_port": self.sink.port,
            "items": [{"name": "Cay", "quantity": 1}],
        }

    def test_stopped_service_refuses_kitchen_and_sends_zero_bytes(self) -> None:
        self._start(
            enabled=False,
            transport=_TcpSinkTransport("127.0.0.1", self.sink.port),
        )
        status, body = self._post("/print/kitchen", self._kitchen("order-1|ocak"))
        self.assertEqual(status, 503)
        self.assertFalse(body["ok"])
        self.assertEqual(body["errorCode"], "print_system_disabled")
        self.assertEqual(bytes(self.sink.received), b"")

    def test_uncertain_ticket_is_not_resent_and_not_called_printed(self) -> None:
        transport = _WriteFails()
        self._start(enabled=True, transport=transport)
        payload = self._kitchen("order-2|ocak")

        status, first = self._post("/print/kitchen", payload)
        self.assertEqual(status, 500)
        self.assertFalse(first["ok"])
        self.assertTrue(first["write_may_have_started"])
        self.assertFalse(first["retry_safe"])
        self.assertEqual(first["print_outcome"], "uncertain")
        # The bridge itself did not try a second time.
        self.assertEqual(transport.calls, 1)

        # The same ticket arriving again (a queue sweep, a restart of the
        # sender) is neither printed nor answered as "already printed".
        status, again = self._post("/print/kitchen", payload)
        self.assertEqual(status, 409)
        self.assertFalse(again["ok"])
        self.assertNotIn("duplicate", again)
        self.assertEqual(again["errorCode"], "print_outcome_uncertain")
        self.assertEqual(transport.calls, 1)

        # Only the operator's confirmed retry sends it again, once.
        status, _retry = self._post(
            "/print/kitchen", {**payload, "operator_confirmed_retry": True}
        )
        self.assertEqual(transport.calls, 2)


if __name__ == "__main__":
    unittest.main()
