from __future__ import annotations

from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging

from .config import BridgeSettings
from .models import PayloadError, ReceiptPayload
from .receipt import ReceiptRenderer
from .transport import CupsRawTransport, TransportError


LOGGER = logging.getLogger("local_print_bridge")


def build_test_payload() -> ReceiptPayload:
    return ReceiptPayload.from_dict(
        {
            "store_name": "IBUL RESTAURANT",
            "branch": "MERKEZ SUBE",
            "phone": "0326 000 00 00",
            "table_no": "12",
            "datetime": datetime.now().astimezone().isoformat(),
            "items": [
                {
                    "name": "Izgara Kofte",
                    "qty": 2,
                    "total": "390.00",
                    "price": "195.00",
                },
                {
                    "name": "Acik Ayran",
                    "qty": 1,
                    "total": "45.00",
                    "price": "45.00",
                    "note": "Buyuk bardak",
                },
            ],
            "subtotal": "435.00",
            "discount": "0.00",
            "grand_total": "435.00",
            "footer_note": "Test fişi - Afiyet olsun",
        }
    )


class PrintBridgeHandler(BaseHTTPRequestHandler):
    server_version = "IBULPrintBridge/0.1"

    settings = BridgeSettings.from_env()
    renderer = ReceiptRenderer(settings)
    transport = CupsRawTransport(settings)

    def do_OPTIONS(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return
        self._send_json(HTTPStatus.NO_CONTENT, None)

    def do_GET(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return

        if self.path != "/health":
            self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "Not found."})
            return

        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "service": "ibul-local-print-bridge",
                "transport": "cups-lp-raw",
                "printer_queue": self.settings.printer_queue,
                "paper_width_mm": self.settings.paper_width_mm,
                "chars_per_line": self.settings.chars_per_line,
                "encoding": self.settings.encoding,
                "codepage": self.settings.codepage,
                "allowed_origins": list(self.settings.allowed_origins),
                "printer": self.transport.health(),
            },
        )

    def do_POST(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin")
        if origin and not self._origin_allowed(origin):
            self._send_json(HTTPStatus.FORBIDDEN, {"ok": False, "error": "Origin not allowed."})
            return

        if self.path == "/print/test":
            self._handle_print_test()
            return
        if self.path == "/print/receipt":
            self._handle_print_receipt()
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "Not found."})

    def log_message(self, format: str, *args: object) -> None:
        LOGGER.info("%s - %s", self.address_string(), format % args)

    def _handle_print_test(self) -> None:
        payload = build_test_payload()
        self._submit_receipt(payload, job_name="ibul-test-receipt")

    def _handle_print_receipt(self) -> None:
        try:
            raw_payload = self._read_json_body()
            payload = ReceiptPayload.from_dict(raw_payload)
        except PayloadError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": str(exc)})
            return
        except json.JSONDecodeError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "Invalid JSON body."})
            return

        job_name = f"adisyon-masa-{payload.table_no}"
        self._submit_receipt(payload, job_name=job_name)

    def _submit_receipt(self, payload: ReceiptPayload, *, job_name: str) -> None:
        try:
            raw_bytes = self.renderer.render(payload)
            result = self.transport.print_bytes(raw_bytes, job_name=job_name)
        except TransportError as exc:
            LOGGER.error("Print transport failed: %s", exc)
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"ok": False, "error": str(exc)})
            return
        except Exception as exc:  # pragma: no cover - defensive guard
            LOGGER.exception("Unexpected receipt rendering failure")
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": f"Unexpected print failure: {exc}"},
            )
            return

        self._send_json(
            HTTPStatus.OK,
            {
                "ok": True,
                "job_id": result.job_id,
                "printer_queue": self.settings.printer_queue,
                "bytes_sent": result.bytes_sent,
                "transport_output": result.raw_output,
            },
        )

    def _read_json_body(self) -> dict[str, object]:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        if not raw_body:
            raise PayloadError("Request body is required.")
        return json.loads(raw_body.decode("utf-8"))

    def _origin_allowed(self, origin: str) -> bool:
        return origin in self.settings.allowed_origins

    def _send_json(self, status: HTTPStatus, payload: dict[str, object] | None) -> None:
        body = b""
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

        self.send_response(status.value)
        origin = self.headers.get("Origin")
        if origin and self._origin_allowed(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
            if self.headers.get("Access-Control-Request-Private-Network", "").lower() == "true":
                self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Max-Age", "600")
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)


def serve() -> None:
    settings = BridgeSettings.from_env()
    PrintBridgeHandler.settings = settings
    PrintBridgeHandler.renderer = ReceiptRenderer(settings)
    PrintBridgeHandler.transport = CupsRawTransport(settings)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    server = ThreadingHTTPServer((settings.host, settings.port), PrintBridgeHandler)
    LOGGER.info(
        "Local print bridge listening on http://%s:%s (queue=%s)",
        settings.host,
        settings.port,
        settings.printer_queue or "<unset>",
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        LOGGER.info("Shutting down local print bridge")
    finally:
        server.server_close()


if __name__ == "__main__":
    serve()
