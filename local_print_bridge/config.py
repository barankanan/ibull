from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
from typing import Any, Sequence

from .runtime_paths import bridge_env_path


DEFAULT_ALLOWED_ORIGINS = (
    "https://ibul-ecommerce.web.app",
    "http://localhost",
    "http://localhost:3000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
)

_DEFAULT_SAFE_ENCODING = "cp857"
_DEFAULT_SAFE_CODEPAGE = 13
_ENCODING_ALIASES = {
    "cp857": "cp857",
    "cp-857": "cp857",
    "ibm857": "cp857",
    "cp1254": "cp1254",
    "windows-1254": "cp1254",
    "windows1254": "cp1254",
    "iso-8859-9": "iso8859_9",
    "iso8859-9": "iso8859_9",
    "iso88599": "iso8859_9",
    "latin5": "iso8859_9",
    "cp437": "cp437",
    "ibm437": "cp437",
}
_RAW_UNSAFE_ENCODINGS = {"utf8", "utf-8"}
_DEFAULT_CODEPAGE_BY_ENCODING = {
    "cp857": _DEFAULT_SAFE_CODEPAGE,
    "cp437": 0,
}

# ESC/POS codepage numbers known to map to Turkish-capable character sets on
# most thermal printers.  Values outside this set are accepted but trigger a
# warning log so misconfigured printers surface quickly.
_TURKISH_CODEPAGE_WHITELIST: frozenset[int] = frozenset({0, 2, 13, 17, 19, 21, 23, 31, 33})


def _load_env_file() -> None:
    path = bridge_env_path(default_relative_to=Path(__file__))
    if not path.is_file():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key or key in os.environ:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ[key] = value


def _split_csv(raw: str | None, fallback: Sequence[str]) -> tuple[str, ...]:
    if raw is None:
        return tuple(fallback)
    values = tuple(part.strip() for part in raw.split(",") if part.strip())
    return values or tuple(fallback)


def _as_bool(raw: str | None, default: bool) -> bool:
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def write_env_file(updates: dict[str, str], env_path: Path | None = None) -> None:
    """Merge *updates* into the .env file (upsert; existing comments are preserved).

    Also updates ``os.environ`` immediately so that a subsequent
    ``BridgeSettings.from_env()`` call sees the new values without a process
    restart.
    """
    path = env_path or bridge_env_path(default_relative_to=Path(__file__))
    path.parent.mkdir(parents=True, exist_ok=True)

    existing: dict[str, str] = {}
    header_lines: list[str] = []   # comment / blank lines at the top

    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                header_lines.append(raw)
                continue
            line = stripped.removeprefix("export ").strip()
            if "=" in line:
                k, _, v = line.partition("=")
                existing[k.strip()] = v.strip()

    clean_updates = {k: str(v) for k, v in updates.items()}
    existing.update(clean_updates)

    # Write back: header comments first, then key=value pairs
    out_lines = header_lines + [f"{k}={v}" for k, v in existing.items()]
    path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")

    # Update os.environ so BridgeSettings.from_env() picks up changes immediately.
    # (The file loader skips keys already present in os.environ.)
    import os as _os
    for k, v in clean_updates.items():
        _os.environ[k] = v


def _parse_int(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value if value >= 0 else None
    raw = str(value).strip()
    if not raw:
        return None
    try:
        parsed = int(raw)
    except ValueError:
        return None
    return parsed if parsed >= 0 else None


def _canonical_encoding(raw: Any) -> str | None:
    if raw is None:
        return None
    normalized = str(raw).strip().lower().replace("_", "-")
    if not normalized:
        return None
    if normalized in _RAW_UNSAFE_ENCODINGS:
        return None
    return _ENCODING_ALIASES.get(normalized)


@dataclass(frozen=True)
class EscPosProfile:
    encoding: str
    codepage: int | None
    requested_encoding: str | None = None
    requested_codepage: int | None = None
    warnings: tuple[str, ...] = ()

    @property
    def fallback_applied(self) -> bool:
        return bool(self.warnings)

    def as_dict(self) -> dict[str, object]:
        return {
            "encoding": self.encoding,
            "codepage": self.codepage,
            "requested_encoding": self.requested_encoding,
            "requested_codepage": self.requested_codepage,
            "warnings": list(self.warnings),
            "fallback_applied": self.fallback_applied,
        }


def resolve_escpos_profile(
    requested_encoding: Any,
    requested_codepage: Any,
    *,
    default_profile: EscPosProfile | None = None,
) -> EscPosProfile:
    base = default_profile or EscPosProfile(
        encoding=_DEFAULT_SAFE_ENCODING,
        codepage=_DEFAULT_SAFE_CODEPAGE,
    )
    requested_encoding_text = (
        None if requested_encoding is None else str(requested_encoding).strip() or None
    )
    requested_codepage_int = _parse_int(requested_codepage)
    warnings: list[str] = []

    effective_encoding = base.encoding
    canonical = _canonical_encoding(requested_encoding)
    if requested_encoding_text:
      # NOTE: cheap raw ESC/POS text mode is not UTF-8-safe.
        normalized = requested_encoding_text.lower().replace("_", "-")
        if normalized in _RAW_UNSAFE_ENCODINGS:
            warnings.append(
                "UTF-8 raw ESC/POS üzerinde güvenilir değil. "
                "CP857 tablosuna geri dönüldü."
            )
        elif canonical is None:
            warnings.append(
                f"Desteklenmeyen encoding '{requested_encoding_text}'. "
                f"{base.encoding}/{base.codepage} kullanılacak."
            )
        else:
            effective_encoding = canonical

    if requested_codepage_int is not None:
        effective_codepage = requested_codepage_int
        if effective_codepage not in _TURKISH_CODEPAGE_WHITELIST:
            warnings.append(
                f"Codepage {effective_codepage} bilinen Türkçe whitelist dışında "
                f"({sorted(_TURKISH_CODEPAGE_WHITELIST)}). "
                "Klon yazıcı ise doğru değeri test fişiyle bulun."
            )
    elif effective_encoding == base.encoding and base.codepage is not None:
        effective_codepage = base.codepage
    else:
        default_codepage = _DEFAULT_CODEPAGE_BY_ENCODING.get(effective_encoding)
        if default_codepage is not None:
            effective_codepage = default_codepage
        else:
            warnings.append(
                f"Encoding '{effective_encoding}' için açık codepage belirtilmedi. "
                f"{base.encoding}/{base.codepage} kullanılacak."
            )
            effective_encoding = base.encoding
            effective_codepage = base.codepage

    return EscPosProfile(
        encoding=effective_encoding,
        codepage=effective_codepage,
        requested_encoding=requested_encoding_text,
        requested_codepage=requested_codepage_int,
        warnings=tuple(warnings),
    )


@dataclass(frozen=True)
class BridgeSettings:
    host: str
    port: int
    printer_queue: str
    paper_width_mm: int
    chars_per_line: int
    encoding: str
    codepage: int | None
    render_mode: str
    raster_chunk_height: int
    allowed_origins: tuple[str, ...]
    healthcheck_queue: bool
    cut_mode: str
    # USB direct transport
    transport_mode: str        # "auto" | "usb" | "cups" | "network"
    usb_vendor_id: int | None  # hex, e.g. 0x0483
    usb_product_id: int | None # hex, e.g. 0x5743
    # Network TCP transport
    network_host: str          # remote printer IP (used when transport_mode=network)
    network_port: int          # remote printer port (default 9100)
    print_system_enabled: bool

    @classmethod
    def from_env(cls) -> "BridgeSettings":
        _load_env_file()
        paper_width_mm = int(os.getenv("PRINT_BRIDGE_PAPER_WIDTH_MM", "58"))
        default_chars = "32" if paper_width_mm <= 58 else "48"
        profile = resolve_escpos_profile(
            os.getenv("PRINT_BRIDGE_ENCODING", _DEFAULT_SAFE_ENCODING),
            os.getenv("PRINT_BRIDGE_CODEPAGE", str(_DEFAULT_SAFE_CODEPAGE)),
            default_profile=EscPosProfile(
                encoding=_DEFAULT_SAFE_ENCODING,
                codepage=_DEFAULT_SAFE_CODEPAGE,
            ),
        )
        cut_mode = os.getenv("PRINT_BRIDGE_CUT_MODE", "partial").strip().lower()
        if cut_mode not in {"partial", "full", "none"}:
            cut_mode = "partial"
        render_mode = os.getenv("PRINT_BRIDGE_RENDER_MODE", "image").strip().lower()
        if render_mode not in {"image", "text"}:
            render_mode = "image"
        raster_chunk_height = int(os.getenv("PRINT_BRIDGE_RASTER_CHUNK_HEIGHT", "256"))
        transport_mode = os.getenv("PRINT_BRIDGE_TRANSPORT", "auto").strip().lower()
        if transport_mode not in {"auto", "usb", "cups", "network"}:
            transport_mode = "auto"
        usb_vid_raw = os.getenv("PRINT_BRIDGE_USB_VENDOR_ID", "").strip()
        usb_pid_raw = os.getenv("PRINT_BRIDGE_USB_PRODUCT_ID", "").strip()
        usb_vendor_id = int(usb_vid_raw, 16) if usb_vid_raw else None
        usb_product_id = int(usb_pid_raw, 16) if usb_pid_raw else None
        network_host = os.getenv("PRINT_BRIDGE_NETWORK_HOST", "").strip()
        network_port = int(os.getenv("PRINT_BRIDGE_NETWORK_PORT", "9100"))
        return cls(
            host=os.getenv("PRINT_BRIDGE_HOST", "127.0.0.1").strip() or "127.0.0.1",
            port=int(os.getenv("PRINT_BRIDGE_PORT", "3001")),
            printer_queue=os.getenv("PRINT_BRIDGE_PRINTER_QUEUE", "").strip(),
            paper_width_mm=paper_width_mm,
            chars_per_line=int(os.getenv("PRINT_BRIDGE_CHARS_PER_LINE", default_chars)),
            encoding=profile.encoding,
            codepage=profile.codepage,
            render_mode=render_mode,
            raster_chunk_height=max(64, raster_chunk_height),
            allowed_origins=_split_csv(
                os.getenv("PRINT_BRIDGE_ALLOWED_ORIGINS"),
                DEFAULT_ALLOWED_ORIGINS,
            ),
            healthcheck_queue=_as_bool(
                os.getenv("PRINT_BRIDGE_HEALTHCHECK_QUEUE"),
                default=True,
            ),
            cut_mode=cut_mode,
            transport_mode=transport_mode,
            usb_vendor_id=usb_vendor_id,
            usb_product_id=usb_product_id,
            network_host=network_host,
            network_port=network_port,
            print_system_enabled=_as_bool(os.getenv("PRINT_SYSTEM_ENABLED"), default=True),
        )

    def as_dict(self) -> dict[str, object]:
        """Return a JSON-serialisable snapshot of the active settings."""
        return {
            "transport_mode": self.transport_mode,
            "printer_queue": self.printer_queue or None,
            "paper_width_mm": self.paper_width_mm,
            "chars_per_line": self.chars_per_line,
            "encoding": self.encoding,
            "codepage": self.codepage,
            "render_mode": self.render_mode,
            "raster_chunk_height": self.raster_chunk_height,
            "cut_mode": self.cut_mode,
            "usb_vendor_id": f"0x{self.usb_vendor_id:04x}" if self.usb_vendor_id else None,
            "usb_product_id": f"0x{self.usb_product_id:04x}" if self.usb_product_id else None,
            "network_host": self.network_host or None,
            "network_port": self.network_port,
            "print_system_enabled": self.print_system_enabled,
        }

    def escpos_profile(self) -> EscPosProfile:
        """
        Return the effective ESC/POS profile for encoding/codepage.

        This exists to keep older bridge/server call sites stable and to ensure
        print/test does not crash if optional config is missing.
        """
        encoding = (self.encoding or _DEFAULT_SAFE_ENCODING).strip() or _DEFAULT_SAFE_ENCODING
        codepage = self.codepage if self.codepage is not None else _DEFAULT_SAFE_CODEPAGE
        return EscPosProfile(encoding=encoding, codepage=codepage)
