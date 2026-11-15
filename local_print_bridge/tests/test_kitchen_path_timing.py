"""Ten isolated kitchen posts: HTTP accept and TCP write, no live printer."""

from __future__ import annotations

import json
import os
import socket
import statistics
import tempfile
import threading
import time
import unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer

from local_print_bridge.config import BridgeSettings
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.server import PrintBridgeHandler
from local_print_bridge.transport import PrintResult


class _TcpSinkTransport:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self.tcp_ms: list[float] = []

    def health(self) -> dict[str, object]:
        return {"ok": True, "transport": "tcp-sink"}

    def discover(self) -> dict[str, object]:
        return {"printers": [], "usb": [], "cups": [], "windows": [], "network": []}

    def resolve_printer(self, **_kwargs: object) -> dict[str, object]:
        return {
            "id": "tcp:sink",
            "name": "sink",
            "backend": "tcp",
            "host": self.host,
            "port": self.port,
        }

    def print_bytes(self, payload: bytes, *_args: object, **_kwargs: object) -> PrintResult:
        started = time.perf_counter()
        with socket.create_connection((self.host, self.port), timeout=2) as sock:
            sock.sendall(payload)
        self.tcp_ms.append((time.perf_counter() - started) * 1000)
        return PrintResult(job_id="sink", raw_output="tcp", bytes_sent=len(payload))


def _percentile(samples: list[float], pct: float) -> float:
    ordered = sorted(samples)
    index = min(len(ordered) - 1, max(0, round((pct / 100) * (len(ordered) - 1))))
    return ordered[index]


class KitchenPathTimingTests(unittest.TestCase):
    def test_ten_kitchen_posts_record_http_and_tcp(self) -> None:
        sink = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sink.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sink.bind(("127.0.0.1", 0))
        sink.listen(20)
        sink_port = sink.getsockname()[1]
        stop = threading.Event()

        def accept_loop() -> None:
            sink.settimeout(0.2)
            while not stop.is_set():
                try:
                    conn, _addr = sink.accept()
                except TimeoutError:
                    continue
                except OSError:
                    break
                with conn:
                    while conn.recv(4096):
                        pass

        thread = threading.Thread(target=accept_loop, daemon=True)
        thread.start()
        previous_env = os.environ.get("PRINT_BRIDGE_ENV_FILE")
        previous_data = os.environ.get("PRINT_BRIDGE_DATA_DIR")
        data_dir = tempfile.TemporaryDirectory(prefix="ibul-kitchen-time-")
        env_file = tempfile.NamedTemporaryFile(prefix="bridge-time-", suffix=".env", delete=False)
        env_file.close()
        os.environ["PRINT_BRIDGE_DATA_DIR"] = data_dir.name
        os.environ["PRINT_BRIDGE_ENV_FILE"] = env_file.name
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
            print_system_enabled=True,
            cut_mode="partial",
            transport_mode="tcp",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="127.0.0.1",
            network_port=sink_port,
        )
        transport = _TcpSinkTransport("127.0.0.1", sink_port)
        PrintBridgeHandler.settings = settings
        PrintBridgeHandler.renderer = ReceiptRenderer(settings)
        PrintBridgeHandler.transport = transport
        server = ThreadingHTTPServer(("127.0.0.1", 0), PrintBridgeHandler)
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        http_ms: list[float] = []
        try:
            for index in range(10):
                body = json.dumps(
                    {
                        "document_type": "kitchen",
                        "job_type": "new_order",
                        "title": "MUTFAK",
                        "store_name": "DESTINA",
                        "daily_order_no": 100 + index,
                        "table_number": 4,
                        "display_table_label": "Salon 4",
                        "waiter_name": "Ayse Yilmaz",
                        "waiter_title": "Salon Sorumlusu",
                        "printed_at": "2026-11-13T06:40:00+03:00",
                        "items": [
                            {"name": "Adana", "quantity": 2, "note": f"olcu {index}"},
                            {"name": "Ayran", "quantity": 1},
                        ],
                        "trace_id": f"kitchen-path-{index}",
                    }
                ).encode()
                started = time.perf_counter()
                connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                connection.request(
                    "POST",
                    "/print/kitchen",
                    body=body,
                    headers={"Content-Type": "application/json"},
                )
                response = connection.getresponse()
                raw = response.read()
                connection.close()
                elapsed = (time.perf_counter() - started) * 1000
                http_ms.append(elapsed)
                self.assertEqual(response.status, 200, raw)
                payload = json.loads(raw)
                self.assertTrue(payload.get("ok"), payload)
                self.assertGreater(index, -1)
        finally:
            server.shutdown()
            server.server_close()
            server_thread.join(timeout=2)
            stop.set()
            sink.close()
            thread.join(timeout=2)
            data_dir.cleanup()
            try:
                os.unlink(env_file.name)
            except FileNotFoundError:
                pass
            if previous_env is None:
                os.environ.pop("PRINT_BRIDGE_ENV_FILE", None)
            else:
                os.environ["PRINT_BRIDGE_ENV_FILE"] = previous_env
            if previous_data is None:
                os.environ.pop("PRINT_BRIDGE_DATA_DIR", None)
            else:
                os.environ["PRINT_BRIDGE_DATA_DIR"] = previous_data

        self.assertEqual(len(http_ms), 10)
        self.assertGreaterEqual(len(transport.tcp_ms), 10)
        print(
            "KITCHEN_E2E http_median_ms="
            f"{statistics.median(http_ms):.3f} "
            f"http_p95_ms={_percentile(http_ms, 95):.3f} "
            f"tcp_median_ms={statistics.median(transport.tcp_ms):.3f} "
            f"tcp_p95_ms={_percentile(transport.tcp_ms, 95):.3f}"
        )


class PrintDisabledSendsNoBytesTests(unittest.TestCase):
    def test_closed_service_writes_zero_tcp_bytes(self) -> None:
        received = bytearray()
        sink = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sink.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sink.bind(("127.0.0.1", 0))
        sink.listen(4)
        sink_port = sink.getsockname()[1]
        stop = threading.Event()

        def accept_loop() -> None:
            sink.settimeout(0.2)
            while not stop.is_set():
                try:
                    conn, _addr = sink.accept()
                except TimeoutError:
                    continue
                except OSError:
                    break
                with conn:
                    while True:
                        chunk = conn.recv(4096)
                        if not chunk:
                            break
                        received.extend(chunk)

        thread = threading.Thread(target=accept_loop, daemon=True)
        thread.start()
        previous_env = os.environ.get("PRINT_BRIDGE_ENV_FILE")
        previous_data = os.environ.get("PRINT_BRIDGE_DATA_DIR")
        data_dir = tempfile.TemporaryDirectory(prefix="ibul-print-off-")
        env_file = tempfile.NamedTemporaryFile(prefix="bridge-off-", suffix=".env", delete=False)
        env_file.close()
        os.environ["PRINT_BRIDGE_DATA_DIR"] = data_dir.name
        os.environ["PRINT_BRIDGE_ENV_FILE"] = env_file.name
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
            print_system_enabled=False,
            cut_mode="partial",
            transport_mode="tcp",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="127.0.0.1",
            network_port=sink_port,
        )
        transport = _TcpSinkTransport("127.0.0.1", sink_port)
        PrintBridgeHandler.settings = settings
        PrintBridgeHandler.renderer = ReceiptRenderer(settings)
        PrintBridgeHandler.transport = transport
        server = ThreadingHTTPServer(("127.0.0.1", 0), PrintBridgeHandler)
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        body = json.dumps(
            {
                "document_type": "kitchen",
                "job_type": "new_order",
                "store_name": "DESTINA",
                "daily_order_no": 1,
                "table_number": 2,
                "items": [{"name": "Cay", "quantity": 1}],
            }
        ).encode()
        try:
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            connection.request("GET", "/health")
            health = connection.getresponse()
            health_body = json.loads(health.read())
            self.assertEqual(health.status, 200)
            self.assertIs(health_body.get("print_system_enabled"), False)
            self.assertIn("print_station_enabled", health_body)
            connection.close()
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            connection.request(
                "POST",
                "/print/kitchen",
                body=body,
                headers={"Content-Type": "application/json"},
            )
            response = connection.getresponse()
            raw = response.read()
            connection.close()
            self.assertEqual(response.status, 503, raw)
            payload = json.loads(raw)
            self.assertEqual(payload.get("errorCode"), "print_system_disabled")
            self.assertEqual(transport.tcp_ms, [])
            self.assertEqual(bytes(received), b"")
        finally:
            server.shutdown()
            server.server_close()
            server_thread.join(timeout=2)
            stop.set()
            sink.close()
            thread.join(timeout=2)
            data_dir.cleanup()
            try:
                os.unlink(env_file.name)
            except FileNotFoundError:
                pass
            if previous_env is None:
                os.environ.pop("PRINT_BRIDGE_ENV_FILE", None)
            else:
                os.environ["PRINT_BRIDGE_ENV_FILE"] = previous_env
            if previous_data is None:
                os.environ.pop("PRINT_BRIDGE_DATA_DIR", None)
            else:
                os.environ["PRINT_BRIDGE_DATA_DIR"] = previous_data
