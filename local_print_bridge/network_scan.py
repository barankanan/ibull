"""Scan local /24 subnets for ESC/POS printers listening on a TCP port."""
from __future__ import annotations

import ipaddress
import logging
import socket
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable

from .network_transport import DEFAULT_TCP_PORT

LOGGER = logging.getLogger("local_print_bridge.network_scan")

DEFAULT_SCAN_TIMEOUT_S = 0.35
DEFAULT_MAX_WORKERS = 64


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
) -> str:
    """Explain why automatic scan returned no printers."""
    if devices:
        return ""
    host_text = printer_host.strip()
    local = local_ips or []
    if host_text and local and ipv4_same_subnet(host_text, local) is False:
        return "printer_on_different_subnet"
    return "no_open_port_on_scanned_subnets"


def _probe_tcp_port(
    host: str,
    port: int,
    *,
    timeout: float,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
) -> bool:
    connect = connect_fn or socket.create_connection
    try:
        with connect((host, port), timeout) as _sock:
            return True
    except OSError:
        return False


def scan_subnet_for_port(
    cidr: str,
    port: int = DEFAULT_TCP_PORT,
    *,
    timeout: float = DEFAULT_SCAN_TIMEOUT_S,
    max_workers: int = DEFAULT_MAX_WORKERS,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
    skip_hosts: set[str] | None = None,
) -> list[dict[str, object]]:
    """Return hosts in ``cidr`` where ``port`` accepts a TCP connection."""
    try:
        network = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        return []
    if network.version != 4:
        return []

    skip = skip_hosts or set()
    hosts = [
        str(host)
        for host in network.hosts()
        if str(host) not in skip
    ]
    if not hosts:
        return []

    found: list[dict[str, object]] = []
    workers = max(1, min(int(max_workers), len(hosts)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(
                _probe_tcp_port,
                host,
                port,
                timeout=timeout,
                connect_fn=connect_fn,
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

    found.sort(key=lambda item: ipaddress.ip_address(str(item["host"])))
    return found


def scan_local_network_printers(
    local_ips: list[str],
    *,
    port: int = DEFAULT_TCP_PORT,
    timeout: float = DEFAULT_SCAN_TIMEOUT_S,
    max_workers: int = DEFAULT_MAX_WORKERS,
    connect_fn: Callable[[tuple[str, int], float], object] | None = None,
) -> dict[str, object]:
    """Scan /24 subnets derived from ``local_ips`` for open ``port`` listeners."""
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
    for cidr in subnets:
        for item in scan_subnet_for_port(
            cidr,
            port,
            timeout=timeout,
            max_workers=max_workers,
            connect_fn=connect_fn,
            skip_hosts=skip_hosts,
        ):
            key = (str(item["host"]), int(item["port"]))
            if key in seen_endpoints:
                continue
            seen_endpoints.add(key)
            devices.append({**item, "subnet": cidr})

    return {
        "ok": True,
        "local_ips": local_ips,
        "subnets": subnets,
        "port": port,
        "devices": devices,
    }
