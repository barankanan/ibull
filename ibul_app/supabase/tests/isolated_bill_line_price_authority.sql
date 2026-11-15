-- Throwaway database only. Does not connect to supabase.co.
-- Proves a waiter cannot store a client price, a paid line cannot change,
-- a delete is audited, and a bill cannot fall under money already taken.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table if not exists public.stores (seller_id uuid primary key);
create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  auth_user_id uuid,
  status text not null,
  permissions text[] not null default '{}'::text[]
);
create table if not exists public.products (
  id text primary key,
  seller_id uuid not null,
  price double precision,
  discount_price double precision
);
create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null
);
create table if not exists public.orders (
  id uuid primary key,
  restaurant_id uuid,
  table_id uuid,
  order_type text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  seller_id uuid,
  product_id text,
  product_name text,
  quantity integer,
  unit_price numeric,
  total_price numeric,
  line_total numeric,
  attributes jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);
create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null default '',
  amount numeric not null,
  created_at timestamptz not null default timezone('utc', now())
);
create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'open',
  created_at timestamptz not null default timezone('utc', now())
);

create or replace function public.restaurant_has_permission(
  p_restaurant_id uuid,
  p_permission text
) returns boolean
language sql stable security definer set search_path = public
as $$
  select auth.uid() = p_restaurant_id
    or exists (
      select 1 from public.store_sub_admins sa
      where sa.store_id = p_restaurant_id
        and sa.auth_user_id = auth.uid()
        and sa.status = 'active'
        and p_permission = any(sa.permissions)
    );
$$;

\ir ../migrations/20261112234500_bill_line_price_authority.sql

insert into public.stores(seller_id) values ('11111111-1111-1111-1111-111111111111');
insert into public.store_sub_admins(id, store_id, auth_user_id, status, permissions)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  '33333333-3333-3333-3333-333333333333',
  'active',
  array['manageOrders','viewOrders']
);
insert into public.products(id, seller_id, price, discount_price)
values ('cay', '11111111-1111-1111-1111-111111111111', 40, 0);
insert into public.store_tables(id, seller_id, table_number)
values ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 7);
insert into public.orders(id, restaurant_id, table_id, order_type, created_at, updated_at)
values (
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  '44444444-4444-4444-4444-444444444444',
  'table',
  timezone('utc', now()) - interval '5 minutes',
  timezone('utc', now()) - interval '1 minute'
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.order_items(id, order_id, seller_id, product_id, product_name, quantity, unit_price, line_total)
values (
  '66666666-6666-6666-6666-666666666666',
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'cay', 'Çay', 1, 40, 40
);
insert into public.order_items(id, order_id, seller_id, product_id, product_name, quantity, unit_price, line_total)
values (
  '77777777-7777-7777-7777-777777777777',
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'cay', 'Çay', 1, 40, 70
);

select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$
begin
  update public.order_items
  set unit_price = 1, line_total = 1
  where id = '66666666-6666-6666-6666-666666666666';
  raise exception 'waiter price forgery was accepted';
exception
  when insufficient_privilege then
    if sqlerrm not like '%Fiyat değiştirme yetkiniz yok%' then
      raise;
    end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.order_items
set unit_price = 55, line_total = 55
where id = '66666666-6666-6666-6666-666666666666';

insert into public.table_payments(seller_id, table_number, amount, created_at)
values (
  '11111111-1111-1111-1111-111111111111',
  7,
  100,
  timezone('utc', now()) - interval '1 minute'
);
do $$
begin
  delete from public.order_items where id = '77777777-7777-7777-7777-777777777777';
  raise exception 'bill fell under collected payment';
exception
  when raise_exception then
    if sqlerrm not like '%alınmış ödemenin altında%' then
      raise;
    end if;
end $$;
delete from public.table_payments
where seller_id = '11111111-1111-1111-1111-111111111111';

update public.order_items
set attributes = '{"payment_status":"paid"}'::jsonb
where id = '77777777-7777-7777-7777-777777777777';
do $$
begin
  update public.order_items
  set quantity = 2
  where id = '77777777-7777-7777-7777-777777777777';
  raise exception 'paid line change was accepted';
exception
  when insufficient_privilege then
    if sqlerrm not like '%Ödemesi alınmış kalem%' then
      raise;
    end if;
end $$;

do $$
declare
  v_stamp timestamptz;
begin
  select updated_at into v_stamp
  from public.orders
  where id = '55555555-5555-5555-5555-555555555555';
  perform set_config('ibul.bill_base_updated_at', (v_stamp - interval '1 hour')::text, true);
  begin
    update public.order_items
    set quantity = 2, line_total = 80
    where id = '66666666-6666-6666-6666-666666666666';
    raise exception 'stale revision was accepted';
  exception
    when serialization_failure then
      null;
  end;
  perform set_config('ibul.bill_base_updated_at', '', true);
end $$;

delete from public.order_items
where id = '66666666-6666-6666-6666-666666666666';

do $$
declare
  v_audit integer;
begin
  if exists (
    select 1 from public.order_items
    where id = '66666666-6666-6666-6666-666666666666'
  ) then
    raise exception 'unpaid line was not deleted';
  end if;
  if not exists (
    select 1 from public.order_items
    where id = '77777777-7777-7777-7777-777777777777'
      and unit_price = 40
  ) then
    raise exception 'protected line was deleted or repriced';
  end if;
  select count(*) into v_audit
  from public.restaurant_order_line_audit
  where order_id = '55555555-5555-5555-5555-555555555555'
    and action = 'delete';
  if v_audit < 1 then
    raise exception 'delete was not audited';
  end if;
  select count(*) into v_audit
  from public.restaurant_order_line_audit
  where order_item_id = '66666666-6666-6666-6666-666666666666'
    and action = 'price_change';
  if v_audit < 1 then
    raise exception 'price change was not audited';
  end if;
end $$;

-- Attack: line_total cannot undercut unit_price * quantity.
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
update public.order_items
set line_total = 1, total_price = 1
where id = '77777777-7777-7777-7777-777777777777';
do $$
declare
  v_line numeric;
begin
  select line_total into v_line
  from public.order_items
  where id = '77777777-7777-7777-7777-777777777777';
  if v_line is distinct from 40 then
    raise exception 'forged line_total stuck, saw %', v_line;
  end if;
end $$;

-- Attack: clearing the paid mark is rejected, so a later price edit cannot slip through.
do $$
begin
  update public.order_items
  set attributes = '{}'::jsonb
  where id = '77777777-7777-7777-7777-777777777777';
  raise exception 'paid flag was cleared';
exception
  when insufficient_privilege then
    if sqlerrm not like '%Ödemesi alınmış kalem%' then
      raise;
    end if;
end $$;

-- Attack: retyping the order does not open a price bypass.
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
do $$
begin
  update public.orders
  set order_type = 'delivery'
  where id = '55555555-5555-5555-5555-555555555555';
  raise exception 'table order was retyped';
exception
  when insufficient_privilege then
    if sqlerrm not like '%tipi değiştirilemez%' then
      raise;
    end if;
end $$;

-- Attack: a signed-in stranger cannot change quantity.
select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999999', false);
do $$
begin
  update public.order_items
  set quantity = 3
  where id = '77777777-7777-7777-7777-777777777777';
  raise exception 'stranger quantity change was accepted';
exception
  when insufficient_privilege then
    if sqlerrm not like '%sipariş güncelleme yetkiniz yok%' then
      raise;
    end if;
end $$;

-- Historical non-catalog unit price can still change quantity.
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.order_items(
  id, order_id, seller_id, product_id, product_name, quantity, unit_price, line_total
) values (
  '88888888-8888-8888-8888-888888888888',
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'cay', 'Çay', 1, 40, 40
);
update public.order_items
set unit_price = 55, line_total = 1
where id = '88888888-8888-8888-8888-888888888888';
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
update public.order_items
set quantity = 2
where id = '88888888-8888-8888-8888-888888888888';
do $$
declare
  v_qty integer;
  v_price numeric;
  v_line numeric;
begin
  select quantity, unit_price, line_total
    into v_qty, v_price, v_line
  from public.order_items
  where id = '88888888-8888-8888-8888-888888888888';
  if v_qty is distinct from 2 or v_price is distinct from 55 or v_line is distinct from 110 then
    raise exception 'historical price quantity edit failed: % % %', v_qty, v_price, v_line;
  end if;
end $$;

-- INSERT: catalog price is accepted and the line total is computed on the server.
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
insert into public.order_items(
  id, order_id, seller_id, product_id, product_name, quantity, unit_price, line_total
) values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'cay', 'Çay', 3, 40, 1
);
do $$
declare
  v_line numeric;
begin
  select line_total into v_line
  from public.order_items
  where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  if v_line is distinct from 120 then
    raise exception 'catalog insert total was not recomputed, saw %', v_line;
  end if;
end $$;

-- INSERT: a copied historical price is not a license to create a new forged line.
do $$
begin
  insert into public.order_items(
    id, order_id, seller_id, product_id, product_name, quantity, unit_price, line_total
  ) values (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '55555555-5555-5555-5555-555555555555',
    '11111111-1111-1111-1111-111111111111',
    'cay', 'Çay', 1, 55, 55
  );
  raise exception 'forged insert was accepted';
exception
  when insufficient_privilege then
    if sqlerrm not like '%Fiyat değiştirme yetkiniz yok%' then
      raise;
    end if;
end $$;

-- A partial paid_amount locks the line even when payment_status is empty.
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.order_items
set attributes = '{"paid_amount":"10"}'::jsonb
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$
begin
  update public.order_items
  set quantity = 4
  where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'partially paid line was changed';
exception
  when insufficient_privilege then
    if sqlerrm not like '%Ödemesi alınmış kalem%' then
      raise;
    end if;
end $$;
