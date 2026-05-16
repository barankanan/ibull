from __future__ import annotations

import subprocess
import unittest
from unittest.mock import patch

from local_print_bridge.config import BridgeSettings
from local_print_bridge.transport import CupsRawTransport


class CupsRawTransportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=3001,
            printer_queue="Canon_E410_series",
            paper_width_mm=80,
            chars_per_line=48,
            encoding="cp857",
            codepage=13,
            render_mode="image",
            raster_chunk_height=256,
            allowed_origins=("http://localhost",),
            healthcheck_queue=False,
            print_system_enabled=True,
            cut_mode="partial",
            transport_mode="cups",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="",
            network_port=9100,
        )

    @patch("local_print_bridge.transport.subprocess.run")
    def test_discover_parses_localized_lpstat_output(self, run_mock):
        device_stdout = "Canon_E410_series için aygıt: usb://Canon/E410%20series?serial=B46F1C\n"
        queue_stdout = (
            "Canon_E410_series yazıcısı, Thu Jan 29 07:50:16 2026 tarihinden beri etkin değil -\n"
            "\tPaused\n"
        )

        def run_side_effect(args, capture_output, text, check, timeout):
            if args[1] == "-v":
                return subprocess.CompletedProcess(args, 0, stdout=device_stdout, stderr="")
            if args[1] == "-p":
                return subprocess.CompletedProcess(args, 0, stdout=queue_stdout, stderr="")
            return subprocess.CompletedProcess(args, 1, stdout="", stderr="")

        run_mock.side_effect = run_side_effect

        transport = CupsRawTransport(self.settings)
        printers = transport.discover()

        self.assertEqual(len(printers), 1)
        self.assertEqual(printers[0]["queue"], "Canon_E410_series")
        self.assertEqual(printers[0]["deviceUri"], "usb://Canon/E410%20series?serial=B46F1C")


if __name__ == "__main__":
    unittest.main()
