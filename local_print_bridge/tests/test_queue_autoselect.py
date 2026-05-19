import unittest

from local_print_bridge.queue_autoselect import pick_auto_windows_printer_queue


class QueueAutoselectTests(unittest.TestCase):
    def test_picks_single_recommended_ready_printer(self) -> None:
        queue = pick_auto_windows_printer_queue(
            [
                {
                    "queue": "POS-58",
                    "name": "POS-58",
                    "recommended": True,
                    "statusLevel": "ready",
                    "ready": True,
                }
            ]
        )
        self.assertEqual(queue, "POS-58")

    def test_picks_pos_candidate_ready_printer(self) -> None:
        queue = pick_auto_windows_printer_queue(
            [
                {
                    "queue": "POS-58",
                    "name": "POS-58",
                    "isPosCandidate": True,
                    "statusLevel": "ready",
                }
            ]
        )
        self.assertEqual(queue, "POS-58")

    def test_does_not_pick_when_multiple_ready_candidates(self) -> None:
        queue = pick_auto_windows_printer_queue(
            [
                {
                    "queue": "POS-58",
                    "recommended": True,
                    "statusLevel": "ready",
                },
                {
                    "queue": "POS-80",
                    "recommended": True,
                    "statusLevel": "ready",
                },
            ]
        )
        self.assertIsNone(queue)


if __name__ == "__main__":
    unittest.main()
