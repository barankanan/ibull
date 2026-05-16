import json
import logging
import platform
import subprocess
import threading
import time
import traceback
from datetime import datetime

from flask import Flask, g, request, jsonify, make_response
from escpos.printer import Usb
import usb.backend.libusb1

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ibul_local_print")

ALLOWED_ORIGIN = "https://ibul-ecommerce.web.app"
SERVICE_NAME = "ibul-python-print"
SERVICE_ROUTES = [
    "/health",
    "/print/test",
    "/print/receipt",
    "/print/kitchen",
    "/system/release-usb-printers",
]
VENDOR_ID = 0x0416
PRODUCT_ID = 0x5011
USB_INTERFACE = 0
USB_IN_EP = 0x81
USB_OUT_EP = 0x03
LIBUSB_PATH = "/opt/homebrew/lib/libusb-1.0.0.dylib"
PRINT_LOCK = threading.Lock()
RECEIPT_WIDTH = 32
RECEIPT_DIVIDER = "-" * RECEIPT_WIDTH
RECEIPT_CHARSET = "CP857"
RECEIPT_CODEPAGE = 13
RECEIPT_CODEPAGE_COMMAND = b"\x1bt" + bytes([RECEIPT_CODEPAGE])
RECEIPT_TURKISH_FALLBACK_MAP = str.maketrans(
    {
        "ş": "s",
        "Ş": "S",
        "ı": "i",
        "İ": "I",
        "ğ": "g",
        "Ğ": "G",
        "ç": "c",
        "Ç": "C",
        "ö": "o",
        "Ö": "O",
        "ü": "u",
        "Ü": "U",
    }
)


def _format_log_value(value):
    if isinstance(value, (dict, list, tuple)):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return str(value)


def _log_server(branch, **fields):
    payload = " ".join(
        f"{key}={_format_log_value(value)}"
        for key, value in fields.items()
        if value is not None
    )
    message = f"[LocalPrint][Server] branch={branch}"
    if payload:
        message = f"{message} {payload}"
    print(message, flush=True)


def _log_server_marker(marker, **fields):
    payload = " ".join(
        f"{key}={_format_log_value(value)}"
        for key, value in fields.items()
        if value is not None
    )
    message = f"[LocalPrint][Server] {marker}"
    if payload:
        message = f"{message} {payload}"
    print(message, flush=True)


def _safe_printer_set(printer, step, **kwargs):
    try:
        printer.set(**kwargs)
        _log_server("printer_set", step=step, options=kwargs, ok=True)
        return True
    except Exception as exc:
        _log_server(
            "printer_set_error",
            step=step,
            options=kwargs,
            error=str(exc),
            stackTrace=traceback.format_exc(),
        )
        return False


def _safe_printer_raw(printer, step, payload):
    try:
        printer._raw(payload)
        _log_server(
            "printer_raw",
            step=step,
            bytesHex=payload.hex(),
            ok=True,
        )
        return True
    except Exception as exc:
        _log_server(
            "printer_raw_error",
            step=step,
            bytesHex=payload.hex(),
            error=str(exc),
            stackTrace=traceback.format_exc(),
        )
        return False


def _printer_lock_context(route):
    class _PrinterLockContext:
        def __enter__(self_inner):
            _log_server("printer_lock_wait", route=route)
            PRINT_LOCK.acquire()
            _log_server("printer_lock_acquired", route=route)
            return self_inner

        def __exit__(self_inner, exc_type, exc, tb):
            if PRINT_LOCK.locked():
                PRINT_LOCK.release()
            _log_server(
                "printer_lock_released",
                route=route,
                hadException=exc is not None,
            )
            return False

    return _PrinterLockContext()


def _close_printer(printer, route):
    if printer is None:
        return
    try:
        printer.close()
        _log_server("printer_close", route=route, ok=True)
    except Exception as exc:
        _log_server(
            "printer_close_error",
            route=route,
            error=str(exc),
            stackTrace=traceback.format_exc(),
        )


def _receipt_text(value, fallback="-"):
    if value is None:
        return fallback
    text = str(value).strip()
    return text or fallback


def _format_receipt_number(value):
    try:
        amount = float(value)
    except (TypeError, ValueError):
        return _receipt_text(value)
    formatted = f"{amount:,.2f}"
    return formatted.replace(",", "X").replace(".", ",").replace("X", ".")


def _format_receipt_amount(value):
    return f"{_format_receipt_number(value)} TL"


def _format_receipt_datetime(value):
    text = _receipt_text(value)
    try:
        normalized = text.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return parsed.strftime("%d.%m.%Y %H:%M")
    except ValueError:
        return text


def _format_receipt_quantity(value):
    try:
        amount = float(value)
    except (TypeError, ValueError):
        return _receipt_text(value, fallback="1")

    if amount.is_integer():
        return str(int(amount))

    formatted = f"{amount:.3f}".rstrip("0").rstrip(".")
    return formatted.replace(".", ",")


def _normalize_receipt_text(value, fallback="-", preserve_whitespace=False):
    if value is None:
        text = fallback
    else:
        text = str(value)
        if preserve_whitespace:
            if text == "":
                text = fallback
        else:
            text = text.strip() or fallback
    _log_server_marker("receipt_normalize_input", value=text)
    normalized = text.translate(RECEIPT_TURKISH_FALLBACK_MAP)
    _log_server_marker("receipt_normalize_output", value=normalized)
    return normalized


def _print_receipt_line(printer, raw_text, *, route, step):
    raw_line = "" if raw_text is None else str(raw_text)
    _log_server_marker(
        "receipt_print_line_raw",
        route=route,
        step=step,
        value=raw_line,
    )
    normalized_line = _normalize_receipt_text(
        raw_line,
        fallback="",
        preserve_whitespace=True,
    )
    _log_server_marker(
        "receipt_print_line_normalized",
        route=route,
        step=step,
        value=normalized_line,
    )
    printer.text(f"{normalized_line}\n")


def _wrap_receipt_text(value, width=RECEIPT_WIDTH):
    text = _receipt_text(value)
    if len(text) <= width:
        return [text]

    words = text.split()
    if not words:
        return [text[:width]]

    lines = []
    current = ""
    for raw_word in words:
        word = raw_word
        if len(word) > width:
            if current:
                lines.append(current)
                current = ""
            while len(word) > width:
                lines.append(word[:width])
                word = word[width:]
            current = word
            continue

        candidate = word if not current else f"{current} {word}"
        if len(candidate) <= width:
            current = candidate
        else:
            lines.append(current)
            current = word

    if current:
        lines.append(current)
    return lines or [text[:width]]


def _receipt_pair(left, right, width=RECEIPT_WIDTH):
    left_text = _receipt_text(left, fallback="")
    right_text = _receipt_text(right, fallback="")
    min_gap = 2
    if len(left_text) + len(right_text) + min_gap <= width:
        gap = width - len(left_text) - len(right_text)
        return f"{left_text}{' ' * gap}{right_text}"

    wrapped_left = _wrap_receipt_text(left_text, width)
    last_line = wrapped_left[-1]
    if len(last_line) + len(right_text) + min_gap <= width:
        gap = width - len(last_line) - len(right_text)
        wrapped_left[-1] = f"{last_line}{' ' * gap}{right_text}"
        return "\n".join(wrapped_left)

    return "\n".join([*wrapped_left, right_text.rjust(width)])


def _format_receipt_item_lines(item, width=RECEIPT_WIDTH):
    name = _receipt_text(
        item.get("name"),
        fallback="Urun",
    )
    # Accept both receipt format ("qty") and kitchen format ("quantity").
    qty = _format_receipt_quantity(item.get("qty", item.get("quantity", 1)))
    # Accept both receipt format ("price") and kitchen format ("unit_price").
    unit_price = _format_receipt_number(item.get("price", item.get("unit_price", 0)))
    # Accept both receipt format ("total") and kitchen format ("line_total").
    line_total = _format_receipt_amount(item.get("total", item.get("line_total", 0)))
    name_lines = _wrap_receipt_text(name, width)
    detail_line = _receipt_pair(f"{qty} x {unit_price}", line_total, width)
    _log_server(
        "receipt_item_wrap",
        itemName=name,
        wrappedLines=len(name_lines),
        detailLine=detail_line,
    )
    return [*name_lines, detail_line]


def _kitchen_note_lines(item, width=RECEIPT_WIDTH, indent="  "):
    raw_note = (
        item.get("note")
        or item.get("notes")
        or item.get("item_note")
        or item.get("general_note")
    )
    if raw_note is None:
        return []

    lines = []
    for raw_line in str(raw_note).splitlines():
        note_line = raw_line.strip()
        if not note_line:
            continue
        wrapped = _wrap_receipt_text(
            f"Not: {note_line}",
            max(8, width - len(indent)),
        )
        for line in wrapped:
            lines.append(f"{indent}{line}")
    return lines


def _kitchen_service_children(item):
    children = item.get("service_children")
    return children if isinstance(children, list) else []


def _kitchen_plates(item):
    plates = item.get("plates")
    return plates if isinstance(plates, list) else []


def _kitchen_service_count(items):
    return sum(
        1
        for item in items
        if _kitchen_service_children(item) or _kitchen_plates(item)
    )


def _kitchen_plate_count(items):
    return sum(len(_kitchen_plates(item)) for item in items)


def _append_kitchen_child_lines(lines, children, width=RECEIPT_WIDTH, indent="  "):
    for child in children:
        name = _receipt_text(
            child.get("name") or child.get("product_name"),
            fallback="Urun",
        )
        qty = _format_receipt_quantity(child.get("qty", child.get("quantity", 1)))
        for line in _wrap_receipt_text(f"- {name} x{qty}", max(8, width - len(indent))):
            lines.append(f"{indent}{line}")

        amount_label = _receipt_text(child.get("amount_label"), fallback="")
        if amount_label and amount_label != "-":
            for line in _wrap_receipt_text(
                amount_label,
                max(8, width - len(indent) - 2),
            ):
                lines.append(f"{indent}  {line}")

        lines.extend(_kitchen_note_lines(child, width, indent=f"{indent}  "))


def _format_kitchen_item_lines(item, width=RECEIPT_WIDTH):
    name = _receipt_text(
        item.get("name") or item.get("product_name"),
        fallback="Urun",
    )
    qty = _format_receipt_quantity(item.get("qty", item.get("quantity", 1)))
    amount_label = _receipt_text(item.get("amount_label"), fallback="")
    note_lines = _kitchen_note_lines(item, width)
    lines = _wrap_receipt_text(f"{name} x{qty}", width)
    if amount_label and amount_label != "-":
        for line in _wrap_receipt_text(amount_label, max(8, width - 2)):
            lines.append(f"  {line}")
    lines.extend(note_lines)

    plates = _kitchen_plates(item)
    if plates:
        for plate in plates:
            plate_label = _receipt_text(plate.get("label"), fallback="Tabak")
            for line in _wrap_receipt_text(plate_label, max(8, width - 2)):
                lines.append(f"  {line}")
            _append_kitchen_child_lines(
                lines,
                plate.get("items") if isinstance(plate, dict) else [],
                width,
                indent="    ",
            )
    else:
        _append_kitchen_child_lines(
            lines,
            _kitchen_service_children(item),
            width,
            indent="  ",
        )

    _log_server(
        "kitchen_item_wrap",
        itemName=name,
        wrappedLines=len(lines),
        quantity=qty,
        hasAmountLabel=amount_label not in ("", "-"),
        hasNote=bool(note_lines),
        serviceChildCount=len(_kitchen_service_children(item)),
        plateCount=len(plates),
    )
    return lines


def _configure_receipt_charset(printer, route):
    charcode_supported = callable(getattr(printer, "charcode", None))
    raw_supported = callable(getattr(printer, "_raw", None))
    raw_override_ok = False
    raw_override_error = None

    if charcode_supported:
        try:
            printer.charcode(RECEIPT_CHARSET)
            if raw_supported:
                raw_override_ok = _safe_printer_raw(
                    printer,
                    "receipt_codepage_override",
                    RECEIPT_CODEPAGE_COMMAND,
                )
                if not raw_override_ok:
                    raw_override_error = "codepage_override_failed"
            _log_server(
                "receipt_charset_mode",
                route=route,
                mode="cp857",
                encoding=RECEIPT_CHARSET.lower(),
                codepage=RECEIPT_CODEPAGE,
                fallbackActive=False,
                rawOverride=raw_override_ok,
                rawSupported=raw_supported,
                rawOverrideError=raw_override_error,
            )
            return {"mode": "cp857", "ascii_only": False}
        except Exception as exc:
            if raw_supported:
                raw_override_ok = _safe_printer_raw(
                    printer,
                    "receipt_codepage_override",
                    RECEIPT_CODEPAGE_COMMAND,
                )
                if not raw_override_ok:
                    raw_override_error = "codepage_override_failed"
            _log_server(
                "receipt_charset_mode",
                route=route,
                mode="latin_fallback",
                encoding="ascii",
                codepage=RECEIPT_CODEPAGE if raw_override_ok else None,
                fallbackActive=True,
                reason="charcode_error",
                error=str(exc),
                rawSupported=raw_supported,
                rawOverride=raw_override_ok,
                rawOverrideError=raw_override_error,
            )
            return {"mode": "latin_fallback", "ascii_only": True}

    if raw_supported:
        raw_override_ok = _safe_printer_raw(
            printer,
            "receipt_codepage_override",
            RECEIPT_CODEPAGE_COMMAND,
        )
        if not raw_override_ok:
            raw_override_error = "codepage_override_failed"

    _log_server(
        "receipt_charset_mode",
        route=route,
        mode="latin_fallback",
        encoding="ascii",
        codepage=RECEIPT_CODEPAGE if raw_override_ok else None,
        fallbackActive=True,
        reason="charcode_unavailable",
        rawSupported=raw_supported,
        rawOverride=raw_override_ok,
        rawOverrideError=raw_override_error,
    )
    return {"mode": "latin_fallback", "ascii_only": True}


def _append_vary(resp, value):
    current_value = resp.headers.get("Vary", "")
    existing_values = {item.strip() for item in current_value.split(",") if item.strip()}
    if value not in existing_values:
        resp.headers["Vary"] = ", ".join(
            [item for item in [current_value.strip(), value] if item]
        )
    return resp


def _add_cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = ALLOWED_ORIGIN
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    resp.headers["Access-Control-Allow-Private-Network"] = "true"
    resp.headers["Access-Control-Max-Age"] = "600"
    _append_vary(resp, "Origin")
    return resp


def get_backend():
    backend = usb.backend.libusb1.get_backend(find_library=lambda _: LIBUSB_PATH)
    _log_server(
        "get_backend",
        libusbPath=LIBUSB_PATH,
        backendReady=backend is not None,
    )
    return backend


def _summarize_payload(data):
    if isinstance(data, dict):
        items = data.get("items")
        return {
            "keys": sorted(data.keys()),
            "itemsCount": len(items) if isinstance(items, list) else 0,
        }
    if data is None:
        return {"type": "none"}
    return {"type": type(data).__name__}


def get_printer():
    backend = get_backend()
    if backend is None:
        raise Exception("libusb backend bulunamadi")

    _log_server(
        "get_printer",
        vendorId=hex(VENDOR_ID),
        productId=hex(PRODUCT_ID),
        interface=USB_INTERFACE,
        inEp=hex(USB_IN_EP),
        outEp=hex(USB_OUT_EP),
    )
    usb_kwargs = {
        "in_ep": USB_IN_EP,
        "out_ep": USB_OUT_EP,
        "usb_args": {"backend": backend},
    }
    try:
        return Usb(
            VENDOR_ID,
            PRODUCT_ID,
            interface=USB_INTERFACE,
            **usb_kwargs,
        )
    except TypeError as exc:
        if "interface" not in str(exc):
            raise
        return Usb(VENDOR_ID, PRODUCT_ID, **usb_kwargs)


def _preflight_response():
    _log_server(
        "preflight",
        route=request.path,
        method=request.method,
        origin=request.headers.get("Origin", "-"),
    )
    return make_response("", 204)


def _service_index():
    return {
        "ok": True,
        "service": SERVICE_NAME,
        "routes": SERVICE_ROUTES,
    }


@app.after_request
def after_request(response):
    response = _add_cors(response)
    started_at = getattr(g, "local_print_started_at", None)
    duration_ms = None
    if started_at is not None:
        duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
    _log_server(
        "response",
        route=request.path,
        method=request.method,
        status=response.status_code,
        durationMs=duration_ms,
        origin=request.headers.get("Origin", "-"),
        allowOrigin=response.headers.get("Access-Control-Allow-Origin"),
        allowMethods=response.headers.get("Access-Control-Allow-Methods"),
        allowHeaders=response.headers.get("Access-Control-Allow-Headers"),
        allowPrivateNetwork=response.headers.get(
            "Access-Control-Allow-Private-Network"
        ),
        vary=response.headers.get("Vary"),
    )
    return response


@app.before_request
def before_request():
    g.local_print_started_at = time.perf_counter()
    raw_bytes = request.get_data(cache=True)
    json_body = request.get_json(silent=True)
    _log_server(
        "request",
        route=request.path,
        method=request.method,
        origin=request.headers.get("Origin", "-"),
        contentType=request.headers.get("Content-Type", "-"),
        contentLength=request.content_length or len(raw_bytes or b""),
        payloadSummary=_summarize_payload(json_body),
    )


@app.route("/", methods=["GET", "OPTIONS"])
def root():
    if request.method == "OPTIONS":
        return _preflight_response()
    return jsonify(_service_index())


@app.route("/health", methods=["GET", "POST", "OPTIONS"])
def health():
    if request.method == "OPTIONS":
        return _preflight_response()
    return jsonify(_service_index())


@app.route("/system/release-usb-printers", methods=["POST", "OPTIONS"])
def release_usb_printers():
    if request.method == "OPTIONS":
        return _preflight_response()
    if platform.system().lower() != "darwin":
        return (
            jsonify(
                {
                    "ok": False,
                    "error": "USB printer release is only supported on macOS.",
                }
            ),
            400,
        )
    try:
        result = subprocess.run(
            ["killall", "-USR1", "cupsd"],
            capture_output=True,
            text=True,
            check=False,
        )
    except Exception as exc:  # noqa: BLE001
        return jsonify({"ok": False, "error": str(exc)}), 500
    if result.returncode != 0:
        return (
            jsonify(
                {
                    "ok": False,
                    "error": (result.stderr or result.stdout or "killall -USR1 cupsd failed").strip(),
                    "exit_code": result.returncode,
                }
            ),
            500,
        )
    time.sleep(0.5)
    return jsonify(
        {
            "ok": True,
            "released": True,
            "command": "killall -USR1 cupsd",
            "wait_ms": 500,
        }
    )


@app.route("/print/test", methods=["GET", "POST", "OPTIONS"])
def print_test():
    if request.method == "OPTIONS":
        return _preflight_response()
    if request.method == "GET":
        return jsonify(
            {
                "ok": True,
                "service": SERVICE_NAME,
                "route": "/print/test",
                "method": "POST",
            }
        )
    try:
        _log_server("print_test_start", route="/print/test")
        _log_server_marker("receipt_text_mode=latin_fallback_forced", route="/print/test")
        with _printer_lock_context("/print/test"):
            p = None
            try:
                p = get_printer()
                _safe_printer_set(p, "test_header_center", align="center")
                _print_receipt_line(
                    p,
                    "IBUL PRINT TEST",
                    route="/print/test",
                    step="test_title",
                )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/test",
                    step="test_divider_top",
                )
                _print_receipt_line(
                    p,
                    "Bu cikti sadece test icindir.",
                    route="/print/test",
                    step="test_body",
                )
                _print_receipt_line(
                    p,
                    "127.0.0.1:3001",
                    route="/print/test",
                    step="test_host",
                )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/test",
                    step="test_divider_bottom",
                )
                p.cut()
            finally:
                _close_printer(p, "/print/test")
        _log_server("print_test_done", route="/print/test")
        return jsonify({"ok": True})
    except Exception as e:
        _log_server(
            "print_test_error",
            route="/print/test",
            error=str(e),
            stackTrace=traceback.format_exc(),
        )
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/print/receipt", methods=["GET", "POST", "OPTIONS"])
def print_receipt():
    if request.method == "OPTIONS":
        return _preflight_response()
    if request.method == "GET":
        return jsonify(
            {
                "ok": True,
                "service": SERVICE_NAME,
                "route": "/print/receipt",
                "method": "POST",
            }
        )
    try:
        data = request.get_json(silent=True) or {}
        table_no = _receipt_text(data.get("table_no"))
        _log_server(
            "print_receipt_payload",
            route="/print/receipt",
            tableNo=table_no,
            payloadSummary=_summarize_payload(data),
        )
        items = data.get("items", [])
        receipt_items = items if isinstance(items, list) else []
        with _printer_lock_context("/print/receipt"):
            p = None
            try:
                p = get_printer()
                _log_server(
                    "print_receipt_start",
                    route="/print/receipt",
                    tableNo=table_no,
                    itemsCount=len(receipt_items),
                )
                charset_mode = _configure_receipt_charset(p, "/print/receipt")
                _log_server_marker(
                    "receipt_text_mode=latin_fallback_forced",
                    route="/print/receipt",
                    charsetMode=charset_mode["mode"],
                )

                _log_server(
                    "receipt_format_start",
                    route="/print/receipt",
                    tableNo=table_no,
                    itemsCount=len(receipt_items),
                    charsetMode=charset_mode["mode"],
                )
                store_name = _receipt_text(
                    data.get("store_name"),
                    fallback="IBUL",
                )
                branch = _receipt_text(
                    data.get("branch"),
                    fallback="",
                )
                receipt_table_no = _receipt_text(
                    data.get("table_no"),
                )
                printed_at = _format_receipt_datetime(data.get("datetime"))
                grand_total = _format_receipt_amount(data.get("grand_total", 0))
                header_lines = _wrap_receipt_text(store_name)
                branch_lines = (
                    _wrap_receipt_text(branch) if branch and branch != "-" else []
                )
                meta_lines = [
                    _receipt_pair("Masa", receipt_table_no),
                    _receipt_pair("Tarih", printed_at),
                ]
                item_lines = []
                for item in receipt_items:
                    item_lines.extend(
                        _format_receipt_item_lines(
                            item,
                        )
                    )
                total_line = _receipt_pair("TOPLAM", grand_total)
                _log_server(
                    "receipt_format_done",
                    route="/print/receipt",
                    tableNo=table_no,
                    itemsCount=len(receipt_items),
                    headerLines=len(header_lines) + len(branch_lines),
                    bodyLines=len(meta_lines) + len(item_lines) + 1,
                )

                _safe_printer_set(p, "receipt_header_center", align="center", bold=True)
                for index, line in enumerate(header_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/receipt",
                        step=f"header_store_name_{index}",
                    )
                _safe_printer_set(p, "receipt_branch_center", align="center", bold=False)
                for index, line in enumerate(branch_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/receipt",
                        step=f"header_branch_{index}",
                    )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/receipt",
                    step="divider_after_header",
                )

                _safe_printer_set(p, "receipt_meta_left", align="left", bold=False)
                for index, line in enumerate(meta_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/receipt",
                        step=f"meta_line_{index}",
                    )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/receipt",
                    step="divider_before_items",
                )

                for index, line in enumerate(item_lines, start=1):
                    step = "item_name"
                    if " x " in line and "TL" in line:
                        step = "item_detail"
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/receipt",
                        step=f"{step}_{index}",
                    )

                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/receipt",
                    step="divider_before_total",
                )
                _safe_printer_set(p, "receipt_total_left", align="left", bold=True)
                _print_receipt_line(
                    p,
                    total_line,
                    route="/print/receipt",
                    step="total_line",
                )
                _safe_printer_set(p, "receipt_total_reset", align="left", bold=False)
                _print_receipt_line(
                    p,
                    "",
                    route="/print/receipt",
                    step="footer_blank_line",
                )
                p.cut()
            finally:
                _close_printer(p, "/print/receipt")

        _log_server(
            "print_receipt_done",
            route="/print/receipt",
            tableNo=table_no,
            itemsCount=len(receipt_items),
        )
        return jsonify({"ok": True})
    except Exception as e:
        _log_server(
            "print_receipt_error",
            route="/print/receipt",
            error=str(e),
            stackTrace=traceback.format_exc(),
        )
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/print/kitchen", methods=["GET", "POST", "OPTIONS"])
def print_kitchen():
    if request.method == "OPTIONS":
        return _preflight_response()
    if request.method == "GET":
        return jsonify(
            {
                "ok": True,
                "service": SERVICE_NAME,
                "route": "/print/kitchen",
                "method": "POST",
            }
        )
    try:
        data = request.get_json(silent=True) or {}
        table_no = _receipt_text(
            data.get("table_no") or data.get("table_name"),
        )
        area_name = _receipt_text(
            data.get("area_name") or data.get("station_name"),
            fallback="Genel",
        )
        items = data.get("items", [])
        kitchen_items = items if isinstance(items, list) else []
        service_count = _kitchen_service_count(kitchen_items)
        plate_count = _kitchen_plate_count(kitchen_items)
        _log_server(
            "print_kitchen_payload",
            route="/print/kitchen",
            tableNo=table_no,
            area=area_name,
            itemCount=len(kitchen_items),
            serviceCount=service_count,
            plateCount=plate_count,
            payloadSummary=_summarize_payload(data),
        )
        if not kitchen_items:
            _log_server(
                "WARN_EMPTY_ITEMS",
                route="/print/kitchen",
                tableNo=table_no,
                area=area_name,
                payloadKeys=sorted(data.keys()),
                action="printing_header_only_no_items",
            )
            # Print a visible placeholder on the ticket so the operator is alerted
            kitchen_items = [{"name": "*** URUN BULUNAMADI / EMPTY ITEMS PAYLOAD ***", "quantity": 1}]
        with _printer_lock_context("/print/kitchen"):
            p = None
            try:
                p = get_printer()
                _log_server(
                    "print_kitchen_start",
                    route="/print/kitchen",
                    tableNo=table_no,
                    area=area_name,
                    itemsCount=len(kitchen_items),
                    serviceCount=service_count,
                    plateCount=plate_count,
                )
                charset_mode = _configure_receipt_charset(p, "/print/kitchen")
                _log_server_marker(
                    "receipt_text_mode=latin_fallback_forced",
                    route="/print/kitchen",
                    charsetMode=charset_mode["mode"],
                )

                order_no = _receipt_text(data.get("order_no"), fallback="")
                printed_at = _format_receipt_datetime(
                    data.get("datetime") or data.get("created_at")
                )
                waiter_name = _receipt_text(data.get("waiter_name"), fallback="")
                header_lines = _wrap_receipt_text("MUTFAK SIPARISI")
                area_lines = _wrap_receipt_text(area_name.upper())
                meta_lines = [
                    _receipt_pair("Alan", area_name),
                    _receipt_pair("Masa", table_no),
                    _receipt_pair("Tarih", printed_at),
                ]
                if order_no and order_no != "-":
                    meta_lines.append(_receipt_pair("Siparis", order_no))
                if waiter_name and waiter_name != "-":
                    meta_lines.append(_receipt_pair("Garson", waiter_name))

                item_lines = []
                for item in kitchen_items:
                    item_lines.extend(_format_kitchen_item_lines(item))
                    item_lines.append("")
                while item_lines and item_lines[-1] == "":
                    item_lines.pop()

                _log_server(
                    "kitchen_format_done",
                    route="/print/kitchen",
                    tableNo=table_no,
                    area=area_name,
                    itemsCount=len(kitchen_items),
                    serviceCount=service_count,
                    plateCount=plate_count,
                    headerLines=len(header_lines) + len(area_lines),
                    bodyLines=len(meta_lines) + len(item_lines),
                )

                _safe_printer_set(p, "kitchen_header_center", align="center", bold=True)
                for index, line in enumerate(header_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/kitchen",
                        step=f"kitchen_header_{index}",
                    )
                _safe_printer_set(p, "kitchen_area_center", align="center", bold=True)
                for index, line in enumerate(area_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/kitchen",
                        step=f"kitchen_area_{index}",
                    )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/kitchen",
                    step="kitchen_divider_after_header",
                )

                _safe_printer_set(p, "kitchen_meta_left", align="left", bold=False)
                for index, line in enumerate(meta_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/kitchen",
                        step=f"kitchen_meta_{index}",
                    )
                _print_receipt_line(
                    p,
                    RECEIPT_DIVIDER,
                    route="/print/kitchen",
                    step="kitchen_divider_before_items",
                )

                _safe_printer_set(p, "kitchen_items_left", align="left", bold=True)
                for index, line in enumerate(item_lines, start=1):
                    _print_receipt_line(
                        p,
                        line,
                        route="/print/kitchen",
                        step=f"kitchen_item_{index}",
                    )

                _safe_printer_set(p, "kitchen_footer_left", align="left", bold=False)
                _print_receipt_line(
                    p,
                    "",
                    route="/print/kitchen",
                    step="kitchen_footer_blank",
                )
                p.cut()
            finally:
                _close_printer(p, "/print/kitchen")

        _log_server(
            "print_kitchen_done",
            route="/print/kitchen",
            tableNo=table_no,
            area=area_name,
            itemsCount=len(kitchen_items),
            serviceCount=service_count,
            plateCount=plate_count,
        )
        return jsonify({"ok": True})
    except Exception as e:
        _log_server(
            "print_kitchen_error",
            route="/print/kitchen",
            error=str(e),
            stackTrace=traceback.format_exc(),
        )
        return jsonify({"ok": False, "error": str(e)}), 500


if __name__ == "__main__":
    _log_server(
        "startup",
        service=SERVICE_NAME,
        host="127.0.0.1",
        port=3001,
        routes=SERVICE_ROUTES,
    )
    app.run(host="127.0.0.1", port=3001)
