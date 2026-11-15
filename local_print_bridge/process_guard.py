"""Decide whether a local print bridge needs recovery.

An open TCP port is not health. launchd KeepAlive restarts a job only after
the process exits, so a stopped-but-not-exited process (macOS STAT ``T``)
keeps the port and is never replaced.

This module never prints, never deletes the queue, and never rewrites a
print-job status. Uncertain work stays uncertain.
"""
from __future__ import annotations

from datetime import datetime, timezone
import socket


MAX_RESTARTS_PER_WINDOW = 3
RESTART_WINDOW_S = 600
MIN_RESTART_GAP_S = 15
HEALTH_TIMEOUT_S = 0.8

RECOVERY_ACTIONS = frozenset(
    {"healthy", "start", "sigcont", "restart", "wait", "give_up", "blocked"}
)


def classify_ps_stat(stat: str | None) -> str:
    """Map a ``ps`` STAT/state token to a recovery class.

    macOS ``T`` means stopped (SIGSTOP/SIGTSTP). The process still exists,
    so ``kill -0`` and launchd both treat it as alive.
    """
    text = (stat or "").strip().upper()
    if not text or text in {"NONE", "ABSENT", "-"}:
        return "absent"
    if "STOPPED" in text or text[0] == "T":
        return "stopped"
    if text[0] == "Z":
        return "zombie"
    if text[0] in {"R", "S", "I", "U", "D", "W"}:
        return "running"
    return "unknown"


def decide_recovery(
    *,
    health_ok: bool,
    port_open: bool,
    process_state: str,
    restarts_in_window: int = 0,
    sigcont_attempted: bool = False,
    seconds_since_restart: float | None = None,
) -> dict[str, object]:
    """Return one recovery action. ``replay_uncertain_jobs`` is always false."""
    state = (process_state or "unknown").strip().lower()
    base = {
        "port_open_is_health": False,
        "replay_uncertain_jobs": False,
        "rewrite_job_status": False,
    }
    if health_ok:
        return {
            **base,
            "action": "healthy",
            "reason": "health_responded",
        }

    if state == "stopped" and not sigcont_attempted:
        return {
            **base,
            "action": "sigcont",
            "reason": "process_stopped_port_is_not_health",
        }

    restart_blocked = restarts_in_window >= MAX_RESTARTS_PER_WINDOW or (
        seconds_since_restart is not None and seconds_since_restart < MIN_RESTART_GAP_S
    )
    if state == "stopped" and sigcont_attempted:
        if restart_blocked:
            return {
                **base,
                "action": "give_up",
                "reason": "stopped_process_still_unresponsive_restart_budget_exhausted",
            }
        return {
            **base,
            "action": "restart",
            "reason": "sigcont_did_not_restore_health",
        }

    if not port_open and state in {"absent", "zombie", "unknown"}:
        return {
            **base,
            "action": "start",
            "reason": "no_listener",
        }

    if port_open and state == "absent":
        return {
            **base,
            "action": "blocked",
            "reason": "port_held_by_unidentified_process",
        }

    if port_open or state == "running":
        if restart_blocked:
            return {
                **base,
                "action": "give_up",
                "reason": "unresponsive_restart_budget_exhausted",
            }
        if state == "running" or port_open:
            return {
                **base,
                "action": "restart",
                "reason": "health_timeout_while_process_or_port_present",
            }

    return {
        **base,
        "action": "wait",
        "reason": "state_not_actionable",
    }


def http_health_ok(host: str, port: int, *, timeout_s: float = HEALTH_TIMEOUT_S) -> bool:
    """True only when ``/health`` returns HTTP 200 within ``timeout_s``.

    A completed TCP handshake is not enough: a stopped process can still
    have its listen socket accepted by the kernel.
    """
    try:
        with socket.create_connection((host, port), timeout=timeout_s) as sock:
            sock.settimeout(timeout_s)
            sock.sendall(
                b"GET /health HTTP/1.1\r\n"
                b"Host: 127.0.0.1\r\n"
                b"Connection: close\r\n\r\n"
            )
            chunks: list[bytes] = []
            while True:
                try:
                    chunk = sock.recv(4096)
                except socket.timeout:
                    break
                if not chunk:
                    break
                chunks.append(chunk)
                if b"\r\n" in b"".join(chunks):
                    break
    except OSError:
        return False
    data = b"".join(chunks)
    if not data:
        return False
    status_line = data.split(b"\r\n", 1)[0]
    return status_line.startswith(b"HTTP/") and b" 200" in status_line


def recovery_log_line(decision: dict[str, object], *, detail: str = "") -> str:
    stamp = datetime.now(timezone.utc).isoformat()
    action = decision.get("action")
    reason = decision.get("reason")
    extra = f" {detail}".rstrip()
    return (
        f"{stamp} action={action} reason={reason} "
        f"replay_uncertain_jobs=false{extra}\n"
    )
