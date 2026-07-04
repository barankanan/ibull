"""Trailing feed, cut padding, and minimum ticket height for restaurant receipts."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping


def _parse_int(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value >= 0 else None
    raw = str(value).strip()
    if not raw:
        return None
    try:
        parsed = int(raw)
    except ValueError:
        return None
    return parsed if parsed >= 0 else None


def _normalize_preset(raw: Any) -> str:
    preset = str(raw or "normal").strip().lower()
    if preset in {"short", "kisa", "kısa"}:
        return "short"
    if preset in {"long", "uzun"}:
        return "long"
    if preset in {"custom", "özel", "ozel"}:
        return "custom"
    return "normal"


@dataclass(frozen=True)
class TailPaddingPolicy:
    bottom_feed_lines: int
    cut_feed_lines: int
    min_trailing_blank_lines: int
    bottom_padding_px: int
    min_receipt_height_px: int
    receipt_length_preset: str = "normal"
    policy_source: str = "default"

    def debug_fields(self) -> dict[str, int | str]:
        return {
            "bottom_feed_lines": self.bottom_feed_lines,
            "cut_feed_lines": self.cut_feed_lines,
            "min_trailing_blank_lines": self.min_trailing_blank_lines,
            "bottom_padding_px": self.bottom_padding_px,
            "raster_bottom_padding_px": self.bottom_padding_px,
            "min_receipt_height_px": self.min_receipt_height_px,
            "receipt_length_preset": self.receipt_length_preset,
            "receipt_length": self.receipt_length_preset,
            "policy_source": self.policy_source,
        }


def default_policy_for_paper(
    paper_width_mm: int,
    *,
    preset: str = "normal",
) -> TailPaddingPolicy:
    is_narrow = paper_width_mm <= 58
    normalized = _normalize_preset(preset)
    if is_narrow:
        if normalized == "short":
            return TailPaddingPolicy(
                bottom_feed_lines=3,
                cut_feed_lines=2,
                min_trailing_blank_lines=3,
                bottom_padding_px=40,
                min_receipt_height_px=380,
                receipt_length_preset="short",
            )
        if normalized == "long":
            return TailPaddingPolicy(
                bottom_feed_lines=12,
                cut_feed_lines=9,
                min_trailing_blank_lines=12,
                bottom_padding_px=220,
                min_receipt_height_px=780,
                receipt_length_preset="long",
            )
        if normalized == "custom":
            return default_policy_for_paper(paper_width_mm, preset="normal")
        return TailPaddingPolicy(
            bottom_feed_lines=6,
            cut_feed_lines=5,
            min_trailing_blank_lines=6,
            bottom_padding_px=90,
            min_receipt_height_px=520,
            receipt_length_preset="normal",
        )
    if normalized == "short":
        return TailPaddingPolicy(
            bottom_feed_lines=2,
            cut_feed_lines=1,
            min_trailing_blank_lines=2,
            bottom_padding_px=40,
            min_receipt_height_px=420,
            receipt_length_preset="short",
        )
    if normalized == "long":
        return TailPaddingPolicy(
            bottom_feed_lines=10,
            cut_feed_lines=8,
            min_trailing_blank_lines=10,
            bottom_padding_px=240,
            min_receipt_height_px=850,
            receipt_length_preset="long",
        )
    if normalized == "custom":
        return default_policy_for_paper(paper_width_mm, preset="normal")
    return TailPaddingPolicy(
        bottom_feed_lines=5,
        cut_feed_lines=4,
        min_trailing_blank_lines=5,
        bottom_padding_px=100,
        min_receipt_height_px=560,
        receipt_length_preset="normal",
    )


def _merge_tail_request_sources(
    requested: Mapping[str, Any] | None,
) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    if not requested:
        return merged
    for key, value in requested.items():
        if value is not None:
            merged[key] = value
    printer = requested.get("printer")
    if isinstance(printer, dict):
        for key, value in printer.items():
            if value is not None and key not in merged:
                merged[key] = value
    selected = requested.get("selected_printer")
    if isinstance(selected, dict):
        for key, value in selected.items():
            if value is not None and merged.get(key) is None:
                merged[key] = value
    return merged


def resolve_tail_padding_policy(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> TailPaddingPolicy:
    merged = _merge_tail_request_sources(requested)
    preset = _normalize_preset(
        merged.get("receipt_length")
        or merged.get("receipt_length_preset")
        or merged.get("ticket_length")
    )
    defaults = default_policy_for_paper(
        paper_width_mm,
        preset="normal" if preset == "custom" else preset,
    )

    bottom_feed = _parse_int(merged.get("bottom_feed_lines"))
    if bottom_feed is None:
        bottom_feed = _parse_int(merged.get("receipt_bottom_feed_lines"))
    if bottom_feed is None:
        bottom_feed = _parse_int(merged.get("kitchen_bottom_padding_lines"))
    if bottom_feed is None:
        bottom_feed = _parse_int(merged.get("receipt_bottom_padding_lines"))
    if bottom_feed is None:
        bottom_feed = _parse_int(merged.get("min_trailing_blank_lines"))
    if bottom_feed is None:
        bottom_feed = defaults.bottom_feed_lines

    cut_feed = _parse_int(merged.get("cut_feed_lines"))
    if cut_feed is None:
        cut_feed = _parse_int(merged.get("receipt_cut_feed_lines"))
    if cut_feed is None:
        cut_feed = defaults.cut_feed_lines

    min_trailing = _parse_int(merged.get("min_trailing_blank_lines"))
    if min_trailing is None:
        min_trailing = _parse_int(merged.get("receipt_min_trailing_blank_lines"))
    if min_trailing is None:
        if preset == "custom":
            min_trailing = bottom_feed
        else:
            min_trailing = max(bottom_feed, defaults.min_trailing_blank_lines)

    bottom_pad = _parse_int(merged.get("bottom_padding_px"))
    if bottom_pad is None:
        bottom_pad = _parse_int(merged.get("raster_bottom_padding_px"))
    if bottom_pad is None:
        bottom_pad = _parse_int(merged.get("receipt_bottom_padding_px"))
    if bottom_pad is None:
        bottom_pad = defaults.bottom_padding_px

    min_height = _parse_int(merged.get("min_receipt_height_px"))
    if min_height is None:
        min_height = _parse_int(merged.get("receipt_min_receipt_height_px"))
    if min_height is None:
        min_height = defaults.min_receipt_height_px

    if preset == "custom":
        return TailPaddingPolicy(
            bottom_feed_lines=bottom_feed,
            cut_feed_lines=cut_feed,
            min_trailing_blank_lines=min_trailing,
            bottom_padding_px=bottom_pad,
            min_receipt_height_px=min_height,
            receipt_length_preset="custom",
            policy_source="custom",
        )

    explicit_numeric = any(
        merged.get(key) is not None
        for key in (
            "bottom_feed_lines",
            "cut_feed_lines",
            "bottom_padding_px",
            "raster_bottom_padding_px",
            "min_receipt_height_px",
            "receipt_bottom_feed_lines",
            "receipt_bottom_padding_px",
            "receipt_min_receipt_height_px",
        )
    )
    source = "preset" if preset != "normal" else ("custom" if explicit_numeric else "default")

    return TailPaddingPolicy(
        bottom_feed_lines=bottom_feed,
        cut_feed_lines=cut_feed,
        min_trailing_blank_lines=min_trailing,
        bottom_padding_px=bottom_pad,
        min_receipt_height_px=min_height,
        receipt_length_preset=preset,
        policy_source=source,
    )


def default_bottom_feed_lines(paper_width_mm: int) -> int:
    return default_policy_for_paper(paper_width_mm).bottom_feed_lines


def default_cut_feed_lines(paper_width_mm: int) -> int:
    return default_policy_for_paper(paper_width_mm).cut_feed_lines


def default_raster_bottom_padding_px(paper_width_mm: int) -> int:
    return default_policy_for_paper(paper_width_mm).bottom_padding_px


def resolve_bottom_feed_lines(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> int:
    return resolve_tail_padding_policy(paper_width_mm, requested).bottom_feed_lines


def resolve_cut_feed_lines(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> int:
    return resolve_tail_padding_policy(paper_width_mm, requested).cut_feed_lines


def resolve_raster_bottom_padding_px(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> int:
    return resolve_tail_padding_policy(paper_width_mm, requested).bottom_padding_px


def resolve_min_receipt_height_px(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> int:
    return resolve_tail_padding_policy(paper_width_mm, requested).min_receipt_height_px


def resolve_min_trailing_blank_lines(
    paper_width_mm: int,
    requested: Mapping[str, Any] | None,
) -> int:
    return resolve_tail_padding_policy(paper_width_mm, requested).min_trailing_blank_lines


def receipt_length_ab_min_fields() -> dict[str, Any]:
    """A/B minimum — all tail padding zero for physical length proof."""
    return {
        "receipt_length": "custom",
        "receipt_length_preset": "custom",
        "bottom_feed_lines": 0,
        "cut_feed_lines": 0,
        "min_trailing_blank_lines": 0,
        "bottom_padding_px": 0,
        "raster_bottom_padding_px": 0,
        "min_receipt_height_px": 0,
        "policy_source": "ab_min_test",
    }


def receipt_length_ab_max_fields() -> dict[str, Any]:
    """A/B maximum — exaggerated tail padding for physical length proof."""
    return {
        "receipt_length": "custom",
        "receipt_length_preset": "custom",
        "bottom_feed_lines": 20,
        "cut_feed_lines": 16,
        "min_trailing_blank_lines": 20,
        "bottom_padding_px": 600,
        "raster_bottom_padding_px": 600,
        "min_receipt_height_px": 1400,
        "policy_source": "ab_max_test",
    }
