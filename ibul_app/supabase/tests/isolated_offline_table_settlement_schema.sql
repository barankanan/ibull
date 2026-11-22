-- Throwaway database only. Does not connect to supabase.co.
-- Production-shaped stand-ins for the tables apply_offline_table_settlement
-- reads and writes. Column names, types, defaults and the local-order unique
-- index follow the live catalog as read on 2026-11-22. The live write-guard
-- triggers on orders / table_order_history are NOT reproduced here.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end $$;

create table public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  is_active boolean not null default true,
  branch_id uuid
);

create table public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  auth_user_id uuid,
  branch_id uuid,
  status text not null,
  permissions text[] not null default '{}'::text[]
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid,
  table_id uuid,
  order_type text default 'table',
  delivery_type text,
  status text default 'confirmed',
  order_status text,
  total_amount numeric default 0,
  local_order_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index idx_orders_restaurant_local_order
  on public.orders (restaurant_id, local_order_id)
  where local_order_id is not null;

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
  product_name text not null,
  quantity integer not null default 1,
  unit_price numeric not null default 0,
  total_price numeric not null default 0,
  line_total numeric,
  created_at timestamptz not null default now()
);

create table public.table_order_history (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid not null,
  seller_id uuid not null,
  table_number integer not null check (table_number > 0),
  items jsonb not null default '[]'::jsonb,
  status text not null default 'closed',
  revision integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb,
  payment_method text,
  payment_note text,
  waiter_id uuid,
  waiter_name text,
  grand_total numeric,
  session_key text,
  closed_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  archived_orders jsonb
);

grant usage on schema public to anon, authenticated, service_role;
