import unittest
from datetime import datetime
from decimal import Decimal

from local_print_bridge.config import BridgeSettings
from local_print_bridge.models import ReceiptItem, ReceiptPayload, ReceiptTotals
from local_print_bridge.receipt import ReceiptRenderer


class ReceiptHeaderRulesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=19001,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="text",
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

    def test_receipt_renders_date_time_from_receipt_printed_at_and_no_subtotal(self) -> None:
        payload = ReceiptPayload(
            store_name="DESTINA",
            branch="",
            phone="",
            table_no="1",
            table_name="Salon 1",
            date_time=datetime.fromisoformat("2026-05-07T12:08:00+03:00"),
            receipt_printed_at="2026-05-07T12:08:00+03:00",
            printed_at="2026-05-07T12:08:00+03:00",
            items=[
                ReceiptItem(
                    name="Ciğer Şiş",
                    quantity=Decimal("1"),
                    line_total=Decimal("360.00"),
                    unit_price=Decimal("360.00"),
                    note="",
                )
            ],
            totals=ReceiptTotals(
                subtotal=Decimal("360.00"),
                discount=Decimal("0.00"),
                service_charge=Decimal("0.00"),
                grand_total=Decimal("360.00"),
            ),
            currency="TRY",
            footer_note="",
        )

        data = ReceiptRenderer(self.settings).render(payload)
        text = data.decode("cp857", errors="ignore")
        self.assertIn("Masa:", text)
        self.assertIn("Salon 1", text)
        self.assertIn("Tarih", text)
        self.assertIn("07.05.2026 12:08", text)
        self.assertIn("GENEL TOPLAM", text)
        self.assertNotIn("Ara Toplam", text)


if __name__ == "__main__":
    unittest.main()

