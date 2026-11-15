"""User-session supervisor for the existing local print bridge.

launchd ``KeepAlive`` cannot continue a stopped process, because the process
has not exited. This host stays running, probes ``/health`` with a short
timeout, and only then chooses SIGCONT or a bounded restart.

It does not print, does not delete SQLite, and does not replay uncertain jobs.
One bridge process is allowed. A second listener is not started while the
port is held.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

from .process_guard import (
    MAX_RESTARTS_PER_WINDOW,
    RESTART_WINDOW_S,
    classify_ps_stat,
    decide_recovery,
    http_health_ok,
    recovery_log_line,
)
from .runtime_paths import bridge_logs_dir

LOGGER = logging.getLogger("local_print_bridge.service_host")


def bridge_child_command() -> list[str]:
    """Command that serves the bridge. Never includes ``--service-host``."""
    if getattr(sys, "frozen", False):
        return [sys.executable]
    return [sys.executable, "-m", "local_print_bridge"]


def _state_path() -> Path:
    return bridge_logs_dir() / "recovery_state.json"


def _log_path() -> Path:
    return bridge_logs_dir() / "recovery.log"


def load_restart_state(path: Path, *, now: float) -> dict[str, object]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        raw = {}
    if not isinstance(raw, dict):
        raw = {}
    stamps = [
        float(item)
        for item in raw.get("restart_stamps") or []
        if isinstance(item, (int, float)) and now - float(item) <= RESTART_WINDOW_S
    ]
    return {
        "restart_stamps": stamps,
        "sigcont_attempted": bool(raw.get("sigcont_attempted")),
    }


def save_restart_state(path: Path, state: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state), encoding="utf-8")


def append_recovery_log(decision: dict[str, object], *, detail: str = "") -> None:
    line = recovery_log_line(decision, detail=detail)
    try:
        path = _log_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(line)
    except OSError as exc:
        LOGGER.warning("recovery log write failed: %s", exc)
    LOGGER.warning("bridge recovery %s", line.strip())


def evaluate_once(
    *,
    health_ok: bool,
    port_open: bool,
    process_state: str,
    state: dict[str, object],
    now: float,
) -> dict[str, object]:
    stamps = [float(item) for item in state.get("restart_stamps") or []]
    seconds_since = None if not stamps else max(0.0, now - max(stamps))
    decision = decide_recovery(
        health_ok=health_ok,
        port_open=port_open,
        process_state=process_state,
        restarts_in_window=len(stamps),
        sigcont_attempted=bool(state.get("sigcont_attempted")),
        seconds_since_restart=seconds_since,
    )
    decision["max_restarts"] = MAX_RESTARTS_PER_WINDOW
    return decision


def apply_decision(
    decision: dict[str, object],
    *,
    pid: int | None,
    state: dict[str, object],
    now: float,
    continue_process,
    stop_process,
    start_process,
) -> dict[str, object]:
    """Apply one decision through injected callbacks. Does not print."""
    action = str(decision.get("action") or "wait")
    if action == "healthy":
        state["sigcont_attempted"] = False
        return state
    if action == "sigcont" and pid:
        continue_process(pid)
        state["sigcont_attempted"] = True
        return state
    if action == "start":
        start_process()
        return state
    if action == "restart" and pid:
        stop_process(pid)
        stamps = [float(item) for item in state.get("restart_stamps") or []]
        stamps.append(now)
        state["restart_stamps"] = stamps
        state["sigcont_attempted"] = False
        start_process()
        return state
    return state


def _posix_stat(pid: int) -> str:
    if pid <= 0 or os.name == "nt":
        return ""
    try:
        completed = subprocess.run(
            ["ps", "-p", str(pid), "-o", "stat="],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return (completed.stdout or "").strip()


def _listener_pid(port: int) -> int | None:
    if os.name == "nt":
        return None
    try:
        completed = subprocess.run(
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in (completed.stdout or "").splitlines():
        try:
            return int(line.strip())
        except ValueError:
            continue
    return None


def _port_open(host: str, port: int) -> bool:
    try:
        with socket_create(host, port):
            return True
    except OSError:
        return False


def socket_create(host: str, port: int):
    import socket

    return socket.create_connection((host, port), timeout=0.4)


def live_recovery_approved() -> bool:
    """Live port 3001 is not signaled until the operator sets this explicitly."""
    return os.getenv("IBUL_BRIDGE_RECOVERY_APPROVED", "").strip() == "1"


def run_host(*, host: str = "127.0.0.1", port: int = 3001, once: bool = False) -> None:
    """Supervise until the process is stopped. ``once`` performs a single pass.

    The default listen port is the live bridge. Without
    ``IBUL_BRIDGE_RECOVERY_APPROVED=1`` this function records the refusal and
    returns. Isolated tests use another port.
    """
    if int(port) == 3001 and not live_recovery_approved():
        append_recovery_log(
            {
                "action": "blocked",
                "reason": "live_recovery_not_approved",
            },
            detail="pid=747 not signaled",
        )
        return
    child: subprocess.Popen[bytes] | None = None

    def continue_process(pid: int) -> None:
        os.kill(pid, signal.SIGCONT)

    def stop_process(pid: int) -> None:
        # Continue first so a stopped process can observe termination.
        # Uncertain jobs are not replayed; this only stops the OS process.
        try:
            os.kill(pid, signal.SIGCONT)
        except OSError:
            pass
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            return
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)
            except OSError:
                return
            time.sleep(0.1)
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass

    def start_process() -> None:
        nonlocal child
        if child is not None and child.poll() is None:
            return
        if _port_open(host, port):
            return
        child = subprocess.Popen(
            bridge_child_command(),
            cwd=os.getcwd(),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    while True:
        now = time.time()
        state = load_restart_state(_state_path(), now=now)
        pid = _listener_pid(port)
        if pid is None and child is not None and child.poll() is None:
            pid = child.pid
        healthy = http_health_ok(host, port)
        port_open = healthy or _port_open(host, port)
        process_state = classify_ps_stat(_posix_stat(pid or 0)) if pid else "absent"
        if os.name == "nt" and not healthy and (pid or _windows_bridge_running()):
            process_state = "running"
        decision = evaluate_once(
            health_ok=healthy,
            port_open=port_open,
            process_state=process_state,
            state=state,
            now=now,
        )
        append_recovery_log(
            decision,
            detail=f"pid={pid or '-'} state={process_state}",
        )
        apply_decision(
            decision,
            pid=pid,
            state=state,
            now=now,
            continue_process=continue_process,
            stop_process=stop_process,
            start_process=start_process,
        )
        save_restart_state(_state_path(), state)
        if once or decision.get("action") == "give_up":
            if once:
                return
        time.sleep(5 if decision.get("action") == "healthy" else 15)


def _windows_bridge_running() -> bool:
    if os.name != "nt":
        return False
    try:
        completed = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq IbulPrintBridge.exe", "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return "ibulprintbridge.exe" in (completed.stdout or "").lower()


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    run_host(once="--once" in sys.argv[1:])


if __name__ == "__main__":
    main()
