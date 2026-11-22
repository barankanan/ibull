"""A scan the OS refused to run must not read as "no printer on the network"."""
import errno
import unittest

from local_print_bridge.network_scan import (
    scan_local_network_printers,
    scan_no_device_reason,
)


def _refuse_with(code):
    def connect(address, timeout):
        raise OSError(code, "refused")

    return connect


class BlockedScanTest(unittest.TestCase):
    def test_every_probe_unreachable_is_reported_as_blocked(self):
        result = scan_local_network_printers(
            ["192.168.10.158"],
            connect_fn=_refuse_with(errno.EHOSTUNREACH),
            verify=False,
        )
        self.assertEqual(result["devices"], [])
        self.assertGreater(result["probe_blocked_count"], 200)
        reason = scan_no_device_reason(
            devices=[],
            probe_blocked_count=result["probe_blocked_count"],
            probe_closed_count=result["probe_closed_count"],
        )
        self.assertEqual(reason, "local_network_blocked")

    def test_closed_ports_stay_a_plain_no_printer_result(self):
        result = scan_local_network_printers(
            ["192.168.10.158"],
            connect_fn=_refuse_with(errno.ECONNREFUSED),
            verify=False,
        )
        self.assertEqual(result["probe_blocked_count"], 0)
        reason = scan_no_device_reason(
            devices=[],
            probe_blocked_count=result["probe_blocked_count"],
            probe_closed_count=result["probe_closed_count"],
        )
        self.assertEqual(reason, "no_open_port_on_scanned_subnets")


if __name__ == "__main__":
    unittest.main()
