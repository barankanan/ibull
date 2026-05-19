from __future__ import annotations

from typing import Any


def _queue_name(printer: dict[str, Any]) -> str:
    return str(printer.get("queue") or printer.get("name") or "").strip()


def _status_level(printer: dict[str, Any]) -> str:
    return str(
        printer.get("statusLevel")
        or printer.get("status_level")
        or ""
    ).strip().lower()


def _is_recommended(printer: dict[str, Any]) -> bool:
    if printer.get("recommended") is True:
        return True
    if printer.get("isPosCandidate") is True:
        return True
    metadata = printer.get("metadata")
    if isinstance(metadata, dict) and metadata.get("recommended") is True:
        return True
    tier = str(
        printer.get("operatorTier")
        or printer.get("operator_tier")
        or (metadata.get("operatorTier") if isinstance(metadata, dict) else "")
        or ""
    ).strip().lower()
    return tier == "pos_candidate"


def _is_ready(printer: dict[str, Any]) -> bool:
    if _status_level(printer) == "ready":
        return True
    if printer.get("ready") is True:
        return True
    if printer.get("canPrint") is True:
        return True
    return str(printer.get("status") or "").strip().lower() in {"online", "ready"}


def _is_ready_recommended(printer: dict[str, Any]) -> bool:
    queue = _queue_name(printer)
    if not queue:
        return False
    return _is_recommended(printer) and _is_ready(printer)


def pick_auto_windows_printer_queue(printers: list[dict[str, Any]]) -> str | None:
    """Pick a single Windows queue when only one POS-ready printer is available."""
    if not printers:
        return None

    recommended_ready = [_queue_name(p) for p in printers if _is_ready_recommended(p)]
    recommended_ready = [q for q in recommended_ready if q]
    if len(recommended_ready) == 1:
        return recommended_ready[0]

    ready_queues = []
    for printer in printers:
        queue = _queue_name(printer)
        if queue and _is_ready(printer):
            ready_queues.append(queue)
    unique_ready = list(dict.fromkeys(ready_queues))
    if len(unique_ready) == 1:
        return unique_ready[0]
    return None
