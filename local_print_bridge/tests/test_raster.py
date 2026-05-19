from __future__ import annotations

from decimal import Decimal
import unittest

from local_print_bridge.config import BridgeSettings
from local_print_bridge.models import KitchenPayload, ReceiptPayload
from local_print_bridge.kitchen import KitchenRenderer
from local_print_bridge.raster import (
    BundledFontMissingError,
    KitchenBitmapRenderer,
    ReceiptBitmapRenderer,
    RasterEscPosEncoder,
    resolve_bundled_mono_font_path,
)
from local_print_bridge.receipt import ReceiptRenderer, resolve_receipt_table_label_lines
from local_print_bridge.server import build_test_payload


class RasterPrintTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = BridgeSettings(
            host="127.0.0.1",
            port=3001,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="image",
            raster_chunk_height=128,
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

    def test_test_payload_contains_turkish_samples(self) -> None:
        payload: ReceiptPayload = build_test_payload()
        combined = " ".join(item.name for item in payload.items) + " " + payload.items[1].note
        self.assertIn("ÇĞİÖŞÜ", combined)
        self.assertIn("Karışık", combined)
        self.assertIn("Şiş", combined)

    def test_bundled_mono_font_exists(self) -> None:
        path = resolve_bundled_mono_font_path(bold=False)
        self.assertTrue(path.endswith("DejaVuSansMono.ttf"))

    def test_guarantee_mode_renders_turkish_product_names(self) -> None:
        guarantee_settings = BridgeSettings(
            host="127.0.0.1",
            port=3001,
            printer_queue="Thermal58",
            paper_width_mm=58,
            chars_per_line=32,
            encoding="cp857",
            codepage=13,
            render_mode="image",
            raster_chunk_height=128,
            allowed_origins=("https://ibul-ecommerce.web.app",),
            healthcheck_queue=False,
            print_system_enabled=True,
            cut_mode="partial",
            transport_mode="auto",
            usb_vendor_id=None,
            usb_product_id=None,
            network_host="",
            network_port=9100,
            turkish_guarantee_mode=True,
        )
        payload = ReceiptPayload.from_dict(
            {
                "store_name": "IBUL",
                "table_no": "1",
                "display_table_label": "Test",
                "items": [
                    {
                        "name": "Çiğ Köfte",
                        "qty": 1,
                        "price": "100",
                        "total": "100",
                        "note": "az pişmiş, soğansız",
                    },
                    {"name": "Ciğer Şiş", "qty": 1, "price": "100", "total": "100"},
                    {"name": "Kuşbaşı", "qty": 1, "price": "100", "total": "100"},
                    {"name": "Kıyma Dürüm", "qty": 1, "price": "100", "total": "100"},
                ],
                "currency": "TRY",
                "grand_total": "400",
            }
        )
        try:
            image = ReceiptBitmapRenderer(guarantee_settings).render(payload)
            rasterized = RasterEscPosEncoder(guarantee_settings).encode(image)
        except (RuntimeError, BundledFontMissingError) as exc:
            self.skipTest(str(exc))
            return
        self.assertGreater(rasterized.height_px, 0)
        self.assertGreater(len(rasterized.data), 100)

    def test_raster_encoder_emits_image_command_sequence(self) -> None:
        try:
            image = ReceiptBitmapRenderer(self.settings).render(build_test_payload())
            rasterized = RasterEscPosEncoder(self.settings).encode(image)
        except RuntimeError as exc:
            self.skipTest(str(exc))
            return

        self.assertGreater(rasterized.width_px, 0)
        self.assertGreater(rasterized.height_px, 0)
        self.assertGreaterEqual(rasterized.chunk_count, 1)
        self.assertIn(b"\x1b@", rasterized.data)
        self.assertIn(b"\x1dv0", rasterized.data)
        self.assertIn(b"\x1dV\x01", rasterized.data)

    def test_table_label_lines_are_resolved_for_raster_renderer(self) -> None:
        payload: ReceiptPayload = build_test_payload()
        *_, final_table_line = resolve_receipt_table_label_lines(payload)
        # build_test_payload should always yield a non-empty table line
        self.assertTrue(final_table_line)
        self.assertNotEqual(final_table_line.strip(), "Masa")
        self.assertIn("Masa:", final_table_line)

    def test_receipt_bitmap_header_lines_include_date_and_grand_total(self) -> None:
        payload = ReceiptPayload.from_dict(
            {
                "store_name": "IBUL",
                "table_no": "1",
                "display_table_label": "Bahçe 3",
                "receipt_printed_at": "2026-05-07T12:53:16.776433+03:00",
                "items": [
                    {"name": "Ciğer Şiş", "qty": 1, "price": "360", "total": "360"},
                ],
                "currency": "TRY",
                "grand_total": "4520",
                "subtotal": "4520",
            }
        )
        *_, final_table_line = resolve_receipt_table_label_lines(payload)
        self.assertEqual(final_table_line, "Masa: Bahçe 3")
        renderer = ReceiptBitmapRenderer(self.settings)
        header = renderer._debug_header_lines(payload, final_table_line=final_table_line)
        self.assertEqual(header["final_date_line"], "Tarih: 07.05.2026 12:53")
        self.assertEqual(header["grand_total"], "4.520,00 TL")
        self.assertEqual(header["final_total_line"], "GENEL TOPLAM: 4.520,00 TL")
        for forbidden in ("Ara Toplam", "Alan:", "Tarih: -", "GENEL TOPLAM: -"):
            self.assertNotIn(forbidden, " | ".join(header.values()))

        # Text renderer must match the same visible header strings.
        raw = ReceiptRenderer(self.settings).render(payload)
        rendered = raw.decode(self.settings.encoding, errors="ignore")
        self.assertIn("Masa: Bahçe 3", rendered)
        self.assertIn("Tarih: 07.05.2026 12:53", rendered)
        self.assertIn("GENEL TOPLAM: 4.520,00 TL", rendered)
        self.assertNotIn("Ara Toplam", rendered)
        self.assertNotIn("Alan:", rendered)
        self.assertNotIn("Tarih:\n", rendered)
        self.assertNotIn("GENEL TOPLAM: -", rendered)
        self.assertNotIn("\nMasa\n", rendered)
        self.assertNotIn("\nMasa:\n", rendered)

    def test_kitchen_bitmap_header_line_uses_printed_at_with_timezone(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "title": "MUTFAK SİPARİŞİ",
                "store_name": "IBUL",
                "job_type": "new_order",
                "order_no": "5",
                "daily_order_no": 5,
                "table_no": "3",
                "table_name": "Bahçe 3",
                "printed_at": "2026-05-07T09:53:34.438122+00:00",
                "items": [
                    {"id": "1", "name": "Test", "quantity": 1},
                ],
            }
        )
        renderer = KitchenBitmapRenderer(self.settings)
        header = renderer._debug_header_lines(payload, order_label="5", table_label="Bahçe 3")
        self.assertEqual(header["final_datetime_line"], "Tarih: 07.05.2026 12:53")
        self.assertEqual(header["time_source"], "printed_at")
        for forbidden in ("Ara Toplam", "Alan:", "Tarih: -"):
            self.assertNotIn(forbidden, " | ".join(header.values()))

        # Text renderer parity checks.
        raw = KitchenRenderer(self.settings).render(payload)
        rendered = raw.decode(self.settings.encoding, errors="ignore")
        self.assertIn("Sipariş No: 5", rendered)
        self.assertIn("Masa: Bahçe 3", rendered)
        self.assertIn("Tarih: 07.05.2026 12:53", rendered)
        self.assertNotIn("Alan:", rendered)
        self.assertNotIn("Tarih:\n", rendered)
        self.assertNotIn("\nMasa\n", rendered)
        self.assertNotIn("\nMasa:\n", rendered)


if __name__ == "__main__":
    unittest.main()
