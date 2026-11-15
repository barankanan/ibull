-- Isolated PostgreSQL 17 check for transfer_table_orders.
-- Not a production migration. Uses disposable local roles and rows.

create schema if not exists public;

create or replace function public.restaurant_staff_may_operate(
  p_restaurant_id uuid,
  p_permission text,
  p_table_number integer
) returns void
language plpgsql
as $$
begin
  return;
end;
$$;

create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  branch_id uuid,
  is_active boolean default true
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'new',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  placement_source text
);

create table if not exists public.orders (
  id uuid primary key,
  user_id uuid not null,
  status text not null,
  order_type text not null,
  delivery_type text,
  total_amount numeric not null,
  payment_status text,
  updated_at timestamptz not null default timezone('utc', now()),
  restaurant_id uuid,
  table_id uuid,
  order_status text
);

create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric not null,
  method text not null default 'cash',
  is_closing boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_transfers_log (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  from_table integer not null,
  to_table integer not null,
  transfer_type text not null,
  transferred_items jsonb not null,
  order_ids jsonb not null,
  waiter_id uuid,
  waiter_name text,
  note text
);

create or replace function public.orders_money_authority_guard()
returns trigger
language plpgsql
as $$
begin
  if current_setting('ibul.marketplace_order_rpc', true) = 'on' then
    if new.total_amount is distinct from old.total_amount
       or new.payment_status is distinct from old.payment_status
       or new.user_id is distinct from old.user_id then
      raise exception 'ORDER_MONEY_COLUMNS_LOCKED';
    end if;
    return new;
  end if;
  if new.table_id is distinct from old.table_id then
    raise exception 'ORDER_UPDATE_DENIED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_money_authority on public.orders;
create trigger trg_orders_money_authority
  before update on public.orders
  for each row
  execute function public.orders_money_authority_guard();

create or replace function public._fail_transfer_log()
returns trigger
language plpgsql
as $$
begin
  if new.note = 'fail-after-write' then
    raise exception 'log blocked';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_fail_transfer_log on public.table_transfers_log;
create trigger trg_fail_transfer_log
  before insert on public.table_transfers_log
  for each row
  execute function public._fail_transfer_log();
