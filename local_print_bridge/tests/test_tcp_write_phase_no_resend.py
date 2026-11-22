"""A print whose bytes may already be on the printer is never resent blindly."""
import socket
import unittest
from unittest.mock import patch

from local_print_bridge import network_transport as nt
from local_print_bridge.print_station import PrintStationConsumer
from local_print_bridge.queue_manager import PrintQueueManager
from local_print_bridge.server import PrintBridgeHandler


class _Sock:
    def __init__(self, fail_write):
        self._fail_write = fail_write

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def settimeout(self, _):
        pass

    def sendall(self, _):
        if self._fail_write:
            raise socket.timeout("timed out")


def _send_fn():
    return nt.print_tcp


class TcpPhaseTests(unittest.TestCase):
    def test_connect_timeout_is_marked_connect_and_may_retry(self):
        with patch.object(
            nt.socket, "create_connection", side_effect=socket.timeout("timed out")
        ):
            with self.assertRaises(nt.TcpTransportError) as ctx:
                _send_fn()("192.0.2.1", 9100, b"abc", timeout=0.1)
        self.assertEqual(ctx.exception.phase, nt.PHASE_CONNECT)
        self.assertFalse(nt.write_may_have_started(ctx.exception))
        for cls in (PrintBridgeHandler, PrintStationConsumer):
            self.assertTrue(
                cls._is_transient_transport_error(object.__new__(cls), ctx.exception)
            )

    def test_write_timeout_is_marked_write_and_never_retries(self):
        with patch.object(
            nt.socket, "create_connection", return_value=_Sock(fail_write=True)
        ):
            with self.assertRaises(nt.TcpTransportError) as ctx:
                _send_fn()("192.0.2.1", 9100, b"abc", timeout=0.1)
        self.assertEqual(ctx.exception.phase, nt.PHASE_WRITE)
        self.assertTrue(nt.write_may_have_started(ctx.exception))
        for cls in (PrintBridgeHandler, PrintStationConsumer):
            self.assertFalse(
                cls._is_transient_transport_error(object.__new__(cls), ctx.exception)
            )

    def test_queue_sends_once_when_write_phase_failed(self):
        calls = []
        err = nt.TcpTransportError("tcp_timeout", "TCP zaman aşımı")
        err.phase = nt.PHASE_WRITE

        def execute():
            calls.append(1)
            raise err

        app = object.__new__(PrintBridgeHandler)
        manager = PrintQueueManager()
        with self.assertRaises(Exception):
            manager.run_job(
                printer_key="p",
                printer_name="p",
                transport_type="ethernet",
                document_type="test",
                job_name="t",
                execute=execute,
                is_transient_error=app._is_transient_transport_error,
                max_retries=1,
            )
        self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
