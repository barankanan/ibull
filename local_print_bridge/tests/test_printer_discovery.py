from __future__ import annotations

import json
import subprocess
import unittest
from unittest import mock

from local_print_bridge.printers import dedupe_printers, discover_windows_printers


class PrinterDiscoveryTests(unittest.TestCase):
    def test_dedupe_printers_removes_duplicate_ids(self) -> None:
        records = [
            {"id": "a", "name": "A"},
            {"id": "a", "name": "A2"},
            {"id": "b", "name": "B"},
            {"id": "", "name": "ignored"},
            {},
        ]
        unique = dedupe_printers(records)
        self.assertEqual([r["id"] for r in unique], ["a", "b"])

    @mock.patch("local_print_bridge.printers.platform.system", return_value="Windows")
    @mock.patch("local_print_bridge.printers.subprocess.run")
    def test_discover_windows_printers_parses_powershell_json(self, run_mock, _system_mock) -> None:
        payload = {
            "spool": [
                {
                    "Name": "USB POS-80",
                    "PortName": "USB001",
                    "DriverName": "Generic / Text Only",
                    "PrinterStatus": "3",
                    "WorkOffline": False,
                    "Default": True,
                    "DeviceID": "USB POS-80",
                    "Availability": "3",
                    "ExtendedPrinterStatus": "2",
                    "DetectedErrorState": "0",
                }
            ],
            "pnp": [
                {
                    "Name": "USB POS-80",
                    "PNPDeviceID": r"USB\\VID_0416&PID_5011\\123",
                }
            ],
        }
        run_mock.return_value = subprocess.CompletedProcess(
            args=["powershell"],
            returncode=0,
            stdout=json.dumps(payload),
            stderr="",
        )

        printers = discover_windows_printers()
        self.assertEqual(len(printers), 1)
        self.assertEqual(printers[0]["backend"], "windows-spool")
        self.assertEqual(printers[0]["queue"], "USB POS-80")
        self.assertEqual(printers[0]["vendorId"], "0x0416")
        self.assertEqual(printers[0]["productId"], "0x5011")
        self.assertTrue(printers[0]["isDefault"])


if __name__ == "__main__":
    unittest.main()

