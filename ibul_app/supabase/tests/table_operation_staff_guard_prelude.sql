-- Isolated legacy close/transfer functions for the staff-guard migration.
-- Not for production. The runner applies this before the migration.

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
  updated_at timestamptz
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

-- Owner-only archive. An authorized waiter must pass only after the wrapper
-- impersonates the owner for this legacy guard.
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

-- Loose close: active membership, including view-only and an empty grant,
-- is enough. The wrapper must reject those callers before this body runs.
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
    p_seller_id,
    p_table_number,
    p_payment_method,
    p_payment_note,
    p_waiter_id,
    p_waiter_name,
    p_session_key
  );
end;
$$;

-- Owner-only transfer. The client used to move every row when this raised.
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
  if p_from_table = p_to_table then
    raise exception 'Kaynak ve hedef masa aynı olamaz.';
  end if;
  update public.table_orders
  set table_number = p_to_table,
      updated_at = timezone('utc', now())
  where seller_id = p_seller_id
    and table_number = p_from_table;
  return jsonb_build_object('success', true);
end;
$$;

grant execute on function public.close_table_with_history(
  uuid, integer, text, text, uuid, text, text
) to authenticated, anon, service_role;
grant execute on function public.close_table_orders(
  uuid, integer, text, text, uuid, text, text
) to authenticated, anon, service_role;
grant execute on function public.close_table_orders_v2(
  uuid, integer, text, text, uuid, text, text
) to authenticated, anon, service_role;
grant execute on function public.transfer_table_orders(
  uuid, integer, integer, text, jsonb, uuid, text, text
) to authenticated, anon, service_role;

insert into public.users (id, email, phone) values
  ('11111111-1111-1111-1111-111111111111', 'owner@ibul.test', null),
  ('22222222-2222-2222-2222-222222222222', 'manager@ibul.test', null),
  ('33333333-3333-3333-3333-333333333333', 'full@ibul.test', null),
  ('44444444-4444-4444-4444-444444444444', 'view@ibul.test', null),
  ('55555555-5555-5555-5555-555555555555', 'empty@ibul.test', null),
  ('66666666-6666-6666-6666-666666666666', 'invited@ibul.test', null),
  ('77777777-7777-7777-7777-777777777777', 'other@ibul.test', null),
  ('88888888-8888-8888-8888-888888888888', null, '5550001111'),
  ('99999999-9999-9999-9999-999999999999', 'tam@ibul.test', null);

insert into public.store_sub_admins (store_id, email, phone, permissions, status) values
  ('11111111-1111-1111-1111-111111111111', 'manager@ibul.test', null, array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'full@ibul.test', null, array['fullAccess'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'view@ibul.test', null, array['viewOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'empty@ibul.test', null, '{}'::text[], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'invited@ibul.test', null, array['manageOrders'], 'invited'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'other@ibul.test', null, array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', null, '5550001111', array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'tam@ibul.test', null, array['Tam Erişim'], 'active');

insert into public.table_orders (seller_id, table_number, items, status)
select '11111111-1111-1111-1111-111111111111', n, '[{"name":"corba","price":40,"quantity":1}]'::jsonb, 'sent'
from generate_series(1, 20) as n;

commit;
