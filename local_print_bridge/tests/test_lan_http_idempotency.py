"""P0: LAN bind defaults + HTTP kitchen job_id idempotency helpers."""

from __future__ import annotations

import unittest

from local_print_bridge import server as bridge_server


class LanHttpIdempotencyTests(unittest.TestCase):
    def setUp(self) -> None:
        with bridge_server._HTTP_PRINT_IDEM_LOCK:
            bridge_server._HTTP_PRINT_RECENT_JOBS.clear()

    def test_default_listen_host_is_loopback(self) -> None:
        from local_print_bridge.config import DEFAULT_LISTEN_HOST

        self.assertEqual(DEFAULT_LISTEN_HOST, "127.0.0.1")
        self.assertNotEqual(DEFAULT_LISTEN_HOST, "0.0.0.0")

    def test_print_station_http_drops_refresh_and_lan_access_token(self) -> None:
        field_map = {
            "restaurant_id": "PRINT_STATION_RESTAURANT_ID",
            "access_token": "PRINT_STATION_ACCESS_TOKEN",
            "refresh_token": "PRINT_STATION_REFRESH_TOKEN",
        }
        body = {
            "restaurant_id": "rest-1",
            "access_token": "access",
            "refresh_token": "refresh",
        }
        loopback = bridge_server.print_station_env_updates_from_http(
            body, "127.0.0.1", field_map
        )
        self.assertEqual(loopback.get("PRINT_STATION_ACCESS_TOKEN"), "access")
        self.assertNotIn("PRINT_STATION_REFRESH_TOKEN", loopback)

        lan = bridge_server.print_station_env_updates_from_http(
            body, "192.168.1.20", field_map
        )
        self.assertEqual(lan.get("PRINT_STATION_RESTAURANT_ID"), "rest-1")
        self.assertNotIn("PRINT_STATION_ACCESS_TOKEN", lan)
        self.assertNotIn("PRINT_STATION_REFRESH_TOKEN", lan)

    def test_private_client_ips_allowed(self) -> None:
        self.assertTrue(bridge_server._is_lan_or_loopback_client("127.0.0.1"))
        self.assertTrue(bridge_server._is_lan_or_loopback_client("192.168.1.20"))
        self.assertTrue(bridge_server._is_lan_or_loopback_client("10.0.0.5"))
        self.assertTrue(bridge_server._is_lan_or_loopback_client("::ffff:192.168.0.2"))
        self.assertFalse(bridge_server._is_lan_or_loopback_client("8.8.8.8"))

    def test_http_print_job_id_dedup(self) -> None:
        job_id = "client-job-abc"
        self.assertFalse(bridge_server._http_print_already_processed(job_id))
        bridge_server._http_print_record_processed(job_id)
        self.assertTrue(bridge_server._http_print_already_processed(job_id))

    def test_extract_print_job_id_prefers_explicit_keys(self) -> None:
        self.assertEqual(
            bridge_server._extract_http_print_job_id(
                {"print_job_id": "pj-1", "job_id": "other"}
            ),
            "pj-1",
        )
        self.assertEqual(
            bridge_server._extract_http_print_job_id(
                {"client_print_job_id": "cj-2"}
            ),
            "cj-2",
        )


    def test_content_key_dedupes_lan_vs_hub_order_ids(self) -> None:
        lan = {
            "restaurant_id": "r1",
            "order_id": "lan-abc",
            "table_number": 7,
            "station_id": "st1",
            "revision": 1,
            "items": [{"name": "Ayran", "qty": 1}],
            "client_print_job_id": "lan-job-1",
        }
        hub = {
            "restaurant_id": "r1",
            "order_id": "uuid-real-order",
            "table_number": 7,
            "station_id": "st1",
            "revision": 1,
            # Different volatile fields / qty vs quantity — still same ticket.
            "items": [
                {
                    "name": "Ayran",
                    "quantity": 1,
                    "product_id": "",
                    "extra_volatile": "hub-only",
                }
            ],
            "print_job_id": "db-job-uuid",
        }
        keys_lan = bridge_server._http_print_idem_keys(lan)
        keys_hub = bridge_server._http_print_idem_keys(hub)
        content_lan = [k for k in keys_lan if k.startswith("content:")]
        content_hub = [k for k in keys_hub if k.startswith("content:")]
        self.assertEqual(content_lan, content_hub)
        self.assertTrue(content_lan)
        bridge_server._http_print_record_keys(keys_lan)
        self.assertTrue(bridge_server._http_print_any_processed(keys_hub))

    def test_logical_print_key_dedupes_lan_vs_hub(self) -> None:
        logical = "logical:r1|7|st1|1|items"
        lan = {
            "restaurant_id": "r1",
            "print_job_id": "lan-job-1",
            "logical_print_key": logical,
            "items": [{"name": "A", "qty": 1}],
        }
        hub = {
            "restaurant_id": "r1",
            "print_job_id": "db-job-uuid",
            "logical_print_key": logical,
            "items": [{"name": "A", "quantity": 1, "note": "different shape"}],
        }
        keys_lan = bridge_server._http_print_idem_keys(lan)
        keys_hub = bridge_server._http_print_idem_keys(hub)
        self.assertIn(logical, keys_lan)
        self.assertIn(logical, keys_hub)
        bridge_server._http_print_record_keys(keys_lan)
        self.assertTrue(bridge_server._http_print_any_processed(keys_hub))


if __name__ == "__main__":
    unittest.main()
