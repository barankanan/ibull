"""Match a saved printer to a newly discovered device.

A different IP is not the same printer unless a stable hardware identity
matches. Nothing in this module changes the printer's own network settings
or sends a print.
"""
from __future__ import annotations

import ipaddress


UNREACHABLE_MESSAGE = (
    "Yazıcıya ulaşılamıyor. Ethernet kablosunu ve ağ bağlantısını kontrol edin."
)


def is_local_scan_ipv4(ip_text: str) -> bool:
    """True for addresses a local printer scan is allowed to touch.

    Public internet addresses are rejected. RFC1918 and link-local are allowed.
    """
    try:
        ip = ipaddress.ip_address((ip_text or "").strip())
    except ValueError:
        return False
    if ip.version != 4:
        return False
    if ip.is_multicast or ip.is_unspecified or ip.is_loopback or ip.is_reserved:
        return False
    return bool(ip.is_private or ip.is_link_local)


def normalize_mac(value: object) -> str:
    hex_digits = "".join(
        character for character in str(value or "").lower() if character in "0123456789abcdef"
    )
    if len(hex_digits) != 12:
        return ""
    return ":".join(hex_digits[index : index + 2] for index in range(0, 12, 2))


def _text(record: dict[str, object], *keys: str) -> str:
    for key in keys:
        value = str(record.get(key) or "").strip()
        if value:
            return value
    return ""


def match_saved_printer(saved: dict[str, object], found: dict[str, object]) -> str:
    """Return ``same_endpoint``, ``hardware_match``, or ``no_match``."""
    saved_host = _text(saved, "host", "ip_address", "ipAddress")
    found_host = _text(found, "host", "ip_address", "ipAddress")
    try:
        saved_port = int(saved.get("port") or saved.get("tcp_port") or 9100)
    except (TypeError, ValueError):
        saved_port = 9100
    try:
        found_port = int(found.get("port") or found.get("tcp_port") or 9100)
    except (TypeError, ValueError):
        found_port = 9100
    if saved_host and found_host and saved_host == found_host and saved_port == found_port:
        return "same_endpoint"

    saved_mac = normalize_mac(_text(saved, "mac", "mac_address", "macAddress"))
    found_mac = normalize_mac(_text(found, "mac", "mac_address", "macAddress"))
    if saved_mac and found_mac and saved_mac == found_mac:
        return "hardware_match"

    for key in ("serial", "usb_serial", "bonjour_name", "queue", "device_identifier"):
        saved_value = _text(saved, key).lower()
        found_value = _text(found, key).lower()
        if saved_value and found_value and saved_value == found_value:
            return "hardware_match"
    return "no_match"


def may_rebind_address(saved: dict[str, object], found: dict[str, object]) -> bool:
    """A new IP may be suggested only when hardware identity matches.

    The caller still must not print until the operator confirms.
    """
    return match_saved_printer(saved, found) == "hardware_match"


def annotate_discovery(
    device: dict[str, object],
    saved: dict[str, object] | None = None,
) -> dict[str, object]:
    """Mark a scan hit as untrusted until identity says otherwise."""
    identity = match_saved_printer(saved or {}, device)
    annotated = dict(device)
    annotated["trusted"] = False
    annotated["auto_print"] = False
    annotated["auto_rebind"] = may_rebind_address(saved or {}, device)
    annotated["identity_match"] = identity
    annotated["connection_type"] = str(device.get("connection_type") or "ethernet")
    return annotated
