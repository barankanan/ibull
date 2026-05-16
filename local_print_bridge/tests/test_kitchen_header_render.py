import unittest

from local_print_bridge.config import BridgeSettings
from local_print_bridge.kitchen import KitchenRenderer
from local_print_bridge.models import KitchenPayload


class KitchenHeaderRenderTests(unittest.TestCase):
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

    def test_kitchen_header_includes_order_no_table_and_time(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "job_type": "new_order",
                "title": "MUTFAK FİŞİ",
                "store_name": "DESTINA",
                "daily_order_no": 7,
                "table_number": 1,
                "display_table_label": "Salon 1",
                "printed_at": "2026-05-07T12:08:00+03:00",
                "items": [
                    {"product_name": "Ciğer Şiş", "quantity": 1},
                ],
            }
        )

        data = KitchenRenderer(self.settings).render(payload)
        text = data.decode("cp857", errors="ignore")

        self.assertIn("Sipariş No: 7", text)
        self.assertIn("Masa: Salon 1", text)
        self.assertIn("Tarih: 07.05.2026 12:08", text)
        self.assertNotIn("Alan:", text)


if __name__ == "__main__":
    unittest.main()

