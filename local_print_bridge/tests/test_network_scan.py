"""Tests for local subnet printer discovery."""
from __future__ import annotations

import unittest
from contextlib import contextmanager

from local_print_bridge.network_scan import (
    ipv4_subnet_cidr,
    scan_local_network_printers,
    scan_no_device_reason,
    scan_subnet_for_port,
    suggest_ethernet_network_settings,
    unique_scan_subnets,
)


class _FakeSocket:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port

    def __enter__(self) -> "_FakeSocket":
        return self

    def __exit__(self, *_args: object) -> None:
        return None


class NetworkScanTests(unittest.TestCase):
    def test_ipv4_subnet_cidr_returns_slash_24(self) -> None:
        self.assertEqual(ipv4_subnet_cidr("192.168.10.158"), "192.168.10.0/24")

    def test_unique_scan_subnets_deduplicates(self) -> None:
        subnets = unique_scan_subnets(
            ["192.168.10.158", "192.168.10.20", "10.0.0.5"],
        )
        self.assertEqual(subnets, ["192.168.10.0/24", "10.0.0.0/24"])

    def test_scan_subnet_for_port_finds_mocked_hosts(self) -> None:
        open_hosts = {"192.168.10.100", "192.168.10.120"}

        @contextmanager
        def fake_connect(address: tuple[str, int], timeout: float):
            host, _port = address
            if host in open_hosts:
                yield _FakeSocket(host, _port)
            else:
                raise OSError("refused")

        found = scan_subnet_for_port(
            "192.168.10.0/24",
            9100,
            timeout=0.1,
            max_workers=32,
            connect_fn=fake_connect,
            skip_hosts={"192.168.10.158"},
        )
        hosts = [item["host"] for item in found]
        self.assertEqual(hosts, ["192.168.10.100", "192.168.10.120"])

    def test_scan_local_network_printers_aggregates(self) -> None:
        @contextmanager
        def fake_connect(address: tuple[str, int], timeout: float):
            host, port = address
            if host == "192.168.10.55" and port == 9100:
                yield _FakeSocket(host, port)
            else:
                raise OSError("refused")

        result = scan_local_network_printers(
            ["192.168.10.158"],
            port=9100,
            timeout=0.1,
            connect_fn=fake_connect,
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["subnets"], ["192.168.10.0/24"])
        self.assertEqual(len(result["devices"]), 1)
        self.assertEqual(result["devices"][0]["host"], "192.168.10.55")

    def test_suggest_ethernet_network_settings_from_local_ip(self) -> None:
        settings = suggest_ethernet_network_settings(
            ["192.168.10.158"],
            printer_host="192.168.1.100",
        )
        self.assertEqual(settings["suggested_printer_ip"], "192.168.10.100")
        self.assertEqual(settings["suggested_target_subnet"], "192.168.10.0/24")
        self.assertEqual(settings["network_state"], "network_mismatch")

    def test_scan_no_device_reason_flags_cross_subnet_manual_ip(self) -> None:
        reason = scan_no_device_reason(
            devices=[],
            printer_host="192.168.1.100",
            local_ips=["192.168.10.158"],
        )
        self.assertEqual(reason, "printer_on_different_subnet")


if __name__ == "__main__":
    unittest.main()
