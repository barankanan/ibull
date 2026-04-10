from __future__ import annotations

from datetime import datetime
import http.client
import json
import threading
import unittest

from local_print_bridge.config import BridgeSettings
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.server import PrintBridgeHandler
from local_print_bridge.transport import PrintResult


class _FakeTransport:
    def __init__(self) -> None:
        self.calls: list[tuple[bytes, str]] = []

    def health(self) -> dict[str, object]:
        return {"ok": True, "transport": "fake", "queue": "Thermal58"}

    def print_bytes(self, payload: bytes, *, job_name: str) -> PrintResult:
        self.calls.append((payload, job_name))
        return PrintResult(
            job_id="Thermal58-101",
            raw_output="request id is Thermal58-101 (1 file(s))",
            bytes_sent=len(payload),
        )


class PrintBridgeServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.transport = _FakeTransport()
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=0,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            allowed_origins=("https://ibul-ecommerce.web.app",),
            healthcheck_queue=False,
            cut_mode="partial",
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

    def test_health_endpoint_returns_bridge_metadata(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/health")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body["service"], "ibul-local-print-bridge")
        self.assertEqual(body["printer_queue"], "Thermal58")

    def test_receipt_endpoint_accepts_flat_payload_and_submits_job(self) -> None:
        payload = json.dumps(
            {
                "store_name": "IBUL RESTAURANT",
                "branch": "MERKEZ SUBE",
                "phone": "0326 000 00 00",
                "table_no": "5",
                "datetime": datetime.now().astimezone().isoformat(),
                "items": [
                    {
                        "name": "Mercimek Corba",
                        "qty": 2,
                        "price": "80.00",
                        "total": "160.00",
                    }
                ],
                "subtotal": "160.00",
                "discount": "0.00",
                "grand_total": "160.00",
            }
        )
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }

        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print/receipt", body=payload, headers=headers)
        response = connection.getresponse()
        response_headers = dict(response.getheaders())
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(body["job_id"], "Thermal58-101")
        self.assertEqual(response_headers["Access-Control-Allow-Origin"], "https://ibul-ecommerce.web.app")
        self.assertEqual(len(self.transport.calls), 1)
        self.assertEqual(self.transport.calls[0][1], "adisyon-masa-5")

    def test_options_returns_private_network_header_for_https_origin(self) -> None:
        headers = {
            "Origin": "https://ibul-ecommerce.web.app",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Private-Network": "true",
        }

        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("OPTIONS", "/print/receipt", headers=headers)
        response = connection.getresponse()
        response_headers = dict(response.getheaders())
        response.read()
        connection.close()

        self.assertEqual(response.status, 204)
        self.assertEqual(response_headers["Access-Control-Allow-Origin"], "https://ibul-ecommerce.web.app")
        self.assertEqual(response_headers["Access-Control-Allow-Private-Network"], "true")


if __name__ == "__main__":
    unittest.main()
