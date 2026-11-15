-- Throwaway database only. Realistic garson snapshot cost with RLS enabled.
-- Does not connect to supabase.co.

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'open',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  display_table_label text,
  area_name text
);
create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric not null,
  method text not null default 'cash',
  created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_table_orders_seller_status_table
  on public.table_orders (seller_id, status, table_number);
create index if not exists idx_table_payments_seller_table
  on public.table_payments (seller_id, table_number, created_at desc);

insert into public.table_orders (seller_id, table_number, items, status, display_table_label, area_name, created_at)
select
  'rest-load',
  (g % 80) + 1,
  jsonb_build_array(
    jsonb_build_object('name', 'Urun', 'quantity', 1, 'price', 40),
    jsonb_build_object('name', 'Icecek', 'quantity', 2, 'price', 15)
  ),
  case when g % 17 = 0 then 'closed' else 'sent' end,
  'Masa ' || ((g % 80) + 1)::text,
  'Salon',
  timezone('utc', now()) - ((g % 400) || ' minutes')::interval
from generate_series(1, 4000) g;

insert into public.table_payments (seller_id, table_number, session_key, amount, created_at)
select
  '11111111-1111-1111-1111-111111111111'::uuid,
  (g % 80) + 1,
  'session-' || g::text,
  25 + (g % 50),
  timezone('utc', now()) - ((g % 200) || ' minutes')::interval
from generate_series(1, 1500) g;

analyze public.table_orders;
analyze public.table_payments;

\echo '--- open table snapshot ---'
explain (analyze, buffers)
select id, seller_id, table_number, items, status, created_at, updated_at,
       display_table_label, area_name
from public.table_orders
where seller_id = 'rest-load'
  and status not in (
    'delivered','cancelled','canceled','closed','paid','completed','complete',
    'completed_payment','payment_completed','archived'
  )
order by created_at desc;

\echo '--- payments for one table ---'
explain (analyze, buffers)
select id, seller_id, table_number, session_key, amount, method, created_at
from public.table_payments
where seller_id = '11111111-1111-1111-1111-111111111111'::uuid
  and table_number = 4
order by created_at;
