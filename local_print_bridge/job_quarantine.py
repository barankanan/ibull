"""Keep historical print jobs out of the automatic claim path.

The store is local to the bridge data directory. It does not update or delete
Supabase rows. A job is skipped when its status is already owned, failed,
paused, or uncertain, or when its id or idempotency key was recorded earlier.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .runtime_paths import bridge_data_dir

HISTORICAL_STATUSES = frozenset(
    {
        "printing",
        "claimed",
        "failed",
        "paused_by_operator",
        "outcome_unknown",
        "unknown",
    }
)


@dataclass(frozen=True)
class ClaimDecision:
    allow: bool
    reason: str


def _store_path(root: Path | None = None) -> Path:
    return (root or bridge_data_dir()) / "job_quarantine.json"


def arm_quarantine(root: Path | None = None) -> None:
    """Mark this data directory as protected. A missing list then stops claims."""
    base = root or bridge_data_dir()
    base.mkdir(parents=True, exist_ok=True)
    (base / "job_quarantine.armed").write_text("1\n", encoding="utf-8")
    path = _store_path(base)
    if not path.is_file():
        path.write_text(
            json.dumps({"job_ids": [], "idempotency_keys": []}, indent=2),
            encoding="utf-8",
        )


def quarantine_fail_closed(root: Path | None = None) -> bool:
    base = root or bridge_data_dir()
    armed = (base / "job_quarantine.armed").is_file()
    store = _store_path(base)
    if not armed:
        return False
    if not store.is_file():
        return True
    try:
        raw = json.loads(store.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return True
    return not isinstance(raw, dict)


def load_quarantine(root: Path | None = None) -> dict[str, list[str]]:
    path = _store_path(root)
    if not path.is_file():
        return {"job_ids": [], "idempotency_keys": []}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"job_ids": [], "idempotency_keys": []}
    if not isinstance(raw, dict):
        return {"job_ids": [], "idempotency_keys": []}
    return {
        "job_ids": [str(item) for item in raw.get("job_ids") or [] if str(item).strip()],
        "idempotency_keys": [
            str(item) for item in raw.get("idempotency_keys") or [] if str(item).strip()
        ],
    }


def remember_quarantine(
    *,
    job_id: str = "",
    idempotency_key: str = "",
    root: Path | None = None,
) -> None:
    current = load_quarantine(root)
    job_ids = list(current["job_ids"])
    keys = list(current["idempotency_keys"])
    if job_id and job_id not in job_ids:
        job_ids.append(job_id)
    if idempotency_key and idempotency_key not in keys:
        keys.append(idempotency_key)
    path = _store_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {"job_ids": job_ids, "idempotency_keys": keys},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def auto_claim_decision(
    job: dict[str, Any],
    *,
    root: Path | None = None,
) -> ClaimDecision:
    """Decide whether an automatic consumer may claim this job.

    Status, job id, and idempotency key all count. Created time alone does not.
    """
    status = str(job.get("status") or "").strip().lower()
    if quarantine_fail_closed(root):
        return ClaimDecision(False, "quarantine_store_missing")
    if status in HISTORICAL_STATUSES:
        return ClaimDecision(False, f"historical_status:{status}")
    if status and status != "pending":
        return ClaimDecision(False, f"status_not_pending:{status}")
    payload = job.get("payload") if isinstance(job.get("payload"), dict) else {}
    if payload.get("quarantine") is True or payload.get("historical") is True:
        return ClaimDecision(False, "payload_quarantine")
    stored = load_quarantine(root)
    job_id = str(job.get("id") or "").strip()
    if job_id and job_id in stored["job_ids"]:
        return ClaimDecision(False, "quarantined_job_id")
    idempotency_key = str(
        payload.get("logical_print_key")
        or payload.get("idempotency_key")
        or job.get("idempotency_key")
        or ""
    ).strip()
    if idempotency_key and idempotency_key in stored["idempotency_keys"]:
        return ClaimDecision(False, "quarantined_idempotency_key")
    return ClaimDecision(True, "pending_new_job")


def kitchen_job_plan(
    *,
    restaurant_id: str,
    order_id: str,
    revision: str,
    station_id: str,
    printer_mac: str,
    issued: set[str] | None = None,
    root: Path | None = None,
) -> dict[str, Any] | None:
    """One kitchen ticket plan. Repeating the same identity returns None."""
    key = "|".join((restaurant_id, order_id, revision or "1", station_id, "new_order"))
    job_id = f"kitchen:{restaurant_id}:{order_id}:{revision or '1'}:{station_id}"
    seen = issued if issued is not None else set()
    decision = auto_claim_decision(
        {
            "id": job_id,
            "status": "pending",
            "idempotency_key": key,
            "payload": {"logical_print_key": key, "station_id": station_id},
        },
        root=root,
    )
    if not decision.allow or key in seen:
        return None
    seen.add(key)
    return {
        "id": job_id,
        "idempotency_key": key,
        "station_id": station_id,
        "printer_mac": printer_mac,
        "copies": 1,
        "historical_selected": False,
    }
