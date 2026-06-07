"""Tests for the Ethernet / TCP transport.

Covers the surface area the operator-facing UI depends on:

    * ``NetworkTcpTransport.print_bytes`` actually streams bytes through a
      real ``socket`` connection.
    * Friendly :class:`TcpTransportError` codes for timeout, refused, and
      unreachable conditions.
    * ``_SmartTransport`` routes ``backend=tcp`` / ``transportType=ethernet``
      payloads straight to :class:`NetworkTcpTransport`, never CUPS/USB.
    * Missing host raises ``tcp_host_missing`` instead of falling back to a
      different transport (defensive guard for the wizard).

The TCP path is fully exercised with an in-process ``socket`` listener; the
smart-router branch is exercised with patches so we don't actually open a
socket when the smoke test only cares about the routing decision.
"""

from __future__ import annotations

import errno
import socket
import threading
import time
import unittest
from unittest.mock import patch

from local_print_bridge.config import BridgeSettings
from local_print_bridge.network_transport import (
    DEFAULT_TCP_PORT,
    NetworkTcpTransport,
    TcpTransportError,
    print_tcp,
)
from local_print_bridge.server import _SmartTransport
from local_print_bridge.transport import TransportError


def _make_settings(transport_mode: str = "auto") -> BridgeSettings:
    return BridgeSettings(
        host="127.0.0.1",
        port=3001,
        printer_queue="POS-58",
        paper_width_mm=80,
        chars_per_line=32,
        encoding="cp857",
        codepage=13,
        render_mode="image",
        raster_chunk_height=128,
        allowed_origins=("http://localhost",),
        healthcheck_queue=False,
        print_system_enabled=True,
        cut_mode="partial",
        transport_mode=transport_mode,
        usb_vendor_id=None,
        usb_product_id=None,
        network_host="",
        network_port=DEFAULT_TCP_PORT,
    )


class _RecordingTcpServer:
    """In-process TCP echo / capture server used to exercise the real path."""

    def __init__(self) -> None:
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._sock.bind(("127.0.0.1", 0))
        self._sock.listen(1)
        self.host, self.port = self._sock.getsockname()
        self.received: bytearray = bytearray()
        self._thread = threading.Thread(target=self._serve, daemon=True)

    def __enter__(self) -> "_RecordingTcpServer":
        self._thread.start()
        return self

    def __exit__(self, *_exc: object) -> None:
        try:
            self._sock.close()
        except OSError:
            pass

    def _serve(self) -> None:
        try:
            conn, _addr = self._sock.accept()
        except OSError:
            return
        with conn:
            conn.settimeout(2.0)
            try:
                while True:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    self.received.extend(chunk)
            except OSError:
                pass


class NetworkTcpTransportTests(unittest.TestCase):
    def test_print_bytes_sends_payload_over_socket(self) -> None:
        with _RecordingTcpServer() as server:
            transport = NetworkTcpTransport(host=server.host, port=server.port)
            result = transport.print_bytes(b"ETHERNET TEST\n", job_name="eth-test")
            time.sleep(0.05)
        self.assertEqual(bytes(server.received), b"ETHERNET TEST\n")
        self.assertEqual(result.bytes_sent, len(b"ETHERNET TEST\n"))
        self.assertEqual(result.metadata.get("actual_backend"), "tcp")
        self.assertEqual(result.metadata.get("actual_host"), server.host)
        self.assertEqual(result.metadata.get("actual_port"), server.port)
        self.assertEqual(result.metadata.get("actual_queue"), "")
        self.assertEqual(result.metadata.get("target_port"), server.port)

    def test_print_tcp_helper_round_trips_data(self) -> None:
        with _RecordingTcpServer() as server:
            sent = print_tcp(server.host, server.port, b"HI\n", timeout=2.0)
            time.sleep(0.05)
        self.assertEqual(sent, 3)
        self.assertEqual(bytes(server.received), b"HI\n")

    def test_missing_host_raises_tcp_host_missing(self) -> None:
        with self.assertRaises(TcpTransportError) as ctx:
            NetworkTcpTransport(host="   ", port=9100)
        self.assertEqual(ctx.exception.code, "tcp_host_missing")

    def test_invalid_port_raises_tcp_port_invalid(self) -> None:
        with self.assertRaises(TcpTransportError) as ctx:
            NetworkTcpTransport(host="127.0.0.1", port=70000)
        self.assertEqual(ctx.exception.code, "tcp_port_invalid")

    def test_timeout_yields_friendly_error(self) -> None:
        transport = NetworkTcpTransport(
            host="127.0.0.1",
            # 1 is reserved; nothing listens there so connect will fail quickly.
            port=1,
            timeout=0.5,
        )

        def _raise_timeout(*_args: object, **_kwargs: object):
            raise socket.timeout("timed out")

        with patch("local_print_bridge.network_transport.socket.create_connection", side_effect=_raise_timeout):
            with self.assertRaises(TcpTransportError) as ctx:
                transport.print_bytes(b"hello", job_name="t-test")
        self.assertEqual(ctx.exception.code, "tcp_timeout")

    def test_connection_refused_yields_friendly_error(self) -> None:
        transport = NetworkTcpTransport(host="127.0.0.1", port=1, timeout=0.5)
        err = OSError(errno.ECONNREFUSED, "connection refused")

        def _raise_refused(*_args: object, **_kwargs: object):
            raise err

        with patch("local_print_bridge.network_transport.socket.create_connection", side_effect=_raise_refused):
            with self.assertRaises(TcpTransportError) as ctx:
                transport.print_bytes(b"hello", job_name="t-test")
        self.assertEqual(ctx.exception.code, "tcp_refused")

    def test_unreachable_yields_friendly_error(self) -> None:
        transport = NetworkTcpTransport(host="10.255.255.1", port=9100, timeout=0.5)
        err = OSError(errno.EHOSTUNREACH, "host unreachable")

        def _raise_unreachable(*_args: object, **_kwargs: object):
            raise err

        with patch("local_print_bridge.network_transport.socket.create_connection", side_effect=_raise_unreachable):
            with self.assertRaises(TcpTransportError) as ctx:
                transport.print_bytes(b"hello", job_name="t-test")
        self.assertEqual(ctx.exception.code, "tcp_unreachable")


class SmartTransportTcpRoutingTests(unittest.TestCase):
    """``_SmartTransport`` must dispatch ``backend=tcp`` jobs over TCP only."""

    def test_backend_tcp_routes_to_network_tcp(self) -> None:
        smart = _SmartTransport(_make_settings("auto"))
        sent: dict[str, object] = {}

        class _FakeTcp:
            def __init__(self, host: str, port: int) -> None:
                sent["host"] = host
                sent["port"] = port

            def print_bytes(self, payload: bytes, *, job_name: str) -> object:
                sent["payload"] = bytes(payload)
                sent["job_name"] = job_name
                return "tcp_ok"

        with patch(
            "local_print_bridge.server.NetworkTcpTransport",
            _FakeTcp,
        ):
            result = smart.print_bytes(
                b"FISH",
                job_name="eth-test",
                selected_printer={
                    "id": "tcp:192.168.1.100:9100",
                    "backend": "tcp",
                    "transportType": "ethernet",
                    "host": "192.168.1.100",
                    "port": 9100,
                    "name": "NETUM ZJ-8360",
                },
            )
        self.assertEqual(result, "tcp_ok")
        self.assertEqual(sent["host"], "192.168.1.100")
        self.assertEqual(sent["port"], 9100)
        self.assertEqual(sent["payload"], b"FISH")

    def test_transport_ethernet_alias_routes_to_network_tcp(self) -> None:
        smart = _SmartTransport(_make_settings("auto"))
        seen: dict[str, object] = {}

        class _FakeTcp:
            def __init__(self, host: str, port: int) -> None:
                seen["host"] = host
                seen["port"] = port

            def print_bytes(self, payload: bytes, *, job_name: str) -> object:
                return "tcp_ok"

        with patch(
            "local_print_bridge.server.NetworkTcpTransport",
            _FakeTcp,
        ):
            smart.print_bytes(
                b"BYTES",
                job_name="eth-test",
                selected_printer={
                    "backend": "cups",  # backend mismatched on purpose
                    "transportType": "ethernet",
                    "host": "10.0.0.5",
                    "port": 9100,
                },
            )
        self.assertEqual(seen["host"], "10.0.0.5")
        self.assertEqual(seen["port"], 9100)

    def test_backend_tcp_without_host_raises_transport_error(self) -> None:
        smart = _SmartTransport(_make_settings("auto"))
        with self.assertRaises(TransportError):
            smart.print_bytes(
                b"x",
                job_name="eth-test",
                selected_printer={
                    "backend": "tcp",
                    "transportType": "ethernet",
                    "host": "",
                    "port": 9100,
                },
            )

    def test_per_request_target_host_uses_tcp_branch(self) -> None:
        smart = _SmartTransport(_make_settings("auto"))
        seen: dict[str, object] = {}

        class _FakeTcp:
            def __init__(self, host: str, port: int) -> None:
                seen["host"] = host
                seen["port"] = port

            def print_bytes(self, payload: bytes, *, job_name: str) -> object:
                return "tcp_ok"

        with patch(
            "local_print_bridge.server.NetworkTcpTransport",
            _FakeTcp,
        ):
            smart.print_bytes(
                b"X",
                job_name="eth-test",
                target_host="192.168.1.100",
                target_port=9100,
            )
        self.assertEqual(seen["host"], "192.168.1.100")
        self.assertEqual(seen["port"], 9100)


if __name__ == "__main__":  # pragma: no cover - convenience runner
    unittest.main()
