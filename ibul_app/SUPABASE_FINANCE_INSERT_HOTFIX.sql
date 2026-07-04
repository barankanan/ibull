-- TEK DOSYA: Gelir/Gider ekleme + RLS düzeltmesi (idempotent).
-- Supabase SQL Editor'da bir kez çalıştırın.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Temel admin rol kontrolleri
-- ---------------------------------------------------------------------------
create or replace function public.is_admin_role(role_key text)
returns boolean
language sql
stable
as $$
  select
    lower(trim(role_key)) = 'admin'
    or lower(trim(role_key)) = 'super_admin'
    or lower(trim(role_key)) like 'admin\_%' escape '\'
$$;

-- users.role veya admin_user_permissions.role_key — hangisi admin ise onu kullan
create or replace function public.resolve_admin_effective_role(target_user_id uuid default auth.uid())
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  account_role text;
  permission_role text;
begin
  if target_user_id is null then
    return null;
  end if;

  if to_regclass('public.users') is not null then
    select lower(trim(u.role))
    into account_role
    from public.users u
    where u.id = target_user_id
    limit 1;
  end if;

  permission_role := null;
  if to_regclass('public.admin_user_permissions') is not null then
    select lower(trim(nullif(trim(a.role_key), '')))
    into permission_role
    from public.admin_user_permissions a
    where a.user_id = target_user_id and a.is_active = true
    limit 1;
  end if;

  if permission_role is not null and public.is_admin_role(permission_role) then
    return permission_role;
  end if;

  if account_role is not null and public.is_admin_role(account_role) then
    return account_role;
  end if;

  return coalesce(permission_role, account_role);
end;
$$;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  effective_role text;
begin
  if target_user_id is null then
    return false;
  end if;
  effective_role := public.resolve_admin_effective_role(target_user_id);
  return effective_role is not null and public.is_admin_role(effective_role);
end;
$$;

-- Finans yazma izni
create or replace function public.admin_can_write_finance()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid;
  effective_role text;
  denied_modules text[];
  allowed_modules text[];
begin
  uid := auth.uid();
  if uid is null then
    return false;
  end if;

  denied_modules := '{}'::text[];
  allowed_modules := null;

  if to_regclass('public.admin_user_permissions') is not null then
    select
      coalesce(a.denied_modules, '{}'::text[]),
      case
        when a.is_active is true
          and cardinality(coalesce(a.allowed_modules, '{}'::text[])) > 0
          then a.allowed_modules
        else null
      end
    into denied_modules, allowed_modules
    from public.admin_user_permissions a
    where a.user_id = uid and a.is_active = true
    limit 1;
  end if;

  if 'finance' = any(coalesce(denied_modules, '{}'::text[])) then
    return false;
  end if;

  effective_role := public.resolve_admin_effective_role(uid);
  if effective_role is null or not public.is_admin_role(effective_role) then
    return false;
  end if;

  if effective_role in ('super_admin', 'admin', 'admin_finance', 'admin_investor') then
    return true;
  end if;

  if allowed_modules is not null then
    return 'finance' = any(allowed_modules);
  end if;

  return true;
end;
$$;

create or replace function public.current_admin_can_access_finance()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.admin_can_write_finance();
end;
$$;

grant execute on function public.is_admin_role(text) to authenticated;
grant execute on function public.resolve_admin_effective_role(uuid) to authenticated;
grant execute on function public.is_admin_user(uuid) to authenticated;
grant execute on function public.admin_can_write_finance() to authenticated;
grant execute on function public.current_admin_can_access_finance() to authenticated;

-- ---------------------------------------------------------------------------
-- Trigger helper
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at_admin_finance()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tablolar (yoksa oluştur)
-- ---------------------------------------------------------------------------
create table if not exists public.admin_expenses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  amount numeric(14, 2) not null default 0,
  expense_date date not null default current_date,
  type text not null default 'one_time',
  recurrence text null,
  status text not null default 'paid',
  payment_method text null,
  vendor text null,
  invoice_url text null,
  note text null,
  created_by uuid null references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.admin_revenues (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  amount numeric(14, 2) not null default 0,
  revenue_date date not null default current_date,
  status text not null default 'received',
  type text not null default 'one_time',
  recurrence text null,
  source text null,
  payment_method text null,
  reference_no text null,
  note text null,
  created_by uuid null references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
);

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.admin_expenses to authenticated;
grant select, insert, update, delete on table public.admin_revenues to authenticated;

-- ---------------------------------------------------------------------------
-- RLS — eski çakışan policy'leri temizle
-- ---------------------------------------------------------------------------
alter table public.admin_expenses enable row level security;
alter table public.admin_revenues enable row level security;

drop policy if exists "admin_expenses_select" on public.admin_expenses;
drop policy if exists "admin_expenses_manage" on public.admin_expenses;
drop policy if exists "admin_expenses_insert" on public.admin_expenses;
drop policy if exists "admin_expenses_update" on public.admin_expenses;
drop policy if exists "admin_expenses_delete" on public.admin_expenses;

drop policy if exists "admin_revenues_select" on public.admin_revenues;
drop policy if exists "admin_revenues_manage" on public.admin_revenues;
drop policy if exists "admin_revenues_insert" on public.admin_revenues;
drop policy if exists "admin_revenues_update" on public.admin_revenues;
drop policy if exists "admin_revenues_delete" on public.admin_revenues;

create policy "admin_expenses_select"
on public.admin_expenses for select to authenticated
using (public.admin_can_write_finance());

create policy "admin_expenses_insert"
on public.admin_expenses for insert to authenticated
with check (public.admin_can_write_finance());

create policy "admin_expenses_update"
on public.admin_expenses for update to authenticated
using (public.admin_can_write_finance())
with check (public.admin_can_write_finance());

create policy "admin_expenses_delete"
on public.admin_expenses for delete to authenticated
using (public.admin_can_write_finance());

create policy "admin_revenues_select"
on public.admin_revenues for select to authenticated
using (public.admin_can_write_finance());

create policy "admin_revenues_insert"
on public.admin_revenues for insert to authenticated
with check (public.admin_can_write_finance());

create policy "admin_revenues_update"
on public.admin_revenues for update to authenticated
using (public.admin_can_write_finance())
with check (public.admin_can_write_finance());

create policy "admin_revenues_delete"
on public.admin_revenues for delete to authenticated
using (public.admin_can_write_finance());

-- ---------------------------------------------------------------------------
-- Güvenli insert RPC (RLS bypass — admin_can_write_finance gate)
-- ---------------------------------------------------------------------------
create or replace function public.admin_insert_expense(
  p_title text,
  p_category text,
  p_amount numeric,
  p_expense_date date,
  p_type text,
  p_recurrence text,
  p_status text,
  p_payment_method text default null,
  p_vendor text default null,
  p_invoice_url text default null,
  p_note text default null
)
returns public.admin_expenses
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.admin_expenses;
  v_uid uuid;
  v_created_by uuid;
begin
  if not public.admin_can_write_finance() then
    raise exception 'permission denied for admin expense insert' using errcode = '42501';
  end if;

  v_uid := auth.uid();
  v_created_by := null;
  if v_uid is not null and exists (select 1 from public.users u where u.id = v_uid) then
    v_created_by := v_uid;
  end if;

  insert into public.admin_expenses (
    title, category, amount, expense_date, type, recurrence, status,
    payment_method, vendor, invoice_url, note, created_by
  )
  values (
    trim(p_title),
    trim(p_category),
    p_amount,
    p_expense_date,
    p_type,
    p_recurrence,
    p_status,
    nullif(trim(coalesce(p_payment_method, '')), ''),
    nullif(trim(coalesce(p_vendor, '')), ''),
    nullif(trim(coalesce(p_invoice_url, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_created_by
  )
  returning * into result;

  return result;
end;
$$;

create or replace function public.admin_insert_revenue(
  p_title text,
  p_category text,
  p_amount numeric,
  p_revenue_date date,
  p_type text,
  p_recurrence text,
  p_status text,
  p_source text default null,
  p_payment_method text default null,
  p_reference_no text default null,
  p_note text default null
)
returns public.admin_revenues
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.admin_revenues;
  v_uid uuid;
  v_created_by uuid;
begin
  if not public.admin_can_write_finance() then
    raise exception 'permission denied for admin revenue insert' using errcode = '42501';
  end if;

  v_uid := auth.uid();
  v_created_by := null;
  if v_uid is not null and exists (select 1 from public.users u where u.id = v_uid) then
    v_created_by := v_uid;
  end if;

  insert into public.admin_revenues (
    title, category, amount, revenue_date, type, recurrence, status,
    source, payment_method, reference_no, note, created_by
  )
  values (
    trim(p_title),
    trim(p_category),
    p_amount,
    p_revenue_date,
    p_type,
    p_recurrence,
    p_status,
    nullif(trim(coalesce(p_source, '')), ''),
    nullif(trim(coalesce(p_payment_method, '')), ''),
    nullif(trim(coalesce(p_reference_no, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_created_by
  )
  returning * into result;

  return result;
end;
$$;

grant execute on function public.admin_insert_expense(
  text, text, numeric, date, text, text, text, text, text, text, text
) to authenticated;

grant execute on function public.admin_insert_revenue(
  text, text, numeric, date, text, text, text, text, text, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------
create or replace function public.debug_admin_finance_access()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid;
  account_role text;
  permission_role text;
  effective_role text;
  user_email text;
  denied_modules text[];
  allowed_modules text[];
begin
  uid := auth.uid();
  if uid is null then
    return jsonb_build_object('authenticated', false);
  end if;

  select lower(trim(u.role)), u.email
  into account_role, user_email
  from public.users u
  where u.id = uid
  limit 1;

  permission_role := null;
  denied_modules := '{}'::text[];
  allowed_modules := null;

  if to_regclass('public.admin_user_permissions') is not null then
    select
      lower(trim(nullif(trim(a.role_key), ''))),
      coalesce(a.denied_modules, '{}'::text[]),
      a.allowed_modules
    into permission_role, denied_modules, allowed_modules
    from public.admin_user_permissions a
    where a.user_id = uid and a.is_active = true
    limit 1;
  end if;

  effective_role := public.resolve_admin_effective_role(uid);

  return jsonb_build_object(
    'authenticated', true,
    'auth_uid', uid,
    'user_email', user_email,
    'user_role', account_role,
    'permission_role_key', permission_role,
    'effective_role', effective_role,
    'allowed_modules', coalesce(allowed_modules, '{}'::text[]),
    'denied_modules', denied_modules,
    'is_admin_user', public.is_admin_user(uid),
    'admin_can_write_finance', public.admin_can_write_finance(),
    'can_access_finance', public.current_admin_can_access_finance()
  );
end;
$$;

grant execute on function public.debug_admin_finance_access() to authenticated;

-- ---------------------------------------------------------------------------
-- Veri düzeltme: users.role yanlış (postgres, user vb.) ama admin izni var
-- ---------------------------------------------------------------------------
update public.users u
set
  role = p.role_key,
  updated_at = timezone('utc', now())
from public.admin_user_permissions p
where p.user_id = u.id
  and p.is_active = true
  and nullif(trim(p.role_key), '') is not null
  and public.is_admin_role(p.role_key)
  and not public.is_admin_role(u.role);
