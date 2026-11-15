"""Local order accept, mock-safe kitchen send, and sync queue.

The listener stays on localhost. A LAN client is still rejected by the
existing loopback guard. This module does not open 0.0.0.0.
"""

from __future__ import annotations

import json
import socket
import time
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import urlparse

from .local_store import LocalRestaurantStore, client_total_cents
from .runtime_paths import bridge_data_dir

_STORE: LocalRestaurantStore | None = None


def open_lan_store() -> LocalRestaurantStore:
    global _STORE
    if _STORE is None:
        _STORE = LocalRestaurantStore(bridge_data_dir() / "lan_orders.sqlite")
    return _STORE

_BLOCKED_SYNC_HOSTS = ("supabase.co", "ihmixxzqnpamcwmrfibx")


def kitchen_ticket(order: dict[str, Any]) -> bytes:
    lines = [
        "IBUL MUTFAK",
        str(order.get("table_label") or order.get("table_number") or ""),
    ]
    for item in order.get("items") or []:
        station = item.get("station_id") or ""
        lines.append(
            f"{item['quantity']} {item['name']}"
            + (f" [{station}]" if station else "")
        )
    return ("\n".join(lines) + "\n").encode("utf-8")


def send_kitchen_ticket(host: str, port: int, payload: bytes, timeout: float = 1.0) -> str:
    """Return sent, failed, or uncertain. Uncertain is not retried here."""
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.sendall(payload)
        return "sent"
    except socket.timeout:
        return "uncertain"
    except OSError:
        return "failed"


def accept_and_queue(
    store: LocalRestaurantStore,
    body: dict[str, Any],
    *,
    printer_host: str,
    printer_port: int,
    deliver: bool,
) -> dict[str, Any]:
    started = time.perf_counter()
    saved = store.accept_order(
        local_order_id=str(body.get("local_order_id") or ""),
        restaurant_id=str(body.get("restaurant_id") or ""),
        table_number=int(body.get("table_number") or 0),
        table_label=str(body.get("table_label") or ""),
        waiter_name=str(body.get("waiter_name") or ""),
        notes=str(body.get("notes") or ""),
        items=list(body.get("items") or []),
        printer_host=printer_host,
        printer_port=printer_port,
        client_total_cents=client_total_cents(body),
    )
    print_status = str(saved.get("print_status") or "queued")
    send_ms = 0.0
    if deliver and not saved.get("duplicate") and saved.get("print_job_id"):
        ticket = kitchen_ticket(
            {
                "table_label": body.get("table_label"),
                "table_number": body.get("table_number"),
                "items": body.get("items") or [],
            }
        )
        send_started = time.perf_counter()
        print_status = send_kitchen_ticket(printer_host, printer_port, ticket)
        send_ms = (time.perf_counter() - send_started) * 1000
        store.mark_print(str(saved["print_job_id"]), print_status)
    saved["print_status"] = print_status
    saved["printed"] = print_status == "sent"
    saved["queue_ms"] = saved.get("db_ms", 0)
    saved["printer_ms"] = send_ms
    saved["accept_ms"] = (time.perf_counter() - started) * 1000
    return saved


def sync_target_allowed(base_url: str) -> bool:
    parsed = urlparse(base_url.strip())
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or not host:
        return False
    if any(marker in host for marker in _BLOCKED_SYNC_HOSTS):
        return False
    return host in {"127.0.0.1", "localhost"}


def flush_sync(store: LocalRestaurantStore, base_url: str) -> dict[str, Any]:
    started = time.perf_counter()
    if not sync_target_allowed(base_url):
        raise ValueError("Senkron hedefi yerel test sunucusu değil. Canlıya gönderilmedi.")
    sent = 0
    for row in store.pending_sync():
        payload = json.loads(row["payload"])
        request = urllib.request.Request(
            base_url.rstrip("/") + "/sync/orders",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=2) as response:
                if response.status >= 300:
                    break
        except urllib.error.URLError:
            break
        store.mark_synced(str(row["id"]))
        sent += 1
    return {
        "synced": sent,
        "pending": len(store.pending_sync()),
        "sync_ms": (time.perf_counter() - started) * 1000,
    }
