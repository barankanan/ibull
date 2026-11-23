-- Asserts for 20261124_table_order_totals_DRAFT. psql var :phase = before | after | rolledback.
\set ON_ERROR_STOP on
select set_config('ibul.test_uid', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false) \gset
\set items '[{"name":"Zeytin Salatası","product_id":"p1","quantity":1,"price":200,"station_id":"11111111-1111-1111-1111-111111111111"},{"name":"Tavuk Tava","product_id":"p1","quantity":2,"price":300,"station_id":"11111111-1111-1111-1111-111111111111"}]'
create temp table res(k text, r jsonb);
insert into res select 'first', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  p_waiter_name => 'Ali', p_local_order_id => ('tot-' || :'phase'));
-- the same send again (lost reply): one order, totals untouched
insert into res select 'replay', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  p_waiter_name => 'Ali', p_local_order_id => ('tot-' || :'phase'));
-- a second deliberate order with the same items
insert into res select 'second', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  p_waiter_name => 'Ali', p_local_order_id => ('tot2-' || :'phase'));
select 'RESULT ' || :'phase'
  || ' orders=' || (select count(*) from public.orders where local_order_id in ('tot-' || :'phase', 'tot2-' || :'phase'))
  || ' same_id_on_replay=' || ((select r->>'order_id' from res where k='first') = (select r->>'order_id' from res where k='replay'))
  || ' replay_flag=' || coalesce((select r->>'idempotent_replay' from res where k='replay'), '-')
  || ' header=' || (select string_agg(subtotal_amount::text || '/' || total_amount::text, ',' order by local_order_id) from public.orders where local_order_id in ('tot-' || :'phase', 'tot2-' || :'phase'))
  || ' lines=' || (select string_agg(coalesce(total_price,0)::text || ':' || coalesce(line_total::text,'null'), ',' order by oi.unit_price) from public.order_items oi join public.orders o on o.id = oi.order_id where o.local_order_id = 'tot-' || :'phase')
  || ' items=' || (select count(*) from public.order_items oi join public.orders o on o.id = oi.order_id where o.local_order_id = 'tot-' || :'phase')
  || ' jobs=' || (select count(*) from public.print_jobs p join public.orders o on o.id = p.order_id where o.local_order_id = 'tot-' || :'phase');
