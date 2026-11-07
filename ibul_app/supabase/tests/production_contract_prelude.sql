-- Production-shaped fixture. Not a connection to the live project.
--
-- Differences from production ihmixxzqnpamcwmrfibx, kept on purpose:
-- - No RLS policies. Production has orders, table_orders, table_payments and
--   print_jobs policies. These tests check EXECUTE grants and SECURITY DEFINER
--   permission raises instead.
-- - restaurant_has_permission treats auth.uid() = seller as the owner.
--   Production proves the owner through stores.seller_id and matches staff
--   through auth.users plus branch_id. staff_must_change_password is absent.
-- - guard_table_payment checks the same permission, client_request_id replay,
--   session lock and session-scoped remaining. It does not write
--   restaurant_staff_operation_log and does not check waiter_id = auth.uid().
-- - restaurant_staff_write_guard covers table_orders table_number changes only.
--   Production also covers orders, order_items and print_jobs.
-- - orders money-authority, is_test rejection and print-job duplicate triggers
--   are not reproduced.

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
end
$$;

create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table if not exists public.users (
  id uuid primary key,
  email text
);

create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  email text,
  permissions text[] not null default '{}',
  status text not null default 'active'
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  order_number text not null unique,
  status text not null,
  payment_method text not null default 'cash',
  delivery_address jsonb not null default '{}'::jsonb,
  subtotal_amount numeric(12,2) not null default 0,
  shipping_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  currency text not null default 'TRY',
  restaurant_id uuid,
  table_id uuid,
  waiter_id uuid,
  order_status text,
  order_type text not null default 'table',
  notes text,
  local_order_id text
);

create unique index if not exists idx_orders_restaurant_local_order
  on public.orders (restaurant_id, local_order_id)
  where local_order_id is not null;

create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid,
  job_type text not null,
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb,
  document_type text not null default 'kitchen',
  printer_role text not null default 'mutfak'
);

create table if not exists public.table_orders (
  id uuid primary key,
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  client_request_id text,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists table_payments_client_request_uidx
  on public.table_payments (seller_id, client_request_id)
  where client_request_id is not null;

create or replace function public.restaurant_has_permission(
  p_seller uuid, p_permission text
) returns boolean language sql stable as $$
  select auth.uid() = p_seller or exists (
    select 1 from public.store_sub_admins sa
    join public.users u on u.id = auth.uid()
    where sa.store_id = p_seller and sa.status = 'active'
      and lower(btrim(sa.email)) = lower(btrim(u.email))
      and p_permission = any (sa.permissions)
  );
$$;

create or replace function public.create_table_order_with_print_jobs_impl(
  p_restaurant_id uuid, p_table_number integer, p_items jsonb,
  p_waiter_id uuid, p_waiter_name text, p_notes text,
  p_job_type text, p_order_type text, p_local_order_id text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid := gen_random_uuid();
  v_job uuid := gen_random_uuid();
  v_local text := nullif(btrim(coalesce(p_local_order_id, '')), '');
begin
  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if auth.uid() is distinct from p_restaurant_id
     and not public.restaurant_has_permission(p_restaurant_id, 'manageOrders') then
    raise exception 'Sipariş gönderme yetkisi yok.' using errcode = '42501';
  end if;
  insert into public.orders (
    id, user_id, order_number, status, payment_method, restaurant_id,
    order_type, notes, local_order_id
  ) values (
    v_id, auth.uid(), 'N-' || left(v_id::text, 8), 'confirmed', 'cash',
    p_restaurant_id, coalesce(p_order_type, 'table'), p_notes, v_local
  );
  insert into public.print_jobs (id, restaurant_id, order_id, job_type, status)
  values (v_job, p_restaurant_id, v_id, coalesce(p_job_type, 'new_order'), 'pending');
  return jsonb_build_object(
    'order_id', v_id, 'print_job_ids', jsonb_build_array(v_job), 'print_job_count', 1,
    'marketplace_rpc', current_setting('ibul.marketplace_order_rpc', true)
  );
end;
$$;

create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid, p_table_number integer, p_items jsonb,
  p_waiter_id uuid, p_waiter_name text, p_notes text,
  p_job_type text, p_order_type text, p_local_order_id text
) returns jsonb language plpgsql as $$
begin
  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id, p_table_number, p_items, p_waiter_id, p_waiter_name,
    p_notes, p_job_type, p_order_type, p_local_order_id
  );
end;
$$;

create or replace function public.record_table_payment(
  p_seller_id uuid, p_table_number integer, p_session_key text,
  p_amount numeric, p_method text, p_is_closing boolean,
  p_client_request_id text, p_paid_by text default null,
  p_waiter_id uuid default null, p_waiter_name text default null,
  p_note text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null
     or not public.restaurant_has_permission(p_seller_id, 'takePartialPayment') then
    raise exception 'Ara ödeme yetkisi yok.' using errcode = '42501';
  end if;
  if p_client_request_id is null or btrim(p_client_request_id) = '' then
    raise exception 'Ödeme isteği kimliği zorunlu.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.table_payments
    where seller_id = p_seller_id and client_request_id = p_client_request_id
  ) then
    raise exception 'IBUL_PAYMENT_REPLAY' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.table_orders
    where seller_id = p_seller_id::text and table_number = p_table_number
      and public.table_order_is_open(status)
  ) then
    raise exception 'Masa hesabı değişti. Ödeme kaydedilmedi.';
  end if;
  insert into public.table_payments (
    seller_id, table_number, session_key, amount, method, client_request_id
  ) values (
    p_seller_id, p_table_number, p_session_key, p_amount, p_method, p_client_request_id
  ) returning id into v_id;
  return jsonb_build_object('id', v_id, 'replayed', false);
end;
$$;

create or replace function public.is_managed_restaurant_staff()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.store_sub_admins sa
    join public.users u on u.id = auth.uid()
    where sa.status = 'active'
      and lower(btrim(sa.email)) = lower(btrim(u.email))
  );
$$;

create or replace function public.guard_table_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bill numeric := 0;
  v_paid numeric := 0;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if not public.restaurant_has_permission(new.seller_id, 'takePartialPayment') then
    raise exception 'Ara ödeme yetkisi yok.' using errcode = '42501';
  end if;
  if new.client_request_id is null or btrim(new.client_request_id) = '' then
    raise exception 'Ödeme isteği kimliği zorunlu.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.table_payments
    where seller_id = new.seller_id and client_request_id = new.client_request_id
  ) then
    raise exception 'IBUL_PAYMENT_REPLAY' using errcode = 'P0002';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    new.seller_id::text || ':' || new.table_number::text || ':' || coalesce(new.session_key, ''),
    0
  ));
  select coalesce(sum(
    coalesce(nullif(item ->> 'line_total', '')::numeric,
      coalesce(nullif(item ->> 'price', '')::numeric, 0)
      * coalesce(nullif(item ->> 'quantity', '')::numeric, 1))
  ), 0)
    into v_bill
  from public.table_orders o
  cross join lateral jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) item
  where o.seller_id = new.seller_id::text
    and o.table_number = new.table_number;
  select coalesce(sum(amount), 0) into v_paid
  from public.table_payments
  where seller_id = new.seller_id
    and table_number = new.table_number
    and session_key = new.session_key;
  if round(v_bill - v_paid, 2) <= 0 or new.amount > round(v_bill - v_paid, 2) + 0.009 then
    raise exception 'Ödeme kalan bakiyeyi aşıyor.' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_table_payment on public.table_payments;
create trigger guard_table_payment
  before insert on public.table_payments
  for each row
  execute function public.guard_table_payment();

create or replace function public.restaurant_staff_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name <> 'table_orders' or not public.is_managed_restaurant_staff() then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;
  if tg_op = 'UPDATE'
     and new.table_number is distinct from old.table_number
     and not public.restaurant_has_permission(new.seller_id::uuid, 'transferTable') then
    raise exception 'Masa aktarma yetkisi yok.' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

drop trigger if exists restaurant_staff_write_guard on public.table_orders;
create trigger restaurant_staff_write_guard
  before update or delete on public.table_orders
  for each row
  execute function public.restaurant_staff_write_guard();

create or replace function public.transfer_table_orders(
  p_seller_id text, p_from integer, p_to integer
) returns void language plpgsql as $$
begin
  if not public.restaurant_has_permission(p_seller_id::uuid, 'transferTable') then
    raise exception 'Masa aktarma yetkisi yok.' using errcode = '42501';
  end if;
  update public.table_orders
  set table_number = p_to
  where seller_id = p_seller_id and table_number = p_from
    and public.table_order_is_open(status);
  update public.table_payments
  set table_number = p_to
  where seller_id::text = p_seller_id
    and table_number = p_from
    and visit_id in (
      select visit_id from public.table_orders
      where seller_id = p_seller_id and table_number = p_to and visit_id is not null
    );
end;
$$;

insert into public.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'owner@ibul.test'),
  ('44444444-4444-4444-8444-444444444444', 'view@ibul.test'),
  ('55555555-5555-4555-8555-555555555555', 'pay@ibul.test'),
  ('66666666-6666-4666-8666-666666666666', 'move@ibul.test');

insert into public.store_sub_admins (store_id, email, permissions, status) values
  ('11111111-1111-4111-8111-111111111111', 'view@ibul.test', array['viewOrders'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'pay@ibul.test', array['takePartialPayment'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'move@ibul.test', array['transferTable'], 'active');

commit;
