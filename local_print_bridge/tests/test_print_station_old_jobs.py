import unittest

from local_print_bridge.print_station import job_is_from_before


class OldJobLimitTest(unittest.TestCase):
    LIMIT = "2026-11-19T20:00:00.000Z"

    def test_no_limit_means_nothing_is_old(self) -> None:
        self.assertFalse(job_is_from_before({"created_at": "2020-01-01T00:00:00Z"}, ""))

    def test_job_created_before_start_is_held(self) -> None:
        self.assertTrue(job_is_from_before({"created_at": "2026-11-19T19:59:59+00:00"}, self.LIMIT))
        # Same instant written in another zone.
        self.assertTrue(job_is_from_before({"created_at": "2026-11-19T22:59:59+03:00"}, self.LIMIT))

    def test_job_created_after_start_prints(self) -> None:
        self.assertFalse(job_is_from_before({"created_at": "2026-11-19T20:00:01+00:00"}, self.LIMIT))
        self.assertFalse(job_is_from_before({"created_at": "2026-11-19T23:00:01.123456+03:00"}, self.LIMIT))

    def test_unreadable_time_is_held_when_a_limit_is_set(self) -> None:
        self.assertTrue(job_is_from_before({"created_at": ""}, self.LIMIT))
        self.assertTrue(job_is_from_before({}, self.LIMIT))


if __name__ == "__main__":
    unittest.main()
