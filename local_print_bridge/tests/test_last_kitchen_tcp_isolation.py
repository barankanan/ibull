"""The "last kitchen printer" cache must belong to one bridge instance.

It used to be a file in the source tree. A bridge started from the same
checkout (an isolated test bridge next to the live one) then reused the live
printer's address for a request that carried no host."""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from local_print_bridge import server


class LastKitchenTcpIsolationTests(unittest.TestCase):
    def setUp(self) -> None:
        self._saved = (server._LAST_KITCHEN_TCP, server._LAST_KITCHEN_TCP_PATH)
        server._LAST_KITCHEN_TCP = None
        server._LAST_KITCHEN_TCP_PATH = None

    def tearDown(self) -> None:
        server._LAST_KITCHEN_TCP, server._LAST_KITCHEN_TCP_PATH = self._saved

    def test_each_data_dir_keeps_its_own_last_printer(self) -> None:
        with tempfile.TemporaryDirectory() as live, tempfile.TemporaryDirectory() as test:
            with mock.patch.dict(os.environ, {"PRINT_BRIDGE_DATA_DIR": live}):
                server._remember_last_kitchen_tcp("192.168.10.100", 9100)
                self.assertEqual(
                    server._load_last_kitchen_tcp(), ("192.168.10.100", 9100)
                )
                self.assertTrue((Path(live) / "last_kitchen_tcp").is_file())
            # Another bridge process: fresh memory, its own data directory.
            server._LAST_KITCHEN_TCP = None
            with mock.patch.dict(os.environ, {"PRINT_BRIDGE_DATA_DIR": test}):
                self.assertIsNone(server._load_last_kitchen_tcp())
                self.assertFalse((Path(test) / "last_kitchen_tcp").exists())

    def test_nothing_is_written_into_the_source_tree(self) -> None:
        source_file = Path(server.__file__).resolve().parent / ".last_kitchen_tcp"
        before = source_file.read_text() if source_file.exists() else None
        with tempfile.TemporaryDirectory() as data:
            with mock.patch.dict(os.environ, {"PRINT_BRIDGE_DATA_DIR": data}):
                server._remember_last_kitchen_tcp("192.168.10.77", 9100)
        after = source_file.read_text() if source_file.exists() else None
        self.assertEqual(before, after)

    def test_loopback_targets_are_never_remembered(self) -> None:
        with tempfile.TemporaryDirectory() as data:
            with mock.patch.dict(os.environ, {"PRINT_BRIDGE_DATA_DIR": data}):
                server._remember_last_kitchen_tcp("127.0.0.1", 9100)
                self.assertIsNone(server._load_last_kitchen_tcp())
                self.assertFalse((Path(data) / "last_kitchen_tcp").exists())


if __name__ == "__main__":
    unittest.main()
