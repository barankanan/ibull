"""Recovery policy: open port is not health, and uncertain jobs are not replayed."""
from __future__ import annotations

import unittest

from local_print_bridge.printer_identity import (
    UNREACHABLE_MESSAGE,
    annotate_discovery,
    is_local_scan_ipv4,
    match_saved_printer,
    may_rebind_address,
)
from local_print_bridge.process_guard import (
    classify_ps_stat,
    decide_recovery,
    http_health_ok,
)
from local_print_bridge.service_host import apply_decision


class ProcessGuardTests(unittest.TestCase):
    def test_stopped_stat_is_not_running(self) -> None:
        self.assertEqual(classify_ps_stat("T"), "stopped")
        self.assertEqual(classify_ps_stat("TN"), "stopped")
        self.assertEqual(classify_ps_stat("S"), "running")

    def test_open_port_without_health_does_not_count_as_healthy(self) -> None:
        decision = decide_recovery(
            health_ok=False,
            port_open=True,
            process_state="stopped",
        )
        self.assertEqual(decision["action"], "sigcont")
        self.assertFalse(decision["port_open_is_health"])
        self.assertFalse(decision["replay_uncertain_jobs"])
        self.assertFalse(decision["rewrite_job_status"])

    def test_health_response_wins_over_open_port(self) -> None:
        decision = decide_recovery(
            health_ok=True,
            port_open=True,
            process_state="running",
        )
        self.assertEqual(decision["action"], "healthy")
        self.assertFalse(decision["replay_uncertain_jobs"])

    def test_sigcont_failure_restarts_once_then_stops(self) -> None:
        restart = decide_recovery(
            health_ok=False,
            port_open=True,
            process_state="stopped",
            sigcont_attempted=True,
            restarts_in_window=0,
            seconds_since_restart=None,
        )
        self.assertEqual(restart["action"], "restart")
        blocked = decide_recovery(
            health_ok=False,
            port_open=True,
            process_state="stopped",
            sigcont_attempted=True,
            restarts_in_window=3,
            seconds_since_restart=30,
        )
        self.assertEqual(blocked["action"], "give_up")
        tight = decide_recovery(
            health_ok=False,
            port_open=True,
            process_state="running",
            restarts_in_window=1,
            seconds_since_restart=2,
        )
        self.assertEqual(tight["action"], "give_up")

    def test_apply_sigcont_does_not_stop_or_start(self) -> None:
        calls: list[str] = []
        state = apply_decision(
            {"action": "sigcont"},
            pid=747,
            state={"restart_stamps": [], "sigcont_attempted": False},
            now=0,
            continue_process=lambda pid: calls.append(f"cont:{pid}"),
            stop_process=lambda pid: calls.append(f"stop:{pid}"),
            start_process=lambda: calls.append("start"),
        )
        self.assertEqual(calls, ["cont:747"])
        self.assertTrue(state["sigcont_attempted"])

    def test_closed_port_health_probe_is_false_quickly(self) -> None:
        self.assertFalse(http_health_ok("127.0.0.1", 9, timeout_s=0.2))

    def test_slow_http_response_is_a_timeout_not_a_crash(self) -> None:
        import socket
        import threading
        import time

        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        port = server.getsockname()[1]
        self.assertNotIn(port, (3001, 18771))
        server.listen(1)

        def serve() -> None:
            conn, _ = server.accept()
            time.sleep(1.2)
            conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            conn.close()

        thread = threading.Thread(target=serve)
        thread.start()
        try:
            self.assertFalse(http_health_ok("127.0.0.1", port, timeout_s=0.8))
        finally:
            thread.join(timeout=3)
            server.close()
        decision = decide_recovery(
            health_ok=False,
            port_open=True,
            process_state="running",
        )
        self.assertEqual(decision["action"], "restart")
        self.assertEqual(
            decision["reason"],
            "health_timeout_while_process_or_port_present",
        )
        self.assertFalse(decision["replay_uncertain_jobs"])

    def test_fast_http_response_stays_healthy(self) -> None:
        import socket
        import threading

        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        port = server.getsockname()[1]
        self.assertNotIn(port, (3001, 18771))
        server.listen(1)

        def serve() -> None:
            conn, _ = server.accept()
            conn.recv(1024)
            conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            conn.close()

        thread = threading.Thread(target=serve)
        thread.start()
        try:
            self.assertTrue(http_health_ok("127.0.0.1", port, timeout_s=0.8))
        finally:
            thread.join(timeout=2)
            server.close()


class PrinterIdentityTests(unittest.TestCase):
    def test_public_address_is_not_scanned(self) -> None:
        self.assertFalse(is_local_scan_ipv4("8.8.8.8"))
        self.assertFalse(is_local_scan_ipv4("1.1.1.1"))
        self.assertTrue(is_local_scan_ipv4("192.168.10.158"))

    def test_different_ip_is_not_the_same_printer_without_hardware_id(self) -> None:
        saved = {"host": "192.168.1.100", "port": 9100, "mac": "aa:bb:cc:dd:ee:ff"}
        found = {"host": "192.168.10.50", "port": 9100}
        self.assertEqual(match_saved_printer(saved, found), "no_match")
        self.assertFalse(may_rebind_address(saved, found))
        annotated = annotate_discovery(found, saved)
        self.assertFalse(annotated["auto_rebind"])
        self.assertFalse(annotated["auto_print"])

    def test_matching_mac_may_suggest_rebind_but_does_not_print(self) -> None:
        saved = {"host": "192.168.1.100", "mac": "AA-BB-CC-DD-EE-FF"}
        found = {"host": "192.168.10.50", "mac_address": "aa:bb:cc:dd:ee:ff"}
        self.assertEqual(match_saved_printer(saved, found), "hardware_match")
        annotated = annotate_discovery(found, saved)
        self.assertTrue(annotated["auto_rebind"])
        self.assertFalse(annotated["auto_print"])
        self.assertIn("Ethernet", UNREACHABLE_MESSAGE)


if __name__ == "__main__":
    unittest.main()
