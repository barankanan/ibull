-- Isolated timing for create_table_order_with_print_jobs.
do $$ begin
  create role anon;
exception when duplicate_object then null;
end $$;
do $$ begin
  create role authenticated;
exception when duplicate_object then null;
end $$;
-- The function body is loaded from the local migration before this file runs.
-- These timings are local database time, not internet latency.
-- Not a production connection.

create schema if not exists auth;
create or replace function auth.uid()
returns uuid language sql as $$
  select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
$$;

create or replace function public.restaurant_has_permission(uuid, text)
returns boolean language sql as $$ select true $$;

create or replace function public.restaurant_table_access(uuid, uuid)
returns boolean language sql as $$ select true $$;

create table public.stores (
  seller_id uuid primary key,
  business_name text
);
create table public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid,
  table_number integer,
  is_active boolean default true,
  display_label text,
  table_name text,
  area_name text,
  area_table_number integer,
  created_at timestamptz default now()
);
create table public.stations (
  id uuid primary key,
  restaurant_id uuid,
  is_active boolean,
  name text,
  code text
);
create table public.station_printers (
  station_id uuid,
  printer_id uuid,
  is_primary boolean,
  created_at timestamptz
);
create table public.printers (
  id uuid primary key,
  restaurant_id uuid,
  is_active boolean,
  name text,
  code text,
  connection_type text,
  ip_address text,
  port integer,
  device_identifier text,
  paper_width_mm integer,
  print_size text
);
create table public.users (id uuid primary key);
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  order_number text,
  status text,
  payment_method text,
  delivery_type text,
  subtotal_amount numeric,
  shipping_amount numeric,
  discount_amount numeric,
  total_amount numeric,
  currency text,
  restaurant_id uuid,
  table_id uuid,
  waiter_id uuid,
  order_status text,
  order_type text,
  notes text,
  local_order_id text,
  created_at timestamptz default now()
);
create unique index orders_local_key
  on public.orders (restaurant_id, local_order_id);
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  product_id text,
  product_name text,
  quantity integer,
  item_note text,
  unit_price numeric,
  station_id uuid,
  attributes jsonb,
  created_at timestamptz default now()
);
create table public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid,
  order_id uuid,
  station_id uuid,
  printer_id uuid,
  job_type text,
  status text,
  order_saved_at timestamptz,
  print_job_created_at timestamptz,
  payload jsonb,
  created_at timestamptz default now()
);
create table public.restaurant_daily_order_counters (
  restaurant_id uuid,
  order_date date,
  last_no integer,
  updated_at timestamptz,
  primary key (restaurant_id, order_date)
);
create table public.restaurant_print_station_configs (
  restaurant_id uuid primary key,
  print_system_enabled boolean
);
create table public.bench (
  item_count integer,
  total_ms numeric,
  queue_ms numeric
);

insert into public.users values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
insert into public.stores values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ölçüm'
);
insert into public.store_tables (seller_id, table_number, table_name)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'Masa 1');

-- LOAD FUNCTION ABOVE THIS LINE WHEN CONCATENATING.
-- MEASURE
do $$
declare
  seller uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  sizes int[] := array[1, 10, 30, 60];
  size int;
  run int;
  items jsonb;
  started timestamptz;
  result jsonb;
  i int;
begin
  foreach size in array sizes loop
    for run in 1..7 loop
      items := '[]'::jsonb;
      for i in 1..size loop
        items := items || jsonb_build_array(jsonb_build_object(
          'product_id', 'p' || i::text,
          'name', 'Ürün ' || i::text,
          'quantity', 1,
          'price', 10
        ));
      end loop;
      started := clock_timestamp();
      result := public.create_table_order_with_print_jobs(
        seller, 1, items, null, 'Garson', null, 'new_order', 'table',
        'bench-' || size::text || '-' || run::text
      );
      insert into public.bench values (
        size,
        round(extract(epoch from clock_timestamp() - started) * 1000, 3),
        round(extract(epoch from
          (result->>'print_job_created_at')::timestamptz
          - (result->>'order_saved_at')::timestamptz) * 1000, 3)
      );
      if coalesce((result->>'print_job_count')::int, 0) <> 1 then
        raise exception 'print queue count was %', result->>'print_job_count';
      end if;
    end loop;
  end loop;

  result := public.create_table_order_with_print_jobs(
    seller, 1,
    '[{"product_id":"p1","name":"Ürün","quantity":1,"price":10}]'::jsonb,
    null, 'Garson', null, 'new_order', 'table', 'bench-1-1'
  );
  if coalesce((result->>'idempotent_replay')::boolean, false) is not true then
    raise exception 'same key did not replay';
  end if;
  if (select count(*) from public.orders where local_order_id = 'bench-1-1') <> 1 then
    raise exception 'same key created a second order';
  end if;
  if (select count(*) from public.print_jobs pj
      join public.orders o on o.id = pj.order_id
      where o.local_order_id = 'bench-1-1') <> 1 then
    raise exception 'same key created a second print job';
  end if;
end $$;

select item_count,
       round(percentile_cont(0.50) within group (order by total_ms)::numeric, 3) as p50_ms,
       round(percentile_cont(0.95) within group (order by total_ms)::numeric, 3) as p95_ms,
       round(max(total_ms), 3) as max_ms,
       round(percentile_cont(0.50) within group (order by queue_ms)::numeric, 3) as queue_p50_ms,
       round(max(queue_ms), 3) as queue_max_ms
from public.bench
group by item_count
order by item_count;
