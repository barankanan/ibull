from __future__ import annotations

import atexit
import logging
import os
from pathlib import Path
import socket
import time

from .config import BridgeSettings
from .server import serve
from .runtime_paths import bridge_lock_path


class _SingleInstanceLock:
    def __init__(self, lock_path: Path) -> None:
        self._lock_path = lock_path
        self._handle = None

    def acquire(self) -> bool:
        self._lock_path.parent.mkdir(parents=True, exist_ok=True)
        self._handle = open(self._lock_path, "a+b")
        try:
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(self._handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(self._handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self._handle.seek(0)
            self._handle.truncate()
            self._handle.write(str(os.getpid()).encode("utf-8"))
            self._handle.flush()
            return True
        except OSError:
            self.release()
            return False

    def release(self) -> None:
        if self._handle is None:
            return
        try:
            if os.name == "nt":
                import msvcrt

                self._handle.seek(0)
                msvcrt.locking(self._handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(self._handle.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        finally:
            self._handle.close()
            self._handle = None


def _bridge_port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def _lock_path() -> Path:
    return bridge_lock_path()


def _serve_with_retries() -> None:
    retry_delays = (0.0, 1.0, 2.0, 5.0)
    for attempt, delay in enumerate(retry_delays, start=1):
        if delay > 0:
            time.sleep(delay)
        try:
            serve()
            return
        except OSError:
            if attempt == len(retry_delays):
                raise
            logging.getLogger("local_print_bridge").exception(
                "Bridge start failed on attempt %d/%d; retrying in %.1fs",
                attempt,
                len(retry_delays),
                retry_delays[attempt],
            )
        except Exception:
            if attempt == len(retry_delays):
                raise
            logging.getLogger("local_print_bridge").exception(
                "Bridge crashed during startup on attempt %d/%d; retrying in %.1fs",
                attempt,
                len(retry_delays),
                retry_delays[attempt],
            )


def main() -> None:
    settings = BridgeSettings.from_env()
    if _bridge_port_open(settings.host, settings.port):
        return

    lock = _SingleInstanceLock(_lock_path())
    if not lock.acquire():
        return

    atexit.register(lock.release)
    _serve_with_retries()


if __name__ == "__main__":
    main()
