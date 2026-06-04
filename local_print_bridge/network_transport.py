"""Direct TCP/IP transport for network ESC/POS printers.

Connects to a raw TCP port (default 9100) and streams ESC/POS bytes.
No CUPS, no driver — just a plain socket write.

Typical use:
    - NETUM ZJ-8360 over Ethernet (TCP 9100)
    - Epson TM-T20, TM-T88 with Ethernet or Wi-Fi
    - Any ESC/POS printer configured in "raw" TCP mode on port 9100

The transport raises :class:`TcpTransportError` for misconfiguration / runtime
issues; every error carries a stable ``code`` so the UI can show a friendly,
localized message:

    - ``tcp_host_missing``  — host string was empty/whitespace.
    - ``tcp_port_invalid``  — port outside 1..65535.
    - ``tcp_timeout``       — connect/send timed out.
    - ``tcp_refused``       — printer actively refused the connection.
    - ``tcp_unreachable``   — no route to host / network down.
    - ``tcp_io_error``      — any other socket level failure.
"""
from __future__ import annotations

import errno
import logging
import socket
import time

from .transport import PrintResult, TransportError

LOGGER = logging.getLogger("local_print_bridge.network")

DEFAULT_TCP_PORT = 9100
DEFAULT_TIMEOUT_SECONDS = 5.0
_SEND_TIMEOUT_S = 10
_MIN_PORT = 1
_MAX_PORT = 65535


class TcpTransportError(TransportError):
    """Specialised transport error that carries a stable ``code`` string."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"[{self.code}] {super().__str__()}"


def _normalize_host(host: object) -> str:
    if host is None:
        return ""
    return str(host).strip()


def _normalize_port(port: object, *, default: int = DEFAULT_TCP_PORT) -> int:
    """Validate and coerce a port number.

    Raises :class:`TcpTransportError` with ``code="tcp_port_invalid"`` when the
    value cannot be coerced into an int inside the IANA-defined range.
    """
    if port is None or (isinstance(port, str) and not port.strip()):
        return default
    try:
        parsed = int(port) if not isinstance(port, str) else int(port.strip())
    except (TypeError, ValueError):
        raise TcpTransportError(
            "tcp_port_invalid",
            f"TCP port '{port}' geçersiz. 1-65535 arası bir sayı girin.",
        )
    if parsed < _MIN_PORT or parsed > _MAX_PORT:
        raise TcpTransportError(
            "tcp_port_invalid",
            f"TCP port {parsed} kapsam dışında. 1-65535 arası bir değer girin.",
        )
    return parsed


def _classify_oserror(exc: OSError, host: str, port: int) -> TcpTransportError:
    """Translate a raw socket error into a friendly :class:`TcpTransportError`."""
    err_no = exc.errno
    text = str(exc) or exc.strerror or "socket error"
    if isinstance(exc, socket.timeout):
        return TcpTransportError(
            "tcp_timeout",
            f"Yazıcı yanıt vermedi ({host}:{port}) — zaman aşımı. "
            "Yazıcının açık ve aynı ağda olduğundan emin olun.",
        )
    if err_no in (errno.ECONNREFUSED,):
        return TcpTransportError(
            "tcp_refused",
            f"Yazıcı bağlantıyı reddetti ({host}:{port}). "
            "Doğru port girildi mi? Yazıcı RAW/9100 modunda mı?",
        )
    if err_no in (
        errno.ENETUNREACH,
        errno.EHOSTUNREACH,
        errno.ENETDOWN,
        errno.EHOSTDOWN,
    ):
        return TcpTransportError(
            "tcp_unreachable",
            f"{host}:{port} adresine ulaşılamıyor. "
            "Aynı ağda olduğunuzdan ve IP'nin doğru olduğundan emin olun.",
        )
    return TcpTransportError(
        "tcp_io_error",
        f"TCP bağlantı hatası ({host}:{port}): {text}",
    )


def print_tcp(
    host: str,
    port: int = DEFAULT_TCP_PORT,
    data: bytes = b"",
    *,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> int:
    """Send ``data`` to ``host:port`` over a raw TCP socket.

    Mirrors the small helper described in the spec::

        with socket.create_connection((host, int(port)), timeout=timeout) as sock:
            sock.sendall(data)

    Returns the number of bytes written. Raises :class:`TcpTransportError` for
    every failure path with a stable ``code``.
    """
    normalized_host = _normalize_host(host)
    if not normalized_host:
        raise TcpTransportError(
            "tcp_host_missing",
            "Ethernet yazıcı için IP adresi zorunludur.",
        )
    normalized_port = _normalize_port(port)
    payload = data or b""

    LOGGER.info(
        "[TCP_PRINT][start] host=%s port=%d bytes=%d",
        normalized_host,
        normalized_port,
        len(payload),
    )
    started = time.monotonic()
    try:
        with socket.create_connection(
            (normalized_host, normalized_port), timeout=timeout
        ) as sock:
            sock.settimeout(max(float(timeout), float(_SEND_TIMEOUT_S)))
            if payload:
                sock.sendall(payload)
    except OSError as exc:
        error = _classify_oserror(exc, normalized_host, normalized_port)
        LOGGER.error(
            "[TCP_PRINT][error] code=%s message=%s",
            error.code,
            str(exc),
        )
        raise error from exc

    duration_ms = int((time.monotonic() - started) * 1000)
    LOGGER.info("[TCP_PRINT][success] durationMs=%d", duration_ms)
    return len(payload)


class NetworkTcpTransport:
    """Send raw bytes to a network ESC/POS printer via TCP socket.

    Used both for the global ``transport_mode=network`` configuration and for
    per-job overrides (e.g. Ethernet printers selected through the wizard).
    """

    def __init__(
        self,
        host: str,
        port: int = DEFAULT_TCP_PORT,
        *,
        timeout: float = DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        normalized_host = _normalize_host(host)
        if not normalized_host:
            raise TcpTransportError(
                "tcp_host_missing",
                "Ethernet yazıcı için IP adresi zorunludur.",
            )
        self.host = normalized_host
        self.port = _normalize_port(port)
        self.timeout = max(0.5, float(timeout))

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def health(self) -> dict[str, object]:
        """Try a TCP connect to verify the printer is reachable."""
        try:
            with socket.create_connection(
                (self.host, self.port), timeout=self.timeout
            ):
                pass
            return {
                "ok": True,
                "transport": "network-tcp",
                "host": self.host,
                "port": self.port,
            }
        except OSError as exc:
            error = _classify_oserror(exc, self.host, self.port)
            return {
                "ok": False,
                "transport": "network-tcp",
                "host": self.host,
                "port": self.port,
                "error_code": error.code,
                "reason": str(exc) or error.args[0],
            }

    def print_bytes(self, payload: bytes, *, job_name: str) -> PrintResult:
        """Open a TCP connection and send the raw ESC/POS payload."""
        bytes_to_send = bytes(payload or b"")
        started = time.monotonic()
        LOGGER.info(
            "[TCP_PRINT][start] host=%s port=%d bytes=%d job=%s",
            self.host,
            self.port,
            len(bytes_to_send),
            job_name,
        )
        try:
            sock = socket.create_connection(
                (self.host, self.port), timeout=self.timeout
            )
        except OSError as exc:
            error = _classify_oserror(exc, self.host, self.port)
            LOGGER.error(
                "[TCP_PRINT][error] code=%s message=%s",
                error.code,
                str(exc),
            )
            raise error from exc

        try:
            sock.settimeout(max(self.timeout, float(_SEND_TIMEOUT_S)))
            total = 0
            if bytes_to_send:
                view = memoryview(bytes_to_send)
                while total < len(bytes_to_send):
                    sent = sock.send(view[total:])
                    if sent == 0:
                        raise TcpTransportError(
                            "tcp_io_error",
                            f"TCP bağlantısı beklenmedik şekilde kapandı "
                            f"({self.host}:{self.port}).",
                        )
                    total += sent
        except TcpTransportError as exc:
            LOGGER.error(
                "[TCP_PRINT][error] code=%s message=%s",
                exc.code,
                str(exc),
            )
            raise
        except OSError as exc:
            error = _classify_oserror(exc, self.host, self.port)
            LOGGER.error(
                "[TCP_PRINT][error] code=%s message=%s",
                error.code,
                str(exc),
            )
            raise error from exc
        finally:
            try:
                sock.close()
            except OSError:
                pass

        duration_ms = int((time.monotonic() - started) * 1000)
        LOGGER.info(
            "[TCP_PRINT][success] durationMs=%d host=%s port=%d bytes=%d job=%s",
            duration_ms,
            self.host,
            self.port,
            total,
            job_name,
        )
        return PrintResult(
            job_id=f"tcp-{self.host}:{self.port}",
            raw_output="network-tcp",
            bytes_sent=total,
            metadata={
                "actual_backend": "tcp",
                "actual_host": self.host,
                "actual_port": self.port,
                "actual_queue": "",
                "target_host": self.host,
                "target_port": self.port,
                "duration_ms": duration_ms,
            },
        )
