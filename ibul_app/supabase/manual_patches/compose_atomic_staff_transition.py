#!/usr/bin/env python3
"""Compose one atomic staff transition from the two reviewed migration files.

The source files each contain their own begin/commit. PostgreSQL commits the
outer transaction at the first inner commit, so the files must not be included
with \\ir or concatenated raw. This script strips exactly one statement-level
begin and commit from each file, then places the single waiter grant between
them. 2026110119 is intentionally absent.

The script does not connect to a database and does not apply SQL.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIRST = ROOT / "migrations" / "2026110117_staff_operation_permissions.sql"
SECOND = (
    ROOT / "migrations" / "20261101184615_staff_close_transfer_direct_write_guard.sql"
)
EXPECTED_PERMISSIONS = (
    "'viewOrders','manageOrders','manageProducts','manageSupport'"
)


def statement_lines(text: str, statement: str) -> list[int]:
    return [
        number
        for number, line in enumerate(text.splitlines(), start=1)
        if line.strip() == statement
    ]


def strip_transaction(path: pathlib.Path) -> str:
    text = path.read_text()
    begins = statement_lines(text, "begin;")
    commits = statement_lines(text, "commit;")
    if len(begins) != 1 or len(commits) != 1 or begins[0] >= commits[0]:
        raise SystemExit(
            f"{path.name}: expected exactly one begin; before one commit;, "
            f"found begin {begins} commit {commits}"
        )
    lines = text.splitlines(keepends=True)
    tail = "".join(lines[commits[0] - 1 :]).strip()
    if tail != "commit;":
        raise SystemExit(f"{path.name}: unexpected SQL after commit;")
    return "".join(lines[begins[0] : commits[0] - 1])


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preflight_sql() -> str:
    return f"""
do $$
declare
  v_waiters integer;
  v_triggers integer;
begin
  if current_setting('transaction_read_only') = 'on' then
    raise exception 'Bağlantı salt okunur. Atomik geçiş yazılmadı.';
  end if;
  if to_regprocedure('public.validate_restaurant_staff_membership()') is null
     or to_regprocedure('public.guard_restaurant_staff_order_write()') is null
     or to_regclass('public.store_sub_admins') is null
     or not exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'close_table_with_history'
     )
     or not exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'transfer_table_orders'
     ) then
    raise exception 'Canlı personel kapısı eksik. Atomik geçiş yazılmadı.';
  end if;
  if position('transferTable' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0
     or position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0
     or position('Hesabı kesme yetkisi yok.' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)) > 0
     or position('print_jobs' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)) = 0 then
    raise exception 'Fonksiyon gövdeleri beklenen canlı taban değil. Atomik geçiş yazılmadı.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'store_sub_admins'
      and column_name = 'staff_role'
  ) then
    raise exception 'store_sub_admins.staff_role yok. Atomik geçiş yazılmadı.';
  end if;
  select count(*) into v_triggers
  from pg_trigger
  where tgrelid = 'public.store_sub_admins'::regclass
    and tgfoid = 'public.validate_restaurant_staff_membership()'::regprocedure
    and not tgisinternal;
  if v_triggers <> 1 then
    raise exception 'Personel doğrulama tetikleyicisi tek değil. Atomik geçiş yazılmadı.';
  end if;
  select count(*) into v_waiters
  from public.store_sub_admins
  where status = 'active' and staff_role = 'waiter';
  if v_waiters <> 1 then
    raise exception 'Aktif garson sayısı 1 değil (%). Atomik geçiş yazılmadı.', v_waiters;
  end if;
  if exists (
    select 1 from public.store_sub_admins
    where 'transferTable' = any(permissions)
       or 'closeBill' = any(permissions)
       or 'manageStaff' = any(permissions)
  ) then
    raise exception 'Personel satırında transferTable, closeBill veya manageStaff zaten var.';
  end if;
  if not exists (
    select 1 from public.store_sub_admins
    where status = 'active'
      and staff_role = 'waiter'
      and branch_id is not null
      and auth_user_id is not null
      and permissions = array[{EXPECTED_PERMISSIONS}]::text[]
  ) then
    raise exception 'Aktif garsonun şubesi, auth bağı veya dört izni beklenen durumda değil.';
  end if;
end $$;

create temp table ibul_atomic_staff_before as
select id, branch_id, status, staff_role, permissions
from public.store_sub_admins;

create temp table ibul_atomic_target as
select id
from public.store_sub_admins
where status = 'active'
  and staff_role = 'waiter'
  and branch_id is not null
  and auth_user_id is not null
  and permissions = array[{EXPECTED_PERMISSIONS}]::text[];

do $$
begin
  if (select count(*) from ibul_atomic_target) <> 1 then
    raise exception 'Hedef garson satırı tek değil.';
  end if;
end $$;
"""


def grant_sql() -> str:
    return f"""
do $$
declare
  v_updated integer;
begin
  update public.store_sub_admins as staff
  set permissions = staff.permissions || array['transferTable']::text[]
  from ibul_atomic_target target
  where staff.id = target.id
    and staff.status = 'active'
    and staff.staff_role = 'waiter'
    and staff.branch_id is not null
    and staff.auth_user_id is not null
    and staff.permissions = array[{EXPECTED_PERMISSIONS}]::text[];
  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'Garson izni güncellenemedi (%).', v_updated;
  end if;
end $$;
"""


def postflight_sql() -> str:
    return f"""
do $$
declare
  v_permissions text[];
  v_validator text;
  v_guard text;
  v_close text;
  v_transfer text;
begin
  select staff.permissions into v_permissions
  from public.store_sub_admins staff
  join ibul_atomic_target target on target.id = staff.id;
  if v_permissions is distinct from array[{EXPECTED_PERMISSIONS},'transferTable']::text[] then
    raise exception 'Garson izin sonucu beklenen dizi değil.';
  end if;
  if exists (
    select 1
    from public.store_sub_admins staff
    join ibul_atomic_staff_before before on before.id = staff.id
    where staff.id <> (select id from ibul_atomic_target)
      and (
        staff.permissions is distinct from before.permissions
        or staff.status is distinct from before.status
        or staff.staff_role is distinct from before.staff_role
        or staff.branch_id is distinct from before.branch_id
      )
  ) then
    raise exception 'Hedef garson dışındaki personel satırı değişti.';
  end if;
  if exists (
    select 1 from public.store_sub_admins
    where 'closeBill' = any(permissions) or 'manageStaff' = any(permissions)
  ) then
    raise exception 'closeBill veya manageStaff yazıldı.';
  end if;
  v_validator := pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure);
  v_guard := pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure);
  if position('transferTable' in v_validator) = 0
     or position('closeBill' in v_validator) = 0
     or position('manageStaff' in v_validator) > 0
     or position('Hesabı kesme yetkisi yok.' in v_guard) = 0
     or position('Masa aktarma yetkisi yok.' in v_guard) = 0
     or position('print_jobs' in v_guard) = 0
     or position('Personel sipariş yetkisi yok.' in v_guard) = 0 then
    raise exception 'Geçiş sonrası fonksiyon kapısı eksik.';
  end if;
  select string_agg(pg_get_functiondef(p.oid), E'\\n')
  into v_close
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'close_table_with_history';
  select string_agg(pg_get_functiondef(p.oid), E'\\n')
  into v_transfer
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'transfer_table_orders';
  if coalesce(v_close, '') not like '%''closeBill''%'
     or coalesce(v_transfer, '') not like '%''transferTable''%' then
    raise exception 'Hesap kesme veya masa aktarma RPC kapısı eksik.';
  end if;
  raise notice 'ATOMIC_TRANSITION_OK';
end $$;
"""


def compose(abort_after_grant: bool) -> str:
    first = strip_transaction(FIRST)
    second = strip_transaction(SECOND)
    if "manageStaff" in first or "manageStaff" in second:
        raise SystemExit("0117 or 184615 contains manageStaff; refusing to compose")
    parts = [
        "-- GENERATED by compose_atomic_staff_transition.py. Do not hand-merge.",
        "-- DO NOT APPLY to production without a separate named approval.",
        f"-- source {FIRST.name} sha256 {sha256(FIRST)}",
        f"-- source {SECOND.name} sha256 {sha256(SECOND)}",
        "-- 2026110119 is not part of this transaction.",
        "begin;",
        preflight_sql().strip(),
        first.rstrip(),
        grant_sql().strip(),
    ]
    if abort_after_grant:
        parts.append(
            "do $$ begin raise exception 'ATOMIC_FORCED_ABORT'; end $$;"
        )
    parts.extend([second.rstrip(), postflight_sql().strip(), "commit;", ""])
    return "\n".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--abort-after-grant", action="store_true")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    sql = compose(args.abort_after_grant)
    if args.output is None:
        sys.stdout.write(sql)
    else:
        args.output.write_text(sql)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
