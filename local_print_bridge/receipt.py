from __future__ import annotations

from decimal import Decimal
import textwrap

from .config import BridgeSettings
from .models import ReceiptItem, ReceiptPayload


ESC = b"\x1b"
GS = b"\x1d"


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


class ReceiptRenderer:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width = settings.chars_per_line

    def render(self, payload: ReceiptPayload) -> bytes:
        chunks: list[bytes] = [_init_printer()]
        if self.settings.codepage is not None:
            chunks.append(_set_codepage(self.settings.codepage))

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
        chunks.extend(self._lines(self._pair("Masa", payload.table_no)))
        chunks.extend(self._lines(self._pair("Tarih", self._format_datetime(payload))))
        chunks.extend(self._lines(self._separator()))

        for item in payload.items:
            chunks.extend(self._render_item(item, payload.currency))

        chunks.extend(self._lines(self._separator()))
        chunks.extend(self._lines(self._pair("Ara Toplam", self._format_money(payload.totals.subtotal, payload.currency))))
        if payload.totals.discount > 0:
            chunks.extend(self._lines(self._pair("Indirim", self._format_money(payload.totals.discount, payload.currency))))
        if payload.totals.service_charge > 0:
            chunks.extend(
                self._lines(
                    self._pair(
                        "Servis",
                        self._format_money(payload.totals.service_charge, payload.currency),
                    )
                )
            )

        chunks.append(_set_bold(True))
        chunks.extend(
            self._lines(
                self._pair(
                    "GENEL TOPLAM",
                    self._format_money(payload.totals.grand_total, payload.currency),
                )
            )
        )
        chunks.append(_set_bold(False))

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
        return text.encode(self.settings.encoding, errors="replace")

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
        return payload.date_time.strftime("%d.%m.%Y %H:%M")

    def _format_money(self, value: Decimal, currency: str) -> str:
        normalized = f"{value.quantize(Decimal('0.01'))}".replace(".", ",")
        suffix = "TL" if currency.upper() in {"TRY", "TL"} else currency.upper()
        return f"{normalized} {suffix}"

    def _format_quantity(self, value: Decimal) -> str:
        if value == value.to_integral():
            return str(int(value))
        return format(value.normalize(), "f").rstrip("0").rstrip(".")
