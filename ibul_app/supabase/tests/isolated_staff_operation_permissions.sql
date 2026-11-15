-- Throwaway database only. Does not connect to supabase.co.

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
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'must_change_password') = 'true', false);
$$;

create table if not exists public.stores (seller_id uuid primary key);
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
create table if not exists public.store_branches (
  id uuid primary key,
  store_id uuid not null,
  status text not null
);
create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  revision integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb,
  last_edit_note text,
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
  revision integer,
  last_edit_summary jsonb,
  last_edit_note text,
  payment_method text,
  payment_note text,
  waiter_id uuid,
  waiter_name text,
  grand_total numeric,
  session_key text,
  table_name text,
  display_table_label text,
  table_display_name text,
  table_area_name text,
  opened_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz
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

create table if not exists public.orders (
  id uuid primary key,
  restaurant_id uuid not null,
  status text not null
);
create table if not exists public.print_jobs (
  id uuid primary key,
  restaurant_id uuid not null,
  status text not null
);
insert into public.orders values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'confirmed');
insert into public.print_jobs values
  ('ffffffff-ffff-ffff-ffff-fffffffffff1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'pending');

insert into auth.users (id, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'owner@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'waiter@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'other-branch@destina.test', now()),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'other@store.test', now());
insert into public.stores values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
insert into public.store_branches values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active');
insert into public.store_tables values
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 1, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 2, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '22222222-2222-2222-2222-222222222222', 3, true);
insert into public.store_sub_admins values
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '11111111-1111-1111-1111-111111111111', 'active', 'waiter@destina.test', array['viewOrders','manageOrders']),
  ('f2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', '22222222-2222-2222-2222-222222222222', 'active', 'other-branch@destina.test', array['transferTable','takePartialPayment','closeBill']);

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
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.stores s where s.seller_id = p_restaurant_id and s.seller_id = auth.uid())
    or exists (
      select 1 from public.store_tables t
      join public.store_sub_admins sa
        on sa.store_id = t.seller_id
       and sa.auth_user_id = auth.uid()
       and sa.status = 'active'
      where t.seller_id = p_restaurant_id
        and t.table_number = p_number
        and t.is_active
        and (sa.branch_id is null or t.branch_id = sa.branch_id)
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
    select coalesce(sum((item->>'price')::numeric * coalesce((item->>'quantity')::numeric, 1)), 0)
    into v_grand_total
    from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) as item;
    insert into public.table_order_history (
      original_order_id, seller_id, table_number, items, status, revision,
      last_edit_summary, last_edit_note, payment_method, payment_note,
      waiter_id, waiter_name, grand_total, session_key, opened_at, closed_at, created_at
    ) values (
      v_order.id, p_seller_id, p_table_number, coalesce(v_order.items, '[]'::jsonb),
      'closed', coalesce(v_order.revision, 1), coalesce(v_order.last_edit_summary, '{}'::jsonb),
      v_order.last_edit_note, p_payment_method, p_payment_note, p_waiter_id, p_waiter_name,
      v_grand_total, v_session, v_order.created_at, timezone('utc', now()), v_order.created_at
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
  v_new_items jsonb;
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
    if p_transfer_type = 'full' then
      update public.table_orders
      set table_number = p_to_table, updated_at = timezone('utc', now())
      where id = v_order.id;
      v_moved_items := v_moved_items || coalesce(v_order.items, '[]'::jsonb);
    else
      select
        jsonb_agg(item) filter (where (item->>'id') = any (select jsonb_array_elements_text(p_item_ids))),
        jsonb_agg(item) filter (where (item->>'id') <> all (select jsonb_array_elements_text(p_item_ids)))
      into v_moved_items, v_new_items
      from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) item;
      if v_new_items is null or jsonb_array_length(v_new_items) = 0 then
        update public.table_orders set table_number = p_to_table, updated_at = timezone('utc', now()) where id = v_order.id;
      else
        update public.table_orders set items = v_new_items, updated_at = timezone('utc', now()) where id = v_order.id;
        insert into public.table_orders (seller_id, table_number, items, status, created_at)
        values (p_seller_id::text, p_to_table, coalesce(v_moved_items, '[]'::jsonb), 'new', timezone('utc', now()));
      end if;
    end if;
  end loop;
  insert into public.table_transfers_log (
    seller_id, from_table, to_table, transfer_type, transferred_items, order_ids, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_from_table, p_to_table, p_transfer_type, v_moved_items, v_order_id_list, p_waiter_id, p_waiter_name, p_note
  );
  return jsonb_build_object('success', true, 'moved_items', v_moved_items, 'transfer_type', p_transfer_type);
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql
\ir ../migrations/20261103214000_guard_table_payment_owner_balance.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  other_branch uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  other_store uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
  moved integer;
  history_count integer;
  payment_count integer;
  replay jsonb;
  close_def text;
  transfer_def text;
begin
  execute 'drop trigger if exists store_sub_admins_validate on public.store_sub_admins';
  execute 'create trigger store_sub_admins_validate before insert or update on public.store_sub_admins for each row execute function public.validate_restaurant_staff_membership()';
  close_def := pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure);
  transfer_def := pg_get_functiondef('public.transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)'::regprocedure);
  if position('restaurant_staff_may_operate' in close_def) = 0
     or position('Yetkisiz işlem.' in close_def) > 0
     or position('Sipariş yönetme yetkisi yok.' in close_def) > 0
     or position('seller_id = p_seller_id::text' in close_def) = 0 then
    raise exception 'close body was replaced instead of patched';
  end if;
  if position('restaurant_staff_may_operate' in transfer_def) = 0
     or position('p_waiter_name, p_note' in transfer_def) = 0
     or position('p_seller_id <> auth.uid()' in transfer_def) > 0 then
    raise exception 'transfer body was replaced instead of patched';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception 'existing staff permissions changed';
  end if;

  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 1, '[{"id":"line-1","price":50,"quantity":1}]'::jsonb);

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  begin
    perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, 'Garson', null);
    raise exception 'transfer without permission succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.close_table_with_history(destina, 1, 'cash', null, waiter, null, 'session-1', null, null, null);
    raise exception 'manageOrders alone closed the bill';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.record_table_payment(destina, 1, 'session-1', 20, 'cash', false, null, null, waiter, null, null);
    raise exception 'payment without permission succeeded';
  exception when insufficient_privilege then null;
  end;

  update public.store_sub_admins
  set permissions = array['viewOrders','manageOrders','transferTable','takePartialPayment','closeBill']
  where auth_user_id = waiter;

  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, 'Garson', 'not');
  select table_number into moved from public.table_orders where seller_id = destina::text;
  if moved <> 2 then
    raise exception 'authorized transfer did not move the order';
  end if;

  perform public.record_table_payment(destina, 2, 'session-1', 20, 'cash', false, 'pay-1', null, waiter, null, null);
  replay := public.record_table_payment(destina, 2, 'session-1', 20, 'cash', false, 'pay-1', null, waiter, null, null);
  if replay ->> 'idempotent_replay' <> 'true' then
    raise exception 'same payment key was not replayed';
  end if;
  select count(*) into payment_count from public.table_payments where client_request_id = 'pay-1';
  if payment_count <> 1 then
    raise exception 'same payment key created a second row';
  end if;
  begin
    perform public.record_table_payment(destina, 3, 'session-1', 10, 'cash', false, 'pay-other-branch', null, waiter, null, null);
    raise exception 'other branch payment succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.record_table_payment(destina, 2, 'session-1', 40, 'cash', false, 'pay-2', null, waiter, null, null);
    raise exception 'overpayment succeeded';
  exception when invalid_parameter_value then null;
  end;
  begin
    insert into public.table_payments (seller_id, table_number, session_key, amount, waiter_id)
    values (waiter, 2, 'session-1', 10, waiter);
    raise exception 'staff inserted a payment under their own id';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', other_branch::text, true);
  begin
    perform public.transfer_table_orders(destina, 2, 1, 'full', '[]'::jsonb, other_branch, null, null);
    raise exception 'other branch transfer succeeded';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', other_store::text, true);
  begin
    perform public.close_table_with_history(destina, 2, 'cash', null, other_store, null, 'session-1', null, null, null);
    raise exception 'other store close succeeded';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  update public.store_sub_admins set status = 'inactive' where auth_user_id = waiter;
  begin
    perform public.close_table_with_history(destina, 2, 'cash', null, waiter, null, 'session-1', null, null, null);
    raise exception 'inactive staff close succeeded';
  exception when insufficient_privilege then null;
  end;
  update public.store_sub_admins
  set status = 'active', permissions = array['closeBill','transferTable','takePartialPayment']
  where auth_user_id = waiter;

  select count(*) into history_count from public.table_order_history;
  perform public.close_table_with_history(destina, 2, 'cash', null, waiter, null, 'session-1', null, null, null);
  if exists (select 1 from public.table_orders where seller_id = destina::text) then
    raise exception 'close left an active order';
  end if;
  perform public.close_table_with_history(destina, 2, 'cash', null, waiter, null, 'session-1', null, null, null);
  if (select count(*) from public.table_order_history) <> history_count + 1 then
    raise exception 'second close archived another bill';
  end if;

  update public.store_sub_admins set permissions = array['viewOrders'] where auth_user_id = waiter;
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 1, '[{"price":10,"quantity":1}]'::jsonb);
  begin
    perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, null, null);
    raise exception 'revoked transfer succeeded';
  exception when insufficient_privilege then null;
  end;
  update public.store_sub_admins set permissions = array['transferTable'] where auth_user_id = waiter;
  perform set_config('request.jwt.claims', '{"app_metadata":{"must_change_password":"true"}}', true);
  begin
    perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, null, null);
    raise exception 'password-change gate allowed a transfer';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);

  perform set_config('request.jwt.claim.sub', destina::text, true);
  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, destina, 'Sahip', null);
  perform public.close_table_with_history(destina, 2, 'cash', null, destina, null, 'owner-session');
  begin
    perform public.record_table_payment(destina, 2, 'owner-session', 10, 'cash', false, 'owner-pay', null, destina, null, null);
    raise exception 'owner paid a zero balance';
  exception when invalid_parameter_value then null;
  end;
  begin
    insert into public.table_payments (seller_id, table_number, session_key, amount, method)
    values (destina, 2, 'legacy-owner', 5, 'cash');
    raise exception 'owner insert bypassed the balance';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.record_table_payment(destina, 2, 'owner-session', 0, 'cash', false, 'owner-zero', null, destina, null, null);
    raise exception 'zero payment was accepted';
  exception when invalid_parameter_value then null;
  end;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  update public.store_sub_admins
  set permissions = array['takePartialPayment']
  where auth_user_id = waiter;
  insert into public.store_tables values
    ('dddddddd-dddd-dddd-dddd-ddddddddddd4', destina, '11111111-1111-1111-1111-111111111111', 4, true);
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 4, '[{"price":50,"quantity":1}]'::jsonb);
  raise notice 'STAFF_OPERATION_PERMISSIONS_OK';
end $$;

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  other_store uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
begin
  perform set_config('request.jwt.claim.sub', other_store::text, true);
  begin
    perform public.record_table_payment(
      destina, 4, 'race', 10, 'cash', false, 'other-store-pay', null,
      other_store, null, null
    );
    raise exception 'other store payment succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
  if exists (
    select 1 from public.table_payments where client_request_id = 'other-store-pay'
  ) then
    raise exception 'other store payment was stored';
  end if;
  raise notice 'OTHER_STORE_PAYMENT_BLOCKED';
end $$;

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  insert into public.store_tables values (
    'dddddddd-dddd-dddd-dddd-ddddddddddd5', destina,
    '11111111-1111-1111-1111-111111111111', 5, true
  );
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 5, '[{"price":50,"quantity":1}]'::jsonb);

  perform set_config('request.jwt.claim.sub', destina::text, true);
  perform public.record_table_payment(
    destina, 5, 'limit', 20, 'cash', false, 'owner-20', null, destina, null, null
  );
  begin
    perform public.record_table_payment(
      destina, 5, 'limit', 40, 'cash', false, 'owner-40', null, destina, null, null
    );
    raise exception 'owner exceeded the remaining balance';
  exception when invalid_parameter_value then null;
  end;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  perform public.record_table_payment(
    destina, 5, 'limit', 30, 'cash', false, 'waiter-30', null, waiter, 'Garson', null
  );
  begin
    perform public.record_table_payment(
      destina, 5, 'limit', 1, 'cash', false, 'waiter-1', null, waiter, 'Garson', null
    );
    raise exception 'waiter exceeded the remaining balance';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.record_table_payment(
      destina, 5, 'limit', -5, 'cash', false, 'waiter-neg', null, waiter, 'Garson', null
    );
    raise exception 'negative payment was accepted';
  exception when invalid_parameter_value then null;
  end;
  if (select coalesce(sum(amount), 0) from public.table_payments where table_number = 5) <> 50 then
    raise exception 'owner and waiter payments did not stop at the bill';
  end if;
  if (select count(*) from public.table_orders where table_number = 5) <> 1 then
    raise exception 'partial payment closed the table';
  end if;
  raise notice 'OWNER_WAITER_BALANCE_OK';
end $$;
