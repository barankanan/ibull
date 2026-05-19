"""Kitchen ticket renderer.

Produces ESC/POS bytes for a kitchen print ticket (mutfak fişi).
The kitchen format shows item names, quantities and notes only — no pricing.
Compare with receipt.py which renders customer-facing adisyon receipts.
"""
from __future__ import annotations

import textwrap

from .config import BridgeSettings
from .models import KitchenChildItem, KitchenItem, KitchenPayload, KitchenPlate
from .models import _parse_datetime
from datetime import datetime
import logging

# Reuse the low-level ESC/POS helpers from receipt.py so encoding/cut/bold
# settings stay in one place.
from .receipt import (
    _begin_document,
    _cut,
    _feed,
    _set_alignment,
    _set_bold,
    _set_text_size,
    encode_text_report,
)

LOGGER = logging.getLogger("local_print_bridge")

# Human-readable labels for each job_type value.
_JOB_TYPE_LABELS: dict[str, str] = {
    "new_order": "YENİ SİPARİŞ",
    "add_item": "EKLEME",
    "cancel_item": "İPTAL",
    "reprint": "TEKRAR BASKI",
}


class KitchenRenderer:
    """Renders a KitchenPayload to raw ESC/POS bytes."""

    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width = settings.chars_per_line

    def render(self, payload: KitchenPayload) -> bytes:
        chunks: list[bytes] = [_begin_document(self.settings)]

        # ── Header ──────────────────────────────────────────────────────────
        # Job type label — large, centred (e.g. "YENİ SİPARİŞ")
        chunks += [_set_alignment("center"), _set_bold(True), _set_text_size(2, 2)]
        title = _JOB_TYPE_LABELS.get(payload.job_type, payload.title or "MUTFAK SİPARİŞİ")
        chunks += self._lines(title)
        chunks += [_set_text_size(1, 1), _set_bold(False)]

        # Area / station name — bold, centred
        if payload.area_name:
            chunks += [_set_bold(True)]
            chunks += self._lines(f"=== {payload.area_name.upper()} ===")
            chunks += [_set_bold(False)]

        chunks += self._lines(self._separator())
        chunks.append(_set_alignment("left"))

        # Table + waiter + order info
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
        # Enforce: never print a bare "Masa" line
        final_table_line = f"Masa: {table_label}".strip() if table_label else ""
        if final_table_line.strip() == "Masa:" or final_table_line.strip() == "Masa":
            final_table_line = ""

        chunks += self._lines(f"Sipariş No: {order_label}")
        if final_table_line:
            chunks += self._lines(final_table_line)
        if payload.waiter_name:
            chunks += self._lines(self._pair("Garson", payload.waiter_name))
        # Time resolution (kitchen dispatch time):
        # printed_at -> kitchen_printed_at -> order_created_at -> created_at -> date_time/datetime -> now
        raw_time = (
            str(getattr(payload, "printed_at", "") or "").strip()
            or str(getattr(payload, "kitchen_printed_at", "") or "").strip()
            or str(getattr(payload, "order_created_at", "") or "").strip()
            or str(getattr(payload, "created_at", "") or "").strip()
        )
        if raw_time:
            kitchen_dt = _parse_datetime(raw_time)
            time_source = "printed_at" if str(getattr(payload, "printed_at", "") or "").strip() else (
                "kitchen_printed_at"
                if str(getattr(payload, "kitchen_printed_at", "") or "").strip()
                else ("order_created_at" if str(getattr(payload, "order_created_at", "") or "").strip() else "created_at")
            )
        else:
            kitchen_dt = getattr(payload, "date_time", None) or datetime.now().astimezone()
            time_source = "date_time"

        kitchen_datetime_text = kitchen_dt.strftime("%d.%m.%Y %H:%M")
        final_datetime_line = f"Tarih: {kitchen_datetime_text}"
        LOGGER.info(
            "[KITCHEN_RENDER_HEADER] order_no=%s table_label=%s kitchen_datetime=%s time_source=%s render_mode=%s final_datetime_line=%s",
            order_label,
            table_label or "-",
            kitchen_datetime_text,
            time_source,
            str(getattr(self.settings, "render_mode", "") or "-"),
            final_datetime_line,
        )
        chunks += self._lines(final_datetime_line)
        chunks += self._lines(self._separator())

        # ── Items ────────────────────────────────────────────────────────────
        for item in payload.items:
            chunks += self._render_item(item)

        chunks += [_feed(3), _cut(self.settings.cut_mode)]
        return b"".join(chunks)

    # ── Item rendering ───────────────────────────────────────────────────────

    def _render_item(self, item: KitchenItem) -> list[bytes]:
        output: list[bytes] = []
        # Item name — normal weight (same as receipt item lines).
        # Quantity is shown as "Nx  Name [amount_label]".
        label = f"{item.quantity}x  {item.name}"
        if item.amount_label:
            label += f" {item.amount_label}"
        output += self._lines(label)

        # Plain note line (merged note + attrs from Flutter layer).
        if item.note:
            output += self._lines(f"  Not: {item.note}")

        # Service plates (tabak grouping) — use structured plates when available,
        # otherwise fall back to the text note which contains plate lines.
        if item.plates:
            for i, plate in enumerate(item.plates):
                if i > 0:
                    output += self._lines("")
                output += self._render_plate(plate)
        elif item.service_children:
            for child in item.service_children:
                output += self._render_child(child, indent="  ")

        # Blank line separator between items
        output += self._lines("")
        return output

    def _render_plate(self, plate: KitchenPlate) -> list[bytes]:
        output: list[bytes] = []
        output += [_set_bold(True)]
        output += self._lines(plate.label)
        output += [_set_bold(False)]
        for item in plate.items:
            output += self._render_child(item, indent="  ")
        return output

    def _render_child(self, item: KitchenChildItem, *, indent: str = "  ") -> list[bytes]:
        output: list[bytes] = []
        label = f"{indent}- {item.quantity}x {item.name}"
        if item.amount_label:
            label += f" {item.amount_label}"
        output += self._lines(label)
        if item.note:
            output += self._lines(f"{indent}  Not: {item.note}")
        return output

    # ── Formatting helpers ───────────────────────────────────────────────────

    def _lines(self, text: str) -> list[bytes]:
        if not text:
            return [b"\n"]
        return [self._encode(line) + b"\n" for line in text.splitlines()]

    def _encode(self, text: str) -> bytes:
        encoded, _, issues, unsupported_chars = encode_text_report(
            text, self.settings.encoding
        )
        if unsupported_chars:
            LOGGER.warning(
                "kitchen_encode_unsupported: encoding=%s codepage=%s unsupported_chars=%r",
                self.settings.encoding,
                self.settings.codepage,
                "".join(unsupported_chars),
            )
        if issues:
            LOGGER.warning(
                "kitchen_line_encode: encoding=%s codepage=%s issues=%s line=%.80r",
                self.settings.encoding,
                self.settings.codepage,
                " | ".join(issues),
                text,
            )
        return encoded

    def _separator(self) -> str:
        return "=" * self.width

    def _pair(self, left: str, right: str) -> str:
        """Left-align left, right-align right within self.width."""
        left = left.strip()
        right = right.strip()
        if not right:
            return left
        available = self.width - len(right) - 1
        if available < 4:
            return f"{left}\n{right.rjust(self.width)}"
        wrapped = textwrap.fill(left, available, break_long_words=True)
        first = wrapped.split("\n")[0]
        gap = self.width - len(first) - len(right)
        return f"{first}{' ' * max(gap, 1)}{right}"
