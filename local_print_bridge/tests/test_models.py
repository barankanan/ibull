from __future__ import annotations

from decimal import Decimal
import unittest

from local_print_bridge.models import ReceiptPayload


class ReceiptPayloadTests(unittest.TestCase):
    def test_flat_receipt_payload_aliases_are_supported(self) -> None:
        payload = ReceiptPayload.from_dict(
            {
                "store_name": "IBUL RESTAURANT",
                "branch": "MERKEZ SUBE",
                "phone": "0326 000 00 00",
                "table_no": "12",
                "datetime": "2026-04-08T14:35:00+03:00",
                "items": [
                    {
                        "name": "Izgara Kofte",
                        "qty": 2,
                        "price": "195.00",
                        "total": "390.00",
                    }
                ],
                "subtotal": "390.00",
                "discount": "0.00",
                "grand_total": "390.00",
            }
        )

        self.assertEqual(payload.table_no, "12")
        self.assertEqual(payload.items[0].quantity, Decimal("2"))
        self.assertEqual(payload.items[0].unit_price, Decimal("195.00"))
        self.assertEqual(payload.items[0].line_total, Decimal("390.00"))
        self.assertEqual(payload.totals.subtotal, Decimal("390.00"))
        self.assertEqual(payload.totals.grand_total, Decimal("390.00"))

    def test_totals_can_be_derived_from_items(self) -> None:
        payload = ReceiptPayload.from_dict(
            {
                "store_name": "IBUL RESTAURANT",
                "table_no": "8",
                "items": [
                    {
                        "name": "Acik Ayran",
                        "qty": 2,
                        "price": "45.00",
                    }
                ],
            }
        )

        self.assertEqual(payload.items[0].line_total, Decimal("90.00"))
        self.assertEqual(payload.totals.subtotal, Decimal("90.00"))
        self.assertEqual(payload.totals.grand_total, Decimal("90.00"))


if __name__ == "__main__":
    unittest.main()
