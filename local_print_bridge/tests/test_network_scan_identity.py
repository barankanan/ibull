"""An open TCP port is never proof of a printer. Fake sockets only: nothing
here touches a real network or a real printer."""
from __future__ import annotations

import unittest
from contextlib import contextmanager

from local_print_bridge.network_scan import (
    ESC_POS_STATUS_QUERY,
    scan_local_network_printers,
    verify_escpos_status,
)


class _Device:
    """A fake TCP endpoint that records every byte sent to it."""

    def __init__(self, reply: bytes | None, *, raises: bool = False) -> None:
        self.reply = reply
        self.raises = raises
        self.sent: list[bytes] = []

    def settimeout(self, _value: float) -> None:
        return None

    def sendall(self, data: bytes) -> None:
        self.sent.append(data)

    def recv(self, _size: int) -> bytes:
        if self.raises:
            raise TimeoutError("no reply")
        return self.reply or b""


def _network(devices: dict[str, _Device], calls: list[str] | None = None):
    @contextmanager
    def connect(address: tuple[str, int], _timeout: float):
        host, port = address
        if calls is not None:
            calls.append(host)
        device = devices.get(host)
        if device is None or port != 9100:
            raise OSError("refused")
        yield device

    return connect


class EthernetDiscoveryIdentityTests(unittest.TestCase):
    def test_a_printer_that_answers_the_status_request_is_verified(self) -> None:
        printer = _Device(b"\x12")
        result = verify_escpos_status(
            "192.168.10.55", 9100, connect_fn=_network({"192.168.10.55": printer})
        )
        self.assertTrue(result["verified"])
        # Only the read-only status request was sent. No print data.
        self.assertEqual(printer.sent, [ESC_POS_STATUS_QUERY])

    def test_an_open_port_that_stays_silent_is_not_a_printer(self) -> None:
        silent = _Device(None, raises=True)
        result = verify_escpos_status(
            "192.168.10.60", 9100, connect_fn=_network({"192.168.10.60": silent})
        )
        self.assertFalse(result["verified"])
        self.assertEqual(result["reason"], "no_status_reply")

    def test_another_service_on_the_port_is_not_a_printer(self) -> None:
        web = _Device(b"HTTP/1.1 400 Bad Request")
        result = verify_escpos_status(
            "192.168.10.70", 9100, connect_fn=_network({"192.168.10.70": web})
        )
        self.assertFalse(result["verified"])
        self.assertEqual(result["reason"], "unexpected_reply")

    def test_public_and_loopback_addresses_are_never_contacted(self) -> None:
        calls: list[str] = []
        connect = _network({}, calls)
        for host in ("8.8.8.8", "127.0.0.1", "0.0.0.0", "not-an-ip"):
            result = verify_escpos_status(host, 9100, connect_fn=connect)
            self.assertFalse(result["verified"], host)
            self.assertEqual(result["reason"], "not_local_address", host)
        self.assertEqual(calls, [])

    def test_scan_lists_verified_and_unverified_separately(self) -> None:
        printer = _Device(b"\x12")
        silent = _Device(None, raises=True)
        web = _Device(b"HTTP/1.1 200 OK")
        result = scan_local_network_printers(
            ["192.168.10.158"],
            port=9100,
            timeout=0.1,
            budget_s=1.0,
            connect_fn=_network(
                {
                    "192.168.10.55": printer,
                    "192.168.10.60": silent,
                    "192.168.10.70": web,
                }
            ),
        )
        self.assertTrue(result["ok"])
        by_host = {device["host"]: device for device in result["devices"]}
        self.assertEqual(set(by_host), {"192.168.10.55", "192.168.10.60", "192.168.10.70"})
        self.assertTrue(by_host["192.168.10.55"]["printer_verified"])
        self.assertEqual(by_host["192.168.10.55"]["kind"], "escpos_printer")
        for host in ("192.168.10.60", "192.168.10.70"):
            self.assertFalse(by_host[host]["printer_verified"], host)
            self.assertEqual(by_host[host]["kind"], "unverified_tcp_service", host)
        self.assertEqual(result["verified_count"], 1)
        self.assertEqual(result["unverified_count"], 2)
        # No scan hit may ever start printing by itself.
        self.assertTrue(all(device["auto_print"] is False for device in result["devices"]))
        # Silent and web devices received only the status request.
        for device in (silent, web):
            self.assertEqual(device.sent, [ESC_POS_STATUS_QUERY])


if __name__ == "__main__":
    unittest.main()
