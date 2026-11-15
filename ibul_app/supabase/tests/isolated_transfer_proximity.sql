-- Isolated check for the unapplied transfer and customer-order migrations.
-- Creates its own objects, applies the two migration files, then asserts.
-- Not a production connection.

create extension if not exists pgcrypto;
create schema if not exists extensions;
create or replace function extensions.digest(payload bytea, algorithm text)
returns bytea
language sql
immutable
as $$ select public.digest(payload, algorithm) $$;

create or replace function public.restaurant_staff_may_operate(
  p_restaurant_id uuid,
  p_permission text,
  p_table_number integer
) returns void
language plpgsql as $$
begin
  if p_permission is distinct from 'transferTable' then
    raise exception 'wrong permission';
  end if;
end $$;

create or replace function public.restaurant_has_permission(
  p_restaurant_id uuid,
  p_permission text
) returns boolean
language sql as $$ select true $$;

create or replace function public.is_managed_restaurant_staff()
returns boolean
language sql as $$ select true $$;

create schema if not exists auth;
create or replace function auth.uid()
returns uuid
language sql
as $$ select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid $$;

create or replace function public.restaurant_table_number_access(
  p_restaurant_id uuid,
  p_table_number integer
) returns boolean
language sql as $$ select true $$;

create or replace function public.guard_restaurant_staff_order_write()
returns trigger
language plpgsql as $$
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;
  raise exception 'blocked';
end $$;

create table if not exists public.stores (
  seller_id uuid primary key,
  store_lat double precision,
  store_lng double precision
);

create table if not exists public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  branch_id uuid,
  is_active boolean default true,
  qr_token text
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id text not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'new',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz,
  placement_source text,
  last_edit_summary jsonb
);

create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  amount numeric not null,
  session_key text
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
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.products (
  id text primary key,
  seller_id uuid not null,
  name text not null,
  price double precision,
  status text,
  approval_status text,
  base_price numeric,
  portion_price numeric,
  price_per_kg numeric,
  pricing_type text,
  service_control_type text,
  min_portion numeric,
  max_portion numeric,
  portion_step numeric,
  min_weight_grams integer,
  max_weight_grams integer,
  weight_step_grams integer,
  stock integer,
  size_options jsonb,
  variants jsonb
);

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
end $$;

drop trigger if exists restaurant_staff_write_guard on public.table_orders;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.table_orders
  for each row execute function public.guard_restaurant_staff_order_write();

\ir ../migrations/20261102194242_transfer_table_orders_text_seller.sql
\ir ../migrations/20261102194243_customer_table_proximity_order.sql

\set ON_ERROR_STOP on

create or replace function public.is_managed_restaurant_staff()
returns boolean language sql as $$ select false $$;

do $$
declare
  seller uuid := '11111111-1111-1111-1111-111111111111';
  branch uuid := '22222222-2222-2222-2222-222222222222';
  other_branch uuid := '33333333-3333-3333-3333-333333333333';
  result jsonb;
  moved int;
  pay_count int;
  pay_table int;
  pay_amount numeric;
begin
  perform set_config('ibul.customer_table_order', '1', true);
  insert into public.stores (seller_id, store_lat, store_lng)
  values (seller, 41.0082, 28.9784);
  insert into public.store_tables (seller_id, table_number, branch_id) values
    (seller, 1, branch),
    (seller, 2, branch),
    (seller, 3, other_branch);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (
    seller::text, 1,
    '[{"id":"a","name":"Çorba","price":10,"quantity":1}]'::jsonb,
    'sent'
  );
  insert into public.table_payments (seller_id, table_number, amount, session_key)
  values (seller, 1, 25, 's1');

  result := public.transfer_table_orders(
    seller, 1, 2, 'full', '[]'::jsonb, null, null, null
  );
  if coalesce((result->>'moved_count')::int, 0) <> 1 then
    raise exception 'transfer did not report one moved order: %', result;
  end if;
  select count(*) into moved
  from public.table_orders
  where seller_id = seller::text and table_number = 2 and status = 'sent';
  if moved <> 1 then
    raise exception 'text seller_id order was not moved';
  end if;
  select count(*), min(table_number), min(amount)
  into pay_count, pay_table, pay_amount
  from public.table_payments
  where seller_id = seller;
  if pay_count <> 1 or pay_table <> 2 or pay_amount <> 25 then
    raise exception 'payment row changed unexpectedly % % %', pay_count, pay_table, pay_amount;
  end if;

  begin
    perform public.transfer_table_orders(
      seller, 2, 3, 'full', '[]'::jsonb, null, null, null
    );
    raise exception 'cross-branch transfer was allowed';
  exception
    when others then
      if sqlerrm not like '%farklı şubede%' then
        raise;
      end if;
  end;
  if (select count(*) from public.table_orders where table_number = 2) <> 1 then
    raise exception 'cross-branch transfer moved the order';
  end if;

  begin
    perform public.transfer_table_orders(
      seller, 9, 2, 'full', '[]'::jsonb, null, null, null
    );
    raise exception 'missing source table was allowed';
  exception
    when others then
      if sqlerrm not like '%Kaynak masa%' then
        raise;
      end if;
  end;
end $$;

create or replace function public.is_managed_restaurant_staff()
returns boolean language sql as $$ select true $$;

do $$
declare
  seller uuid := '11111111-1111-1111-1111-111111111111';
  result jsonb;
  order_count int;
  started timestamptz;
  elapsed_ms int;
  items jsonb;
  i int;
  n int;
begin
  insert into public.products (
    id, seller_id, name, price, status, approval_status
  )
  select 'p' || g, seller, 'Ürün ' || g, 10, 'Aktif', 'approved'
  from generate_series(1, 60) g;

  begin
    insert into public.table_orders (seller_id, table_number, items, status)
    values (seller::text, 1, '[]'::jsonb, 'new');
    raise exception 'direct insert bypassed the staff guard';
  exception
    when others then
      if sqlerrm <> 'blocked' then
        raise;
      end if;
  end;

  result := public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-near', null
  );
  if result->>'id' is null then
    raise exception 'near order was not saved';
  end if;

  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      41.0200, 28.9784, 10, 'order', 'req-far', null
    );
    raise exception 'order outside 100 metres was saved';
  exception
    when others then
      if sqlerrm not like '%100 metre%' then
        raise;
      end if;
  end;

  result := public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":1,"quantity":1}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-price', null
  );
  if coalesce((result->>'needs_confirmation')::boolean, false) is not true then
    raise exception 'wrong price was accepted';
  end if;
  if (
    select count(*) from public.table_orders
    where last_edit_summary->>'client_request_id' = 'req-price'
  ) <> 0 then
    raise exception 'wrong price inserted an order';
  end if;

  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-near', null
  );
  select count(*) into order_count
  from public.table_orders
  where last_edit_summary->>'client_request_id' = 'req-near';
  if order_count <> 1 then
    raise exception 'idempotent replay created % orders', order_count;
  end if;

  perform public.place_customer_table_order(
    seller, 1, '[]'::jsonb, 41.0086, 28.9784, 10, 'waiter_call', 'call-1', null
  );
  perform public.place_customer_table_order(
    seller, 1, '[]'::jsonb, 41.0086, 28.9784, 10, 'waiter_call', 'call-2', null
  );
  select count(*) into order_count
  from public.table_orders
  where status = 'call_waiter' and table_number = 1;
  if order_count <> 1 then
    raise exception 'waiter call was not rate limited: %', order_count;
  end if;

  foreach n in array array[1, 10, 30, 60] loop
    items := '[]'::jsonb;
    for i in 1..n loop
      items := items || jsonb_build_array(jsonb_build_object(
        'productId', 'p' || i,
        'price', 10,
        'quantity', 1
      ));
    end loop;
    started := clock_timestamp();
    perform public.place_customer_table_order(
      seller, 2, items, 41.0086, 28.9784, 10, 'order', 'bench-' || n, null
    );
    elapsed_ms := (extract(epoch from clock_timestamp() - started) * 1000)::int;
    raise notice 'CUSTOMER_ORDER_ITEMS % ms %', n, elapsed_ms;
  end loop;

  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1,"selectedSizeName":"Yok"}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-cheap-size', null
    );
    raise exception 'unknown size was accepted';
  exception
    when others then
      if sqlerrm not like '%Boyut%' then
        raise;
      end if;
  end;

  update public.products
  set size_options = '[{"id":"lg","name":"Büyük","price":18}]'::jsonb
  where id = 'p1';
  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":18,"quantity":1,"selectedSizeName":"Büyük"}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-size', null
  );
  if (
    select (o.items->0->>'price')::numeric
    from public.table_orders o
    where last_edit_summary->>'client_request_id' = 'req-size'
  ) <> 18 then
    raise exception 'stored price was not the server size price';
  end if;

  update public.products
  set price = 999, portion_price = 20
  where id = 'p2';
  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p2","price":10,"quantity":1,"selectedServiceAmount":0.5}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-portion', null
  );
  if (
    select (o.items->0->>'price')::numeric
    from public.table_orders o
    where last_edit_summary->>'client_request_id' = 'req-portion'
  ) <> 10 then
    raise exception 'half portion was not priced from portion_price';
  end if;

  update public.products
  set portion_price = null, price = 999, price_per_kg = 40,
      min_weight_grams = 250, weight_step_grams = 250
  where id = 'p3';
  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p3","price":10,"quantity":1,"selectedWeightGrams":250}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-weight', null
  );
  if (
    select (o.items->0->>'price')::numeric
    from public.table_orders o
    where last_edit_summary->>'client_request_id' = 'req-weight'
  ) <> 10 then
    raise exception 'weight price was not taken from price_per_kg';
  end if;

  update public.products
  set price_per_kg = null, price = null, portion_price = null
  where id = 'p4';
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p4","price":10,"quantity":1}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-missing-price', null
    );
    raise exception 'missing catalog price was accepted';
  exception
    when others then
      if sqlerrm not like '%katalogda yok%' then
        raise;
      end if;
  end;

  result := public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":1,"quantity":1}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-stale', null
  );
  if coalesce((result->>'needs_confirmation')::boolean, false) is not true then
    raise exception 'stale price was saved without confirmation';
  end if;
  if (
    select count(*) from public.table_orders
    where last_edit_summary->>'client_request_id' = 'req-stale'
  ) <> 0 then
    raise exception 'confirmation preview inserted an order';
  end if;
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":1,"quantity":2}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-stale', null, null, true, null,
      result->>'price_confirm_token'
    );
    raise exception 'changed quantity was confirmed with the old token';
  exception
    when others then
      if sqlerrm not like '%eşleşmiyor%' then
        raise;
      end if;
  end;
  if (
    select count(*) from public.table_orders
    where last_edit_summary->>'client_request_id' = 'req-stale'
  ) <> 0 then
    raise exception 'rejected confirmation inserted an order';
  end if;
  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":1,"quantity":1}]'::jsonb,
    41.0086, 28.9784, 10, 'order', 'req-stale', null, null, true, null,
    result->>'price_confirm_token'
  );
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":2}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-near', null
    );
    raise exception 'different payload reused a request id';
  exception
    when others then
      if sqlerrm not like '%başka bir siparişe ait%' then
        raise;
      end if;
  end;
  if (
    select count(*) from public.table_orders
    where last_edit_summary->>'client_request_id' = 'req-near'
  ) <> 1 then
    raise exception 'mismatched retry changed the saved order';
  end if;

  begin
    perform public.issue_customer_proximity_grant(seller, 1, 'session-1', false);
    raise exception 'unconfirmed staff grant was issued';
  exception
    when others then
      if sqlerrm not like '%gördüğünüz%' then
        raise;
      end if;
  end;

  result := public.issue_customer_proximity_grant(seller, 1, 'session-1234', true);
  if length(result->>'grant_code') <> 32 then
    raise exception 'grant code is too short';
  end if;
  begin
    perform public.place_customer_table_order(
      seller, 2,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      null, null, null, 'order', 'req-wrong-table',
      result->>'grant_code', 'session-1234'
    );
    raise exception 'grant worked on another table';
  exception
    when others then
      if sqlerrm not like '%onay kodu%' then
        raise;
      end if;
  end;
  perform public.place_customer_table_order(
    seller, 1,
    '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
    null, null, null, 'order', 'req-grant',
    result->>'grant_code', 'session-1234'
  );
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      null, null, null, 'order', 'req-grant-again',
      result->>'grant_code', 'session-1234'
    );
    raise exception 'grant was reused';
  exception
    when others then
      if sqlerrm not like '%onay kodu%' then
        raise;
      end if;
  end;

  result := public.issue_customer_proximity_grant(seller, 1, 'session-expire', true);
  update public.customer_proximity_grants
  set expires_at = timezone('utc', now()) - interval '1 minute'
  where grant_code = result->>'grant_code';
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      null, null, null, 'order', 'req-expired',
      result->>'grant_code', 'session-expire'
    );
    raise exception 'expired grant was accepted';
  exception
    when others then
      if sqlerrm not like '%onay kodu%' then
        raise;
      end if;
  end;

  update public.store_tables
  set qr_token = 'qr-table-1'
  where seller_id = seller and table_number = 1;
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-bad-qr',
      null, null, false, 'other-store-qr'
    );
    raise exception 'foreign qr was accepted';
  exception
    when others then
      if sqlerrm not like '%QR%' then
        raise;
      end if;
  end;

  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p1","price":10,"quantity":1}]'::jsonb,
      41.0086, 28.9784, 80, 'order', 'req-coarse', null
    );
    raise exception 'coarse location was accepted';
  exception
    when others then
      if sqlerrm not like '%Konum doğrulanamadı%' then
        raise;
      end if;
  end;

  update public.products set status = 'Taslak' where id = 'p5';
  begin
    perform public.place_customer_table_order(
      seller, 1,
      '[{"productId":"p5","price":10,"quantity":1}]'::jsonb,
      41.0086, 28.9784, 10, 'order', 'req-inactive', null
    );
    raise exception 'inactive product was accepted';
  exception
    when others then
      if sqlerrm not like '%satışı kapalı%' then
        raise;
      end if;
  end;

  begin
    perform set_config('ibul.customer_table_order', '1', true);
    delete from public.table_orders
    where last_edit_summary->>'client_request_id' = 'req-size';
    raise exception 'customer flag allowed a delete';
  exception
    when others then
      if sqlerrm <> 'blocked' then
        raise;
      end if;
  end;
end $$;
