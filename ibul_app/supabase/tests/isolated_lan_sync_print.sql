-- Isolated PostgreSQL proof for order replay, content conflict and print evidence.
-- Not a production connection. No physical printer.

do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;

create schema if not exists auth;
create schema if not exists extensions;
create extension if not exists pgcrypto;
create or replace function extensions.digest(bytea, text)
returns bytea language sql as $$ select public.digest($1, $2) $$;

create or replace function auth.uid()
returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::json->>'sub',
    nullif(current_setting('ibul.test_uid', true), '')
  )::uuid
$$;

create table if not exists public.test_flags (
  name text primary key,
  ok boolean not null
);
insert into public.test_flags values ('permission', true), ('table', true)
on conflict (name) do update set ok = excluded.ok;

create table if not exists public.store_branches (
  id uuid primary key,
  store_id uuid not null,
  status text not null,
  name text,
  is_primary boolean not null default false,
  created_at timestamptz default now()
);
create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  status text not null,
  permissions text[] not null default '{}',
  auth_user_id uuid,
  branch_id uuid
);

create table if not exists public.stores (
  seller_id uuid primary key,
  business_name text
);
create table if not exists public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid,
  table_number integer,
  is_active boolean default true,
  display_label text,
  table_name text,
  area_name text,
  area_table_number integer,
  branch_id uuid,
  created_at timestamptz default now()
);

create or replace function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable as $$
  select coalesce((select ok from public.test_flags where name = 'permission'), false)
    and auth.uid() is not null
    and (
      exists (
        select 1 from public.stores
        where seller_id = p_restaurant_id and seller_id = auth.uid()
      )
      or exists (
        select 1 from public.store_sub_admins sa
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and sa.auth_user_id = auth.uid()
          and (p_permission is null or p_permission = any(sa.permissions))
          and (
            sa.branch_id is null
            or exists (
              select 1 from public.store_branches b
              where b.id = sa.branch_id
                and b.store_id = sa.store_id
                and b.status = 'active'
            )
          )
      )
    )
$$;

create or replace function public.restaurant_table_access(p_restaurant_id uuid, p_table_id uuid)
returns boolean language sql stable as $$
  select coalesce((select ok from public.test_flags where name = 'table'), false)
    and (
      auth.uid() = p_restaurant_id
      or exists (
        select 1
        from public.store_sub_admins sa
        join public.store_tables t on t.id = p_table_id
          and t.seller_id = sa.store_id
          and t.is_active
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and sa.auth_user_id = auth.uid()
          and (
            sa.branch_id is null
            or (
              t.branch_id = sa.branch_id
              and exists (
                select 1 from public.store_branches b
                where b.id = sa.branch_id
                  and b.store_id = sa.store_id
                  and b.status = 'active'
              )
            )
          )
      )
    )
$$;
create table if not exists public.stations (
  id uuid primary key,
  restaurant_id uuid,
  is_active boolean,
  name text,
  code text
);
create table if not exists public.station_printers (
  station_id uuid,
  printer_id uuid,
  is_primary boolean,
  created_at timestamptz
);
create table if not exists public.printers (
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
create table if not exists public.users (id uuid primary key);
create table if not exists public.orders (
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
create unique index if not exists orders_local_key
  on public.orders (restaurant_id, local_order_id);
create table if not exists public.order_items (
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
create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid,
  order_id uuid,
  station_id uuid,
  printer_id uuid,
  job_type text,
  status text,
  last_error text,
  order_saved_at timestamptz,
  print_job_created_at timestamptz,
  payload jsonb,
  created_at timestamptz default now()
);
create table if not exists public.restaurant_daily_order_counters (
  restaurant_id uuid,
  order_date date,
  last_no integer,
  updated_at timestamptz,
  primary key (restaurant_id, order_date)
);
create table if not exists public.restaurant_print_station_configs (
  restaurant_id uuid primary key,
  print_system_enabled boolean
);

insert into public.users values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc')
on conflict do nothing;
insert into public.stores values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ölçüm'
) on conflict do nothing;
insert into public.store_branches values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'active'),
  ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'active')
on conflict (id) do nothing;
insert into public.store_tables (seller_id, table_number, table_name, branch_id)
select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'Masa 1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
where not exists (
  select 1 from public.store_tables
  where seller_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and table_number = 1
);
update public.store_tables
set branch_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
where seller_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and table_number = 1;
insert into public.store_tables (seller_id, table_number, table_name, branch_id)
select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 2, 'Masa 2',
  '99999999-9999-9999-9999-999999999999'
where not exists (
  select 1 from public.store_tables
  where seller_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and table_number = 2
);
insert into public.store_sub_admins (store_id, status, permissions, auth_user_id, branch_id)
select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'active', array['manageOrders'],
  'cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
where not exists (
  select 1 from public.store_sub_admins
  where auth_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
);
insert into public.stations values
  ('11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 'Ocak', 'OCAK'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 'Fırın', 'FIRIN'),
  ('33333333-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 'Kasap', 'KASAP')
on conflict do nothing;

-- LOAD FUNCTIONS ABOVE THIS LINE WHEN CONCATENATING.
