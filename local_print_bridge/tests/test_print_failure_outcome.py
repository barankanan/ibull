"""A failed send is either "certainly not sent" or "outcome unknown"."""

from __future__ import annotations

import unittest

from local_print_bridge import server as bridge_server
from local_print_bridge.network_transport import (
    PHASE_CONNECT,
    PHASE_WRITE,
    TcpTransportError,
)
from local_print_bridge.transport import TransportError


def _tcp_error(phase: str | None) -> TcpTransportError:
    error = TcpTransportError("tcp_failed", "boom")
    error.phase = phase
    return error


class PrintFailureOutcomeTests(unittest.TestCase):
    def setUp(self) -> None:
        with bridge_server._HTTP_PRINT_IDEM_LOCK:
            bridge_server._HTTP_PRINT_RECENT_JOBS.clear()
            bridge_server._HTTP_PRINT_UNCERTAIN_KEYS.clear()

    def test_connect_failure_is_safe_to_send_again(self) -> None:
        outcome = bridge_server.print_failure_outcome(_tcp_error(PHASE_CONNECT))
        self.assertTrue(outcome["retry_safe"])
        self.assertFalse(outcome["write_may_have_started"])
        self.assertEqual(outcome["print_outcome"], "not_sent")

    def test_write_failure_is_uncertain(self) -> None:
        outcome = bridge_server.print_failure_outcome(_tcp_error(PHASE_WRITE))
        self.assertFalse(outcome["retry_safe"])
        self.assertTrue(outcome["write_may_have_started"])
        self.assertEqual(outcome["print_outcome"], "uncertain")

    def test_unknown_phase_is_never_called_safe(self) -> None:
        for exc in (_tcp_error(None), TransportError("usb write failed"), RuntimeError("x")):
            outcome = bridge_server.print_failure_outcome(exc)
            self.assertFalse(outcome["retry_safe"], exc)
            self.assertEqual(outcome["print_outcome"], "uncertain")

    def test_ticket_that_never_reached_the_printer_prints_on_the_next_attempt(self) -> None:
        keys = ["logical:order-1|rev-1|ocak", "job:job-1"]
        bridge_server._http_print_record_keys(keys)
        self.assertTrue(bridge_server._http_print_any_processed(keys))
        # connect-phase failure: the keys are dropped
        bridge_server._http_print_forget_keys(keys)
        self.assertFalse(bridge_server._http_print_any_processed(keys))
        self.assertFalse(bridge_server._http_print_any_uncertain(keys))

    def test_uncertain_ticket_is_held_and_never_reported_as_printed(self) -> None:
        keys = ["logical:order-1|rev-1|ocak"]
        bridge_server._http_print_record_keys(keys)
        bridge_server._http_print_mark_uncertain(keys)
        self.assertTrue(bridge_server._http_print_any_uncertain(keys))
        # still recorded: nothing prints a second copy by itself
        self.assertTrue(bridge_server._http_print_any_processed(keys))

    def test_another_station_of_the_same_order_is_not_affected(self) -> None:
        bridge_server._http_print_record_keys(["logical:order-1|rev-1|ocak"])
        bridge_server._http_print_mark_uncertain(["logical:order-1|rev-1|ocak"])
        other = ["logical:order-1|rev-1|firin"]
        self.assertFalse(bridge_server._http_print_any_uncertain(other))
        self.assertFalse(bridge_server._http_print_any_processed(other))

    def test_operator_confirmed_retry_clears_the_hold(self) -> None:
        keys = ["logical:order-1|rev-1|ocak"]
        bridge_server._http_print_record_keys(keys)
        bridge_server._http_print_mark_uncertain(keys)
        bridge_server._http_print_forget_keys(keys)
        self.assertFalse(bridge_server._http_print_any_uncertain(keys))
        self.assertFalse(bridge_server._http_print_any_processed(keys))

    def test_uncertain_mark_expires_with_the_recent_key(self) -> None:
        keys = ["logical:order-9|rev-1|ocak"]
        bridge_server._http_print_record_keys(keys)
        bridge_server._http_print_mark_uncertain(keys)
        with bridge_server._HTTP_PRINT_IDEM_LOCK:
            bridge_server._HTTP_PRINT_RECENT_JOBS.clear()
        self.assertFalse(bridge_server._http_print_any_uncertain(keys))


class NetworkTransportPhaseTests(unittest.TestCase):
    """The transport the real kitchen path uses must tag the failure phase."""

    def test_connect_failure_is_tagged_connect(self) -> None:
        import socket as _socket

        from local_print_bridge.network_transport import NetworkTcpTransport

        probe = _socket.socket()
        probe.bind(("127.0.0.1", 0))
        dead_port = probe.getsockname()[1]
        probe.close()  # nothing listens here
        transport = NetworkTcpTransport("127.0.0.1", dead_port, timeout=0.5)
        with self.assertRaises(TcpTransportError) as ctx:
            transport.print_bytes(b"ticket", job_name="t")
        self.assertEqual(ctx.exception.phase, PHASE_CONNECT)
        self.assertTrue(bridge_server.print_failure_outcome(ctx.exception)["retry_safe"])

    def test_write_failure_is_tagged_write_and_is_not_transient(self) -> None:
        from unittest.mock import patch

        from local_print_bridge import network_transport as nt
        from local_print_bridge.network_transport import (
            NetworkTcpTransport,
            write_may_have_started,
        )

        class _Sock:
            def settimeout(self, _):
                pass

            def send(self, _):
                raise ConnectionResetError("connection reset by peer")

            def close(self):
                pass

        transport = NetworkTcpTransport("192.0.2.10", 9100, timeout=0.5)
        with patch.object(nt.socket, "create_connection", return_value=_Sock()):
            with self.assertRaises(TcpTransportError) as ctx:
                transport.print_bytes(b"ticket", job_name="t")
        self.assertEqual(ctx.exception.phase, PHASE_WRITE)
        self.assertTrue(write_may_have_started(ctx.exception))
        self.assertFalse(bridge_server.print_failure_outcome(ctx.exception)["retry_safe"])
        # "connection reset" used to look transient: the bridge resent the
        # ticket by itself. With the phase tagged it never does.
        handler = object.__new__(bridge_server.PrintBridgeHandler)
        self.assertFalse(handler._is_transient_transport_error(ctx.exception))


if __name__ == "__main__":
    unittest.main()
