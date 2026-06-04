from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
import logging
from pathlib import Path
from typing import Iterable

from .config import BridgeSettings, default_raster_width_px
from .models import KitchenItem, KitchenPayload, ReceiptItem, ReceiptPayload, _parse_datetime
from .pillow_probe import probe_pillow
from .receipt import _cut, _feed, _init_printer, resolve_receipt_table_label_lines

Image = None  # type: ignore[assignment]
ImageDraw = None  # type: ignore[assignment]
ImageFont = None  # type: ignore[assignment]
_PIL_IMPORT_ERROR: BaseException | None = None
_PIL_LOADED = False


def _load_pil(*, force: bool = False) -> None:
    global Image, ImageDraw, ImageFont, _PIL_IMPORT_ERROR, _PIL_LOADED
    if _PIL_LOADED and not force and _PIL_IMPORT_ERROR is None:
        return
    try:
        from PIL import Image as _Image
        from PIL import ImageDraw as _ImageDraw
        from PIL import ImageFont as _ImageFont

        Image = _Image
        ImageDraw = _ImageDraw
        ImageFont = _ImageFont
        _PIL_IMPORT_ERROR = None
        _PIL_LOADED = True
    except ImportError as exc:
        Image = None
        ImageDraw = None
        ImageFont = None
        _PIL_IMPORT_ERROR = exc
        _PIL_LOADED = True


_load_pil()

LOGGER = logging.getLogger("local_print_bridge")

ESC = b"\x1b"
GS = b"\x1d"

# Pre-computed byte inversion table for ESC/POS raster encoding.
# Pillow 1-bit: white=1, black=0.  ESC/POS: black=1, white=0.
_XOR_TABLE = bytes(b ^ 0xFF for b in range(256))

def _bundled_font_candidates(filename: str) -> tuple[str, ...]:
    import sys

    paths: list[str] = []
    bridge_fonts = Path(__file__).resolve().parent / "fonts" / filename
    paths.append(str(bridge_fonts))
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        for rel in (("fonts", filename), ("local_print_bridge", "fonts", filename)):
            candidate = Path(meipass).joinpath(*rel)
            paths.append(str(candidate))
    return tuple(paths)


_BUNDLED_MONO_REGULAR = "DejaVuSansMono.ttf"
_BUNDLED_MONO_BOLD = "DejaVuSansMono-Bold.ttf"

_FONT_CANDIDATES_REGULAR = (
    *_bundled_font_candidates("DejaVuSans.ttf"),
    *_bundled_font_candidates(_BUNDLED_MONO_REGULAR),
    "C:/Windows/Fonts/arial.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
)
_FONT_CANDIDATES_BOLD = (
    *_bundled_font_candidates("DejaVuSans-Bold.ttf"),
    *_bundled_font_candidates(_BUNDLED_MONO_BOLD),
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica Bold.ttc",
    "/Library/Fonts/Arial Bold.ttf",
)
_GUARANTEE_FONT_CANDIDATES_REGULAR = _bundled_font_candidates(_BUNDLED_MONO_REGULAR)
_GUARANTEE_FONT_CANDIDATES_BOLD = _bundled_font_candidates(_BUNDLED_MONO_BOLD)


def _require_pillow() -> None:
    _load_pil(force=True)
    status = probe_pillow()
    if status.get("pillow_available") is True and Image is not None:
        return
    detail = status.get("import_error") or (
        str(_PIL_IMPORT_ERROR) if _PIL_IMPORT_ERROR is not None else "Pillow import failed"
    )
    raise RuntimeError(
        "Bitmap baski icin Pillow gerekir. "
        "local_print_bridge/requirements.txt icine Pillow eklendi; "
        "pip install -r local_print_bridge/requirements.txt calistirin. "
        f"python={status.get('python_executable')} "
        f"pillow_available={status.get('pillow_available')} "
        f"import_error={detail}"
    ) from (_PIL_IMPORT_ERROR or ImportError(str(detail)))


def _paper_width_px(mm: int) -> int:
    if mm <= 58:
        return 384
    if mm <= 72:
        return 512
    return 576


# ── Font cache: avoid repeated disk I/O + FreeType init per print ─────────
_font_cache: dict[tuple[int, bool, bool], "ImageFont.FreeTypeFont"] = {}
_bundled_mono_font_path: str | None = None
_bundled_mono_bold_font_path: str | None = None

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


class BundledFontMissingError(RuntimeError):
    """Raised when Turkish Guarantee Mode cannot find bundled mono fonts."""

    error_code = "bundled_font_missing"


def resolve_bundled_mono_font_path(*, bold: bool = False) -> str:
    """Return cached path to bundled DejaVu Sans Mono (guarantee mode only)."""
    global _bundled_mono_font_path, _bundled_mono_bold_font_path
    cached = _bundled_mono_bold_font_path if bold else _bundled_mono_font_path
    if cached is not None and Path(cached).exists():
        return cached
    filename = _BUNDLED_MONO_BOLD if bold else _BUNDLED_MONO_REGULAR
    for raw_path in _bundled_font_candidates(filename):
        path = Path(raw_path)
        if path.exists():
            resolved = str(path)
            if bold:
                _bundled_mono_bold_font_path = resolved
            else:
                _bundled_mono_font_path = resolved
            return resolved
    raise BundledFontMissingError(
        "bundled_font_missing: "
        f"local_print_bridge/fonts/{filename} bulunamadi. "
        "Bridge kurulumunda Turkce Garanti Modu fontlari eksik."
    )


def bundled_mono_font_status() -> dict[str, object]:
    """Diagnostics for /health and warmup."""
    status: dict[str, object] = {
        "regular": None,
        "bold": None,
        "regular_exists": False,
        "bold_exists": False,
    }
    try:
        regular = resolve_bundled_mono_font_path(bold=False)
        status["regular"] = regular
        status["regular_exists"] = True
    except BundledFontMissingError:
        pass
    try:
        bold = resolve_bundled_mono_font_path(bold=True)
        status["bold"] = bold
        status["bold_exists"] = True
    except BundledFontMissingError:
        pass
    return status


def _settings_guarantee_mode(settings: BridgeSettings | None) -> bool:
    return bool(getattr(settings, "turkish_guarantee_mode", False))


def _load_font(
    size: int,
    *,
    bold: bool,
    settings: BridgeSettings | None = None,
) -> "ImageFont.FreeTypeFont":
    _require_pillow()
    guarantee = _settings_guarantee_mode(settings)
    key = (size, bold, guarantee)
    cached = _font_cache.get(key)
    if cached is not None:
        return cached
    if guarantee:
        font_path = resolve_bundled_mono_font_path(bold=bold)
        try:
            font = ImageFont.truetype(font_path, size=size)
            _font_cache[key] = font
            return font
        except OSError as exc:
            raise BundledFontMissingError(
                f"bundled_font_missing: {font_path} yuklenemedi ({exc})"
            ) from exc
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


def warm_font_cache(*, guarantee: bool = True) -> int:
    """Pre-load ticket fonts into cache (guarantee mono fonts by default).

    Call at bridge startup to eliminate cold-start font loading latency.
    Returns the number of fonts loaded.
    """
    _require_pillow()
    loaded = 0
    if guarantee:
        try:
            resolve_bundled_mono_font_path(bold=False)
            resolve_bundled_mono_font_path(bold=True)
        except BundledFontMissingError as exc:
            LOGGER.warning("Guarantee font warm-up skipped: %s", exc)
    for size, bold in _KITCHEN_FONT_SPECS:
        cache_key = (size, bold, guarantee)
        if cache_key not in _font_cache:
            try:
                stub_settings = BridgeSettings(
                    host="127.0.0.1",
                    port=3001,
                    printer_queue="",
                    paper_width_mm=58,
                    chars_per_line=32,
                    encoding="cp857",
                    codepage=13,
                    render_mode="image",
                    raster_chunk_height=256,
                    allowed_origins=(),
                    healthcheck_queue=False,
                    cut_mode="partial",
                    transport_mode="auto",
                    network_host="",
                    network_port=9100,
                    turkish_guarantee_mode=guarantee,
                )
                _load_font(size, bold=bold, settings=stub_settings)
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
    chunk_heights: tuple[int, ...] = ()


@dataclass(frozen=True)
class RasterChunk:
    index: int
    total: int
    width_px: int
    height_px: int
    source_height_px: int
    bytes_per_row: int
    data_len: int
    command_len: int
    command: str


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
        configured_width = getattr(settings, "raster_width_px", None)
        self.width_px = configured_width or _paper_width_px(settings.paper_width_mm)
        self.margin_x = 12 if self.width_px <= 384 else 16
        self.top_padding = 8
        self.bottom_padding = 8
        self.content_width = self.width_px - (self.margin_x * 2)

    def _font(self, size: int, *, bold: bool = False) -> "ImageFont.FreeTypeFont":
        return _load_font(size, bold=bold, settings=self.settings)

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
        image = self._build_image(blocks)
        LOGGER.info(
            "[ReceiptLayout][summary] items=%d blocks=%d estimatedHeight=%d paperWidthPx=%d charsPerLine=%d",
            len(payload.items),
            len(blocks),
            image.size[1],
            self.width_px,
            self.settings.chars_per_line,
        )
        return image

    def _item_blocks(self, item: ReceiptItem, currency: str) -> list[_TextBlock]:
        blocks = [
            _TextBlock(
                "pair",
                f"{self._format_quantity(item.quantity)} x {item.name}",
                right_text=self._format_money(item.line_total, currency),
                size=22,
                spacing_after=1,
            )
        ]
        if item.note:
            blocks.append(_TextBlock("text", f"Not: {item.note}", size=20, spacing_after=2))
        else:
            blocks.append(_TextBlock("space", spacing_after=3))
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
        image = self._build_image(blocks)
        LOGGER.info(
            "[KitchenLayout][summary] items=%d blocks=%d estimatedHeight=%d paperWidthPx=%d charsPerLine=%d",
            len(payload.items),
            len(blocks),
            image.size[1],
            self.width_px,
            self.settings.chars_per_line,
        )
        return image

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
        image = self._normalize_image(image)
        width_px, height_px = image.size
        chunks: list[bytes] = [_init_printer()]
        chunk_count = 0
        chunk_heights: list[int] = []
        raster_mode = str(getattr(self.settings, "raster_mode", "gs_v_0") or "gs_v_0").strip().lower()
        chunk_plan = self._chunk_plan_for_mode(height_px, raster_mode)
        total_chunks = len(chunk_plan)
        for index, (top, bottom) in enumerate(chunk_plan, start=1):
            chunk = image.crop((0, top, width_px, bottom))
            command, meta = self._encode_chunk(
                chunk,
                raster_mode=raster_mode,
                index=index,
                total=total_chunks,
            )
            chunk_heights.append(meta.source_height_px)
            LOGGER.info(
                "[PrintRender][raster_chunk] index=%d total=%d widthPx=%d heightPx=%d sourceHeightPx=%d bytesPerRow=%d dataLen=%d commandLen=%d command=%s",
                meta.index,
                meta.total,
                meta.width_px,
                meta.height_px,
                meta.source_height_px,
                meta.bytes_per_row,
                meta.data_len,
                meta.command_len,
                meta.command,
            )
            chunks.append(command)
            chunk_count += 1
        chunks.append(_feed(3))
        chunks.append(_cut(self.settings.cut_mode))
        return RasterizedDocument(
            data=b"".join(chunks),
            width_px=width_px,
            height_px=height_px,
            chunk_count=chunk_count,
            chunk_heights=tuple(chunk_heights),
        )

    def build_gs_v0_raster(self, image: "Image.Image") -> bytes:
        return self._build_gs_v0_command(self._normalize_image(image))[0]

    def build_esc_star_raster(self, image: "Image.Image") -> bytes:
        return self._build_esc_star_command(self._normalize_image(image))[0]

    def _normalize_image(self, image: "Image.Image") -> "Image.Image":
        if image.mode != "1":
            grayscale = image.convert("L")
            image = grayscale.point(lambda value: 0 if value < 180 else 255, mode="1")
        width_px, height_px = image.size
        padded_width = ((width_px + 7) // 8) * 8
        if padded_width == width_px:
            return image
        padded = Image.new("1", (padded_width, height_px), color=1)
        padded.paste(image, (0, 0))
        return padded

    def _chunk_plan_for_mode(self, height_px: int, raster_mode: str) -> list[tuple[int, int]]:
        if raster_mode == "esc_star":
            chunk_height = 24
        else:
            chunk_height = max(256, self.settings.raster_chunk_height)
        return [
            (top, min(top + chunk_height, height_px))
            for top in range(0, height_px, chunk_height)
        ]

    def _encode_chunk(
        self,
        image: "Image.Image",
        *,
        raster_mode: str,
        index: int,
        total: int,
    ) -> tuple[bytes, RasterChunk]:
        if raster_mode == "esc_star":
            return self._build_esc_star_command(image, index=index, total=total)
        return self._build_gs_v0_command(image, index=index, total=total)

    def _build_gs_v0_command(
        self,
        image: "Image.Image",
        *,
        index: int = 1,
        total: int = 1,
    ) -> tuple[bytes, RasterChunk]:
        width_px, height_px = image.size
        width_bytes = (width_px + 7) // 8

        raw = image.tobytes("raw", "1")
        packed = raw.translate(_XOR_TABLE)
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
        data_len = len(packed)
        expected_data_len = width_bytes * height_px
        if data_len != expected_data_len:
            raise ValueError(
                f"GS v 0 data length mismatch: expected={expected_data_len} actual={data_len}"
            )
        command = (
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
        meta = RasterChunk(
            index=index,
            total=total,
            width_px=width_px,
            height_px=height_px,
            source_height_px=height_px,
            bytes_per_row=width_bytes,
            data_len=data_len,
            command_len=len(command),
            command="GSv0",
        )
        self._validate_chunk(meta)
        return command, meta

    def _build_esc_star_command(
        self,
        image: "Image.Image",
        *,
        index: int = 1,
        total: int = 1,
    ) -> tuple[bytes, RasterChunk]:
        width_px, source_height_px = image.size
        width_bytes = width_px // 8
        padded_height = 24
        if source_height_px < padded_height:
            padded = Image.new("1", (width_px, padded_height), color=1)
            padded.paste(image, (0, 0))
            image = padded
        elif source_height_px > padded_height:
            raise ValueError(f"ESC * chunk height must be <=24, got {source_height_px}")

        pixels = image.load()
        data = bytearray()
        for x in range(width_px):
            for band in range(3):
                value = 0
                for bit in range(8):
                    y = band * 8 + bit
                    pixel = pixels[x, y]
                    is_black = pixel == 0
                    if is_black:
                        value |= 1 << (7 - bit)
                data.append(value)

        data_len = len(data)
        expected_data_len = width_bytes * padded_height
        if data_len != expected_data_len:
            raise ValueError(
                f"ESC * data length mismatch: expected={expected_data_len} actual={data_len}"
            )
        command = (
            ESC
            + b"*"
            + bytes([33, width_px & 0xFF, (width_px >> 8) & 0xFF])
            + bytes(data)
            + b"\n"
        )
        meta = RasterChunk(
            index=index,
            total=total,
            width_px=width_px,
            height_px=padded_height,
            source_height_px=source_height_px,
            bytes_per_row=width_bytes,
            data_len=data_len,
            command_len=len(command),
            command="ESC*",
        )
        self._validate_chunk(meta)
        return command, meta

    def _validate_chunk(self, meta: RasterChunk) -> None:
        if meta.width_px % 8 != 0:
            raise ValueError(f"Raster width must be padded to /8, got {meta.width_px}")
        expected_data_len = meta.bytes_per_row * meta.height_px
        if meta.data_len != expected_data_len:
            raise ValueError(
                f"Raster chunk data length mismatch: expected={expected_data_len} actual={meta.data_len}"
            )
        header_len = 8 if meta.command == "GSv0" else 6
        if meta.command_len != header_len + meta.data_len:
            raise ValueError(
                f"Raster command length mismatch: expected={header_len + meta.data_len} actual={meta.command_len}"
            )
