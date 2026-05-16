"""Direct TCP/IP transport for network ESC/POS printers.

Connects to a raw TCP port (default 9100) and streams ESC/POS bytes.
No CUPS, no driver — just a plain socket write.

Typical use:
    - Epson TM-T20, TM-T88 with Ethernet or Wi-Fi
    - Any ESC/POS printer configured in "raw" TCP mode on port 9100
"""
from __future__ import annotations

import logging
import socket

from .transport import PrintResult, TransportError

LOGGER = logging.getLogger("local_print_bridge.network")

_DEFAULT_PORT = 9100
_CONNECT_TIMEOUT_S = 5
_SEND_TIMEOUT_S = 10


class NetworkTcpTransport:
    """Send raw bytes to a network ESC/POS printer via TCP socket."""

    def __init__(
        self,
        host: str,
        port: int = _DEFAULT_PORT,
    ) -> None:
        if not host:
            raise ValueError("NetworkTcpTransport requires a non-empty host.")
        self.host = host
        self.port = port

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def health(self) -> dict[str, object]:
        """Try a TCP connect to verify the printer is reachable."""
        try:
            with socket.create_connection(
                (self.host, self.port), timeout=_CONNECT_TIMEOUT_S
            ):
                pass
            return {
                "ok": True,
                "transport": "network-tcp",
                "host": self.host,
                "port": self.port,
            }
        except OSError as exc:
            return {
                "ok": False,
                "transport": "network-tcp",
                "host": self.host,
                "port": self.port,
                "reason": str(exc),
            }

    def print_bytes(self, payload: bytes, *, job_name: str) -> PrintResult:
        """Open a TCP connection and send the raw ESC/POS payload."""
        try:
            sock = socket.create_connection(
                (self.host, self.port), timeout=_CONNECT_TIMEOUT_S
            )
        except OSError as exc:
            raise TransportError(
                f"Cannot connect to {self.host}:{self.port} — {exc}"
            ) from exc

        try:
            sock.settimeout(_SEND_TIMEOUT_S)
            total = 0
            view = memoryview(payload)
            while total < len(payload):
                sent = sock.send(view[total:])
                if sent == 0:
                    raise TransportError(
                        f"TCP connection to {self.host}:{self.port} closed unexpectedly."
                    )
                total += sent
        except OSError as exc:
            raise TransportError(
                f"TCP send to {self.host}:{self.port} failed — {exc}"
            ) from exc
        finally:
            try:
                sock.close()
            except OSError:
                pass

        LOGGER.info(
            "network-tcp: sent %d bytes to %s:%d (job=%s)",
            total,
            self.host,
            self.port,
            job_name,
        )
        return PrintResult(
            job_id=None,
            raw_output="network-tcp",
            bytes_sent=total,
            metadata={
                "actual_backend": "network-tcp",
                "target_host": self.host,
                "target_port": self.port,
            },
        )
