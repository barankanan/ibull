import unittest

from local_print_bridge.models import KitchenPayload


class KitchenPayloadParsingTests(unittest.TestCase):
    def test_kitchen_item_name_prefers_product_name(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "job_type": "new_order",
                "station_name": "Ocak",
                "table_no": "5",
                "order_no": "123",
                "created_at": "2026-05-06T12:00:00Z",
                "items": [
                    {
                        "order_item_id": "oi-1",
                        "product_name": "Adana Kebap",
                        "quantity": 2,
                        "item_note": "acısız",
                        "amount_label": "500g",
                    }
                ],
            }
        )

        self.assertEqual(len(payload.items), 1)
        self.assertEqual(payload.items[0].id, "oi-1")
        self.assertEqual(payload.items[0].name, "Adana Kebap")
        self.assertEqual(payload.items[0].quantity, 2)
        self.assertEqual(payload.items[0].note, "acısız")
        self.assertEqual(payload.items[0].amount_label, "500g")

    def test_kitchen_child_item_name_prefers_product_name(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "job_type": "new_order",
                "station_name": "Ocak",
                "table_no": "5",
                "order_no": "123",
                "created_at": "2026-05-06T12:00:00Z",
                "items": [
                    {
                        "order_item_id": "oi-1",
                        "product_name": "Servis",
                        "quantity": 1,
                        "plates": [
                            {
                                "label": "Tabak 1",
                                "items": [
                                    {
                                        "id": "child-1",
                                        "product_name": "Salata",
                                        "quantity": 1,
                                        "note": "soğansız",
                                    }
                                ],
                            }
                        ],
                    }
                ],
            }
        )

        child = payload.items[0].plates[0].items[0]
        self.assertEqual(child.name, "Salata")
        self.assertEqual(child.note, "soğansız")


if __name__ == "__main__":
    unittest.main()

