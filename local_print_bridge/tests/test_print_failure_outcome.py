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


if __name__ == "__main__":
    unittest.main()
