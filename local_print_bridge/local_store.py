"""Durable LAN order store for the existing print bridge.

SQLite WAL is the local authority for orders accepted while Supabase is
unreachable. It does not replace the server RPC when the client is online.
"""

from __future__ import annotations

import json
import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any


_SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
  local_order_id TEXT PRIMARY KEY,
  restaurant_id TEXT NOT NULL,
  table_number INTEGER NOT NULL,
  table_label TEXT NOT NULL DEFAULT '',
  waiter_name TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS order_items (
  id TEXT PRIMARY KEY,
  local_order_id TEXT NOT NULL,
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_cents INTEGER NOT NULL,
  station_id TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (local_order_id) REFERENCES orders(local_order_id)
);
CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  local_order_id TEXT NOT NULL,
  method TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS print_jobs (
  id TEXT PRIMARY KEY,
  local_order_id TEXT NOT NULL,
  station_id TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  local_order_id TEXT NOT NULL UNIQUE,
  payload TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL
);
"""


def _cents(amount: float) -> int:
    return int(round(float(amount) * 100))


class LocalRestaurantStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(self.path, check_same_thread=False)
        self._db.row_factory = sqlite3.Row
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.executescript(_SCHEMA)
        self._db.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS print_jobs_order_station "
            "ON print_jobs(local_order_id, station_id)"
        )
        self._db.commit()

    def close(self) -> None:
        self._db.close()

    def set_restaurant(self, restaurant_id: str) -> None:
        self._db.execute(
            "INSERT INTO meta(key, value) VALUES('restaurant_id', ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (restaurant_id,),
        )
        self._db.commit()

    def restaurant_id(self) -> str:
        row = self._db.execute(
            "SELECT value FROM meta WHERE key='restaurant_id'"
        ).fetchone()
        return "" if row is None else str(row["value"])

    def accept_order(
        self,
        *,
        local_order_id: str,
        restaurant_id: str,
        table_number: int,
        table_label: str,
        waiter_name: str,
        notes: str,
        items: list[dict[str, Any]],
        printer_host: str,
        printer_port: int,
        client_total_cents: int | None = None,
    ) -> dict[str, Any]:
        started = time.perf_counter()
        if not local_order_id.strip() or not restaurant_id.strip() or table_number <= 0:
            raise ValueError("Sipariş kimliği, restoran veya masa eksik.")
        if not items:
            raise ValueError("Sipariş kalemi yok.")
        existing = self._db.execute(
            "SELECT local_order_id, table_number, total_cents, status FROM orders WHERE local_order_id=?",
            (local_order_id,),
        ).fetchone()
        if existing is not None:
            jobs = self._jobs(local_order_id)
            stored_items = self._db.execute(
                "SELECT name, quantity, unit_cents, station_id FROM order_items "
                "WHERE local_order_id=? ORDER BY name",
                (local_order_id,),
            ).fetchall()
            incoming = sorted(
                (
                    str(item.get("name") or "").strip(),
                    int(item.get("quantity") or 0),
                    _cents(float(item.get("unit_price") or item.get("price") or 0)),
                    str(item.get("station_id") or "").strip(),
                )
                for item in items
            )
            stored = sorted(
                (
                    str(row["name"]),
                    int(row["quantity"]),
                    int(row["unit_cents"]),
                    str(row["station_id"]),
                )
                for row in stored_items
            )
            if incoming != stored or int(existing["table_number"]) != table_number:
                raise ValueError(
                    "Aynı sipariş kimliği farklı içerikle geldi. Üzerine yazılmadı."
                )
            return {
                "ok": True,
                "saved": True,
                "duplicate": True,
                "local_order_id": local_order_id,
                "total_cents": int(existing["total_cents"]),
                "print_status": jobs[0]["status"] if jobs else "queued",
                "printed": False,
                "db_ms": (time.perf_counter() - started) * 1000,
            }
        normalized: list[dict[str, Any]] = []
        total = 0
        for raw in items:
            name = str(raw.get("name") or "").strip()
            qty = int(raw.get("quantity") or 0)
            unit = _cents(float(raw.get("unit_price") or raw.get("price") or 0))
            if not name or qty <= 0 or unit < 0:
                raise ValueError("Sipariş satırı geçersiz.")
            station = str(raw.get("station_id") or "").strip()
            normalized.append(
                {
                    "name": name,
                    "quantity": qty,
                    "unit_cents": unit,
                    "station_id": station,
                }
            )
            total += unit * qty
        if client_total_cents is not None and abs(client_total_cents - total) > 1:
            raise ValueError("İstemci tutarı satır fiyatlarıyla uyuşmuyor.")
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        stations: list[str] = []
        for item in normalized:
            station = item["station_id"] or "genel"
            if station not in stations:
                stations.append(station)
        payloads = []
        for station in stations:
            station_items = [item for item in normalized if (item["station_id"] or "genel") == station]
            payloads.append(
                (
                    f"{local_order_id}:{station}:rev1",
                    station,
                    json.dumps(
                        {
                            "local_order_id": local_order_id,
                            "restaurant_id": restaurant_id,
                            "table_number": table_number,
                            "table_label": table_label,
                            "revision": "1",
                            "station_id": station,
                            "items": station_items,
                            "total_cents": total,
                            "printer": {"host": printer_host, "port": printer_port},
                        },
                        ensure_ascii=False,
                    ),
                )
            )
        self._db.execute("BEGIN")
        try:
            self._db.execute(
                "INSERT INTO orders(local_order_id, restaurant_id, table_number, "
                "table_label, waiter_name, notes, total_cents, status, created_at) "
                "VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    local_order_id,
                    restaurant_id,
                    table_number,
                    table_label,
                    waiter_name,
                    notes,
                    total,
                    "accepted",
                    now,
                ),
            )
            for item in normalized:
                self._db.execute(
                    "INSERT INTO order_items(id, local_order_id, name, quantity, "
                    "unit_cents, station_id) VALUES(?,?,?,?,?,?)",
                    (
                        str(uuid.uuid4()),
                        local_order_id,
                        item["name"],
                        item["quantity"],
                        item["unit_cents"],
                        item["station_id"],
                    ),
                )
            for job_id, station, payload in payloads:
                self._db.execute(
                    "INSERT INTO print_jobs(id, local_order_id, station_id, status, "
                    "payload, created_at) VALUES(?,?,?,?,?,?)",
                    (job_id, local_order_id, station, "queued", payload, now),
                )
            self._db.execute(
                "INSERT INTO sync_queue(id, local_order_id, payload, status, created_at) "
                "VALUES(?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    local_order_id,
                    payloads[0][2],
                    "pending",
                    now,
                ),
            )
            self._db.execute(
                "INSERT INTO meta(key, value) VALUES('restaurant_id', ?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (restaurant_id,),
            )
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise
        db_ms = (time.perf_counter() - started) * 1000
        return {
            "ok": True,
            "saved": True,
            "duplicate": False,
            "local_order_id": local_order_id,
            "print_job_id": payloads[0][0],
            "print_job_ids": [item[0] for item in payloads],
            "station_ids": [item[1] for item in payloads],
            "total_cents": total,
            "print_status": "queued",
            "printed": False,
            "db_ms": db_ms,
        }

    def mark_print(self, job_id: str, status: str) -> None:
        if status not in {"queued", "sent", "uncertain", "failed"}:
            raise ValueError("Geçersiz baskı durumu.")
        self._db.execute(
            "UPDATE print_jobs SET status=? WHERE id=?",
            (status, job_id),
        )
        self._db.commit()

    def pending_sync(self) -> list[dict[str, Any]]:
        rows = self._db.execute(
            "SELECT id, local_order_id, payload FROM sync_queue WHERE status='pending' "
            "ORDER BY created_at"
        ).fetchall()
        return [dict(row) for row in rows]

    def mark_synced(self, sync_id: str) -> None:
        self._db.execute(
            "UPDATE sync_queue SET status='synced' WHERE id=?",
            (sync_id,),
        )
        self._db.commit()

    def get_order(self, local_order_id: str) -> dict[str, Any] | None:
        row = self._db.execute(
            "SELECT * FROM orders WHERE local_order_id=?",
            (local_order_id,),
        ).fetchone()
        if row is None:
            return None
        items = self._db.execute(
            "SELECT name, quantity, unit_cents, station_id FROM order_items "
            "WHERE local_order_id=?",
            (local_order_id,),
        ).fetchall()
        jobs = self._jobs(local_order_id)
        return {
            "order": dict(row),
            "items": [dict(item) for item in items],
            "print_jobs": jobs,
        }

    def order_ids(self) -> list[str]:
        rows = self._db.execute(
            "SELECT local_order_id FROM orders ORDER BY created_at"
        ).fetchall()
        return [str(row["local_order_id"]) for row in rows]

    def order_count(self) -> int:
        row = self._db.execute("SELECT COUNT(*) AS n FROM orders").fetchone()
        return int(row["n"])

    def claim_queued_job(self, job_id: str) -> dict[str, Any] | None:
        """Atomically take one queued job. A second caller gets nothing."""
        self._db.execute("BEGIN IMMEDIATE")
        try:
            row = self._db.execute(
                "SELECT id, local_order_id, station_id, status, payload "
                "FROM print_jobs WHERE id=?",
                (job_id,),
            ).fetchone()
            if row is None or str(row["status"]) != "queued":
                self._db.rollback()
                return None
            updated = self._db.execute(
                "UPDATE print_jobs SET status='claimed' WHERE id=? AND status='queued'",
                (job_id,),
            )
            if updated.rowcount != 1:
                self._db.rollback()
                return None
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise
        return dict(row)

    def _jobs(self, local_order_id: str) -> list[dict[str, Any]]:
        rows = self._db.execute(
            "SELECT id, status, payload FROM print_jobs WHERE local_order_id=?",
            (local_order_id,),
        ).fetchall()
        return [dict(row) for row in rows]


def client_total_cents(body: dict[str, Any]) -> int | None:
    if "total" not in body and "client_total" not in body:
        return None
    raw = body.get("client_total", body.get("total"))
    try:
        return _cents(float(raw))
    except (TypeError, ValueError):
        return None
