import threading
import time
import unittest

from local_print_bridge import graceful_stop


class GracefulStopTest(unittest.TestCase):
    def setUp(self) -> None:
        graceful_stop.reset_for_tests()

    def test_waits_for_the_ticket_being_printed(self) -> None:
        state = {"active": 1}
        stopped = threading.Event()
        order: list[str] = []
        answered = threading.Event()

        def stop_server() -> None:
            order.append(f"server_stop active={state['active']}")
            stopped.set()

        def request() -> None:
            graceful_stop.finish_work_then_stop(
                stop_server=stop_server,
                queue_summary=lambda: {"activePrinters": state["active"], "queueDepthByPrinter": {}},
                stop_consumer=lambda: order.append("consumer_stop"),
                idle_timeout=5,
                poll=0.01,
            )
            answered.set()

        threading.Thread(target=request).start()
        time.sleep(0.1)
        self.assertFalse(answered.is_set(), "the answer waits for the ticket")
        self.assertFalse(stopped.is_set(), "server must stay up while a ticket prints")
        state["active"] = 0
        self.assertTrue(stopped.wait(2))
        self.assertTrue(answered.wait(2))
        self.assertEqual(order, ["consumer_stop", "server_stop active=0"])

    def test_second_request_does_not_start_another_stop(self) -> None:
        stopped = threading.Event()
        calls: list[int] = []

        def stop_server() -> None:
            calls.append(1)
            stopped.set()

        self.assertTrue(graceful_stop.finish_work_then_stop(stop_server=stop_server))
        self.assertFalse(graceful_stop.finish_work_then_stop(stop_server=stop_server))
        self.assertTrue(stopped.wait(2))
        time.sleep(0.05)
        self.assertEqual(len(calls), 1)
        self.assertTrue(graceful_stop.stopping())

    def test_a_stuck_printer_does_not_block_the_stop_forever(self) -> None:
        stopped = threading.Event()
        graceful_stop.finish_work_then_stop(
            stop_server=stopped.set,
            queue_summary=lambda: {"activePrinters": 1},
            idle_timeout=0.2,
            poll=0.01,
        )
        self.assertTrue(stopped.wait(2))


if __name__ == "__main__":
    unittest.main()
