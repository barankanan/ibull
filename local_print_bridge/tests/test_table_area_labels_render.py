import unittest
from datetime import datetime
from decimal import Decimal

from local_print_bridge.config import BridgeSettings
from local_print_bridge.models import KitchenPayload, ReceiptItem, ReceiptPayload, ReceiptTotals
from local_print_bridge.receipt import ReceiptRenderer
from local_print_bridge.kitchen import KitchenRenderer
from local_print_bridge.receipt import resolve_receipt_table_label_lines


class TableAreaLabelRenderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=19001,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="image",
            raster_chunk_height=256,
            allowed_origins=("https://ibul-ecommerce.web.app",),
            healthcheck_queue=False,
            print_system_enabled=True,
            cut_mode="partial",
            transport_mode="auto",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="",
            network_port=9100,
        )

    def test_receipt_renders_area_and_table_name(self) -> None:
        payload = ReceiptPayload(
            store_name="IBUL RESTAURANT",
            branch="",
            phone="",
            table_no="3",
            date_time=datetime.fromisoformat("2026-05-06T14:00:00+03:00"),
            items=[
                ReceiptItem(
                    name="Adana Kebap",
                    quantity=Decimal("1"),
                    line_total=Decimal("100.00"),
                    unit_price=Decimal("100.00"),
                    note="",
                )
            ],
            totals=ReceiptTotals(
                subtotal=Decimal("100.00"),
                discount=Decimal("0.00"),
                service_charge=Decimal("0.00"),
                grand_total=Decimal("100.00"),
            ),
            currency="TRY",
            footer_note="",
            table_area_name="Bahçe",
            table_name="Bahçe 3",
        )

        data = ReceiptRenderer(self.settings).render(payload)
        self.assertNotIn("Alan:".encode("cp857"), data)
        self.assertIn("Bahçe".encode("cp857"), data)
        self.assertIn("Masa:".encode("cp857"), data)
        self.assertIn("Bahçe 3".encode("cp857"), data)

    def test_kitchen_renders_area_and_table_name(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "job_type": "new_order",
                "station_name": "Ocak",
                "table_no": "3",
                "table_name": "Bahçe 3",
                "table_area_name": "Bahçe",
                "order_no": "TBL-TEST",
                "created_at": "2026-05-06T12:00:00Z",
                "items": [
                    {
                        "order_item_id": "oi-1",
                        "product_name": "Ciğer Şiş",
                        "quantity": 1,
                    }
                ],
            }
        )
        data = KitchenRenderer(self.settings).render(payload)
        self.assertNotIn("Alan".encode("cp857"), data)
        self.assertIn("Bahçe".encode("cp857"), data)
        self.assertIn("Masa:".encode("cp857"), data)
        self.assertIn("Bahçe 3".encode("cp857"), data)

    def test_receipt_table_label_rules_resolve_expected_lines(self) -> None:
        payload = ReceiptPayload(
            store_name="IBUL RESTAURANT",
            branch="",
            phone="",
            table_no="12",
            date_time=datetime.fromisoformat("2026-05-06T14:00:00+03:00"),
            items=[
                ReceiptItem(
                    name="Adana Kebap",
                    quantity=Decimal("1"),
                    line_total=Decimal("100.00"),
                    unit_price=Decimal("100.00"),
                    note="",
                )
            ],
            totals=ReceiptTotals(
                subtotal=Decimal("100.00"),
                discount=Decimal("0.00"),
                service_charge=Decimal("0.00"),
                grand_total=Decimal("100.00"),
            ),
            currency="TRY",
            footer_note="",
            table_area_name="Bahçe",
            table_name="Bahçe 3",
        )
        (
            parsed_table_no,
            parsed_table_name,
            parsed_table_area_name,
            final_table_line,
        ) = resolve_receipt_table_label_lines(payload)
        self.assertEqual(parsed_table_no, "12")
        self.assertEqual(parsed_table_name, "Bahçe 3")
        self.assertEqual(parsed_table_area_name, "Bahçe")
        self.assertEqual(final_table_line, "Masa: Bahçe 3")

    def test_receipt_table_label_fallback_uses_table_no_when_name_missing(self) -> None:
        payload = ReceiptPayload(
            store_name="IBUL RESTAURANT",
            branch="",
            phone="",
            table_no="12",
            date_time=datetime.fromisoformat("2026-05-06T14:00:00+03:00"),
            items=[
                ReceiptItem(
                    name="Adana Kebap",
                    quantity=Decimal("1"),
                    line_total=Decimal("100.00"),
                    unit_price=Decimal("100.00"),
                    note="",
                )
            ],
            totals=ReceiptTotals(
                subtotal=Decimal("100.00"),
                discount=Decimal("0.00"),
                service_charge=Decimal("0.00"),
                grand_total=Decimal("100.00"),
            ),
            currency="TRY",
            footer_note="",
            table_area_name="",
            table_name="",
        )
        *_, final_table_line = resolve_receipt_table_label_lines(payload)
        self.assertEqual(final_table_line, "Masa: Masa 12")


if __name__ == "__main__":
    unittest.main()

