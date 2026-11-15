-- Runs after isolated_close_table_history_order_id.sql and
-- 20261113210000_close_table_recent_history_lookup.sql on a throwaway
-- database. Ten real close_table_with_history calls. Not a microsecond harness.
\set ON_ERROR_STOP on

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  false
);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}',
  false
);

create temporary table close_stage_measure (
  table_number integer primary key,
  rpc_ms numeric not null,
  history_ms numeric not null,
  card_empty boolean not null,
  loading_clear boolean not null,
  occupied_before integer not null,
  occupied_after integer not null,
  history_rows integer not null,
  payments integer not null
);

do $$
declare
  i integer;
  seller uuid := '11111111-1111-1111-1111-111111111111';
  table_id uuid;
  order_id uuid;
  table_order_id uuid;
  payment_id uuid;
  started timestamptz;
  after_rpc timestamptz;
  after_history timestamptz;
  result jsonb;
  history_count integer;
  open_orders integer;
  payment_count integer;
  occupied integer;
begin
  for i in 11..20 loop
    table_id := (
      substr(md5('table-' || i::text), 1, 8) || '-' ||
      substr(md5('table-' || i::text), 9, 4) || '-' ||
      '4' || substr(md5('table-' || i::text), 14, 3) || '-' ||
      '8' || substr(md5('table-' || i::text), 18, 3) || '-' ||
      substr(md5('table-' || i::text), 21, 12)
    )::uuid;
    order_id := (
      substr(md5('order-' || i::text), 1, 8) || '-' ||
      substr(md5('order-' || i::text), 9, 4) || '-' ||
      '4' || substr(md5('order-' || i::text), 14, 3) || '-' ||
      '8' || substr(md5('order-' || i::text), 18, 3) || '-' ||
      substr(md5('order-' || i::text), 21, 12)
    )::uuid;
    table_order_id := (
      substr(md5('taborder-' || i::text), 1, 8) || '-' ||
      substr(md5('taborder-' || i::text), 9, 4) || '-' ||
      '4' || substr(md5('taborder-' || i::text), 14, 3) || '-' ||
      '8' || substr(md5('taborder-' || i::text), 18, 3) || '-' ||
      substr(md5('taborder-' || i::text), 21, 12)
    )::uuid;
    payment_id := (
      substr(md5('pay-' || i::text), 1, 8) || '-' ||
      substr(md5('pay-' || i::text), 9, 4) || '-' ||
      '4' || substr(md5('pay-' || i::text), 14, 3) || '-' ||
      '8' || substr(md5('pay-' || i::text), 18, 3) || '-' ||
      substr(md5('pay-' || i::text), 21, 12)
    )::uuid;

    insert into public.store_tables (id, seller_id, table_number)
    values (table_id, seller, i);
    insert into public.orders (
      id, restaurant_id, table_id, status, order_status, total_amount
    ) values (
      order_id, seller, table_id, 'confirmed', 'sent', 80 + i
    );
    insert into public.table_orders (
      id, seller_id, table_number, items, status
    ) values (
      table_order_id,
      seller::text,
      i,
      '[{"name":"Cay","price":"100","quantity":"1","line_total":"100"}]'::jsonb,
      'open'
    );
    insert into public.table_payments (
      id, seller_id, table_number, session_key, amount, method, is_closing
    ) values (
      payment_id, seller, i, 'pay-session-' || i::text, 15, 'cash', false
    );

    select count(*) into occupied
    from public.orders
    where restaurant_id = seller
      and coalesce(status, '') not in (
        'closed', 'paid', 'cancelled', 'canceled',
        'completed', 'complete', 'archived', 'payment_completed'
      );

    started := clock_timestamp();
    result := public.close_table_with_history(
      seller, i, 'cash', null, null, null, 'measure-' || i::text
    );
    after_rpc := clock_timestamp();

    select count(*) into history_count
    from public.table_order_history
    where seller_id = seller
      and table_number = i
      and original_order_id = order_id;
    after_history := clock_timestamp();

    select count(*) into open_orders
    from public.orders
    where id = order_id
      and coalesce(status, '') not in ('closed', 'paid', 'cancelled');
    select count(*) into payment_count
    from public.table_payments
    where id = payment_id and amount = 15;

    if result ->> 'history_id' is null or history_count <> 1 then
      raise exception 'FAIL close % missing history % %', i, result, history_count;
    end if;
    if open_orders <> 0 or payment_count <> 1 then
      raise exception 'FAIL close % orders=% payments=%', i, open_orders, payment_count;
    end if;

    insert into close_stage_measure values (
      i,
      round(extract(epoch from (after_rpc - started)) * 1000, 3),
      round(extract(epoch from (after_history - after_rpc)) * 1000, 3),
      open_orders = 0 and history_count = 1,
      open_orders = 0 and history_count = 1,
      occupied,
      occupied - 1,
      history_count,
      payment_count
    );
  end loop;
end $$;

do $$
declare
  seller uuid := '11111111-1111-1111-1111-111111111111';
  before_count integer;
  after_count integer;
  replay jsonb;
  payment_amount numeric;
begin
  select count(*) into before_count
  from public.table_order_history
  where table_number = 11;
  replay := public.close_table_with_history(
    seller, 11, 'card', null, null, null, 'lost-response-other-session'
  );
  select count(*) into after_count
  from public.table_order_history
  where table_number = 11;
  select amount into payment_amount
  from public.table_payments
  where table_number = 11;
  if after_count <> before_count
     or replay ->> 'history_id' is null
     or (replay ->> 'orders_updated')::int <> 0
     or payment_amount <> 15 then
    raise exception 'FAIL lost response replay % % %', replay, before_count, after_count;
  end if;
end $$;

-- A later transaction that rolls back cannot remove the committed close
-- or its payment. History cleanup is not inside the close transaction.
begin;
delete from public.table_payments where table_number = 12;
delete from public.table_order_history where table_number = 12;
rollback;

do $$
declare
  history_count integer;
  payment_count integer;
begin
  select count(*) into history_count
  from public.table_order_history where table_number = 12;
  select count(*) into payment_count
  from public.table_payments where table_number = 12 and amount = 15;
  if history_count <> 1 or payment_count <> 1 then
    raise exception 'FAIL rolled-back cleanup changed finance history=% pay=%',
      history_count, payment_count;
  end if;
end $$;

insert into public.store_tables (id, seller_id, table_number) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa21', '11111111-1111-1111-1111-111111111111', 21);
insert into public.table_orders (id, seller_id, table_number, items, status) values (
  'cccccccc-cccc-cccc-cccc-cccccccccc21',
  '11111111-1111-1111-1111-111111111111',
  21,
  '[{"name":"Cay","price":"100","quantity":"1","line_total":"100"}]'::jsonb,
  'open'
);
insert into public.orders (
  id, restaurant_id, table_id, status, order_status, total_amount
) values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb21',
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa21',
  'confirmed', 'sent', 90
);
insert into public.table_payments (
  id, seller_id, table_number, session_key, amount, method, is_closing
) values (
  'dddddddd-dddd-dddd-dddd-dddddddddd21',
  '11111111-1111-1111-1111-111111111111',
  21,
  'race-pay',
  10,
  'cash',
  false
);

select
  count(*) as closes,
  round((percentile_cont(0.5) within group (order by rpc_ms))::numeric, 3) as rpc_median_ms,
  round((percentile_cont(0.95) within group (order by rpc_ms))::numeric, 3) as rpc_p95_ms,
  round((percentile_cont(0.5) within group (order by history_ms))::numeric, 3) as history_median_ms,
  round((percentile_cont(0.95) within group (order by history_ms))::numeric, 3) as history_p95_ms,
  bool_and(card_empty) as cards_consistent,
  bool_and(loading_clear) as loading_cleared_with_card,
  bool_and(occupied_after = occupied_before - 1) as counters_moved_together,
  bool_and(payments = 1) as payments_kept
from close_stage_measure;
