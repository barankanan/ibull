from __future__ import annotations

from datetime import datetime
import http.client
from http import HTTPStatus
import json
import os
import threading
import tempfile
import unittest
from unittest import mock

from local_print_bridge.config import BridgeSettings
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.server import PrintBridgeHandler
from local_print_bridge.transport import PrintResult
from local_print_bridge.print_station import (
    PrintStationConsumer,
    PrintStationRuntimeConfig,
)


class _FakeTransport:
    def __init__(self) -> None:
        self.calls: list[tuple[bytes, str, dict[str, object] | None]] = []
        self.queue_status_calls = 0

    def health(self) -> dict[str, object]:
        return {"ok": True, "transport": "fake", "queue": "Thermal58"}

    def discover(self) -> dict[str, object]:
        printer = {
            "id": "windows:USB POS-80",
            "name": "USB POS-80",
            "queue": "USB POS-80",
            "backend": "windows-spool",
            "connectionType": "usb",
            "vendorId": "0x1234",
            "productId": "0xabcd",
            "status": "online",
        }
        return {"printers": [printer], "usb": [], "cups": [], "windows": [printer], "network": []}

    def resolve_printer(
        self,
        *,
        selected_printer: dict[str, object] | None = None,
        printer_id: str | None = None,
        printer_name: str | None = None,
    ) -> dict[str, object] | None:
        if selected_printer is not None:
            return selected_printer
        printer = self.discover()["printers"][0]
        if printer_id == printer["id"] or printer_name == printer["name"]:
            return printer
        return None

    def print_bytes(
        self,
        payload: bytes,
        *,
        job_name: str,
        target_host: str | None = None,
        target_port: int | None = None,
        selected_printer: dict[str, object] | None = None,
    ) -> PrintResult:
        self.calls.append((payload, job_name, selected_printer))
        return PrintResult(
            job_id="Thermal58-101",
            raw_output="request id is Thermal58-101 (1 file(s))",
            bytes_sent=len(payload),
        )

    def queue_status(self, queue_name: str) -> dict[str, object]:
        self.queue_status_calls += 1
        return {
            "queue_status": "idle",
            "queue_has_active_job": False,
            "queue_name": queue_name,
        }


class PrintBridgeServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.transport = _FakeTransport()
        self._previous_env_file = os.environ.get("PRINT_BRIDGE_ENV_FILE")
        self._previous_data_dir = os.environ.get("PRINT_BRIDGE_DATA_DIR")
        temp_data_dir = tempfile.TemporaryDirectory(prefix="ibul-bridge-data-")
        self._temp_data_dir_obj = temp_data_dir
        os.environ["PRINT_BRIDGE_DATA_DIR"] = temp_data_dir.name
        temp_env = tempfile.NamedTemporaryFile(prefix="bridge-test-", suffix=".env", delete=False)
        temp_env.close()
        self._temp_env_path = temp_env.name
        os.environ["PRINT_BRIDGE_ENV_FILE"] = self._temp_env_path
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
            allowed_origins=("https://ibul-ecommerce.web.app",),
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
        self.assertEqual(body["render_mode"], "image")
        self.assertIn("pillow_available", body)
        self.assertIn("python_executable", body)
        self.assertIsInstance(body.get("build"), dict)
        self.assertIn("python_executable", body["build"])

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
        self.assertEqual(body["render_mode"], "image")
        self.assertIn("printer_write_started_at", body)
        self.assertIn("printer_write_completed_at", body)
        self.assertEqual(response_headers["Access-Control-Allow-Origin"], "https://ibul-ecommerce.web.app")
        self.assertEqual(len(self.transport.calls), 1)
        self.assertEqual(self.transport.calls[0][1], "adisyon-masa-5")

    def test_print_test_endpoint_does_not_raise_name_error(self) -> None:
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps(
            {
                "test_mode": "escpos_short",
                "render_mode": "image",
            }
        )
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print/test", body=payload, headers=headers)
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body.get("render_mode"), "text")

    def test_ethernet_connection_test_bypasses_queue_checks(self) -> None:
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps(
            {
                "test_mode": "ethernet_connection",
                "target_host": "192.168.1.100",
                "target_port": 9100,
                "printer": {
                    "id": "tcp:192.168.1.100:9100",
                    "name": "NETUM ZJ-8360 Ethernet",
                    "displayName": "NETUM ZJ-8360 Ethernet",
                    "backend": "tcp",
                    "transportType": "ethernet",
                    "transport_type": "ethernet",
                    "host": "192.168.1.100",
                    "port": 9100,
                    "source": "ethernet_dialog_form",
                },
            }
        )
        with mock.patch(
            "local_print_bridge.server.NetworkTcpTransport.health",
            return_value={
                "ok": True,
                "transport": "network-tcp",
                "host": "192.168.1.100",
                "port": 9100,
            },
        ):
            connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
            connection.request("POST", "/print/test", body=payload, headers=headers)
            response = connection.getresponse()
            body = json.loads(response.read())
            connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body.get("backend"), "tcp")
        self.assertEqual(body.get("target_host"), "192.168.1.100")
        self.assertEqual(body.get("target_port"), 9100)
        self.assertEqual(body["printer"]["transport_type"], "ethernet")
        self.assertEqual(self.transport.queue_status_calls, 0)
        self.assertEqual(len(self.transport.calls), 0)

    def test_ethernet_test_print_bypasses_queue_checks(self) -> None:
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps(
            {
                "test_mode": "ethernet_test",
                "target_host": "192.168.1.100",
                "target_port": 9100,
                "printer": {
                    "id": "tcp:192.168.1.100:9100",
                    "name": "NETUM ZJ-8360 Ethernet",
                    "displayName": "NETUM ZJ-8360 Ethernet",
                    "backend": "tcp",
                    "transportType": "ethernet",
                    "transport_type": "ethernet",
                    "host": "192.168.1.100",
                    "port": 9100,
                    "source": "ethernet_dialog_form",
                },
            }
        )
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print/test", body=payload, headers=headers)
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(self.transport.queue_status_calls, 0)
        self.assertEqual(len(self.transport.calls), 1)

    def test_ethernet_connection_test_returns_friendly_tcp_error(self) -> None:
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps(
            {
                "test_mode": "ethernet_connection",
                "target_host": "192.168.1.100",
                "target_port": 9100,
            }
        )
        with mock.patch(
            "local_print_bridge.server.NetworkTcpTransport.health",
            return_value={
                "ok": False,
                "transport": "network-tcp",
                "host": "192.168.1.100",
                "port": 9100,
                "error_code": "tcp_unreachable",
                "reason": "192.168.1.100:9100 adresine ulaşılamıyor.",
            },
        ):
            connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
            connection.request("POST", "/print/test", body=payload, headers=headers)
            response = connection.getresponse()
            body = json.loads(response.read())
            connection.close()

        self.assertEqual(response.status, 503)
        self.assertFalse(body["ok"])
        self.assertEqual(body.get("errorCode"), "tcp_unreachable")
        self.assertIn("ulaşılamıyor", body.get("error", ""))
        self.assertEqual(self.transport.queue_status_calls, 0)

    def test_resolve_render_mode_maps_escpos_short_to_text(self) -> None:
        handler = PrintBridgeHandler.__new__(PrintBridgeHandler)
        resolved = handler._resolve_render_mode(
            {"test_mode": "escpos_short", "render_mode": "image"}
        )
        self.assertEqual(resolved, "text")

    def test_resolve_render_mode_turkish_guarantee_forces_image(self) -> None:
        handler = PrintBridgeHandler.__new__(PrintBridgeHandler)
        resolved = handler._resolve_render_mode(
            {
                "turkish_print_mode": "turkish_guarantee",
                "render_mode": "text",
            }
        )
        self.assertEqual(resolved, "image")
        resolved_flag = handler._resolve_render_mode(
            {"turkish_guarantee_mode": True, "render_mode": "text"}
        )
        self.assertEqual(resolved_flag, "image")

    def test_print_endpoint_rejects_when_print_system_disabled(self) -> None:
        PrintBridgeHandler.settings = BridgeSettings(
            host=self.settings.host,
            port=self.settings.port,
            printer_queue=self.settings.printer_queue,
            paper_width_mm=self.settings.paper_width_mm,
            chars_per_line=self.settings.chars_per_line,
            encoding=self.settings.encoding,
            codepage=self.settings.codepage,
            render_mode=self.settings.render_mode,
            raster_chunk_height=self.settings.raster_chunk_height,
            allowed_origins=self.settings.allowed_origins,
            healthcheck_queue=self.settings.healthcheck_queue,
            print_system_enabled=False,
            cut_mode=self.settings.cut_mode,
            transport_mode=self.settings.transport_mode,
            usb_vendor_id=self.settings.usb_vendor_id,
            usb_product_id=self.settings.usb_product_id,
            network_host=self.settings.network_host,
            network_port=self.settings.network_port,
        )
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps({"raw_hex": "1b40"})
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print", body=payload, headers=headers)
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()
        self.assertEqual(response.status, 503)
        self.assertEqual(body.get("errorCode"), "print_system_disabled")

    def test_print_test_bitmap_endpoint_does_not_raise_name_error(self) -> None:
        headers = {
            "Content-Type": "application/json",
            "Origin": "https://ibul-ecommerce.web.app",
        }
        payload = json.dumps({"render_mode": "image"})
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print/test/turkish", body=payload, headers=headers)
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])

    def test_print_station_prefers_job_printer_for_kitchen_jobs(self) -> None:
        consumer = PrintStationConsumer(
            settings_provider=lambda: self.settings,
            transport_provider=lambda: self.transport,
            queue_manager_provider=lambda: None,
            log_store_provider=lambda: None,
        )
        config = PrintStationRuntimeConfig(
            enabled=True,
            print_system_enabled=True,
            restaurant_id="rest-1",
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon",
            access_token="token",
            refresh_token="refresh",
            user_id="user-1",
            device_name="MacBook",
            device_platform="macos",
            receipt_printer_id="windows:USB POS-80",
            receipt_printer_name="USB POS-80",
            kitchen_printer_id="windows:Kitchen Queue",
            kitchen_printer_name="Kitchen Queue",
            poll_interval_ms=2500,
            heartbeat_interval_ms=15000,
            max_retry_count=2,
        )

        selected = consumer._resolve_printer(
            config,
            "mutfak",
            {
                "printer_id": "windows:USB POS-80",
                "printer_name": "USB POS-80",
            },
        )

        self.assertEqual(selected["id"], "windows:USB POS-80")
        self.assertEqual(selected["name"], "USB POS-80")

    def test_print_station_prefers_embedded_printer_payload(self) -> None:
        consumer = PrintStationConsumer(
            settings_provider=lambda: self.settings,
            transport_provider=lambda: self.transport,
            queue_manager_provider=lambda: None,
            log_store_provider=lambda: None,
        )
        config = PrintStationRuntimeConfig(
            enabled=True,
            print_system_enabled=True,
            restaurant_id="rest-1",
            supabase_url="https://example.supabase.co",
            supabase_anon_key="anon",
            access_token="token",
            refresh_token="refresh",
            user_id="user-1",
            device_name="MacBook",
            device_platform="macos",
            receipt_printer_id="windows:USB POS-80",
            receipt_printer_name="USB POS-80",
            kitchen_printer_id="windows:Kitchen Queue",
            kitchen_printer_name="Kitchen Queue",
            poll_interval_ms=2500,
            heartbeat_interval_ms=15000,
            max_retry_count=2,
        )

        selected = consumer._resolve_printer(
            config,
            "mutfak",
            {
                "printer": {
                    "id": "usb:station-queue",
                    "name": "Station Queue",
                    "queue": "Station Queue",
                    "backend": "usb-direct",
                },
                "printer_id": "windows:Kitchen Queue",
                "printer_name": "Kitchen Queue",
            },
        )

        self.assertEqual(selected["id"], "usb:station-queue")
        self.assertEqual(selected["backend"], "usb-direct")

    def test_printers_endpoint_returns_unified_inventory(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/printers")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body["count"], 1)
        self.assertEqual(body["printers"][0]["id"], "windows:USB POS-80")
        self.assertEqual(body["printers"][0]["connectionType"], "usb")

    def test_setup_status_returns_operator_snapshot(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/setup/status")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body["step"], "system_check")
        self.assertIn(body["status"], {"ready", "setup_required", "printer_offline"})
        self.assertIn("platform", body)
        self.assertIn("checks", body)
        self.assertIn("printers", body)

    def test_setup_install_returns_standardized_response(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/setup/install", body="{}", headers={"Content-Type": "application/json"})
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body["step"], "install")
        self.assertEqual(body["status"], "ready")
        self.assertIn("detected", body)
        self.assertIn("settings", body)

    def test_setup_driver_help_is_ui_safe(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/setup/driver-help")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(body["step"], "driver_help")
        self.assertIn("message", body)
        self.assertIn("actionRequired", body)
        self.assertIn("helpSteps", body)

    def test_release_usb_printers_endpoint_calls_helper(self) -> None:
        with mock.patch(
            "local_print_bridge.server._release_usb_printers",
            return_value=(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "released": True,
                    "command": "killall -USR1 cupsd",
                    "wait_ms": 500,
                },
            ),
        ) as release_mock:
            connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
            connection.request(
                "POST",
                "/system/release-usb-printers",
                body="{}",
                headers={"Content-Type": "application/json"},
            )
            response = connection.getresponse()
            body = json.loads(response.read())
            connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertTrue(body["released"])
        self.assertEqual(body["command"], "killall -USR1 cupsd")
        release_mock.assert_called_once_with()

    def test_configure_print_station_accepts_print_system_enabled(self) -> None:
        payload = json.dumps(
            {
                "print_system_enabled": False,
                "restaurant_id": "rest-1",
                "device_name": "test-device",
            }
        )
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request(
            "POST",
            "/configure/print-station",
            body=payload,
            headers={"Content-Type": "application/json"},
        )
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertIn("queue", body)
        with open(self._temp_env_path, "r", encoding="utf-8") as env_file:
            env_contents = env_file.read()
        self.assertIn("PRINT_SYSTEM_ENABLED=False", env_contents)

    def test_print_endpoint_accepts_document_and_printer_id(self) -> None:
        payload = json.dumps(
            {
                "printer_id": "windows:USB POS-80",
                "job_name": "manual-check",
                "document": {
                    "lines": [
                        {"type": "text", "value": "Masa 8", "align": "center", "bold": True},
                        {"type": "separator"},
                        {"type": "text", "value": "Corba x1"},
                    ]
                },
            }
        )
        headers = {"Content-Type": "application/json"}

        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("POST", "/print", body=payload, headers=headers)
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(body["render_mode"], "document")
        self.assertEqual(body["printer"]["id"], "windows:USB POS-80")
        self.assertEqual(self.transport.calls[-1][1], "manual-check")
        self.assertIsNotNone(self.transport.calls[-1][2])

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

    def test_health_includes_operator_fields(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/health")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertIn("bridge_version", body)
        self.assertIn("service_mode", body)
        self.assertIn("autostart_enabled", body)
        self.assertIn("default_queue", body)
        self.assertEqual(body["default_queue"], body["printer_queue"])

    def test_health_includes_bundled_font_status(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/health")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 200)
        bundled = body.get("bundled_font")
        self.assertIsInstance(bundled, dict)
        self.assertIn("regular", bundled)
        self.assertIn("bold", bundled)
        self.assertTrue(bundled.get("regular_exists") is True)
        self.assertTrue(bundled.get("bold_exists") is True)

    def test_resolve_render_mode_maps_escpos_text_to_text(self) -> None:
        handler = PrintBridgeHandler.__new__(PrintBridgeHandler)
        resolved = handler._resolve_render_mode(
            {"test_mode": "escpos_text", "render_mode": "image"}
        )
        self.assertEqual(resolved, "text")

    def test_spool_snapshot_requires_printer_name(self) -> None:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/spool/snapshot")
        response = connection.getresponse()
        body = json.loads(response.read())
        connection.close()

        self.assertEqual(response.status, 400)
        self.assertEqual(body["errorCode"], "printer_name_required")

    def test_spool_snapshot_returns_windows_job_snapshot(self) -> None:
        with mock.patch(
            "local_print_bridge.windows_transport.peek_windows_spool_jobs",
            return_value={
                "ok": True,
                "printer_name": "POS-58",
                "job_count": 1,
                "active_job_ids": [7],
                "latest_job_id": 7,
            },
        ):
            connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
            connection.request("GET", "/spool/snapshot?printer_name=POS-58")
            response = connection.getresponse()
            body = json.loads(response.read())
            connection.close()

        self.assertEqual(response.status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(body["printer_name"], "POS-58")
        self.assertEqual(body["latest_job_id"], 7)


if __name__ == "__main__":
    unittest.main()
