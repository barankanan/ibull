import unittest

from local_print_bridge.lan_pairing import lan_bridge_decision


class LanBridgeDecisionTests(unittest.TestCase):
    def test_loopback_keeps_the_working_print_path(self) -> None:
        self.assertEqual(
            lan_bridge_decision("/print/kitchen", loopback=True),
            "allow",
        )
        self.assertEqual(
            lan_bridge_decision("/configure", loopback=True),
            "allow",
        )

    def test_lan_cannot_open_admin_or_print_routes(self) -> None:
        self.assertEqual(
            lan_bridge_decision(
                "/configure",
                loopback=False,
                authorization="Bearer paired-token",
            ),
            "admin_forbidden",
        )
        self.assertEqual(
            lan_bridge_decision("/print/kitchen", loopback=False),
            "loopback_only",
        )
        self.assertEqual(
            lan_bridge_decision("/setup/install", loopback=False),
            "admin_forbidden",
        )
