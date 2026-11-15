"""Loopback guard for the print bridge.

The bridge keeps its management and print routes on the seller computer.
A LAN pairing token belongs to the separate waiter host and cannot open
these routes.
"""

from __future__ import annotations

_ADMIN_PREFIXES = (
    "/setup",
    "/configure",
    "/system",
    "/diagnostics",
    "/print/logs",
    "/spool",
    "/queue/clear",
    "/warmup",
)


def is_bridge_admin_path(path: str) -> bool:
    text = (path or "").strip()
    return text.startswith(_ADMIN_PREFIXES)


def lan_bridge_decision(path: str, *, loopback: bool, authorization: str = "") -> str:
    """Return allow, admin_forbidden, or loopback_only."""
    if loopback:
        return "allow"
    if is_bridge_admin_path(path):
        return "admin_forbidden"
    # A bearer token must not promote a LAN client into the localhost API.
    _ = authorization
    return "loopback_only"
