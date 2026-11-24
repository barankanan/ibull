-- Setup for run_isolated_table_order_totals_risks.sh. THROWAWAY PostgreSQL only.
-- Adds the production columns, tables and triggers the base isolated schema
-- does not carry. Function bodies are loaded by the runner from the repo
-- files and checked byte for byte (md5) against production.
\set ON_ERROR_STOP on

alter table public.orders add column if not exists updated_at timestamptz default now();
alter table public.orders add column if not exists is_test boolean;
alter table public.orders add column if not exists customer_delivery_fee numeric;
alter table public.orders add column if not exists seller_delivery_fee numeric;
alter table public.orders add column if not exists total_delivery_fee numeric not null default 0;
alter table public.order_items add column if not exists seller_id uuid;
alter table public.order_items add column if not exists total_price numeric not null default 0;
alter table public.order_items add column if not exists line_total numeric;
alter table public.order_items add column if not exists status text not null default 'new';
alter table public.order_items add column if not exists kitchen_status text not null default 'pending';
alter table public.order_items add column if not exists sent_to_kitchen_at timestamptz;
alter table public.order_items add column if not exists updated_at timestamptz default now();

-- production: table_orders.seller_id is text
alter table public.table_orders alter column seller_id type text using seller_id::text;
alter table public.table_orders add column if not exists revision integer;
alter table public.table_orders add column if not exists updated_at timestamptz;
alter table public.table_orders add column if not exists last_edit_summary jsonb;
alter table public.table_orders add column if not exists last_edit_note text;

create table if not exists public.table_order_history (
  id uuid primary key default gen_random_uuid(), original_order_id uuid,
  seller_id uuid not null, table_number integer, items jsonb default '[]'::jsonb,
  status text not null default 'closed', revision integer, last_edit_summary jsonb,
  last_edit_note text, payment_method text, payment_note text, waiter_id uuid,
  waiter_name text, grand_total numeric, session_key text, opened_at timestamptz,
  closed_at timestamptz default now(), created_at timestamptz default now(),
  table_name text, display_table_label text, table_display_name text,
  table_area_name text, archived_at timestamptz, archived_orders jsonb
);
create table if not exists public.products (id text primary key, seller_id uuid);
insert into public.products values
  ('p1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), ('p2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
on conflict do nothing;

alter table auth.users add column if not exists raw_app_meta_data jsonb default '{}'::jsonb;
alter table auth.users add column if not exists email_confirmed_at timestamptz;
alter table auth.users add column if not exists phone text;
alter table auth.users add column if not exists phone_confirmed_at timestamptz;
alter table public.users add column if not exists email text;
alter table public.users add column if not exists phone text;
alter table public.store_sub_admins add column if not exists email text;
alter table public.store_sub_admins add column if not exists phone text;

-- staff c…: manageOrders + closeBill on branch a… (table 1); staff d…: no order permission
insert into auth.users (id, email, raw_app_meta_data) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'staff@example.test', '{"managed_restaurant_staff":"true"}'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'noperm@example.test', '{"managed_restaurant_staff":"true"}')
on conflict (id) do update set raw_app_meta_data = excluded.raw_app_meta_data;
insert into public.users (id) values ('dddddddd-dddd-dddd-dddd-dddddddddddd') on conflict do nothing;
update public.store_sub_admins set permissions = array['manageOrders','closeBill']
 where auth_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
insert into public.store_sub_admins (store_id, status, permissions, auth_user_id, branch_id)
select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'active', array['viewReports'],
       'dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
where not exists (select 1 from public.store_sub_admins where auth_user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd');

-- Stand-ins (NOT production bodies; logic noted in the report):
create or replace function public.staff_must_change_password() returns boolean
language sql stable as $$ select false $$;
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_table_number integer)
returns boolean language sql stable as $$
  select public.restaurant_table_access(p_restaurant_id,
    (select id from public.store_tables where seller_id = p_restaurant_id and table_number = p_table_number limit 1)) $$;
create or replace function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
create or replace function auth.role() returns text language sql stable as $$ select 'authenticated'::text $$;
create or replace function public.is_admin_user(p uuid) returns boolean language sql stable as $$ select false $$;
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
