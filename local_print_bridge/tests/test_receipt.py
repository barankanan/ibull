from __future__ import annotations

from datetime import datetime
from decimal import Decimal
import unittest

from local_print_bridge.config import BridgeSettings
from local_print_bridge.models import ReceiptItem, ReceiptPayload, ReceiptTotals
from local_print_bridge.receipt import ReceiptRenderer


class ReceiptRendererTests(unittest.TestCase):
    def test_basic_receipt_contains_escpos_commands_and_fields(self) -> None:
        settings = BridgeSettings(
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
        payload = ReceiptPayload(
            store_name="IBUL RESTAURANT",
            branch="MERKEZ SUBE",
            phone="0326 000 00 00",
            table_no="5",
            date_time=datetime.fromisoformat("2026-04-08T14:35:00+03:00"),
            items=[
                ReceiptItem(
                    name="Mercimek Corba",
                    quantity=Decimal("2"),
                    line_total=Decimal("160.00"),
                    unit_price=Decimal("80.00"),
                    note="Az tuz",
                )
            ],
            totals=ReceiptTotals(
                subtotal=Decimal("160.00"),
                discount=Decimal("0.00"),
                service_charge=Decimal("0.00"),
                grand_total=Decimal("160.00"),
            ),
            currency="TRY",
            footer_note="Afiyet olsun",
        )

        data = ReceiptRenderer(settings).render(payload)

        self.assertIn(b"\x1b@", data)
        self.assertIn(b"\x1bt\r", data)
        self.assertIn("IBUL RESTAURANT".encode("cp857"), data)
        self.assertIn("Masa:".encode("cp857"), data)
        self.assertIn("Mercimek Corba".encode("cp857"), data)
        self.assertIn("160,00 TL".encode("cp857"), data)
        self.assertIn(b"\x1dV\x01", data)


if __name__ == "__main__":
    unittest.main()
