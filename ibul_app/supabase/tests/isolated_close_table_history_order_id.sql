-- Isolated PostgreSQL 17 fixture derived from the live close contract.
-- Synthetic ids only. Does not connect to production.
\set ON_ERROR_STOP on

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz,
  raw_app_meta_data jsonb not null default '{}'::jsonb
);

create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.jwt()
returns jsonb
language sql stable
as $$
  select case
    when nullif(current_setting('request.jwt.claims', true), '') is null then '{}'::jsonb
    else current_setting('request.jwt.claims', true)::jsonb
  end;
$$;

create or replace function auth.role()
returns text
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '');
$$;

create table public.users (
  id uuid primary key,
  email text,
  phone text,
  role text
);

create table public.stores (
  seller_id uuid primary key
);

create table public.store_branches (
  id uuid primary key,
  store_id uuid,
  status text
);

create table public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  status text not null,
  permissions text[],
  auth_user_id uuid,
  email text,
  phone text,
  branch_id uuid
);

create table public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid,
  table_id uuid,
  order_type text not null default 'table',
  delivery_type text,
  status text not null default 'confirmed',
  order_status text,
  total_amount numeric not null default 0,
  user_id uuid,
  subtotal_amount numeric,
  shipping_amount numeric,
  discount_amount numeric,
  customer_delivery_fee numeric,
  seller_delivery_fee numeric,
  total_delivery_fee numeric,
  payment_status text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
  seller_id uuid
);

create table public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'open',
  created_at timestamptz default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb
);

create table public.table_order_history (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid not null,
  seller_id uuid not null references auth.users(id) on delete cascade,
  table_number integer not null check (table_number > 0),
  items jsonb not null default '[]'::jsonb,
  status text not null default 'closed',
  revision integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb,
  payment_method text,
  payment_note text,
  waiter_id uuid references auth.users(id) on delete set null,
  waiter_name text,
  grand_total numeric,
  session_key text,
  closed_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  archived_orders jsonb
);

create table public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric not null,
  method text not null,
  paid_by text,
  waiter_id uuid,
  waiter_name text,
  note text,
  is_closing boolean not null default false,
  created_at timestamptz not null default now(),
  client_request_id text
);

create table public.restaurant_staff_operation_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  seller_id uuid,
  table_number integer,
  operation text,
  summary jsonb
);

create or replace function public.staff_must_change_password()
returns boolean
language sql stable security definer
set search_path to public
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'managed_restaurant_staff') = 'true'
    and (auth.jwt() -> 'app_metadata' ->> 'must_change_password') = 'true',
    false
  );
$$;

create or replace function public.restaurant_table_access(
  p_restaurant_id uuid,
  p_table_id uuid
)
returns boolean
language sql stable
as $$
  select auth.uid() = p_restaurant_id
    or exists (
      select 1
      from public.store_sub_admins sa
      where sa.store_id = p_restaurant_id
        and sa.auth_user_id = auth.uid()
        and sa.status = 'active'
    );
$$;

create or replace function public.restaurant_table_number_access(
  p_restaurant_id uuid,
  p_number integer
)
returns boolean
language sql stable
as $$
  select auth.uid() = p_restaurant_id
    or exists (
      select 1
      from public.store_tables t
      where t.seller_id = p_restaurant_id
        and t.table_number = p_number
        and public.restaurant_table_access(p_restaurant_id, t.id)
    );
$$;

create or replace function public.restaurant_has_permission(
  p_restaurant_id uuid,
  p_permission text
)
returns boolean
language sql stable security definer
set search_path to public
as $$
  select auth.uid() is not null
    and not public.staff_must_change_password()
    and (
      exists (
        select 1 from public.stores
        where seller_id = p_restaurant_id and seller_id = auth.uid()
      )
      or exists (
        select 1
        from public.store_sub_admins sa
        join auth.users au on au.id = auth.uid()
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and (sa.branch_id is null or exists (
            select 1 from public.store_branches b
            where b.id = sa.branch_id
              and b.store_id = sa.store_id
              and b.status = 'active'
          ))
          and (p_permission is null or p_permission = any(sa.permissions))
          and (sa.auth_user_id = au.id or (sa.auth_user_id is null and (
            (au.email_confirmed_at is not null and lower(trim(sa.email)) = lower(trim(au.email)))
            or (au.phone_confirmed_at is not null and sa.phone = au.phone)
          )))
      )
    );
$$;

create or replace function public.restaurant_staff_may_operate(
  p_restaurant_id uuid,
  p_permission text,
  p_table_number integer
)
returns void
language plpgsql security definer
set search_path to public
as $$
declare
  v_must_change boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if to_regprocedure('public.staff_must_change_password()') is not null then
    execute 'select public.staff_must_change_password()' into v_must_change;
    if coalesce(v_must_change, false) then
      raise exception 'Önce geçici şifre değiştirilmeli.' using errcode = '42501';
    end if;
  end if;
  if not public.restaurant_has_permission(p_restaurant_id, p_permission) then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
  end if;
  if p_table_number is not null
     and not public.restaurant_table_number_access(p_restaurant_id, p_table_number) then
    raise exception 'Bu masada işlem yetkiniz yok.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language sql stable
as $$ select false; $$;

create or replace function public.can_access_order_as_seller(
  target_order_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql stable security definer
set search_path to public
as $$
  select exists (
    select 1
    from public.order_items oi
    where oi.order_id = target_order_id
      and oi.seller_id = target_user_id
  );
$$;

create or replace function public.orders_money_authority_guard()
returns trigger
language plpgsql security definer
set search_path to public
as $$
declare
  v_rpc boolean := current_setting('ibul.marketplace_order_rpc', true) = 'on';
  v_webhook boolean := current_setting('ibul.payment_webhook', true) = 'on';
  v_service boolean := coalesce(auth.role(), '') = 'service_role';
  v_allowed boolean := false;
begin
  if v_rpc or v_service then
    return new;
  end if;
  if tg_op = 'INSERT' then
    raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode = '42501';
  end if;
  if auth.uid() is not null then
    v_allowed := old.user_id = auth.uid()
      or coalesce(public.is_admin_user(auth.uid()), false);
    if to_regprocedure('public.can_access_order_as_seller(uuid,uuid)') is not null then
      v_allowed := v_allowed or public.can_access_order_as_seller(old.id, auth.uid());
    end if;
    if not v_allowed then
      raise exception 'ORDER_UPDATE_DENIED' using errcode = '42501';
    end if;
  end if;
  if new.user_id is distinct from old.user_id
     or new.subtotal_amount is distinct from old.subtotal_amount
     or new.shipping_amount is distinct from old.shipping_amount
     or new.discount_amount is distinct from old.discount_amount
     or new.total_amount is distinct from old.total_amount
     or new.customer_delivery_fee is distinct from old.customer_delivery_fee
     or new.seller_delivery_fee is distinct from old.seller_delivery_fee
     or new.total_delivery_fee is distinct from old.total_delivery_fee
  then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
  end if;
  if new.payment_status is distinct from old.payment_status
     and lower(coalesce(new.payment_status, '')) in ('paid', 'refunded')
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;
  if lower(coalesce(new.status, '')) in ('paid', 'refunded')
     and lower(coalesce(old.status, '')) is distinct from lower(coalesce(new.status, ''))
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger trg_orders_money_authority
before update on public.orders
for each row execute function public.orders_money_authority_guard();

create or replace function public.guard_table_payment()
returns trigger
language plpgsql security definer
set search_path to public
as $$
declare
  v_is_owner boolean;
  v_order_total numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_remaining numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  v_is_owner := exists (
    select 1 from public.stores s
    where s.seller_id = auth.uid()
      and s.seller_id = new.seller_id
  );
  if not v_is_owner then
    perform public.restaurant_staff_may_operate(
      new.seller_id, 'takePartialPayment', new.table_number
    );
  end if;
  if new.amount is null or new.amount <= 0 then
    raise exception 'Ödeme tutarı geçersiz.' using errcode = '22023';
  end if;
  new.amount := round(new.amount, 2);
  select coalesce(sum(
    coalesce(
      nullif(item ->> 'line_total', '')::numeric,
      coalesce(nullif(item ->> 'price', '')::numeric, 0)
      * coalesce(nullif(item ->> 'quantity', '')::numeric, 1)
    )
  ), 0)
  into v_order_total
  from public.table_orders o
  cross join lateral jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) item
  where o.seller_id = new.seller_id::text
    and o.table_number = new.table_number;
  select coalesce(sum(amount), 0)
  into v_paid
  from public.table_payments
  where seller_id = new.seller_id
    and table_number = new.table_number
    and session_key = new.session_key;
  v_remaining := round(v_order_total - v_paid, 2);
  if v_remaining <= 0 or new.amount > v_remaining + 0.009 then
    raise exception 'Ödeme kalan bakiyeyi aşıyor.' using errcode = '22023';
  end if;
  return new;
end;
$$;

insert into auth.users (id, email, email_confirmed_at) values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'staff@example.test', now());

insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'staff@example.test');

insert into public.stores (seller_id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('44444444-4444-4444-4444-444444444444');

insert into public.store_sub_admins (store_id, status, permissions, auth_user_id, email) values
  (
    '11111111-1111-1111-1111-111111111111',
    'active',
    array['viewOrders']::text[],
    '22222222-2222-2222-2222-222222222222',
    'staff@example.test'
  );

insert into public.store_tables (id, seller_id, table_number) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 1),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '11111111-1111-1111-1111-111111111111', 2),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3', '11111111-1111-1111-1111-111111111111', 3),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4', '11111111-1111-1111-1111-111111111111', 4),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6', '11111111-1111-1111-1111-111111111111', 6),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa7', '44444444-4444-4444-4444-444444444444', 7),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa9', '11111111-1111-1111-1111-111111111111', 9);

insert into public.orders (
  id, restaurant_id, table_id, status, order_status, total_amount, created_at
) values
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'confirmed', 'sent', 640, '2026-11-01 10:00:00+00'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'confirmed', 'sent', 200, '2026-11-01 09:00:00+00'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb32',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'confirmed', 'sent', 400, '2026-11-01 11:00:00+00'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb6',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6',
    'confirmed', 'sent', 320, '2026-11-01 12:00:00+00'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb7',
    '44444444-4444-4444-4444-444444444444',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa7',
    'confirmed', 'sent', 150, '2026-11-01 12:00:00+00'
  );

insert into public.order_items (order_id, seller_id) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31', '11111111-1111-1111-1111-111111111111');

insert into public.table_orders (id, seller_id, table_number, items, status, created_at) values
  (
    'cccccccc-cccc-cccc-cccc-ccccccccccc4',
    '11111111-1111-1111-1111-111111111111',
    4,
    '[{"name":"Peynir","price":"200","quantity":"1","line_total":"200"}]'::jsonb,
    'open',
    '2026-11-01 08:00:00+00'
  ),
  (
    'cccccccc-cccc-cccc-cccc-ccccccccccc9',
    '11111111-1111-1111-1111-111111111111',
    9,
    '[{"name":"Cay","price":"100","quantity":"1","line_total":"100"}]'::jsonb,
    'open',
    '2026-11-01 08:00:00+00'
  );

insert into public.table_payments (
  id, seller_id, table_number, session_key, amount, method, is_closing
) values (
  'dddddddd-dddd-dddd-dddd-ddddddddddd2',
  '11111111-1111-1111-1111-111111111111',
  2,
  'bill-2',
  100,
  'cash',
  false
);

create trigger guard_table_payment
before insert on public.table_payments
for each row execute function public.guard_table_payment();

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  false
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}',
  false
);

-- Live insert shape: aggregate over an empty table_orders still emits one
-- row and omits original_order_id.
do $$
begin
  insert into public.table_order_history (
    seller_id, table_number, grand_total, archived_orders
  )
  select
    '11111111-1111-1111-1111-111111111111'::uuid,
    1,
    coalesce(sum(0), 0),
    coalesce(jsonb_agg(to_jsonb(src)), '[]'::jsonb)
  from public.table_orders src
  where false;
  raise exception 'FAIL old empty aggregate did not raise 23502';
exception
  when not_null_violation then
    null;
end $$;

\ir ../migrations/20261105183000_close_table_history_order_id.sql

do $$
declare
  v jsonb;
  v_again jsonb;
  v_history int;
  v_status text;
  v_total numeric;
  v_paid numeric;
  v_original uuid;
  v_archived int;
  v_table_status text;
begin
  v := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    1,
    'cash',
    null,
    null,
    null,
    'empty-session'
  );
  if (v ->> 'orders_updated')::int <> 0
     or (v ->> 'table_orders_updated')::int <> 0
     or v ->> 'history_id' is not null then
    raise exception 'FAIL empty table wrote a close: %', v;
  end if;
  select count(*) into v_history from public.table_order_history;
  if v_history <> 0 then
    raise exception 'FAIL empty table created history';
  end if;

  v := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    2,
    'cash',
    null,
    null,
    null,
    'sess-bahce'
  );
  if (v ->> 'orders_updated')::int <> 1 or (v ->> 'grand_total')::numeric <> 640 then
    raise exception 'FAIL ordered close: %', v;
  end if;
  select original_order_id, grand_total,
         jsonb_array_length(archived_orders)
  into v_original, v_total, v_archived
  from public.table_order_history
  where id = (v ->> 'history_id')::uuid;
  if v_original <> 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'::uuid
     or v_total <> 640
     or v_archived <> 1 then
    raise exception 'FAIL history identity % % %', v_original, v_total, v_archived;
  end if;
  select status, total_amount into v_status, v_total
  from public.orders
  where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  if v_status <> 'closed' or v_total <> 640 then
    raise exception 'FAIL order money changed % %', v_status, v_total;
  end if;
  select amount into v_paid
  from public.table_payments
  where id = 'dddddddd-dddd-dddd-dddd-ddddddddddd2';
  if v_paid <> 100 then
    raise exception 'FAIL payment changed %', v_paid;
  end if;

  v_again := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    2,
    'cash',
    null,
    null,
    null,
    'sess-bahce'
  );
  select count(*) into v_history
  from public.table_order_history
  where table_number = 2;
  if v_history <> 1
     or (v_again ->> 'orders_updated')::int <> 0
     or (v_again ->> 'history_id') <> (v ->> 'history_id') then
    raise exception 'FAIL replay duplicated history % %', v_again, v_history;
  end if;

  v := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    3,
    'cash',
    null,
    null,
    null,
    'sess-two'
  );
  if (v ->> 'grand_total')::numeric <> 600 or (v ->> 'orders_updated')::int <> 2 then
    raise exception 'FAIL two-order total %', v;
  end if;
  select count(*) into v_history
  from public.table_order_history
  where table_number = 3;
  if v_history <> 2 then
    raise exception 'FAIL two-order history count %', v_history;
  end if;
  select h.original_order_id, h.grand_total, jsonb_array_length(h.archived_orders),
         h.session_key, h.archived_orders -> 0 ->> 'id'
  into v_original, v_total, v_archived, v_status, v_table_status
  from public.table_order_history h
  where h.original_order_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31';
  if v_original <> 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31'::uuid
     or v_total <> 200
     or v_archived <> 1
     or v_status <> 'sess-two'
     or v_table_status <> 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31' then
    raise exception 'FAIL first order history % % % % %',
      v_original, v_total, v_archived, v_status, v_table_status;
  end if;
  select h.original_order_id, h.grand_total, jsonb_array_length(h.archived_orders),
         h.session_key, h.archived_orders -> 0 ->> 'id'
  into v_original, v_total, v_archived, v_status, v_table_status
  from public.table_order_history h
  where h.original_order_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb32';
  if v_original <> 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb32'::uuid
     or v_total <> 400
     or v_archived <> 1
     or v_status <> 'sess-two:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb32'
     or v_table_status <> 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb32' then
    raise exception 'FAIL second order history % % % % %',
      v_original, v_total, v_archived, v_status, v_table_status;
  end if;
  v_again := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    3,
    'cash',
    null,
    null,
    null,
    'sess-two'
  );
  select count(*) into v_history
  from public.table_order_history
  where table_number = 3;
  if v_history <> 2 or (v_again ->> 'orders_updated')::int <> 0 then
    raise exception 'FAIL two-order replay % %', v_again, v_history;
  end if;

  begin
    update public.orders
    set total_amount = total_amount + 1
    where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb31';
    raise exception 'FAIL money column update was allowed';
  exception
    when insufficient_privilege then
      null;
  end;

  v := public.close_table_with_history(
    '11111111-1111-1111-1111-111111111111',
    4,
    'cash',
    null,
    null,
    null,
    'sess-table-order'
  );
  select original_order_id, grand_total into v_original, v_total
  from public.table_order_history
  where id = (v ->> 'history_id')::uuid;
  select status into v_table_status
  from public.table_orders
  where id = 'cccccccc-cccc-cccc-cccc-ccccccccccc4';
  if v_original <> 'cccccccc-cccc-cccc-cccc-ccccccccccc4'::uuid
     or v_total <> 200
     or v_table_status <> 'archived' then
    raise exception 'FAIL table_orders source % % %', v_original, v_total, v_table_status;
  end if;
end $$;

do $$
declare
  v_status text;
  v_history int;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-2222-2222-222222222222',
    false
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"22222222-2222-2222-2222-222222222222"}',
    false
  );
  select count(*) into v_history from public.table_order_history where table_number = 6;
  begin
    perform public.close_table_with_history(
      '11111111-1111-1111-1111-111111111111',
      6,
      'cash',
      null,
      null,
      null,
      'staff-denied'
    );
    raise exception 'FAIL staff without closeBill closed the table';
  exception
    when insufficient_privilege then
      null;
  end;
  select status into v_status
  from public.orders
  where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb6';
  if v_status <> 'confirmed'
     or (select count(*) from public.table_order_history where table_number = 6) <> v_history then
    raise exception 'FAIL unauthorized close changed rows %', v_status;
  end if;
end $$;

do $$
declare
  v_status text;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '44444444-4444-4444-4444-444444444444',
    false
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"44444444-4444-4444-4444-444444444444"}',
    false
  );
  begin
    perform public.close_table_with_history(
      '44444444-4444-4444-4444-444444444444',
      7,
      'cash',
      null,
      null,
      null,
      'fk-fail'
    );
    raise exception 'FAIL missing auth user still closed';
  exception
    when foreign_key_violation then
      null;
  end;
  select status into v_status
  from public.orders
  where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb7';
  if v_status <> 'confirmed'
     or exists (
       select 1 from public.table_order_history where table_number = 7
     ) then
    raise exception 'FAIL fk failure was not atomic %', v_status;
  end if;
end $$;

do $$
declare
  v_paid numeric;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '11111111-1111-1111-1111-111111111111',
    false
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111"}',
    false
  );
  insert into public.table_payments (
    seller_id, table_number, session_key, amount, method, is_closing
  ) values (
    '11111111-1111-1111-1111-111111111111',
    9,
    'pay-9',
    40,
    'cash',
    false
  );
  begin
    insert into public.table_payments (
      seller_id, table_number, session_key, amount, method, is_closing
    ) values (
      '11111111-1111-1111-1111-111111111111',
      9,
      'pay-9',
      70,
      'cash',
      false
    );
    raise exception 'FAIL overpayment was accepted';
  exception
    when check_violation or invalid_parameter_value then
      null;
  end;
  select coalesce(sum(amount), 0) into v_paid
  from public.table_payments
  where table_number = 9;
  if v_paid <> 40 then
    raise exception 'FAIL overpayment changed the paid total %', v_paid;
  end if;
end $$;
