-- Production-shaped restaurant schema for the isolated PostgreSQL 17 run.
-- This is not a live dump. It loads the objects the open migrations call,
-- including the existing overpayment trigger guard_table_payment, the loose
-- close RPC, the owner-only history/transfer RPCs, and the print RPC.
-- Cancel side effects are represented by the stock and kitchen triggers that
-- fire only when orders.status becomes cancelled.

begin;

create schema if not exists auth;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role;
  end if;
end
$$;

create table if not exists public.users (
  id uuid primary key,
  email text,
  phone text
);

create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  email text,
  phone text,
  permissions text[] not null default '{}'::text[],
  status text not null default 'invited',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  placement_source text,
  updated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  paid_by text,
  waiter_id uuid,
  waiter_name text,
  note text,
  is_closing boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_transfers_log (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  from_table integer not null,
  to_table integer not null,
  transfer_type text not null,
  transferred_items jsonb,
  order_ids jsonb,
  waiter_id uuid,
  waiter_name text,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  order_number text,
  status text not null,
  order_status text,
  restaurant_id uuid,
  notes text,
  order_type text,
  delivery_type text,
  total_amount numeric not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid not null references public.orders (id) on delete cascade,
  job_type text not null,
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb
);

create table if not exists public.stock_events (
  id integer generated always as identity primary key,
  order_id uuid,
  reason text not null
);

create table if not exists public.waiter_order_requests (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  items_draft jsonb not null,
  customer_notes text,
  status text not null,
  resulting_table_order_id uuid,
  created_by uuid not null
);

create table if not exists public.production_guard_baseline (
  name text primary key,
  definition text not null
);

alter table public.table_orders enable row level security;
drop policy if exists table_orders_authenticated_all on public.table_orders;
create policy table_orders_authenticated_all
  on public.table_orders
  for all
  to authenticated
  using (true)
  with check (true);

grant usage on schema auth, public to authenticated, anon, service_role;
grant execute on function auth.uid() to authenticated, anon, service_role;
grant select on public.users to authenticated, service_role;
grant select, insert, update, delete on public.store_sub_admins to authenticated;
grant select, insert, update, delete on public.table_orders to authenticated, service_role;
grant select, insert, update, delete on public.table_payments to authenticated, service_role;
grant select, insert on public.orders to authenticated, service_role;
grant select, insert, update on public.print_jobs to authenticated, service_role;
grant select, insert on public.stock_events to authenticated, service_role;
grant select, insert, update on public.waiter_order_requests to authenticated, service_role;

-- Any active staff member can pass this coarse check. The payment trigger
-- and the new order wrapper must still require manageOrders / Tam Erişim.
create or replace function public.user_can_access_restaurant(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() = p_restaurant_id
    or exists (
      select 1
      from public.store_sub_admins sa
      join public.users u on u.id = auth.uid()
      where sa.store_id = p_restaurant_id
        and sa.status = 'active'
        and (
          (
            sa.email is not null
            and btrim(sa.email) <> ''
            and lower(btrim(coalesce(u.email, ''))) = lower(btrim(sa.email))
          )
          or (
            sa.phone is not null
            and btrim(sa.phone) <> ''
            and btrim(coalesce(u.phone, '')) = btrim(sa.phone)
          )
        )
    );
$$;

-- Existing production overpayment guard. Migrations must not replace it.
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
  select coalesce(sum(
    round(
      coalesce((item->>'price')::numeric, 0)
      * coalesce(nullif(item->>'quantity', '')::numeric, 1),
      2
    )
  ), 0)
  into v_bill
  from public.table_orders o
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(o.items) = 'array' then o.items else '[]'::jsonb end
  ) item
  where o.seller_id = new.seller_id
    and o.table_number = new.table_number
    and lower(coalesce(o.status, '')) not in (
      'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
      'completed_payment', 'payment_completed', 'archived', 'print_anchor'
    );

  select coalesce(sum(amount), 0)
  into v_paid
  from public.table_payments
  where seller_id = new.seller_id
    and table_number = new.table_number;

  if round(coalesce(v_paid, 0) + new.amount, 2) > round(coalesce(v_bill, 0), 2) then
    raise exception 'Kalan tutardan fazla ödeme alınamaz.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_table_payment on public.table_payments;
create trigger trg_guard_table_payment
  before insert on public.table_payments
  for each row
  execute function public.guard_table_payment();

create or replace function public.restore_stock_on_cancel()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    insert into public.stock_events (order_id, reason)
    values (new.id, 'cancel_restock');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restore_stock_on_cancel on public.orders;
create trigger trg_restore_stock_on_cancel
  before update on public.orders
  for each row
  execute function public.restore_stock_on_cancel();

create or replace function public.void_kitchen_ticket_on_cancel()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update public.print_jobs
    set status = 'failed'
    where order_id = new.id
      and status = 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_void_kitchen_ticket_on_cancel on public.orders;
create trigger trg_void_kitchen_ticket_on_cancel
  before update on public.orders
  for each row
  execute function public.void_kitchen_ticket_on_cancel();

create or replace function public.close_table_with_history(
  p_seller_id uuid,
  p_table_number integer,
  p_payment_method text default 'cash',
  p_payment_note text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_session_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_seller_id is distinct from auth.uid() then
    raise exception 'Yetki hatası: bu masayı kapatma yetkiniz yok.'
      using errcode = '42501';
  end if;
  update public.table_orders
  set status = 'archived',
      updated_at = timezone('utc', now())
  where seller_id = p_seller_id
    and table_number = p_table_number
    and status <> 'archived';
end;
$$;

create or replace function public.close_table_orders(
  p_seller_id uuid,
  p_table_number integer,
  p_payment_method text default 'cash',
  p_payment_note text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_session_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is distinct from p_seller_id
     and not exists (
       select 1
       from public.store_sub_admins sa
       join public.users u on u.id = auth.uid()
       where sa.store_id = p_seller_id
         and sa.status = 'active'
         and (
           (
             sa.email is not null
             and btrim(sa.email) <> ''
             and lower(btrim(coalesce(u.email, ''))) = lower(btrim(sa.email))
           )
           or (
             sa.phone is not null
             and btrim(sa.phone) <> ''
             and btrim(coalesce(u.phone, '')) = btrim(sa.phone)
           )
         )
         and (
           cardinality(coalesce(sa.permissions, '{}'::text[])) = 0
           or 'viewOrders' = any(sa.permissions)
           or 'manageOrders' = any(sa.permissions)
         )
     )
  then
    raise exception 'Yetkisiz işlem.' using errcode = '42501';
  end if;

  update public.table_orders
  set status = 'archived',
      updated_at = timezone('utc', now())
  where seller_id = p_seller_id
    and table_number = p_table_number
    and status <> 'archived';

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.close_table_orders_v2(
  p_seller_id uuid,
  p_table_number integer,
  p_payment_method text default 'cash',
  p_payment_note text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_session_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.close_table_orders(
    p_seller_id, p_table_number, p_payment_method, p_payment_note,
    p_waiter_id, p_waiter_name, p_session_key
  );
end;
$$;

create or replace function public.transfer_table_orders(
  p_seller_id uuid,
  p_from_table integer,
  p_to_table integer,
  p_transfer_type text default 'full',
  p_item_ids jsonb default '[]'::jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_seller_id is distinct from auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
  update public.table_orders
  set table_number = p_to_table,
      updated_at = timezone('utc', now())
  where seller_id = p_seller_id
    and table_number = p_from_table;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_job_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  insert into public.orders (
    user_id, order_number, status, order_status, restaurant_id, notes,
    order_type, delivery_type, total_amount
  )
  values (
    auth.uid(),
    'TBL-LIVE',
    'confirmed',
    'sent',
    p_restaurant_id,
    nullif(btrim(coalesce(p_notes, '')), ''),
    'table',
    'table',
    0
  )
  returning id into v_order_id;

  insert into public.print_jobs (
    restaurant_id, order_id, job_type, status, payload
  )
  values (
    p_restaurant_id,
    v_order_id,
    coalesce(nullif(btrim(coalesce(p_job_type, '')), ''), 'new_order'),
    'pending',
    jsonb_build_object('table_number', p_table_number, 'items', p_items)
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', 'TBL-LIVE',
    'print_job_ids', jsonb_build_array(v_job_id)
  );
end;
$$;

create or replace function public.approve_waiter_order_request(
  p_request_id uuid,
  p_edited_items jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.waiter_order_requests%rowtype;
  v_items jsonb;
  v_table_order_id uuid;
  v_print jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select * into v_req
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;
  if v_req.status <> 'pending_waiter_approval' then
    raise exception 'Bu istek onay için uygun değil.' using errcode = '22023';
  end if;

  v_items := coalesce(p_edited_items, v_req.items_draft);
  insert into public.table_orders (
    seller_id, table_number, items, status, placement_source
  )
  values (v_req.seller_id, v_req.table_number, v_items, 'new', 'customer')
  returning id into v_table_order_id;

  update public.waiter_order_requests
  set status = 'approved_converted',
      resulting_table_order_id = v_table_order_id
  where id = p_request_id;

  v_print := public.create_table_order_with_print_jobs(
    v_req.seller_id,
    v_req.table_number,
    v_items,
    auth.uid(),
    'Garson',
    format('waiter_request:%s', p_request_id::text),
    'new_order',
    'table'
  );

  update public.table_orders
  set status = 'sent'
  where id = v_table_order_id;

  return jsonb_build_object(
    'request_id', p_request_id,
    'table_order_id', v_table_order_id,
    'print_result', v_print
  );
end;
$$;

create or replace function public.reject_waiter_order_request(
  p_request_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  update public.waiter_order_requests
  set status = 'rejected'
  where id = p_request_id
    and status = 'pending_waiter_approval';
  return jsonb_build_object('request_id', p_request_id, 'status', 'rejected');
end;
$$;

insert into public.production_guard_baseline (name, definition)
values (
  'guard_table_payment',
  pg_get_functiondef('public.guard_table_payment()'::regprocedure)
);

insert into public.users (id, email, phone) values
  ('11111111-1111-4111-8111-111111111111', 'owner@ibul.test', null),
  ('22222222-2222-4222-8222-222222222222', 'manager@ibul.test', null),
  ('33333333-3333-4333-8333-333333333333', 'full@ibul.test', null),
  ('44444444-4444-4444-8444-444444444444', 'view@ibul.test', null),
  ('55555555-5555-4555-8555-555555555555', 'empty@ibul.test', null),
  ('66666666-6666-4666-8666-666666666666', 'invited@ibul.test', null),
  ('77777777-7777-4777-8777-777777777777', 'other@ibul.test', null);

insert into public.store_sub_admins (store_id, email, permissions, status) values
  ('11111111-1111-4111-8111-111111111111', 'manager@ibul.test', array['manageOrders'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'full@ibul.test', array['fullAccess'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'view@ibul.test', array['viewOrders'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'empty@ibul.test', '{}'::text[], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'invited@ibul.test', array['manageOrders'], 'invited'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'other@ibul.test', array['manageOrders'], 'active');

insert into public.table_orders (seller_id, table_number, items, status)
select
  '11111111-1111-4111-8111-111111111111',
  n,
  '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
  'sent'
from generate_series(1, 12) as n;

insert into public.table_orders (seller_id, table_number, items, status)
values (
  '11111111-1111-4111-8111-111111111111',
  20,
  '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
  'sent'
);

insert into public.waiter_order_requests (
  id, seller_id, table_number, items_draft, customer_notes, status, created_by
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  '11111111-1111-4111-8111-111111111111',
  30,
  '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
  'az tuzlu',
  'pending_waiter_approval',
  '11111111-1111-4111-8111-111111111111'
);

commit;
