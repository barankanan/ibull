import threading
import time
import unittest
from unittest import mock

from local_print_bridge import server


class HealthLanAddressCacheTest(unittest.TestCase):
    def setUp(self) -> None:
        server._LAN_ADDRESS_CACHE = None
        server._LAN_ADDRESS_REFRESHING = False

    def test_health_path_never_waits_for_a_slow_lookup(self) -> None:
        release = threading.Event()
        calls: list[int] = []

        def slow_lookup() -> list[str]:
            calls.append(1)
            release.wait(5)
            return ["192.168.1.20"]

        with mock.patch.object(server, "_local_ipv4_addresses", slow_lookup):
            started = time.monotonic()
            first = server._cached_lan_addresses()
            second = server._cached_lan_addresses()
            elapsed = time.monotonic() - started
            self.assertEqual(first, [])
            self.assertEqual(second, [])
            self.assertLess(elapsed, 0.5, "the request path must not block")
            release.set()
            for _ in range(50):
                if server._cached_lan_addresses():
                    break
                time.sleep(0.02)
            self.assertEqual(server._cached_lan_addresses(), ["192.168.1.20"])
            self.assertEqual(len(calls), 1, "one lookup at a time")

    def test_known_addresses_are_kept_while_a_refresh_hangs(self) -> None:
        server._LAN_ADDRESS_CACHE = (time.monotonic() - 999, ["10.0.0.5"])
        hang = threading.Event()
        with mock.patch.object(server, "_local_ipv4_addresses", lambda: (hang.wait(5), [])[1]):
            self.assertEqual(server._cached_lan_addresses(), ["10.0.0.5"])
            self.assertEqual(server._cached_lan_addresses(), ["10.0.0.5"])
            hang.set()


if __name__ == "__main__":
    unittest.main()
