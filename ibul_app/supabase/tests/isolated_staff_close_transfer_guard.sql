-- Throwaway database only. Does not connect to supabase.co.
-- Order: live-shaped guard, 2026110117, 2026110119, then the direct-write guard.

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
  permissions text[] not null default '{}'::text[]
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
  status text not null default 'sent',
  revision integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz
);
create table if not exists public.table_order_history (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid,
  seller_id uuid,
  table_number integer,
  items jsonb,
  status text,
  payment_method text,
  session_key text,
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
  note text,
  created_at timestamptz not null default timezone('utc', now())
);
create table if not exists public.table_transfers_log (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid,
  from_table integer,
  to_table integer,
  transfer_type text,
  transferred_items jsonb,
  order_ids jsonb,
  waiter_id uuid,
  waiter_name text,
  note text,
  created_at timestamptz default timezone('utc', now())
);
create table if not exists public.orders (
  id uuid primary key,
  restaurant_id uuid,
  table_id uuid,
  status text
);
create table if not exists public.print_jobs (
  id uuid primary key,
  restaurant_id uuid,
  order_id uuid,
  status text
);

insert into auth.users (id, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'owner@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'waiter@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'assistant@destina.test', now()),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'other@store.test', now());
insert into public.stores values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1');
insert into public.store_branches values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active');
insert into public.store_tables values
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 1, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 2, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '22222222-2222-2222-2222-222222222222', 3, true);
insert into public.store_sub_admins values
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '11111111-1111-1111-1111-111111111111', 'active', 'waiter@destina.test', array['viewOrders','manageOrders']),
  ('f2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', '11111111-1111-1111-1111-111111111111', 'active', 'assistant@destina.test', array['viewOrders']),
  ('f3333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', null, 'active', 'other@store.test', array['viewOrders','manageOrders','closeBill','transferTable']);

create or replace function public.is_managed_restaurant_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.store_sub_admins
    where auth_user_id = auth.uid()
  );
$$;
create or replace function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.stores s where s.seller_id = p_restaurant_id and s.seller_id = auth.uid())
    or exists (
      select 1 from public.store_sub_admins sa
      where sa.store_id = p_restaurant_id
        and sa.auth_user_id = auth.uid()
        and sa.status = 'active'
        and p_permission = any(sa.permissions)
    )
  );
$$;
create or replace function public.restaurant_table_access(p_restaurant_id uuid, p_table_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.stores s where s.seller_id = p_restaurant_id and s.seller_id = auth.uid())
    or exists (
      select 1 from public.store_tables t
      join public.store_sub_admins sa
        on sa.store_id = t.seller_id
       and sa.auth_user_id = auth.uid()
       and sa.status = 'active'
      where t.id = p_table_id
        and t.seller_id = p_restaurant_id
        and t.is_active
        and (sa.branch_id is null or t.branch_id = sa.branch_id)
    );
$$;
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.store_tables t
    where t.seller_id = p_restaurant_id
      and t.table_number = p_number
      and public.restaurant_table_access(p_restaurant_id, t.id)
  );
$$;
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.branch_id is not null and not exists(select 1 from public.store_branches
    where id = new.branch_id and store_id = new.store_id) then
    raise exception 'Şube bu işletmeye ait değil.' using errcode = '42501';
  end if;
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.' using errcode = '22023';
  end if;
  if new.auth_user_id is not null and not exists(select 1 from auth.users
    where id = new.auth_user_id and lower(email) = lower(new.email)) then
    raise exception 'Auth kimliği uyuşmuyor.' using errcode = '42501';
  end if;
  return new;
end; $$;

create or replace function public.guard_restaurant_staff_order_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare r uuid; t uuid; row_data jsonb;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  if tg_table_name='orders' then
    r:=(row_data->>'restaurant_id')::uuid; t:=(row_data->>'table_id')::uuid;
  elsif tg_table_name in ('order_items','print_jobs') then
    select restaurant_id,table_id into r,t from public.orders where id=(row_data->>'order_id')::uuid;
  else
    r:=(row_data->>'seller_id')::uuid;
    select id into t from public.store_tables where seller_id=r and table_number=(row_data->>'table_number')::integer limit 1;
  end if;
  if tg_op='UPDATE' and (
    (to_jsonb(old)->>'restaurant_id') is distinct from (row_data->>'restaurant_id')
    or (to_jsonb(old)->>'seller_id') is distinct from (row_data->>'seller_id')
    or (to_jsonb(old)->>'order_id') is distinct from (row_data->>'order_id')
    or (to_jsonb(old)->>'table_id') is distinct from (row_data->>'table_id')
  ) then raise exception 'İşletme veya masa kimliği değiştirilemez.' using errcode='42501'; end if;
  if r is null or not public.restaurant_has_permission(r,'manageOrders')
    or not public.restaurant_table_access(r,t) then
    raise exception 'Personel sipariş yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;

drop trigger if exists restaurant_staff_write_guard on public.table_orders;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.table_orders
  for each row execute function public.guard_restaurant_staff_order_write();
drop trigger if exists restaurant_staff_write_guard on public.table_order_history;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.table_order_history
  for each row execute function public.guard_restaurant_staff_order_write();

create or replace function public.close_table_with_history(
  p_seller_id uuid,
  p_table_number integer,
  p_payment_method text default 'cash',
  p_payment_note text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_session_key text default null,
  p_table_name text default null,
  p_table_area_name text default null,
  p_display_table_label text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_order record;
  v_grand_total numeric(12,2);
  v_session text;
  v_actor_authorized boolean := false;
begin
  IF NOT public.restaurant_has_permission(p_seller_id, 'manageOrders') OR NOT public.restaurant_table_number_access(p_seller_id,p_table_number) THEN
    RAISE EXCEPTION 'Sipariş yönetme yetkisi yok.' USING ERRCODE='42501';
  END IF;
  v_actor_authorized := auth.uid() = p_seller_id;
  IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;
  v_session := coalesce(p_session_key, 'session_' || p_seller_id || '_' || p_table_number);
  for v_order in
    select * from public.table_orders
    where seller_id = p_seller_id::text and table_number = p_table_number
  loop
    v_grand_total := 0;
    insert into public.table_order_history (
      original_order_id, seller_id, table_number, items, status, payment_method, session_key, closed_at, created_at
    ) values (
      v_order.id, p_seller_id, p_table_number, coalesce(v_order.items, '[]'::jsonb),
      'closed', p_payment_method, v_session, timezone('utc', now()), v_order.created_at
    );
  end loop;
  delete from public.table_orders
  where seller_id = p_seller_id::text and table_number = p_table_number;
end $$;

create or replace function public.transfer_table_orders(
  p_seller_id uuid,
  p_from_table integer,
  p_to_table integer,
  p_transfer_type text default 'full',
  p_item_ids jsonb default '[]'::jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_moved_items jsonb := '[]'::jsonb;
  v_order record;
  v_order_id_list jsonb := '[]'::jsonb;
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
  if p_from_table = p_to_table then
    raise exception 'Kaynak ve hedef masa aynı olamaz.';
  end if;
  for v_order in
    select * from public.table_orders
    where seller_id = p_seller_id::text and table_number = p_from_table
  loop
    v_order_id_list := v_order_id_list || to_jsonb(v_order.id::text);
    update public.table_orders
    set table_number = p_to_table, updated_at = timezone('utc', now())
    where id = v_order.id;
    v_moved_items := v_moved_items || coalesce(v_order.items, '[]'::jsonb);
  end loop;
  insert into public.table_transfers_log (
    seller_id, from_table, to_table, transfer_type, transferred_items, order_ids, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_from_table, p_to_table, p_transfer_type, v_moved_items, v_order_id_list, p_waiter_id, p_waiter_name, p_note
  );
  return jsonb_build_object('success', true);
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  order_id uuid;
begin
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception '0117 changed the active waiter permissions';
  end if;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"corba"}]'::jsonb, 'sent')
  returning id into order_id;
  begin
    perform public.close_table_with_history(destina, 1, 'cash');
    raise exception '0117 allowed close without closeBill';
  exception when insufficient_privilege then null;
  end;
  if not exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'denied close RPC removed the order';
  end if;
  delete from public.table_orders where id = order_id;
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception '0117 was expected to leave direct delete open';
  end if;
end $$;

\ir ../manual_patches/2026110119_staff_manage_permission.sql

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();

do $$
declare
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0 then
    raise exception '0119 did not add manageStaff';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception '0119 changed the active waiter permissions';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['manageStaff','notAPermission']
    where auth_user_id = waiter;
    raise exception 'unknown permission was accepted';
  exception when sqlstate '22023' then null;
  end;
end $$;

\ir ../migrations/20261101184615_staff_close_transfer_direct_write_guard.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  other_store uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  assistant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  outsider uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
  guard_def text;
begin
  guard_def := pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure);
  if position('print_jobs' in guard_def) = 0
     or position('Hesabı kesme yetkisi yok.' in guard_def) = 0
     or position('Masa aktarma yetkisi yok.' in guard_def) = 0
     or position('Personel sipariş yetkisi yok.' in guard_def) = 0 then
    raise exception 'direct-write guard did not keep the order and print path';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception 'direct-write guard changed the active waiter permissions';
  end if;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"corba"}]'::jsonb, 'sent')
  returning id into order_id;
  update public.table_orders set status = 'preparing' where id = order_id;
  begin
    delete from public.table_orders where id = order_id;
    raise exception 'manageOrders waiter deleted a table order';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set table_number = 2 where id = order_id;
    raise exception 'manageOrders waiter transferred a table';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set status = 'closed' where id = order_id;
    raise exception 'manageOrders waiter closed by status';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.table_order_history (seller_id, table_number, status, session_key)
    values (destina, 1, 'closed', 'direct');
    raise exception 'manageOrders waiter inserted close history';
  exception when insufficient_privilege then null;
  end;
  if (select status from public.table_orders where id = order_id) <> 'preparing' then
    raise exception 'order taking update was lost';
  end if;
  if (select table_number from public.table_orders where id = order_id) <> 1 then
    raise exception 'table number changed without transferTable';
  end if;

  update public.store_sub_admins
  set permissions = array['viewOrders','closeBill']
  where auth_user_id = assistant;
  perform set_config('request.jwt.claim.sub', assistant::text, true);
  begin
    insert into public.table_orders (seller_id, table_number, items, status)
    values (destina::text, 1, '[]'::jsonb, 'sent');
    raise exception 'assistant without manageOrders took an order';
  exception when insufficient_privilege then null;
  end;
  delete from public.table_orders where id = order_id;
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'closeBill assistant could not close the granted table';
  end if;
  perform set_config('request.jwt.claim.sub', owner::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 3, '[]'::jsonb, 'sent')
  returning id into order_id;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  update public.store_sub_admins
  set permissions = array['transferTable']
  where auth_user_id = waiter;
  begin
    update public.table_orders set table_number = 2 where id = order_id;
    raise exception 'transfer reached another branch';
  exception when insufficient_privilege then null;
  end;
  if (select table_number from public.table_orders where id = order_id) <> 3 then
    raise exception 'other-branch table number changed';
  end if;
  perform set_config('request.jwt.claim.sub', assistant::text, true);
  begin
    delete from public.table_orders where id = order_id;
    raise exception 'closeBill reached another branch';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', outsider::text, true);
  begin
    delete from public.table_orders where id = order_id;
    raise exception 'other restaurant closed this table';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set table_number = 2 where id = order_id;
    raise exception 'other restaurant transferred this table';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', owner::text, true);
  delete from public.table_orders where id = order_id;
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'owner close was blocked';
  end if;
  raise notice 'STAFF_CLOSE_TRANSFER_GUARD_OK';
end $$;
