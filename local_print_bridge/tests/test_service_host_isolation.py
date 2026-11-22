"""Isolated supervisor checks. They never touch a live bridge process: the
protected stand-in is a throw-away stopped process, and port 3001 is only
used to prove that it is refused without approval."""
from __future__ import annotations

import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import tempfile
import time
import unittest

from local_print_bridge.process_guard import decide_recovery
from local_print_bridge.service_host import run_host


_DUMMY_LISTENER = r"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"ok": true, "service": "ibul-local-print-bridge"}'
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        return

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
"""


class IsolatedServiceHostTests(unittest.TestCase):
    def test_live_port_is_not_signaled_without_approval(self) -> None:
        os.environ.pop("IBUL_BRIDGE_RECOVERY_APPROVED", None)
        protected = _spawn_protected_stopped_process()
        try:
            with tempfile.TemporaryDirectory() as tmp:
                os.environ["PRINT_BRIDGE_DATA_DIR"] = tmp
                before = _stat(protected.pid)
                run_host(port=3001, once=True)
                after = _stat(protected.pid)
                self.assertEqual(before, after)
                self.assertEqual(after[:1], "T")
                self.assertTrue((Path(tmp) / "logs" / "recovery.log").is_file())
                text = (Path(tmp) / "logs" / "recovery.log").read_text(encoding="utf-8")
                self.assertIn("live_recovery_not_approved", text)
                self.assertIn("replay_uncertain_jobs=false", text)
        finally:
            _reap(protected)

    def test_stopped_dummy_is_detected_and_sqlite_is_kept(self) -> None:
        os.environ.pop("IBUL_BRIDGE_RECOVERY_APPROVED", None)
        dummy = subprocess.Popen(
            ["python3", "-c", _DUMMY_LISTENER],
            stdout=subprocess.PIPE,
            text=True,
        )
        assert dummy.stdout is not None
        port_line = dummy.stdout.readline().strip()
        port = int(port_line)
        self.assertNotEqual(port, 3001)
        # Unrelated stopped process: the host must signal only the process that
        # owns the port it supervises, never anything else.
        protected = _spawn_protected_stopped_process()
        try:
            os.kill(dummy.pid, signal.SIGSTOP)
            self.assertEqual(_stat(dummy.pid)[:1], "T")
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                db_path = root / "queue.sqlite"
                _seed_wal_database(db_path)
                before = _job_rows(db_path)
                os.environ["PRINT_BRIDGE_DATA_DIR"] = tmp
                run_host(port=port, once=True)
                deadline = time.time() + 2
                while time.time() < deadline and _stat(dummy.pid)[:1] == "T":
                    time.sleep(0.05)
                self.assertNotEqual(_stat(dummy.pid)[:1], "T")
                self.assertEqual(_stat(protected.pid)[:1], "T")
                log_text = (root / "logs" / "recovery.log").read_text(encoding="utf-8")
                self.assertIn("action=sigcont", log_text)
                self.assertIn("replay_uncertain_jobs=false", log_text)
                backup = root / "queue-backup.sqlite"
                _backup_database(db_path, backup)
                self.assertEqual(_job_rows(backup), before)
                self.assertEqual(_job_rows(db_path), before)
                exhausted = decide_recovery(
                    health_ok=False,
                    port_open=True,
                    process_state="stopped",
                    sigcont_attempted=True,
                    restarts_in_window=3,
                    seconds_since_restart=30,
                )
                self.assertEqual(exhausted["action"], "give_up")
        finally:
            _reap(protected)
            if dummy.poll() is None:
                dummy.send_signal(signal.SIGCONT)
                dummy.kill()
                dummy.wait(timeout=3)


def _seed_wal_database(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute(
        "CREATE TABLE print_jobs (id TEXT PRIMARY KEY, status TEXT NOT NULL)"
    )
    connection.execute(
        "INSERT INTO print_jobs(id, status) VALUES('job-1', 'printing')"
    )
    connection.commit()
    connection.close()


def _backup_database(source: Path, target: Path) -> None:
    src = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    dst = sqlite3.connect(target)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()


def _job_rows(path: Path) -> list[tuple[str, str]]:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        return list(connection.execute("SELECT id, status FROM print_jobs"))
    finally:
        connection.close()


def _stat(pid: int) -> str:
    completed = subprocess.run(
        ["ps", "-p", str(pid), "-o", "stat="],
        capture_output=True,
        text=True,
        check=False,
    )
    return (completed.stdout or "").strip()


def _spawn_protected_stopped_process() -> subprocess.Popen:
    """Stand-in for an unrelated live process that the host must never signal."""
    proc = subprocess.Popen(["python3", "-c", "import time; time.sleep(120)"])
    os.kill(proc.pid, signal.SIGSTOP)
    deadline = time.time() + 2
    while time.time() < deadline and _stat(proc.pid)[:1] != "T":
        time.sleep(0.02)
    return proc


def _reap(proc: subprocess.Popen) -> None:
    if proc.poll() is None:
        proc.send_signal(signal.SIGCONT)
        proc.kill()
        proc.wait(timeout=3)


if __name__ == "__main__":
    unittest.main()
