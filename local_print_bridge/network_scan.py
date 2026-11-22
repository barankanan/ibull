"""Scan local /24 subnets for ESC/POS printers listening on a TCP port."""
from __future__ import annotations

import errno
import ipaddress
import logging
import socket
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable

from .network_transport import DEFAULT_TCP_PORT
from .printer_identity import is_local_scan_ipv4

LOGGER = logging.getLogger("local_print_bridge.network_scan")

# ESC/POS real-time status request (DLE EOT 1). It asks the printer for one
# status byte and prints nothing. An open port alone never makes a device a
# printer; only a valid status reply does.
ESC_POS_STATUS_QUERY = b"\x10\x04\x01"
DEFAULT_VERIFY_TIMEOUT_S = 0.6

DEFAULT_SCAN_TIMEOUT_S = 0.18
DEFAULT_MAX_WORKERS = 64
DEFAULT_SCAN_BUDGET_S = 2.0
# Prefer common last-octet printer DHCP slots; never hardcode a full IP.
_PRIORITY_HOST_SUFFIXES = (".1", ".2", ".10", ".20", ".50", ".100", ".101", ".200")


def _prioritize_hosts(hosts: list[str], *, hint: str = "") -> list[str]:
    """Probe likely printer IPs first; never hardcode a full address."""
    hint_host = (hint or "").strip()
    prioritized: list[str] = []
    seen: set[str] = set()

    def _add(host: str) -> None:
        text = host.strip()
        if not text or text in seen:
            return
        seen.add(text)
        prioritized.append(text)

    if hint_host:
        _add(hint_host)
    for host in hosts:
        if any(host.endswith(suffix) for suffix in _PRIORITY_HOST_SUFFIXES):
            _add(host)
    for host in hosts:
        _add(host)
    return prioritized


def ipv4_subnet_cidr(ip_text: str, prefix_len: int = 24) -> str | None:
    """Return a /24-style CIDR for a private IPv4 address."""
    try:
        ip = ipaddress.ip_address(ip_text.strip())
    except ValueError:
        return None
    if ip.version != 4 or ip.is_loopback or ip.is_link_local:
        return None
    network = ipaddress.ip_network(f"{ip}/{prefix_len}", strict=False)
    return str(network)


def unique_scan_subnets(local_ips: list[str], *, prefix_len: int = 24) -> list[str]:
    seen: set[str] = set()
    subnets: list[str] = []
    for ip_text in local_ips:
        cidr = ipv4_subnet_cidr(ip_text, prefix_len=prefix_len)
        if cidr and cidr not in seen:
            seen.add(cidr)
            subnets.append(cidr)
    return subnets


def ipv4_same_subnet(host: str, local_ips: list[str]) -> bool | None:
    """Return whether ``host`` shares a /24-style prefix with any local IPv4."""
    host_text = host.strip()
    if not host_text:
        return None
    try:
        target_ip = ipaddress.ip_address(host_text)
    except ValueError:
        return None
    if target_ip.version != 4:
        return None
    target_prefix = ".".join(str(target_ip).split(".")[:3])
    matched = False
    for local_ip_text in local_ips:
        try:
            local_ip = ipaddress.ip_address(local_ip_text.strip())
        except ValueError:
            continue
        if local_ip.version != 4:
            continue
        matched = True
        if ".".join(str(local_ip).split(".")[:3]) == target_prefix:
            return True
    if not matched:
        return None
    return False


def format_subnet_mismatch_guidance(host: str, local_ips: list[str]) -> str:
    """Operator-facing copy when printer and computer are on different /24 subnets."""
    host_text = host.strip()
    if not host_text or not local_ips:
        return (
            "Yazıcı ile bilgisayar aynı ağda görünmüyor. "
            "Yazıcı IP'sini işletme ağına alın."
        )
    try:
        target_ip = ipaddress.ip_address(host_text)
    except ValueError:
        return (
            "Yazıcı ile bilgisayar aynı ağda görünmüyor. "
            "Yazıcı IP'sini işletme ağına alın."
        )
    local_prefix = ".".join(local_ips[0].split(".")[:3])
    target_prefix = ".".join(str(target_ip).split(".")[:3])
    return (
        f"Bilgisayarınız {local_prefix}.x ağında, yazıcı {target_prefix}.x ağında. "
        "Bu cihazlar aynı ağda değil. Yazıcı IP'sini işletme ağına alın."
    )


def suggest_ethernet_network_settings(
    local_ips: list[str],
    *,
    printer_host: str = "",
    prefix_len: int = 24,
    default_port: int = DEFAULT_TCP_PORT,
) -> dict[str, object]:
    """Derive migration targets from the computer's active IPv4 address."""
    subnets = unique_scan_subnets(local_ips, prefix_len=prefix_len)
    primary_local = local_ips[0].strip() if local_ips else ""
    suggested_target_subnet = subnets[0] if subnets else ""
    suggested_printer_ip = ""
    suggested_gateway = ""
    subnet_mask = "255.255.255.0"
    if primary_local:
        parts = primary_local.split(".")
        if len(parts) == 4:
            suggested_printer_ip = f"{parts[0]}.{parts[1]}.{parts[2]}.100"
            suggested_gateway = f"{parts[0]}.{parts[1]}.{parts[2]}.1"

    same_subnet = ipv4_same_subnet(printer_host, local_ips) if printer_host.strip() else None
    mismatch_guidance = (
        format_subnet_mismatch_guidance(printer_host, local_ips)
        if same_subnet is False
        else ""
    )
    network_state = "ok"
    if same_subnet is False:
        network_state = "network_mismatch"
    elif same_subnet is None and printer_host.strip():
        network_state = "unknown"

    return {
        "local_ips": local_ips,
        "scanned_subnets": subnets,
        "suggested_target_subnet": suggested_target_subnet,
        "suggested_printer_ip": suggested_printer_ip,
        "suggested_gateway": suggested_gateway,
        "subnet_mask": subnet_mask,
        "suggested_port": default_port,
        "suggested_profile": "pos80",
        "same_subnet": same_subnet,
        "network_state": network_state,
        "mismatch_guidance": mismatch_guidance,
    }


def scan_no_device_reason(
    *,
    devices: list[dict[str, object]],
    printer_host: str = "",
    local_ips: list[str] | None = None,
    probe_blocked_count: int = 0,
    probe_closed_count: int = 0,
) -> str:
    """Explain why automatic scan returned no printers."""
    if devices:
        return ""
    # Nothing answered and most probes were refused by the OS/network rather
    # than closed: the scan could not look, so "no printer found" would lie.
    if probe_blocked_count > 0 and probe_blocked_count >= probe_closed_count:
        return "local_network_blocked"
    host_text = printer_host.strip()
    local = local_ips or []
    if host_text and local and ipv4_same_subnet(host_text, local) is False:
        return "printer_on_different_subnet"
    return "no_open_port_on_scanned_subnets"


# Errors that mean "the OS or network refused to even try", not "no printer
# here". A closed port (ECONNREFUSED) or silence (timeout) is the normal
# answer for an empty address; these are not. On macOS a process without the
# Local Network permission gets EHOSTUNREACH for every LAN address.
_BLOCKED_PROBE_ERRNOS = frozenset(
    code
    for code in (
        getattr(errno, "EHOSTUNREACH", None),
        getattr(errno, "ENETUNREACH", None),
        getattr(errno, "ENETDOWN", None),
        getattr(errno, "EPERM", None),
        getattr(errno, "EACCES", None),
    )
    if code is not None
)


def _probe_tcp_port(
    host: str,
    port: int,
    *,
    timeout: float,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
    error_sink: dict[str, int] | None = None,
) -> bool:
    connect = connect_fn or socket.create_connection
    try:
        with connect((host, port), timeout) as _sock:
            return True
    except OSError as exc:
        if error_sink is not None:
            # EHOSTUNREACH is also what a genuinely absent host can return on
            # some networks, so this only counts; the caller decides by ratio.
            key = (
                "blocked"
                if getattr(exc, "errno", None) in _BLOCKED_PROBE_ERRNOS
                else "closed"
            )
            error_sink[key] = error_sink.get(key, 0) + 1
        return False


def scan_subnet_for_port(
    cidr: str,
    port: int = DEFAULT_TCP_PORT,
    *,
    timeout: float = DEFAULT_SCAN_TIMEOUT_S,
    max_workers: int = DEFAULT_MAX_WORKERS,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
    skip_hosts: set[str] | None = None,
    printer_host_hint: str = "",
    budget_s: float = DEFAULT_SCAN_BUDGET_S,
    error_sink: dict[str, int] | None = None,
) -> list[dict[str, object]]:
    """Return hosts in ``cidr`` where ``port`` accepts a TCP connection.

    Discovery is connect-only: success means the TCP handshake completed.
    Printers are not expected to send a banner/response.
    """
    try:
        network = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        return []
    if network.version != 4:
        return []

    skip = {h.strip() for h in (skip_hosts or set()) if h and h.strip()}
    # Skip network/broadcast-style addresses already excluded by hosts(),
    # plus our own interface IPs.
    hosts = [
        str(host)
        for host in network.hosts()
        if str(host) not in skip
    ]
    if not hosts:
        return []

    hosts = _prioritize_hosts(hosts, hint=printer_host_hint)
    found: list[dict[str, object]] = []
    deadline = time.monotonic() + max(0.2, float(budget_s))
    workers = max(1, min(int(max_workers), len(hosts)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(
                _probe_tcp_port,
                host,
                port,
                timeout=timeout,
                connect_fn=connect_fn,
                error_sink=error_sink,
            ): host
            for host in hosts
        }
        for future in as_completed(futures):
            host = futures[future]
            try:
                if future.result():
                    found.append(
                        {
                            "host": host,
                            "port": port,
                            "reachable": True,
                            "port_open": True,
                        }
                    )
            except Exception as exc:  # pragma: no cover - defensive
                LOGGER.debug("Scan probe failed for %s:%d — %s", host, port, exc)
            # Prefer returning quickly once we have hits and budget is exhausted.
            if found and time.monotonic() >= deadline:
                break

    found.sort(key=lambda item: ipaddress.ip_address(str(item["host"])))
    return found


def _is_escpos_status_byte(value: int) -> bool:
    """DLE EOT 1 reply: bits 0 and 7 clear, bit 1 and bit 4 set."""
    return (value & 0x93) == 0x12


def verify_escpos_status(
    host: str,
    port: int,
    *,
    timeout: float = DEFAULT_VERIFY_TIMEOUT_S,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
) -> dict[str, object]:
    """Ask one device for its ESC/POS status byte. Never prints.

    Only local addresses are contacted. A device that does not answer, or
    answers with something that is not a printer status, stays unverified.
    """
    if not is_local_scan_ipv4(host):
        return {"verified": False, "reason": "not_local_address"}
    connect = connect_fn or socket.create_connection
    try:
        with connect((host, port), timeout) as sock:
            sock.settimeout(timeout)  # type: ignore[attr-defined]
            sock.sendall(ESC_POS_STATUS_QUERY)  # type: ignore[attr-defined]
            reply = sock.recv(8)  # type: ignore[attr-defined]
    except (OSError, AttributeError):
        return {"verified": False, "reason": "no_status_reply"}
    if not reply:
        return {"verified": False, "reason": "no_status_reply"}
    if _is_escpos_status_byte(reply[0]):
        return {"verified": True, "reason": "escpos_status", "status_byte": reply[0]}
    return {"verified": False, "reason": "unexpected_reply"}


def annotate_scan_candidate(
    device: dict[str, object],
    *,
    verify_timeout: float = DEFAULT_VERIFY_TIMEOUT_S,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
) -> dict[str, object]:
    """Mark an open-port hit as a verified printer or an unverified service."""
    result = verify_escpos_status(
        str(device.get("host") or ""),
        int(device.get("port") or DEFAULT_TCP_PORT),
        timeout=verify_timeout,
        connect_fn=connect_fn,
    )
    verified = bool(result.get("verified"))
    annotated = dict(device)
    annotated["printer_verified"] = verified
    annotated["kind"] = "escpos_printer" if verified else "unverified_tcp_service"
    annotated["identity"] = str(result.get("reason") or "")
    annotated["auto_print"] = False
    return annotated


def scan_local_network_printers(
    local_ips: list[str],
    *,
    port: int = DEFAULT_TCP_PORT,
    timeout: float = DEFAULT_SCAN_TIMEOUT_S,
    max_workers: int = DEFAULT_MAX_WORKERS,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
    printer_host_hint: str = "",
    budget_s: float = DEFAULT_SCAN_BUDGET_S,
    verify: bool = True,
    verify_timeout: float = DEFAULT_VERIFY_TIMEOUT_S,
) -> dict[str, object]:
    """Scan /24 subnets derived from ``local_ips`` for open ``port`` listeners.

    With ``verify`` (default) every open-port hit is checked with a read-only
    ESC/POS status request. Hits that do not answer stay in the list as
    ``unverified_tcp_service``: they are shown, never trusted as printers.
    """
    subnets = unique_scan_subnets(local_ips)
    if not subnets:
        return {
            "ok": False,
            "errorCode": "no_local_network",
            "error": "Bilgisayarın yerel ağ IP adresi algılanamadı.",
            "local_ips": local_ips,
            "subnets": [],
            "devices": [],
        }

    skip_hosts = {ip.strip() for ip in local_ips if ip.strip()}
    devices: list[dict[str, object]] = []
    seen_endpoints: set[tuple[str, int]] = set()
    probe_errors: dict[str, int] = {}
    # Split wall-clock budget across discovered subnets.
    per_subnet_budget = max(0.4, float(budget_s) / max(1, len(subnets)))
    for cidr in subnets:
        for item in scan_subnet_for_port(
            cidr,
            port,
            timeout=timeout,
            max_workers=max_workers,
            connect_fn=connect_fn,
            skip_hosts=skip_hosts,
            printer_host_hint=printer_host_hint,
            budget_s=per_subnet_budget,
            error_sink=probe_errors,
        ):
            key = (str(item["host"]), int(item["port"]))
            if key in seen_endpoints:
                continue
            seen_endpoints.add(key)
            devices.append({**item, "subnet": cidr})

    if verify and devices:
        with ThreadPoolExecutor(max_workers=min(8, len(devices))) as pool:
            devices = list(
                pool.map(
                    lambda device: annotate_scan_candidate(
                        device,
                        verify_timeout=verify_timeout,
                        connect_fn=connect_fn,
                    ),
                    devices,
                )
            )

    return {
        "ok": True,
        "local_ips": local_ips,
        "subnets": subnets,
        "port": port,
        "devices": devices,
        "probe_blocked_count": probe_errors.get("blocked", 0),
        "probe_closed_count": probe_errors.get("closed", 0),
        "verified_count": sum(1 for d in devices if d.get("printer_verified") is True),
        "unverified_count": sum(1 for d in devices if d.get("printer_verified") is False),
    }
