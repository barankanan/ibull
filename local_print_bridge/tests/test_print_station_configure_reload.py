"""The print-system switch must reach the live print handlers at once."""
from __future__ import annotations

import unittest
from unittest import mock

from local_print_bridge import server


class _Stub:
    _PRINT_STATION_FIELD_MAP = server.PrintBridgeHandler._PRINT_STATION_FIELD_MAP
    client_address = ("127.0.0.1", 50000)
    print_station_consumer = None

    def __init__(self, body):
        self._body = body
        self.sent = None

    def _read_json_body(self):
        return self._body

    def _send_json(self, status, payload):
        self.sent = (status, payload)

    def _queue_status_payload(self):
        return {}


class ConfigureReloadTest(unittest.TestCase):
    def test_switch_reloads_handler_settings(self):
        stub = _Stub({"print_system_enabled": False})
        sentinel = object()
        with mock.patch.object(server, "write_env_file") as write, \
                mock.patch.object(server.BridgeSettings, "from_env", return_value=sentinel), \
                mock.patch.object(server, "_reload_handlers") as reload_handlers:
            server.PrintBridgeHandler._handle_configure_print_station(stub)
        write.assert_called_once()
        reload_handlers.assert_called_once_with(sentinel)
        self.assertTrue(stub.sent[1]["ok"])

    def test_unknown_fields_change_nothing(self):
        stub = _Stub({"not_a_field": 1})
        with mock.patch.object(server, "write_env_file") as write, \
                mock.patch.object(server, "_reload_handlers") as reload_handlers:
            server.PrintBridgeHandler._handle_configure_print_station(stub)
        write.assert_not_called()
        reload_handlers.assert_not_called()
        self.assertFalse(stub.sent[1]["ok"])


if __name__ == "__main__":
    unittest.main()
