from __future__ import annotations

from decimal import Decimal
import logging
import textwrap

from .config import BridgeSettings
from .models import ReceiptItem, ReceiptPayload


ESC = b"\x1b"
GS = b"\x1d"
TURKISH_TEST_LINES = (
    "Türkçe Test: ığüşöç İĞÜŞÖÇ",
    "Ürün: Çiğ Köfte, Tavuk Şiş, Kıyma Dürüm",
    "Not: az pişmiş, soğansız, acısız",
)

LOGGER = logging.getLogger("local_print_bridge")

# Fallback chain for Turkish text: try each codec in order.
# Never fall back to utf-8 — raw UTF-8 bytes confuse most ESC/POS devices.
_TURKISH_CODEC_FALLBACKS = ("cp857", "cp1254", "iso8859_9", "cp437")


def encode_text_report(text: str, encoding: str) -> tuple[bytes, str, list[str], list[str]]:
    """Strict-first encode; logs unmappable characters, never emits raw UTF-8."""
    issues: list[str] = []
    unsupported_chars: list[str] = []
    try:
        return text.encode(encoding, errors="strict"), encoding, issues, unsupported_chars
    except UnicodeEncodeError as exc:
        unsupported_chars.extend(list(text[exc.start : exc.end]))
        start = max(exc.start - 8, 0)
        end = min(exc.end + 8, len(text))
        snippet = text[start:end]
        issues.append(
            f"unmappable@{exc.start}:{exc.end} codec={encoding} snippet={snippet!r}"
        )
        LOGGER.warning(
            "encode_text_report: strict encode failed encoding=%s %s unsupported_chars=%r",
            encoding,
            issues[-1],
            "".join(unsupported_chars),
        )
    for codec in _TURKISH_CODEC_FALLBACKS:
        if codec == encoding:
            continue
        try:
            encoded = text.encode(codec, errors="strict")
            issues.append(f"fallback_codec={codec}")
            LOGGER.warning(
                "encode_text_report: using fallback codec=%s instead of %s issues=%s unsupported_chars=%r",
                codec,
                encoding,
                issues,
                "".join(unsupported_chars),
            )
            return encoded, codec, issues, unsupported_chars
        except (UnicodeEncodeError, LookupError):
            continue
    issues.append("replace_fallback=cp437")
    LOGGER.error(
        "encode_text_report: all codecs failed encoding=%s text_preview=%.60r issues=%s unsupported_chars=%r",
        encoding,
        text,
        issues,
        "".join(unsupported_chars),
    )
    return text.encode("cp437", errors="replace"), "cp437(replace)", issues, unsupported_chars


def encode_text(text: str, encoding: str) -> tuple[bytes, str]:
    """Encode *text* using *encoding*; see ``encode_text_report`` for logging."""
    encoded, codec, issues, _unsupported = encode_text_report(text, encoding)
    if issues and codec != encoding:
        LOGGER.warning(
            "encode_text: encoding=%s selected_codec=%s issues=%s",
            encoding,
            codec,
            " | ".join(issues),
        )
    return encoded, codec


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
    return ESC + b"t" + bytes([table & 0xFF])


def _set_charset(charset: int) -> bytes:
    return ESC + b"R" + bytes([charset & 0xFF])


def _begin_document(settings: BridgeSettings) -> bytes:
    chunks = [_init_printer()]
    esc_r = getattr(settings, "esc_r", None)
    if esc_r is not None:
        chunks.append(_set_charset(int(esc_r)))
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
        encoded, codec, issues, unsupported_chars = encode_text_report(
            text, self.settings.encoding
        )
        if issues or unsupported_chars:
            LOGGER.warning(
                "print_encoding_unsupported: printer_name=%s encoding=%s codepage=%s "
                "unsupported_chars=%r issues=%s line=%.80r",
                self.settings.printer_queue or "-",
                self.settings.encoding,
                self.settings.codepage,
                "".join(unsupported_chars),
                " | ".join(issues),
                text,
            )
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


def render_turkish_encoding_calibration_ticket(
    base_settings: BridgeSettings,
    *,
    encoding: str,
    codepage: int,
    label: str,
    sample_lines: tuple[str, ...] = TURKISH_TEST_LINES,
) -> tuple[bytes, list[str]]:
    """Single ESC/POS text ticket for one encoding/codepage candidate."""
    section_settings = BridgeSettings(
        host=base_settings.host,
        port=base_settings.port,
        printer_queue=base_settings.printer_queue,
        paper_width_mm=base_settings.paper_width_mm,
        chars_per_line=base_settings.chars_per_line,
        encoding=encoding,
        codepage=codepage,
        render_mode="text",
        raster_chunk_height=base_settings.raster_chunk_height,
        allowed_origins=base_settings.allowed_origins,
        healthcheck_queue=base_settings.healthcheck_queue,
        cut_mode=base_settings.cut_mode,
        transport_mode=base_settings.transport_mode,
        usb_vendor_id=base_settings.usb_vendor_id,
        usb_product_id=base_settings.usb_product_id,
        network_host=base_settings.network_host,
        network_port=base_settings.network_port,
    )
    renderer = TurkishCodepageDiagnosticRenderer(section_settings)
    unsupported_chars: list[str] = []
    for line in sample_lines:
        _, _, _, line_unsupported = encode_text_report(line, encoding)
        unsupported_chars.extend(line_unsupported)
    unique_unsupported = list(dict.fromkeys(unsupported_chars))
    chunks: list[bytes] = [_begin_document(section_settings)]
    chunks.extend(
        [
            _set_alignment("center"),
            _set_bold(True),
            _set_text_size(1, 1),
        ]
    )
    chunks.extend(renderer._lines(label, section_settings))
    chunks.extend(renderer._lines(f"Encoding: {encoding}", section_settings))
    chunks.extend(renderer._lines(f"Codepage ESC t {codepage}", section_settings))
    chunks.extend(renderer._lines("-" * renderer.width, section_settings))
    chunks.append(_set_alignment("left"))
    for line in sample_lines:
        chunks.extend(renderer._wrapped_lines(line, section_settings))
    chunks.extend(renderer._lines("-" * renderer.width, section_settings))
    chunks.extend([_feed(3), _cut(section_settings.cut_mode)])
    return b"".join(chunks), unique_unsupported


def render_turkish_encoding_combined_calibration_ticket(
    base_settings: BridgeSettings,
    *,
    candidates: list[dict[str, object]],
    test_line: str | None = None,
) -> tuple[bytes, list[str]]:
    """Print every encoding/codepage option on one receipt (numbered lines)."""
    primary_line = (test_line or TURKISH_TEST_LINES[0]).strip()
    unsupported_chars: list[str] = []
    chunks: list[bytes] = [_init_printer(), _set_alignment("center"), _set_bold(True)]
    header_renderer = TurkishCodepageDiagnosticRenderer(
        BridgeSettings(
            host=base_settings.host,
            port=base_settings.port,
            printer_queue=base_settings.printer_queue,
            paper_width_mm=base_settings.paper_width_mm,
            chars_per_line=base_settings.chars_per_line,
            encoding="cp857",
            codepage=13,
            render_mode="text",
            raster_chunk_height=base_settings.raster_chunk_height,
            allowed_origins=base_settings.allowed_origins,
            healthcheck_queue=base_settings.healthcheck_queue,
            cut_mode=base_settings.cut_mode,
            transport_mode=base_settings.transport_mode,
            usb_vendor_id=base_settings.usb_vendor_id,
            usb_product_id=base_settings.usb_product_id,
            network_host=base_settings.network_host,
            network_port=base_settings.network_port,
        )
    )
    chunks.extend(header_renderer._lines("TURKCE KARAKTER TESTI", header_renderer.settings))
    chunks.extend(header_renderer._lines("Tum secenekler tek fiste", header_renderer.settings))
    chunks.extend(header_renderer._lines("-" * header_renderer.width, header_renderer.settings))
    chunks.append(_set_alignment("left"))
    chunks.append(_set_bold(False))

    for index, candidate in enumerate(candidates, start=1):
        encoding = str(candidate.get("encoding") or "cp857").strip()
        codepage_raw = candidate.get("code_page", candidate.get("codepage"))
        try:
            codepage = int(codepage_raw) if codepage_raw is not None else 13
        except (TypeError, ValueError):
            codepage = 13
        esc_r_raw = candidate.get("esc_r_value", candidate.get("esc_r"))
        esc_r: int | None
        try:
            esc_r = int(esc_r_raw) if esc_r_raw is not None else None
        except (TypeError, ValueError):
            esc_r = None
        raw_lines = candidate.get("lines")
        if isinstance(raw_lines, list) and raw_lines:
            block_lines = [str(line).strip() for line in raw_lines if str(line).strip()]
        else:
            esc_r_suffix = f" / ESC R {esc_r}" if esc_r is not None else ""
            block_lines = [
                str(
                    candidate.get("line")
                    or f"[{index}] {encoding} / ESC t {codepage}{esc_r_suffix}"
                ).strip(),
                primary_line,
                TURKISH_TEST_LINES[1] if len(TURKISH_TEST_LINES) > 1 else "",
                TURKISH_TEST_LINES[2] if len(TURKISH_TEST_LINES) > 2 else "",
            ]
            block_lines = [line for line in block_lines if line]
        section_settings = BridgeSettings(
            host=base_settings.host,
            port=base_settings.port,
            printer_queue=base_settings.printer_queue,
            paper_width_mm=base_settings.paper_width_mm,
            chars_per_line=base_settings.chars_per_line,
            encoding=encoding,
            codepage=codepage,
            esc_r=esc_r,
            render_mode="text",
            raster_chunk_height=base_settings.raster_chunk_height,
            allowed_origins=base_settings.allowed_origins,
            healthcheck_queue=base_settings.healthcheck_queue,
            cut_mode=base_settings.cut_mode,
            transport_mode=base_settings.transport_mode,
            usb_vendor_id=base_settings.usb_vendor_id,
            usb_product_id=base_settings.usb_product_id,
            network_host=base_settings.network_host,
            network_port=base_settings.network_port,
        )
        chunks.append(_init_printer())
        if esc_r is not None:
            chunks.append(_set_charset(esc_r))
        chunks.append(_set_codepage(codepage))
        chunks.append(_set_alignment("left"))
        for line in block_lines:
            for wrapped in textwrap.wrap(
                line,
                width=section_settings.chars_per_line,
                break_long_words=True,
                break_on_hyphens=False,
            ):
                encoded, _, _, line_unsupported = encode_text_report(wrapped, encoding)
                unsupported_chars.extend(line_unsupported)
                chunks.append(encoded + b"\n")
        chunks.append(b"\n")

    chunks.extend([_feed(4), _cut(base_settings.cut_mode)])
    return b"".join(chunks), list(dict.fromkeys(unsupported_chars))


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
            encoded, codec, issues, unsupported_chars = encode_text_report(
                line, settings.encoding
            )
            if issues or unsupported_chars:
                LOGGER.warning(
                    "diagnostic_encode: encoding=%s codepage=%s unsupported_chars=%r issues=%s",
                    settings.encoding,
                    settings.codepage,
                    "".join(unsupported_chars),
                    " | ".join(issues),
                )
            elif codec != settings.encoding:
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
