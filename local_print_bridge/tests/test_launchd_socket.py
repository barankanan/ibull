import socket
import sys
import unittest

from local_print_bridge import launchd_socket


class _FakeLibc:
    def __init__(self, rc: int) -> None:
        self.rc = rc
        self.calls = 0

    def launch_activate_socket(self, name, fds, count):  # noqa: ANN001
        self.calls += 1
        return self.rc


class LaunchdSocketTests(unittest.TestCase):
    def test_no_name_means_normal_bind(self) -> None:
        fake = _FakeLibc(0)
        self.assertIsNone(launchd_socket.activated_socket("", libc=fake))
        self.assertEqual(fake.calls, 0)
        self.assertEqual(launchd_socket.requested_name({}), "")

    def test_name_comes_from_environment(self) -> None:
        self.assertEqual(
            launchd_socket.requested_name({launchd_socket.ENV_NAME: " Listeners "}),
            "Listeners",
        )

    @unittest.skipUnless(sys.platform == "darwin", "launchd is macOS only")
    def test_not_started_by_launchd_falls_back(self) -> None:
        # Outside launchd the call fails (ESRCH); the bridge then binds itself.
        self.assertIsNone(launchd_socket.activated_socket("Listeners"))
        self.assertIsNone(
            launchd_socket.activated_socket("Listeners", libc=_FakeLibc(3))
        )

    def test_other_platforms_never_ask_launchd(self) -> None:
        fake = _FakeLibc(0)
        original = sys.platform
        try:
            sys.platform = "win32"
            self.assertIsNone(launchd_socket.activated_socket("Listeners", libc=fake))
        finally:
            sys.platform = original
        self.assertEqual(fake.calls, 0)

    def test_plain_server_still_binds(self) -> None:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            self.assertGreater(probe.getsockname()[1], 0)


if __name__ == "__main__":
    unittest.main()
