from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
from typing import Sequence


DEFAULT_ALLOWED_ORIGINS = (
    "https://ibul-ecommerce.web.app",
    "http://localhost",
    "http://localhost:3000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
)


def _load_env_file() -> None:
    env_path = os.getenv("PRINT_BRIDGE_ENV_FILE", "").strip()
    path = Path(env_path) if env_path else Path(__file__).with_name(".env")
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


@dataclass(frozen=True)
class BridgeSettings:
    host: str
    port: int
    printer_queue: str
    paper_width_mm: int
    chars_per_line: int
    encoding: str
    codepage: int | None
    allowed_origins: tuple[str, ...]
    healthcheck_queue: bool
    cut_mode: str

    @classmethod
    def from_env(cls) -> "BridgeSettings":
        _load_env_file()
        paper_width_mm = int(os.getenv("PRINT_BRIDGE_PAPER_WIDTH_MM", "58"))
        default_chars = "32" if paper_width_mm <= 58 else "48"
        codepage_raw = os.getenv("PRINT_BRIDGE_CODEPAGE", "13").strip()
        codepage = int(codepage_raw) if codepage_raw else None
        cut_mode = os.getenv("PRINT_BRIDGE_CUT_MODE", "partial").strip().lower()
        if cut_mode not in {"partial", "full", "none"}:
            cut_mode = "partial"
        return cls(
            host=os.getenv("PRINT_BRIDGE_HOST", "127.0.0.1").strip() or "127.0.0.1",
            port=int(os.getenv("PRINT_BRIDGE_PORT", "19001")),
            printer_queue=os.getenv("PRINT_BRIDGE_PRINTER_QUEUE", "").strip(),
            paper_width_mm=paper_width_mm,
            chars_per_line=int(os.getenv("PRINT_BRIDGE_CHARS_PER_LINE", default_chars)),
            encoding=os.getenv("PRINT_BRIDGE_ENCODING", "cp857").strip() or "cp857",
            codepage=codepage,
            allowed_origins=_split_csv(
                os.getenv("PRINT_BRIDGE_ALLOWED_ORIGINS"),
                DEFAULT_ALLOWED_ORIGINS,
            ),
            healthcheck_queue=_as_bool(
                os.getenv("PRINT_BRIDGE_HEALTHCHECK_QUEUE"),
                default=True,
            ),
            cut_mode=cut_mode,
        )
