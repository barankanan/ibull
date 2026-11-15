"""Stored station platform must not override the machine that is running."""
from __future__ import annotations

import unittest

from local_print_bridge.print_station import reported_device_platform
from local_print_bridge.printer_identity import match_saved_printer


class DevicePlatformTests(unittest.TestCase):
    def test_stored_windows_label_does_not_replace_this_host(self) -> None:
        report = reported_device_platform("windows")
        self.assertIn(report["devicePlatform"], {"macos", "windows", "linux"})
        self.assertEqual(report["configuredDevicePlatform"], "windows")
        if report["devicePlatform"] != "windows":
            self.assertFalse(report["platformMatchesHost"])

    def test_open_tcp_port_is_not_a_saved_printer_match(self) -> None:
        self.assertEqual(
            match_saved_printer(
                {"host": "192.168.1.100", "port": 9100},
                {"host": "192.168.10.100", "port": 9100, "port_open": True},
            ),
            "no_match",
        )


if __name__ == "__main__":
    unittest.main()
