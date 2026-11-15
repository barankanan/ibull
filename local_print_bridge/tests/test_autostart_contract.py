import unittest

from local_print_bridge.server import (
    _autostart_state,
    _macos_launch_agent_plist,
)


class AutostartContractTests(unittest.TestCase):
    def test_macos_plist_logs_under_application_support_and_restarts(self) -> None:
        plist = _macos_launch_agent_plist("/usr/bin/python3", "/tmp/ibul")
        self.assertIn("RunAtLoad", plist)
        self.assertIn("<key>KeepAlive</key>", plist)
        self.assertIn("<key>SuccessfulExit</key>", plist)
        self.assertIn("local_print_bridge.service_host", plist)
        self.assertIn("Application Support/IbulPrintBridge/logs/bridge.log", plist)
        self.assertNotIn("/tmp/ibul-local-print.log", plist)
        self.assertNotIn("<true/>\n  <key>ThrottleInterval</key>", plist)

    def test_windows_run_key_is_not_reported_as_a_service(self) -> None:
        state = _autostart_state("windows")
        self.assertFalse(state["is_windows_service"])
        self.assertFalse(state["requires_admin"])
        self.assertEqual(state["crash_restart"], "user_supervisor")
        self.assertIn(state["mode"], {"run_key", "startup_script"})


if __name__ == "__main__":
    unittest.main()
