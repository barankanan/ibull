from __future__ import annotations

from decimal import Decimal
import logging
import textwrap

from .config import BridgeSettings
from .models import ReceiptItem, ReceiptPayload


ESC = b"\x1b"
GS = b"\x1d"
TURKISH_TEST_LINES = (
    "ÇĞİÖŞÜ çğıöşü Iİ ıi",
    "İğne, Şiş, Çorba, Kuzu Şiş, Karışık, Adisyon",
)

LOGGER = logging.getLogger("local_print_bridge")

# Fallback chain for Turkish text: try each codec in order.
# Never fall back to utf-8 — raw UTF-8 bytes confuse most ESC/POS devices.
_TURKISH_CODEC_FALLBACKS = ("cp857", "cp1254", "iso8859_9", "cp437")


def encode_text(text: str, encoding: str) -> tuple[bytes, str]:
    """Encode *text* using *encoding* with a controlled Turkish fallback chain.

    Returns ``(encoded_bytes, selected_codec)``.  If *encoding* itself works
    the selected_codec will equal *encoding*.  Falls back through
    ``_TURKISH_CODEC_FALLBACKS`` on ``UnicodeEncodeError`` or ``LookupError``.
    The final resort is ``cp437`` with ``errors='replace'`` so a byte string
    is always returned — never raw UTF-8.
    """
    codecs_to_try = [encoding]
    for fb in _TURKISH_CODEC_FALLBACKS:
        if fb != encoding:
            codecs_to_try.append(fb)

    for codec in codecs_to_try:
        try:
            encoded = text.encode(codec, errors="strict")
            if codec != encoding:
                LOGGER.warning(
                    "encode_text: fallback used encoding=%s failed_encoding=%s "
                    "selected_codec=%s text_preview=%.40r",
                    encoding,
                    encoding,
                    codec,
                    text,
                )
            return encoded, codec
        except (UnicodeEncodeError, LookupError):
            continue

    # Absolute last resort — replace unmappable chars with '?'
    LOGGER.error(
        "encode_text: all codecs failed, using cp437 with replace "
        "encoding=%s text_preview=%.40r",
        encoding,
        text,
    )
    return text.encode("cp437", errors="replace"), "cp437(replace)"


def _init_printer() -> bytes:
    return ESC + b"@"


def _set_alignment(mode: str) -> bytes:
    lookup = {"left": 0, "center": 1, "right": 2}
    return ESC + b"a" + bytes([lookup[mode]])


def _set_bold(enabled: bool) -> bytes:
    return ESC + b"E" + bytes([1 if enabled else 0])


def _set_text_size(width: int, height: int) -> bytes:
    size = ((max(width, 1) - 1) << 4) + (max(height, 1) - 1)
    return GS + b"!" + bytes([size])


def _feed(lines: int) -> bytes:
    return ESC + b"d" + bytes([max(lines, 0)])


def _cut(mode: str) -> bytes:
    if mode == "none":
        return b""
    return GS + b"V" + (b"\x00" if mode == "full" else b"\x01")


def _set_codepage(table: int) -> bytes:
    return ESC + b"t" + bytes([table])


def _begin_document(settings: BridgeSettings) -> bytes:
    chunks = [_init_printer()]
    if settings.codepage is not None:
        chunks.append(_set_codepage(settings.codepage))
    return b"".join(chunks)


def resolve_receipt_table_label_lines(payload: ReceiptPayload) -> tuple[str, str, str, str]:
    """
    Returns (parsed_table_no, parsed_table_name, parsed_table_area_name, final_table_line).

    Invariants:
    - Never return a table line that is just "Masa".
    - If table_name is present => "Masa: <table_name>"
    - If table_name is empty but area_name + area_table_number present => "Masa: <area_name> <area_table_number>"
    - If table_name is empty but table_no present => "Masa: Masa <table_no>"
    - If both table_name and table_no are empty => table line is empty (omitted by renderers).
    """
    parsed_table_no = str(getattr(payload, "table_no", "") or "").strip()
    parsed_table_name = str(getattr(payload, "table_name", "") or "").strip()
    parsed_table_area_name = str(getattr(payload, "table_area_name", "") or "").strip()
    parsed_area_name = str(getattr(payload, "area_name", "") or "").strip()
    parsed_area_table_number = str(getattr(payload, "area_table_number", "") or "").strip()

    if parsed_table_name:
        final_table_value = parsed_table_name
    elif parsed_area_name and parsed_area_table_number:
        final_table_value = f"{parsed_area_name} {parsed_area_table_number}".strip()
    elif parsed_table_no:
        final_table_value = f"Masa {parsed_table_no}"
    else:
        final_table_value = ""

    final_table_line = f"Masa: {final_table_value}" if final_table_value else ""
    if final_table_line.strip() == "Masa":
        final_table_line = ""
    return (parsed_table_no, parsed_table_name, parsed_table_area_name, final_table_line)


class ReceiptRenderer:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width = settings.chars_per_line

    def render(self, payload: ReceiptPayload) -> bytes:
        chunks: list[bytes] = [_begin_document(self.settings)]

        (
            parsed_table_no,
            parsed_table_name,
            parsed_table_area_name,
            final_table_line,
        ) = resolve_receipt_table_label_lines(payload)
        LOGGER.info(
            "[RECEIPT_RENDER_TABLE_LABEL] parsed.table_no=%s parsed.table_area_name=%s "
            "parsed.table_name=%s final_area_line=%s final_table_line=%s render_mode=%s",
            parsed_table_no,
            parsed_table_area_name,
            parsed_table_name,
            "-",
            final_table_line or "-",
            str(getattr(self.settings, "render_mode", "") or "-"),
        )

        chunks.extend(
            [
                _set_alignment("center"),
                _set_bold(True),
                _set_text_size(2, 2),
            ]
        )
        chunks.extend(self._lines(payload.store_name.upper()))
        chunks.extend([_set_text_size(1, 1), _set_bold(False)])

        if payload.branch:
            chunks.extend(self._lines(payload.branch))
        if payload.phone:
            chunks.extend(self._lines(f"Tel: {payload.phone}"))
        chunks.extend(self._lines(self._separator()))

        chunks.append(_set_alignment("left"))
        if final_table_line:
            chunks.extend(self._lines(final_table_line))
        receipt_datetime = self._format_datetime(payload)
        if receipt_datetime:
            # Keep parity with raster renderer: always print a single explicit line.
            chunks.extend(self._lines(f"Tarih: {receipt_datetime}"))
        chunks.extend(self._lines(self._separator()))

        for item in payload.items:
            chunks.extend(self._render_item(item, payload.currency))

        chunks.extend(self._lines(self._separator()))
        total_value, total_source = self._resolve_grand_total(payload)
        if total_value is not None:
            formatted_total = self._format_money(total_value, payload.currency)
            LOGGER.info(
                "[RECEIPT_RENDER_HEADER_TOTAL] table_label=%s receipt_datetime=%s grand_total=%s total_source=%s render_mode=%s",
                final_table_line.replace("Masa: ", "", 1) if final_table_line else "-",
                receipt_datetime or "-",
                formatted_total,
                total_source,
                str(getattr(self.settings, "render_mode", "") or "-"),
            )
            chunks.append(_set_bold(True))
            # Keep parity with raster renderer: always print a single explicit line.
            chunks.extend(self._lines(f"GENEL TOPLAM: {formatted_total}"))
            chunks.append(_set_bold(False))
        else:
            LOGGER.warning(
                "[RECEIPT_RENDER_HEADER_TOTAL] table_label=%s receipt_datetime=%s grand_total=%s total_source=%s render_mode=%s",
                final_table_line.replace("Masa: ", "", 1) if final_table_line else "-",
                receipt_datetime or "-",
                "-",
                total_source,
                str(getattr(self.settings, "render_mode", "") or "-"),
            )

        if payload.footer_note:
            chunks.extend(self._lines(self._separator()))
            chunks.append(_set_alignment("center"))
            chunks.extend(self._lines(payload.footer_note))
            chunks.append(_set_alignment("left"))

        chunks.extend([_feed(3), _cut(self.settings.cut_mode)])
        return b"".join(chunks)

    def _render_item(self, item: ReceiptItem, currency: str) -> list[bytes]:
        qty_prefix = f"{self._format_quantity(item.quantity)} x "
        price_text = self._format_money(item.line_total, currency)
        label_lines = self._wrap(qty_prefix + item.name, max(4, self.width - len(price_text) - 1))
        output = self._lines(self._pair(label_lines[0], price_text))
        for continuation in label_lines[1:]:
            output.extend(self._lines(continuation))
        if item.note:
            for note_line in self._wrap(f"  Not: {item.note}", self.width):
                output.extend(self._lines(note_line))
        if item.unit_price is not None:
            unit_price = self._format_money(item.unit_price, currency)
            output.extend(self._lines(f"  Birim: {unit_price}"))
        return output

    def _lines(self, text: str) -> list[bytes]:
        if not text:
            return [b"\n"]
        return [self._encode(line) + b"\n" for line in text.splitlines()]

    def _encode(self, text: str) -> bytes:
        encoded, _ = encode_text(text, self.settings.encoding)
        return encoded

    def _wrap(self, text: str, width: int | None = None) -> list[str]:
        normalized = " ".join(text.split())
        if not normalized:
            return [""]
        return textwrap.wrap(
            normalized,
            width=width or self.width,
            break_long_words=True,
            break_on_hyphens=False,
        )

    def _pair(self, left: str, right: str) -> str:
        left = left.strip()
        right = right.strip()
        if not right:
            return left
        available = self.width - len(right) - 1
        if available < 4:
            return f"{left}\n{right.rjust(self.width)}"
        wrapped_left = self._wrap(left, available)
        first = wrapped_left[0]
        gap = self.width - len(first) - len(right)
        lines = [f"{first}{' ' * max(gap, 1)}{right}"]
        lines.extend(wrapped_left[1:])
        return "\n".join(lines)

    def _separator(self) -> str:
        return "-" * self.width

    def _format_datetime(self, payload: ReceiptPayload) -> str:
        try:
            return payload.date_time.strftime("%d.%m.%Y %H:%M")
        except Exception:
            return ""

    def _resolve_grand_total(self, payload: ReceiptPayload) -> tuple[Decimal | None, str]:
        # Priority:
        # 1) grand_total
        # 2) subtotal
        # 3) sum(line_total)
        # 4) sum(quantity * unit_price)
        try:
            gt = getattr(getattr(payload, "totals", None), "grand_total", None)
            if isinstance(gt, Decimal):
                return gt, "grand_total"
        except Exception:
            pass
        try:
            st = getattr(getattr(payload, "totals", None), "subtotal", None)
            if isinstance(st, Decimal):
                return st, "subtotal"
        except Exception:
            pass
        try:
            items_total = sum((item.line_total for item in payload.items), Decimal("0"))
            if items_total >= 0:
                return items_total, "items.sum(line_total)"
        except Exception:
            pass
        try:
            calc_total = Decimal("0")
            for item in payload.items:
                if item.unit_price is None:
                    return None, "missing_unit_price"
                calc_total += item.quantity * item.unit_price
            return calc_total, "items.sum(quantity*unit_price)"
        except Exception:
            return None, "total_unresolved"

    def _format_money(self, value: Decimal, currency: str) -> str:
        # Turkish formatting with thousands separator (parity with raster renderer):
        # 4520 -> "4.520,00 TL"
        quantized = value.quantize(Decimal("0.01"))
        raw = format(quantized, ",.2f")  # "4,520.00"
        normalized = raw.replace(",", "X").replace(".", ",").replace("X", ".")
        suffix = "TL" if currency.upper() in {"TRY", "TL"} else currency.upper()
        return f"{normalized} {suffix}"

    def _format_quantity(self, value: Decimal) -> str:
        if value == value.to_integral():
            return str(int(value))
        return format(value.normalize(), "f").rstrip("0").rstrip(".")


class TurkishCodepageDiagnosticRenderer:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width = settings.chars_per_line

    def render(
        self,
        *,
        encoding: str,
        codepages: list[int],
        sample_lines: tuple[str, ...] = TURKISH_TEST_LINES,
    ) -> bytes:
        chunks: list[bytes] = []
        for index, codepage in enumerate(codepages):
            section_settings = BridgeSettings(
                host=self.settings.host,
                port=self.settings.port,
                printer_queue=self.settings.printer_queue,
                paper_width_mm=self.settings.paper_width_mm,
                chars_per_line=self.settings.chars_per_line,
                encoding=encoding,
                codepage=codepage,
                render_mode=self.settings.render_mode,
                raster_chunk_height=self.settings.raster_chunk_height,
                allowed_origins=self.settings.allowed_origins,
                healthcheck_queue=self.settings.healthcheck_queue,
                cut_mode="none" if index < len(codepages) - 1 else self.settings.cut_mode,
                transport_mode=self.settings.transport_mode,
                usb_vendor_id=self.settings.usb_vendor_id,
                usb_product_id=self.settings.usb_product_id,
                network_host=self.settings.network_host,
                network_port=self.settings.network_port,
            )
            chunks.extend(self._render_section(section_settings, sample_lines, section_no=index + 1))
        return b"".join(chunks)

    def _render_section(
        self,
        settings: BridgeSettings,
        sample_lines: tuple[str, ...],
        *,
        section_no: int,
    ) -> list[bytes]:
        chunks: list[bytes] = [_begin_document(settings)]
        chunks.extend(
            [
                _set_alignment("center"),
                _set_bold(True),
                _set_text_size(2, 2),
            ]
        )
        chunks.extend(self._lines(f"TURKCE TEST #{section_no}", settings))
        chunks.extend([_set_text_size(1, 1), _set_bold(False)])
        chunks.extend(self._lines(f"Encoding: {settings.encoding}", settings))
        chunks.extend(self._lines(f"Codepage: {settings.codepage}", settings))
        chunks.extend(self._lines("-" * self.width, settings))
        chunks.append(_set_alignment("left"))
        for line in sample_lines:
            chunks.extend(self._wrapped_lines(line, settings))
        chunks.extend(self._lines("-" * self.width, settings))
        chunks.extend([_feed(3), _cut(settings.cut_mode)])
        return chunks

    def _lines(self, text: str, settings: BridgeSettings) -> list[bytes]:
        if not text:
            return [b"\n"]
        result = []
        for line in text.splitlines():
            encoded, codec = encode_text(line, settings.encoding)
            if codec != settings.encoding:
                LOGGER.warning(
                    "diagnostic_encode: fallback codec=%s for encoding=%s codepage=%s",
                    codec,
                    settings.encoding,
                    settings.codepage,
                )
            result.append(encoded + b"\n")
        return result

    def _wrapped_lines(self, text: str, settings: BridgeSettings) -> list[bytes]:
        wrapped = textwrap.wrap(
            text,
            width=self.width,
            break_long_words=True,
            break_on_hyphens=False,
        )
        return self._lines("\n".join(wrapped or [""]), settings)
