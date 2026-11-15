-- Proves 2026110117 does not widen branch visibility, and 2026110116 does.
-- 0116 stays a separate, unapproved change.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
$$;
create or replace function public.staff_must_change_password()
returns boolean language sql stable as $$ select false; $$;

create table if not exists public.stores (seller_id uuid primary key);
create table if not exists public.store_branches (
  id uuid primary key, store_id uuid not null, status text not null
);
create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  auth_user_id uuid,
  branch_id uuid,
  status text not null,
  email text,
  phone text,
  permissions text[] not null
);
create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  branch_id uuid,
  table_number integer not null,
  is_active boolean not null default true
);
create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text,
  revision integer,
  last_edit_summary jsonb,
  last_edit_note text,
  created_at timestamptz default timezone('utc', now()),
  updated_at timestamptz
);
create table if not exists public.table_order_history (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid,
  seller_id uuid,
  table_number integer,
  items jsonb,
  status text,
  revision integer,
  last_edit_summary jsonb,
  last_edit_note text,
  payment_method text,
  payment_note text,
  waiter_id uuid,
  waiter_name text,
  grand_total numeric,
  session_key text,
  opened_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz
);
create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  is_closing boolean not null default false,
  paid_by text,
  waiter_id uuid,
  waiter_name text,
  note text
);

insert into auth.users values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'owner@destina.test', null, now(), null),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'waiter@destina.test', null, now(), null);
insert into public.stores values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
insert into public.store_branches values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active');
insert into public.store_tables values
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 1, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '22222222-2222-2222-2222-222222222222', 3, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd9', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', null, 9, true);
insert into public.store_sub_admins values (
  'f1111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  '11111111-1111-1111-1111-111111111111',
  'active', 'waiter@destina.test', null, array['viewOrders','manageOrders']
);

create or replace function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.stores s where s.seller_id = p_restaurant_id and s.seller_id = auth.uid())
    or exists (
      select 1 from public.store_sub_admins sa
      where sa.store_id = p_restaurant_id and sa.auth_user_id = auth.uid()
        and sa.status = 'active' and p_permission = any(sa.permissions)
    )
  );
$$;
create or replace function public.restaurant_table_access(p_restaurant_id uuid, p_table_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() = p_restaurant_id or exists (
    select 1 from public.store_sub_admins sa
    join public.store_tables t on t.id = p_table_id and t.seller_id = sa.store_id and t.is_active
    where sa.store_id = p_restaurant_id and sa.auth_user_id = auth.uid() and sa.status = 'active'
      and sa.branch_id is not null and t.branch_id = sa.branch_id
  );
$$;
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.store_tables t
    where t.seller_id = p_restaurant_id and t.table_number = p_number
      and public.restaurant_table_access(p_restaurant_id, t.id)
  );
$$;
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql as $$
begin
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.';
  end if;
  return new;
end $$;
create or replace function public.transfer_table_orders(p_seller_id uuid, p_from_table integer, p_to_table integer)
returns void language plpgsql as $$
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
end $$;
create or replace function public.close_table_with_history(p_seller_id uuid, p_table_number integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası: bu masayı kapatma yetkiniz yok.' using errcode = '42501';
  end if;
  delete from public.table_orders
  where seller_id = p_seller_id::text and table_number = p_table_number;
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  if public.restaurant_table_number_access(destina, 9) then
    raise exception '0117 opened an unassigned table';
  end if;
  if not public.restaurant_table_number_access(destina, 1) then
    raise exception 'same-branch table closed after 0117';
  end if;
  if public.restaurant_table_number_access(destina, 3) then
    raise exception 'other-branch table opened after 0117';
  end if;
end $$;

\ir ../migrations/2026110116_staff_unassigned_table_access.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  if not public.restaurant_table_number_access(destina, 9) then
    raise exception '0116 did not open the unassigned table in this fixture';
  end if;
  if public.restaurant_table_number_access(destina, 3) then
    raise exception '0116 opened another branch';
  end if;
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 9, '[{"price":15,"quantity":1}]'::jsonb);
  begin
    perform public.close_table_with_history(destina, 9);
    raise exception 'visible unassigned table closed without closeBill';
  exception when insufficient_privilege then null;
  end;
  update public.store_sub_admins set permissions = array['closeBill'] where auth_user_id = waiter;
  perform public.close_table_with_history(destina, 9);
  if exists (select 1 from public.table_orders where table_number = 9) then
    raise exception 'closeBill did not close the visible table';
  end if;
  raise notice 'STAFF_MIGRATIONS_TOGETHER_OK';
end $$;
