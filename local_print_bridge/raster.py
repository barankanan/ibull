from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
import logging
from pathlib import Path
from typing import Iterable

from .config import BridgeSettings
from .models import KitchenItem, KitchenPayload, ReceiptItem, ReceiptPayload, _parse_datetime
from .receipt import _cut, _feed, _init_printer, resolve_receipt_table_label_lines

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:  # pragma: no cover - exercised only when Pillow is missing
    Image = None  # type: ignore[assignment]
    ImageDraw = None  # type: ignore[assignment]
    ImageFont = None  # type: ignore[assignment]
    _PIL_IMPORT_ERROR = exc
else:
    _PIL_IMPORT_ERROR = None

LOGGER = logging.getLogger("local_print_bridge")

ESC = b"\x1b"
GS = b"\x1d"

# Pre-computed byte inversion table for ESC/POS raster encoding.
# Pillow 1-bit: white=1, black=0.  ESC/POS: black=1, white=0.
_XOR_TABLE = bytes(b ^ 0xFF for b in range(256))

_FONT_CANDIDATES_REGULAR = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
)
_FONT_CANDIDATES_BOLD = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica Bold.ttc",
    "/Library/Fonts/Arial Bold.ttf",
)


def _require_pillow() -> None:
    if _PIL_IMPORT_ERROR is not None:
        raise RuntimeError(
            "Bitmap baski icin Pillow gerekir. "
            "local_print_bridge/requirements.txt icine Pillow eklendi; "
            "pip install -r local_print_bridge/requirements.txt calistirin."
        ) from _PIL_IMPORT_ERROR


def _paper_width_px(mm: int) -> int:
    if mm <= 58:
        return 384
    if mm <= 72:
        return 512
    return 576


# ── Font cache: avoid repeated disk I/O + FreeType init per print ─────────
_font_cache: dict[tuple[int, bool], "ImageFont.FreeTypeFont"] = {}

# All font sizes used by KitchenBitmapRenderer (bold + non-bold).
_KITCHEN_FONT_SPECS: list[tuple[int, bool]] = [
    (28, True),   # title
    (20, False),  # area, meta fields
    (22, True),   # item label
    (18, False),  # item note, plate label, child note
    (16, False),  # child note small
    (22, False),  # item label non-bold
    (20, True),   # meta bold
]


def _load_font(size: int, *, bold: bool) -> "ImageFont.FreeTypeFont":
    _require_pillow()
    key = (size, bold)
    cached = _font_cache.get(key)
    if cached is not None:
        return cached
    candidates = _FONT_CANDIDATES_BOLD if bold else _FONT_CANDIDATES_REGULAR
    for raw_path in candidates:
        path = Path(raw_path)
        if not path.exists():
            continue
        try:
            font = ImageFont.truetype(str(path), size=size)
            _font_cache[key] = font
            return font
        except OSError:
            continue
    try:
        fallback_name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
        font = ImageFont.truetype(fallback_name, size=size)
        _font_cache[key] = font
        return font
    except OSError as exc:
        raise RuntimeError(
            "Unicode destekli TTF font bulunamadi. "
            "DejaVu Sans veya Arial gibi bir fontun sistemde mevcut oldugundan emin olun."
        ) from exc


def warm_font_cache() -> int:
    """Pre-load all kitchen ticket fonts into cache.

    Call at bridge startup to eliminate cold-start font loading latency.
    Returns the number of fonts loaded.
    """
    _require_pillow()
    loaded = 0
    for size, bold in _KITCHEN_FONT_SPECS:
        key = (size, bold)
        if key not in _font_cache:
            try:
                _load_font(size, bold=bold)
                loaded += 1
            except RuntimeError:
                pass
    return loaded


@dataclass(frozen=True)
class RasterizedDocument:
    data: bytes
    width_px: int
    height_px: int
    chunk_count: int


@dataclass(frozen=True)
class _TextBlock:
    kind: str
    text: str = ""
    align: str = "left"
    bold: bool = False
    size: int = 22
    spacing_after: int = 6
    right_text: str = ""


class _BitmapRendererBase:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width_px = _paper_width_px(settings.paper_width_mm)
        self.margin_x = 12 if self.width_px <= 384 else 16
        self.top_padding = 8
        self.bottom_padding = 8
        self.content_width = self.width_px - (self.margin_x * 2)

    def _font(self, size: int, *, bold: bool = False) -> "ImageFont.FreeTypeFont":
        return _load_font(size, bold=bold)

    def _wrap_text(
        self,
        draw: "ImageDraw.ImageDraw",
        text: str,
        *,
        font: "ImageFont.FreeTypeFont",
        max_width: int,
    ) -> list[str]:
        normalized = " ".join(text.split())
        if not normalized:
            return [""]
        words = normalized.split(" ")
        lines: list[str] = []
        current = words[0]
        for word in words[1:]:
            candidate = f"{current} {word}"
            if draw.textlength(candidate, font=font) <= max_width:
                current = candidate
                continue
            lines.append(current)
            current = word
        lines.append(current)
        final_lines: list[str] = []
        for line in lines:
            if draw.textlength(line, font=font) <= max_width:
                final_lines.append(line)
                continue
            buffer = ""
            for char in line:
                candidate = f"{buffer}{char}"
                if buffer and draw.textlength(candidate, font=font) > max_width:
                    final_lines.append(buffer)
                    buffer = char
                else:
                    buffer = candidate
            if buffer:
                final_lines.append(buffer)
        return final_lines or [""]

    def _line_height(
        self,
        draw: "ImageDraw.ImageDraw",
        font: "ImageFont.FreeTypeFont",
    ) -> int:
        bbox = draw.textbbox((0, 0), "ÇĞİÖŞÜyg", font=font)
        return (bbox[3] - bbox[1]) + 2

    def _pair_lines(
        self,
        draw: "ImageDraw.ImageDraw",
        left: str,
        right: str,
        *,
        font: "ImageFont.FreeTypeFont",
    ) -> list[tuple[str, str]]:
        right_width = int(draw.textlength(right, font=font))
        available = max(40, self.content_width - right_width - 12)
        left_lines = self._wrap_text(draw, left, font=font, max_width=available)
        pairs = [(line, "") for line in left_lines[:-1]]
        pairs.append((left_lines[-1], right))
        return pairs

    def _build_image(self, blocks: Iterable[_TextBlock]) -> "Image.Image":
        _require_pillow()
        probe = Image.new("L", (self.width_px, 32), color=255)
        probe_draw = ImageDraw.Draw(probe)
        height = self.top_padding + self.bottom_padding
        prepared: list[tuple[_TextBlock, list[str] | list[tuple[str, str]], int, "ImageFont.FreeTypeFont"]] = []

        for block in blocks:
            font = self._font(block.size, bold=block.bold)
            line_height = self._line_height(probe_draw, font)
            if block.kind == "rule":
                height += 6 + block.spacing_after
                prepared.append((block, [], 6, font))
                continue
            if block.kind == "space":
                height += block.spacing_after
                prepared.append((block, [], block.spacing_after, font))
                continue
            if block.kind == "pair":
                lines = self._pair_lines(
                    probe_draw,
                    block.text,
                    block.right_text,
                    font=font,
                )
                height += (len(lines) * line_height) + block.spacing_after
                prepared.append((block, lines, line_height, font))
                continue
            lines = self._wrap_text(
                probe_draw,
                block.text,
                font=font,
                max_width=self.content_width,
            )
            height += (len(lines) * line_height) + block.spacing_after
            prepared.append((block, lines, line_height, font))

        image = Image.new("L", (self.width_px, max(height, 32)), color=255)
        draw = ImageDraw.Draw(image)
        y = self.top_padding

        for block, lines, line_height, font in prepared:
            if block.kind == "space":
                y += block.spacing_after
                continue
            if block.kind == "rule":
                y += 2
                draw.line(
                    (self.margin_x, y, self.width_px - self.margin_x, y),
                    fill=0,
                    width=1,
                )
                y += 4 + block.spacing_after
                continue
            if block.kind == "pair":
                for left, right in lines:  # type: ignore[assignment]
                    draw.text((self.margin_x, y), left, font=font, fill=0)
                    if right:
                        right_width = draw.textlength(right, font=font)
                        draw.text(
                            (self.width_px - self.margin_x - right_width, y),
                            right,
                            font=font,
                            fill=0,
                        )
                    y += line_height
                y += block.spacing_after
                continue

            for line in lines:  # type: ignore[assignment]
                line_width = draw.textlength(line, font=font)
                if block.align == "center":
                    x = (self.width_px - line_width) / 2
                elif block.align == "right":
                    x = self.width_px - self.margin_x - line_width
                else:
                    x = self.margin_x
                draw.text((x, y), line, font=font, fill=0)
                y += line_height
            y += block.spacing_after
        return image

    def _format_money(self, value: Decimal, currency: str) -> str:
        # Default formatting (no grouping). Kept for backward compatibility with
        # existing callers; prefer _format_money_tr() for receipts.
        normalized = f"{value.quantize(Decimal('0.01'))}".replace(".", ",")
        suffix = "TL" if currency.upper() in {"TRY", "TL"} else currency.upper()
        return f"{normalized} {suffix}"

    def _format_money_tr(self, value: Decimal, currency: str) -> str:
        """Turkish money formatting with thousands separator.

        Example: 4520 -> "4.520,00 TL"
        """
        quantized = value.quantize(Decimal("0.01"))
        # format(..., ",.2f") => "4,520.00" then swap separators.
        raw = format(quantized, ",.2f")
        normalized = raw.replace(",", "X").replace(".", ",").replace("X", ".")
        suffix = "TL" if currency.upper() in {"TRY", "TL"} else currency.upper()
        return f"{normalized} {suffix}"

    def _format_quantity(self, value: Decimal) -> str:
        if value == value.to_integral():
            return str(int(value))
        return format(value.normalize(), "f").rstrip("0").rstrip(".")


class ReceiptBitmapRenderer(_BitmapRendererBase):
    def _resolve_grand_total(self, payload: ReceiptPayload) -> tuple[Decimal | None, str]:
        # Keep parity with ReceiptRenderer._resolve_grand_total().
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

    def _debug_header_lines(
        self,
        payload: ReceiptPayload,
        *,
        final_table_line: str,
    ) -> dict[str, str]:
        receipt_datetime = ""
        try:
            receipt_datetime = payload.date_time.strftime("%d.%m.%Y %H:%M")
        except Exception:
            receipt_datetime = ""
        final_date_line = f"Tarih: {receipt_datetime}" if receipt_datetime else "Tarih: -"

        total_value, total_source = self._resolve_grand_total(payload)
        formatted_total = (
            self._format_money_tr(total_value, payload.currency) if total_value is not None else "-"
        )
        final_total_line = (
            f"GENEL TOPLAM: {formatted_total}" if total_value is not None else "GENEL TOPLAM: -"
        )

        return {
            "table_label": final_table_line.replace("Masa: ", "", 1) if final_table_line else "-",
            "receipt_datetime": receipt_datetime or "-",
            "grand_total": formatted_total,
            "total_source": total_source,
            "final_date_line": final_date_line,
            "final_total_line": final_total_line,
        }

    def render(self, payload: ReceiptPayload) -> "Image.Image":
        blocks: list[_TextBlock] = [
            _TextBlock("text", payload.store_name.upper(), align="center", bold=True, size=34, spacing_after=4),
        ]
        if payload.branch:
            blocks.append(_TextBlock("text", payload.branch, align="center", size=22, spacing_after=2))
        if payload.phone:
            blocks.append(_TextBlock("text", f"Tel: {payload.phone}", align="center", size=20, spacing_after=6))
        blocks.append(_TextBlock("rule", spacing_after=8))
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
        if final_table_line:
            blocks.append(_TextBlock("text", final_table_line, size=22, spacing_after=4))

        header_debug = self._debug_header_lines(payload, final_table_line=final_table_line or "")
        blocks.append(_TextBlock("text", header_debug["final_date_line"], size=22, spacing_after=8))
        blocks.append(_TextBlock("rule", spacing_after=8))
        for item in payload.items:
            blocks.extend(self._item_blocks(item, payload.currency))
        blocks.append(_TextBlock("rule", spacing_after=8))

        LOGGER.info(
            "[RECEIPT_RENDER_HEADER_TOTAL] table_label=%s receipt_datetime=%s grand_total=%s total_source=%s render_mode=%s "
            "final_date_line=%s final_total_line=%s will_draw_lines=%s",
            header_debug["table_label"],
            header_debug["receipt_datetime"],
            header_debug["grand_total"],
            header_debug["total_source"],
            str(getattr(self.settings, "render_mode", "") or "-"),
            header_debug["final_date_line"],
            header_debug["final_total_line"],
            "yes",
        )
        if header_debug["grand_total"] != "-" and header_debug["final_total_line"] != "GENEL TOPLAM: -":
            blocks.append(_TextBlock("text", header_debug["final_total_line"], size=26, bold=True, spacing_after=8))
        if payload.footer_note:
            blocks.append(_TextBlock("rule", spacing_after=8))
            blocks.append(
                _TextBlock(
                    "text",
                    payload.footer_note,
                    align="center",
                    size=20,
                    spacing_after=0,
                )
            )
        return self._build_image(blocks)

    def _item_blocks(self, item: ReceiptItem, currency: str) -> list[_TextBlock]:
        blocks = [
            _TextBlock(
                "pair",
                f"{self._format_quantity(item.quantity)} x {item.name}",
                right_text=self._format_money(item.line_total, currency),
                size=22,
                spacing_after=2,
            )
        ]
        if item.note:
            blocks.append(_TextBlock("text", f"Not: {item.note}", size=20, spacing_after=2))
        if item.unit_price is not None:
            blocks.append(
                _TextBlock(
                    "text",
                    f"Birim: {self._format_money(item.unit_price, currency)}",
                    size=20,
                    spacing_after=6,
                )
            )
        else:
            blocks.append(_TextBlock("space", spacing_after=6))
        return blocks


class KitchenBitmapRenderer(_BitmapRendererBase):
    _JOB_TYPE_LABELS = {
        "new_order": "YENİ SİPARİŞ",
        "add_item": "EKLEME",
        "cancel_item": "İPTAL",
        "reprint": "TEKRAR BASKI",
    }

    def render(self, payload: KitchenPayload) -> "Image.Image":
        title = self._JOB_TYPE_LABELS.get(payload.job_type, payload.title or "MUTFAK SİPARİŞİ")
        blocks: list[_TextBlock] = [
            _TextBlock("text", title, align="center", bold=True, size=28, spacing_after=2),
        ]
        if payload.area_name:
            blocks.append(_TextBlock("text", payload.area_name.upper(), align="center", bold=True, size=20, spacing_after=2))
        blocks.append(_TextBlock("rule", spacing_after=4))
        daily_no = getattr(payload, "daily_order_no", 0) or 0
        kitchen_no = getattr(payload, "kitchen_order_no", 0) or 0
        order_no = str(getattr(payload, "order_no", "") or "").strip()
        order_number = str(getattr(payload, "order_number", "") or "").strip()
        order_id = str(getattr(payload, "order_id", "") or "").strip()
        if daily_no > 0:
            order_label = str(daily_no)
        elif kitchen_no > 0:
            order_label = str(kitchen_no)
        elif order_no and order_no != "-":
            order_label = order_no
        elif order_number:
            order_label = order_number
        else:
            order_label = order_id[:8] if order_id else "-"

        table_label = str(getattr(payload, "table_name", "") or "").strip()
        if not table_label:
            table_label = f"Masa {str(getattr(payload, 'table_no', '') or '').strip()}".strip()
        final_table_line = f"Masa: {table_label}".strip() if table_label else ""
        if final_table_line.strip() == "Masa:" or final_table_line.strip() == "Masa":
            final_table_line = ""

        blocks.append(_TextBlock("text", f"Sipariş No: {order_label}", size=20, spacing_after=2))
        if final_table_line:
            blocks.append(_TextBlock("text", final_table_line, size=20, spacing_after=2))
        if payload.waiter_name:
            blocks.append(_TextBlock("pair", "Garson", right_text=payload.waiter_name, size=20, spacing_after=2))
        header_debug = self._debug_header_lines(payload, order_label=order_label, table_label=table_label)
        LOGGER.info(
            "[KITCHEN_RENDER_HEADER] order_no=%s table_label=%s kitchen_datetime=%s time_source=%s render_mode=%s "
            "final_datetime_line=%s will_draw_lines=%s",
            header_debug["order_no"],
            header_debug["table_label"],
            header_debug["kitchen_datetime"],
            header_debug["time_source"],
            str(getattr(self.settings, "render_mode", "") or "-"),
            header_debug["final_datetime_line"],
            "yes",
        )
        blocks.append(_TextBlock("text", header_debug["final_datetime_line"], size=20, spacing_after=4))
        blocks.append(_TextBlock("rule", spacing_after=4))
        for item in payload.items:
            blocks.extend(self._item_blocks(item))
        return self._build_image(blocks)

    def _debug_header_lines(
        self,
        payload: KitchenPayload,
        *,
        order_label: str,
        table_label: str,
    ) -> dict[str, str]:
        printed_at = str(getattr(payload, "printed_at", "") or "").strip()
        kitchen_printed_at = str(getattr(payload, "kitchen_printed_at", "") or "").strip()
        order_created_at = str(getattr(payload, "order_created_at", "") or "").strip()
        created_at = str(getattr(payload, "created_at", "") or "").strip()
        raw_time = printed_at or kitchen_printed_at or order_created_at or created_at
        if raw_time:
            kitchen_dt = _parse_datetime(raw_time)
            time_source = (
                "printed_at"
                if printed_at
                else (
                    "kitchen_printed_at"
                    if kitchen_printed_at
                    else ("order_created_at" if order_created_at else "created_at")
                )
            )
        else:
            kitchen_dt = getattr(payload, "date_time", None)
            time_source = "date_time"
        kitchen_datetime_text = kitchen_dt.strftime("%d.%m.%Y %H:%M") if kitchen_dt else ""
        final_datetime_line = f"Tarih: {kitchen_datetime_text}" if kitchen_datetime_text else "Tarih: -"
        return {
            "order_no": order_label or "-",
            "table_label": table_label or "-",
            "kitchen_datetime": kitchen_datetime_text or "-",
            "time_source": time_source,
            "final_datetime_line": final_datetime_line,
        }

    def _item_blocks(self, item: KitchenItem) -> list[_TextBlock]:
        label = f"{item.quantity}x  {item.name}"
        if item.amount_label:
            label += f" {item.amount_label}"
        blocks = [_TextBlock("text", label, size=22, bold=True, spacing_after=1)]
        if item.note:
            blocks.append(_TextBlock("text", f"Not: {item.note}", size=18, spacing_after=1))
        for plate in item.plates:
            blocks.append(_TextBlock("text", plate.label, size=18, bold=True, spacing_after=1))
            for child in plate.items:
                child_label = f"- {child.quantity}x {child.name}"
                if child.amount_label:
                    child_label += f" {child.amount_label}"
                blocks.append(_TextBlock("text", child_label, size=18, spacing_after=1))
                if child.note:
                    blocks.append(_TextBlock("text", f"  Not: {child.note}", size=16, spacing_after=1))
        for child in item.service_children:
            child_label = f"- {child.quantity}x {child.name}"
            if child.amount_label:
                child_label += f" {child.amount_label}"
            blocks.append(_TextBlock("text", child_label, size=18, spacing_after=1))
            if child.note:
                blocks.append(_TextBlock("text", f"  Not: {child.note}", size=16, spacing_after=1))
        blocks.append(_TextBlock("space", spacing_after=4))
        return blocks


class RasterEscPosEncoder:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings

    def encode(self, image: "Image.Image") -> RasterizedDocument:
        _require_pillow()
        if image.mode != "1":
            grayscale = image.convert("L")
            image = grayscale.point(lambda value: 0 if value < 180 else 255, mode="1")
        width_px, height_px = image.size
        # Use large chunk height to minimise the number of GS v0 commands and
        # USB round-trips.  Ideally the entire image fits in a single chunk.
        chunk_height = max(256, self.settings.raster_chunk_height)
        chunks: list[bytes] = [_init_printer()]
        chunk_count = 0
        for top in range(0, height_px, chunk_height):
            bottom = min(top + chunk_height, height_px)
            chunk = image.crop((0, top, width_px, bottom))
            chunks.append(self._encode_chunk(chunk))
            chunk_count += 1
        chunks.append(_feed(3))
        chunks.append(_cut(self.settings.cut_mode))
        return RasterizedDocument(
            data=b"".join(chunks),
            width_px=width_px,
            height_px=height_px,
            chunk_count=chunk_count,
        )

    def _encode_chunk(self, image: "Image.Image") -> bytes:
        """Encode a 1-bit image chunk as ESC/POS raster data.

        Uses Pillow's tobytes() for bulk bit-packing instead of pixel-by-pixel
        Python loops.  This is 20-50x faster for typical ticket sizes.
        """
        width_px, height_px = image.size
        width_bytes = (width_px + 7) // 8

        # Pillow 1-bit "raw" mode "1": MSB first, rows padded to byte boundary.
        # Pillow: white=1, black=0.  ESC/POS: black=1, white=0.  → XOR 0xFF.
        raw = image.tobytes("raw", "1")

        # Fast XOR inversion using pre-computed translate table.
        packed = raw.translate(_XOR_TABLE)

        # Safety: if Pillow stride != expected width_bytes, rebuild row-by-row.
        pillow_stride = len(raw) // height_px if height_px else width_bytes
        if pillow_stride != width_bytes:
            rows = bytearray()
            for y in range(height_px):
                row_start = y * pillow_stride
                row = raw[row_start : row_start + width_bytes]
                if len(row) < width_bytes:
                    row += b"\x00" * (width_bytes - len(row))
                rows.extend(row)
            packed = bytes(rows).translate(_XOR_TABLE)

        return (
            GS
            + b"v0"
            + bytes(
                [
                    0,
                    width_bytes & 0xFF,
                    (width_bytes >> 8) & 0xFF,
                    height_px & 0xFF,
                    (height_px >> 8) & 0xFF,
                ]
            )
            + packed
        )
