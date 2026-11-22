"""Operator stop: let the print in progress finish, then exit."""
from __future__ import annotations

import threading
import time
from typing import Callable

_STARTED = threading.Event()


def stopping() -> bool:
    return _STARTED.is_set()


def reset_for_tests() -> None:
    _STARTED.clear()


def finish_work_then_stop(
    *,
    stop_server: Callable[[], None],
    queue_summary: Callable[[], dict[str, object]] | None = None,
    stop_consumer: Callable[[], None] | None = None,
    consumer_thread: threading.Thread | None = None,
    idle_timeout: float = 30.0,
    poll: float = 0.1,
) -> bool:
    """Blocks until the print in progress is done, then stops the server.

    Returns False when a stop is already under way. Nothing new is fetched
    from the queue; a ticket already being written to a printer is waited for
    (at most ``idle_timeout`` seconds). Waiting jobs stay where they are
    stored. The caller answers the request after this returns, so the seller
    app knows the bridge is idle before the operating system lets go of it.
    """
    if _STARTED.is_set():
        return False
    _STARTED.set()

    def _busy() -> bool:
        if queue_summary is None:
            return False
        try:
            summary = queue_summary()
        except Exception:  # noqa: BLE001
            return False
        return bool(summary.get("activePrinters")) or bool(
            summary.get("queueDepthByPrinter")
        )

    deadline = time.monotonic() + max(0.0, idle_timeout)
    if stop_consumer is not None:
        stop_consumer()
    if consumer_thread is not None and consumer_thread.is_alive():
        consumer_thread.join(timeout=max(0.0, deadline - time.monotonic()))
    while _busy() and time.monotonic() < deadline:
        time.sleep(poll)
    # shutdown() waits for the serving loop, so it cannot run on the thread
    # that is still answering this request.
    threading.Thread(target=stop_server, name="ibul-print-bridge-stop", daemon=False).start()
    return True
