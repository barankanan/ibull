-- The hand-applied email/phone close gate must be swapped for the
-- operation check without replacing the rest of the function.

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
  email_confirmed_at timestamptz
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
create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  auth_user_id uuid,
  status text not null,
  email text,
  permissions text[] not null
);
create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  branch_id uuid,
  table_number integer not null,
  is_active boolean not null default true
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
insert into public.stores values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
insert into auth.users values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'owner@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'waiter@destina.test', now());
insert into public.store_sub_admins values
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'active', 'waiter@destina.test', array['viewOrders']);
insert into public.store_tables values
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', null, 1, true);

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
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable as $$ select true; $$;
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql as $$
begin
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.';
  end if;
  return new;
end $$;
create or replace function public.transfer_table_orders(
  p_seller_id uuid, p_from_table integer, p_to_table integer
) returns void language plpgsql as $$
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
end $$;
create or replace function public.close_table_with_history(
  p_seller_id uuid, p_table_number integer
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_actor_authorized boolean := false;
begin
  v_actor_authorized := auth.uid() = p_seller_id or exists (
    select 1 from public.store_sub_admins sa
    where sa.store_id = p_seller_id and sa.status = 'active'
      and ('manageOrders' = any(sa.permissions) or 'viewOrders' = any(sa.permissions))
  );
  IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;
  -- keep-archive-body
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql

do $$
declare
  def text := pg_get_functiondef('public.close_table_with_history(uuid,integer)'::regprocedure);
begin
  if position('keep-archive-body' in def) = 0
     or position('restaurant_staff_may_operate' in def) = 0
     or position('Yetkisiz işlem.' in def) > 0 then
    raise exception 'actor gate was not patched in place';
  end if;
  perform set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', true);
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  begin
    perform public.close_table_with_history('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 1);
    raise exception 'viewOrders still closed the bill';
  exception when insufficient_privilege then null;
  end;
  update public.store_sub_admins
  set permissions = array['closeBill']
  where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  perform public.close_table_with_history('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 1);
  raise notice 'STAFF_ACTOR_GATE_OK';
end $$;
