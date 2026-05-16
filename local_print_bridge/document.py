from __future__ import annotations

from typing import Any

from .config import BridgeSettings
from .receipt import (
    _begin_document,
    _cut,
    _feed,
    _set_alignment,
    _set_bold,
    _set_text_size,
    encode_text,
)


class DocumentPayloadError(ValueError):
    """Raised when a generic ESC/POS document payload is invalid."""


class EscPosDocumentRenderer:
    def __init__(self, settings: BridgeSettings) -> None:
        self.settings = settings
        self.width = settings.chars_per_line

    def render(self, document: Any) -> bytes:
        if not isinstance(document, dict):
            raise DocumentPayloadError("`document` must be an object.")

        raw_lines = document.get("lines")
        if not isinstance(raw_lines, list) or not raw_lines:
            raise DocumentPayloadError("`document.lines` must be a non-empty array.")

        chunks: list[bytes] = [_begin_document(self.settings)]

        for index, entry in enumerate(raw_lines):
            if isinstance(entry, str):
                entry = {"type": "text", "value": entry}
            if not isinstance(entry, dict):
                raise DocumentPayloadError(f"`document.lines[{index}]` must be an object.")

            kind = str(entry.get("type", "text")).strip().lower() or "text"
            if kind == "separator":
                char = str(entry.get("char", "-") or "-")[0]
                chunks.extend(self._render_text_line(char * self.width, align="left", bold=False))
                continue
            if kind == "newline":
                count = max(1, int(entry.get("count", 1) or 1))
                chunks.append(_feed(count))
                continue
            if kind != "text":
                raise DocumentPayloadError(
                    f"`document.lines[{index}].type` must be one of text, separator, newline."
                )

            value = str(entry.get("value", entry.get("text", "")) or "")
            if not value:
                chunks.append(b"\n")
                continue
            align = str(entry.get("align", "left")).strip().lower() or "left"
            if align not in {"left", "center", "right"}:
                raise DocumentPayloadError(
                    f"`document.lines[{index}].align` must be left, center, or right."
                )
            bold = bool(entry.get("bold", False))
            width = max(1, min(8, int(entry.get("width", 1) or 1)))
            height = max(1, min(8, int(entry.get("height", 1) or 1)))
            chunks.extend(
                self._render_text_line(
                    value,
                    align=align,
                    bold=bold,
                    width=width,
                    height=height,
                )
            )

        feed_lines = max(0, int(document.get("feed", 3) or 0))
        if feed_lines:
            chunks.append(_feed(feed_lines))
        if document.get("cut", True):
            chunks.append(_cut(self.settings.cut_mode))
        return b"".join(chunks)

    def _render_text_line(
        self,
        value: str,
        *,
        align: str,
        bold: bool,
        width: int = 1,
        height: int = 1,
    ) -> list[bytes]:
        encoded, _ = encode_text(value, self.settings.encoding)
        return [
            _set_alignment(align),
            _set_bold(bold),
            _set_text_size(width, height),
            encoded + b"\n",
            _set_text_size(1, 1),
            _set_bold(False),
            _set_alignment("left"),
        ]
