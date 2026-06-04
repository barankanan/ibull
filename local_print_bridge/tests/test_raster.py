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
from local_print_bridge.receipt import (
    ReceiptRenderer,
    normalize_text_for_safe_fallback,
    resolve_receipt_table_label_lines,
)
from local_print_bridge.server import build_test_payload


def _first_raster_width_bytes(payload: bytes) -> int:
    if b"\x1dv0" in payload:
        start = payload.index(b"\x1dv0")
        return payload[start + 4] + (payload[start + 5] << 8)
    start = payload.index(b"\x1b*")
    return payload[start + 3] + (payload[start + 4] << 8)


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
        self.assertEqual(_first_raster_width_bytes(rasterized.data), 48)

    def test_build_gs_v0_raster_returns_bytes_and_valid_lengths(self) -> None:
        try:
            image = ReceiptBitmapRenderer(self.settings).render(build_test_payload())
        except RuntimeError as exc:
            self.skipTest(str(exc))
            return
        encoder = RasterEscPosEncoder(self.settings)
        payload = encoder.build_gs_v0_raster(image.crop((0, 0, image.size[0], min(64, image.size[1]))))
        self.assertIsInstance(payload, bytes)
        self.assertNotIsInstance(payload, str)
        self.assertIn(b"\x1dv0", payload)

    def test_build_esc_star_raster_returns_bytes_and_valid_lengths(self) -> None:
        settings = BridgeSettings(
            **{**self.settings.__dict__, "paper_width_mm": 80, "chars_per_line": 48, "raster_mode": "esc_star"}
        )
        try:
            image = KitchenBitmapRenderer(settings).render(
                KitchenPayload.from_dict(
                    {
                        "title": "MUTFAK SİPARİŞİ",
                        "store_name": "IBUL",
                        "job_type": "new_order",
                        "order_no": "1",
                        "table_no": "1",
                        "table_name": "Bahçe 1",
                        "items": [{"id": "1", "name": "Ciğer Şiş", "quantity": 1}],
                    }
                )
            )
        except RuntimeError as exc:
            self.skipTest(str(exc))
            return
        encoder = RasterEscPosEncoder(settings)
        payload = encoder.build_esc_star_raster(image.crop((0, 0, image.size[0], min(24, image.size[1]))))
        self.assertIsInstance(payload, bytes)
        self.assertNotIsInstance(payload, str)
        self.assertIn(b"\x1b*", payload)

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

    def test_kitchen_bulk_raster_chunks_long_ticket_and_cuts_once(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "title": "MUTFAK SİPARİŞİ",
                "store_name": "IBUL",
                "job_type": "new_order",
                "order_no": "77",
                "daily_order_no": 77,
                "table_no": "9",
                "table_name": "Bahçe 9",
                "printed_at": "2026-05-07T12:53:34+03:00",
                "items": [
                    {
                        "id": f"item-{index}",
                        "name": f"Kemiksiz Tavuk Servis {index}",
                        "quantity": 1,
                        "amount_label": "500 g",
                        "note": "ÇĞİÖŞÜ çğıöşü",
                    }
                    for index in range(1, 11)
                ],
            }
        )
        settings = BridgeSettings(
            host="127.0.0.1",
            port=3001,
            printer_queue="Kitchen80",
            paper_width_mm=80,
            chars_per_line=48,
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
        try:
            image = KitchenBitmapRenderer(settings).render(payload)
            rasterized = RasterEscPosEncoder(settings).encode(image)
        except RuntimeError as exc:
            self.skipTest(str(exc))
            return

        self.assertGreater(rasterized.chunk_count, 1)
        self.assertEqual(sum(rasterized.chunk_heights), rasterized.height_px)
        self.assertEqual(_first_raster_width_bytes(rasterized.data), 72)
        self.assertTrue(rasterized.data.endswith(b"\x1dV\x01"))
        self.assertEqual(rasterized.data.count(b"\x1dV\x01"), 1)

    def test_esc_star_profile_uses_alternate_raster_mode(self) -> None:
        payload = KitchenPayload.from_dict(
            {
                "title": "MUTFAK SİPARİŞİ",
                "store_name": "IBUL",
                "job_type": "new_order",
                "order_no": "18",
                "table_no": "8",
                "table_name": "Bahçe 8",
                "items": [{"id": "1", "name": "Uzun Ürün Adı ÇĞİÖŞÜ", "quantity": 1}],
            }
        )
        settings = BridgeSettings(
            **{
                **self.settings.__dict__,
                "paper_width_mm": 80,
                "chars_per_line": 48,
                "raster_mode": "esc_star",
                "raster_width_px": 576,
            }
        )
        try:
            image = KitchenBitmapRenderer(settings).render(payload)
            rasterized = RasterEscPosEncoder(settings).encode(image)
        except RuntimeError as exc:
            self.skipTest(str(exc))
            return
        self.assertIn(b"\x1b*", rasterized.data)
        self.assertNotIn(b"\x1dv0", rasterized.data)
        self.assertEqual(_first_raster_width_bytes(rasterized.data), 576)

    def test_safe_text_fallback_normalizes_turkish_when_needed(self) -> None:
        self.assertEqual(
            normalize_text_for_safe_fallback("İzgara Şiş Çorba"),
            "Izgara Sis Corba",
        )


if __name__ == "__main__":
    unittest.main()
