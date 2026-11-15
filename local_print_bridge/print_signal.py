"""Wake the existing print-station poll from the print_signal broadcast.

The listener only sets the consumer wake event. It does not claim or print.
The 2.5s poll remains the path used when this socket is down.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import socket
import ssl
import threading
from typing import Any, Callable
from urllib.parse import quote, urlsplit

LOGGER = logging.getLogger("local_print_bridge.print_signal")


def _jobs_target_this_restaurant(body: dict[str, Any], restaurant_id: str) -> bool:
    stated = str(body.get("restaurant_id") or "").strip()
    if stated and stated != restaurant_id:
        return False
    jobs = body.get("job_ids")
    return isinstance(jobs, list) and any(str(job).strip() for job in jobs)


def signal_frame_should_wake(text: str, restaurant_id: str) -> bool:
    try:
        message = json.loads(text)
    except json.JSONDecodeError:
        return False
    if not isinstance(message, dict) or message.get("event") != "broadcast":
        return False
    payload = message.get("payload")
    if not isinstance(payload, dict) or payload.get("event") != "new_print_jobs":
        return False
    # Documented shape nests the user body. realtime_client 2.7 send() puts
    # job_ids on the broadcast payload itself; the server forwards that map.
    inner = payload.get("payload")
    if isinstance(inner, dict):
        return _jobs_target_this_restaurant(inner, restaurant_id)
    return _jobs_target_this_restaurant(payload, restaurant_id)


def join_reply_status(text: str) -> str | None:
    """'ok', 'error', or None when the frame is not this channel's phx_reply."""
    try:
        message = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(message, dict) or message.get("event") != "phx_reply":
        return None
    if str(message.get("ref") or "") not in {"", "1"}:
        return None
    payload = message.get("payload")
    if not isinstance(payload, dict):
        return None
    status = str(payload.get("status") or "")
    if status == "ok":
        return "ok"
    if status:
        return "error"
    return None


def _recv_exact(sock: socket.socket, size: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < size:
        part = sock.recv(size - len(chunks))
        if not part:
            raise ConnectionError("print signal closed")
        chunks.extend(part)
    return bytes(chunks)


def _send_frame(sock: socket.socket, opcode: int, payload: bytes) -> None:
    mask = os.urandom(4)
    header = bytearray([0x80 | opcode])
    length = len(payload)
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header.extend(length.to_bytes(2, "big"))
    else:
        header.append(0x80 | 127)
        header.extend(length.to_bytes(8, "big"))
    header.extend(mask)
    masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    sock.sendall(bytes(header) + masked)


def read_text_frame(sock: socket.socket, timeout: float) -> str | None:
    sock.settimeout(timeout)
    try:
        header = _recv_exact(sock, 2)
    except (TimeoutError, socket.timeout):
        return None
    opcode = header[0] & 0x0F
    masked = (header[1] & 0x80) != 0
    length = header[1] & 0x7F
    if length == 126:
        length = int.from_bytes(_recv_exact(sock, 2), "big")
    elif length == 127:
        length = int.from_bytes(_recv_exact(sock, 8), "big")
    mask = _recv_exact(sock, 4) if masked else b""
    payload = _recv_exact(sock, length) if length else b""
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    if opcode == 0x8:
        raise ConnectionError("print signal closed")
    if opcode == 0x9:
        _send_frame(sock, 0xA, payload)
        return None
    if opcode != 0x1:
        return None
    return payload.decode("utf-8", errors="replace")


def _join_message(restaurant_id: str, access_token: str) -> str:
    return json.dumps(
        {
            "topic": f"realtime:print_signal:{restaurant_id}",
            "event": "phx_join",
            "payload": {
                "config": {
                    "broadcast": {"ack": False, "self": False},
                    "presence": {"enabled": False},
                    "private": False,
                },
                "access_token": access_token,
            },
            "ref": "1",
            "join_ref": "1",
        },
        separators=(",", ":"),
    )


def open_realtime_socket(config: Any) -> socket.socket:
    parts = urlsplit(str(config.supabase_url).strip())
    scheme = parts.scheme.lower()
    if scheme not in {"https", "http", "wss", "ws"} or not parts.hostname:
        raise ConnectionError("print signal url unavailable")
    secure = scheme in {"https", "wss"}
    port = parts.port or (443 if secure else 80)
    path = (
        "/realtime/v1/websocket?apikey="
        + quote(str(config.supabase_anon_key), safe="")
        + "&vsn=1.0.0"
    )
    raw = socket.create_connection((parts.hostname, port), timeout=8)
    if secure:
        raw = ssl.create_default_context().wrap_socket(raw, server_hostname=parts.hostname)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {parts.hostname}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    )
    raw.sendall(request.encode("ascii"))
    response = bytearray()
    while b"\r\n\r\n" not in response:
        part = raw.recv(1024)
        if not part:
            raise ConnectionError("print signal handshake closed")
        response.extend(part)
        if len(response) > 8192:
            raise ConnectionError("print signal handshake rejected")
    status = response.split(b"\r\n", 1)[0]
    if b" 101 " not in status:
        raise ConnectionError("print signal handshake rejected")
    return raw


class PrintSignalListener:
    def __init__(
        self,
        *,
        wake: Callable[[], None],
        stop_event: threading.Event,
        config_loader: Callable[[], Any],
        connect: Callable[[Any], socket.socket] | None = None,
    ) -> None:
        self._wake = wake
        self._stop = stop_event
        self._config_loader = config_loader
        self._connect = connect or open_realtime_socket
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._thread = threading.Thread(
            target=self._run,
            daemon=True,
            name="ibul-print-signal",
        )
        self._thread.start()

    def _run(self) -> None:
        backoff = 1.0
        while not self._stop.is_set():
            config = self._config_loader()
            if not getattr(config, "ready", False) or not getattr(
                config, "print_system_enabled", False
            ):
                self._stop.wait(2)
                continue
            try:
                self._listen_once(config)
                backoff = 1.0
            except Exception as exc:  # noqa: BLE001
                LOGGER.warning("print signal disconnected: %s", type(exc).__name__)
                self._stop.wait(backoff)
                backoff = min(10.0, backoff * 2)

    def _listen_once(self, config: Any) -> None:
        sock = self._connect(config)
        try:
            _send_frame(
                sock,
                0x1,
                _join_message(
                    str(config.restaurant_id),
                    str(getattr(config, "access_token", "") or ""),
                ).encode("utf-8"),
            )
            while not self._stop.is_set():
                text = read_text_frame(sock, 20)
                if text is None:
                    _send_frame(
                        sock,
                        0x1,
                        b'{"topic":"phoenix","event":"heartbeat","payload":{},"ref":"hb"}',
                    )
                    continue
                reply = join_reply_status(text)
                if reply == "error":
                    raise ConnectionError("print signal join rejected")
                if reply == "ok":
                    LOGGER.info("print signal join ok")
                    continue
                if signal_frame_should_wake(text, str(config.restaurant_id)):
                    LOGGER.info("PRINT_TIMING source=print_signal wake=1")
                    self._wake()
        finally:
            try:
                sock.close()
            except Exception:  # noqa: BLE001
                return
