"""On-demand start on macOS: take the listening socket that launchd holds.

With a ``Sockets`` entry in the LaunchAgent, launchd owns 127.0.0.1:<port> and
starts the bridge only when something connects (the seller app's health
check). Nothing runs at login. The bridge must then serve on launchd's socket
instead of binding the port itself.
"""
from __future__ import annotations

import ctypes
import os
import socket
import sys

ENV_NAME = "PRINT_BRIDGE_LAUNCHD_SOCKET"


def requested_name(environ: dict[str, str] | None = None) -> str:
    env = os.environ if environ is None else environ
    return (env.get(ENV_NAME) or "").strip()


def activated_socket(name: str, *, libc: object | None = None) -> socket.socket | None:
    """Returns launchd's listening socket for ``name``, or None when this
    process was not started by launchd for that socket."""
    if not name or sys.platform != "darwin":
        return None
    try:
        lib = libc or ctypes.CDLL(None)
        fds = ctypes.POINTER(ctypes.c_int)()
        count = ctypes.c_size_t(0)
        rc = lib.launch_activate_socket(
            name.encode("utf-8"), ctypes.byref(fds), ctypes.byref(count)
        )
        if rc != 0 or count.value < 1:
            return None
        fd = int(fds[0])
        extra = [int(fds[i]) for i in range(1, count.value)]
        try:
            ctypes.CDLL(None).free(fds)
        except Exception:  # noqa: BLE001
            pass
        for other in extra:
            try:
                os.close(other)
            except OSError:
                pass
        return socket.socket(fileno=fd)
    except Exception:  # noqa: BLE001
        return None
