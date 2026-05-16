from __future__ import annotations

import os
from pathlib import Path
import platform


_APP_DIR_NAME = "IbulPrintBridge"


def bridge_data_dir() -> Path:
    configured = os.getenv("PRINT_BRIDGE_DATA_DIR", "").strip()
    if configured:
        path = Path(configured).expanduser()
        path.mkdir(parents=True, exist_ok=True)
        return path

    system_name = platform.system().lower()
    if system_name == "windows":
        local_app_data = os.getenv("LOCALAPPDATA", "").strip()
        base = Path(local_app_data) if local_app_data else Path.home() / "AppData" / "Local"
        path = base / _APP_DIR_NAME
    elif system_name == "darwin":
        path = Path.home() / "Library" / "Application Support" / _APP_DIR_NAME
    else:
        path = Path.home() / ".local" / "share" / _APP_DIR_NAME

    path.mkdir(parents=True, exist_ok=True)
    return path


def bridge_env_path(default_relative_to: Path | None = None) -> Path:
    configured = os.getenv("PRINT_BRIDGE_ENV_FILE", "").strip()
    if configured:
        return Path(configured).expanduser()

    if default_relative_to is not None:
        legacy_path = default_relative_to.with_name(".env")
        if legacy_path.is_file():
            return legacy_path

    return bridge_data_dir() / ".env"


def bridge_logs_dir() -> Path:
    path = bridge_data_dir() / "logs"
    path.mkdir(parents=True, exist_ok=True)
    return path


def bridge_server_log_path() -> Path:
    return bridge_logs_dir() / "bridge.log"


def bridge_print_log_path() -> Path:
    return bridge_logs_dir() / "print_logs.jsonl"


def bridge_lock_path() -> Path:
    return bridge_data_dir() / "bridge.lock"
