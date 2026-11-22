-- Call matrix for the order RPC. psql variable :tag makes local ids unique per run.
\set ON_ERROR_STOP on
select set_config('ibul.test_uid', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false) \gset
\set items '[{"name":"Çorba","product_id":"p1","quantity":1,"price":40,"station_id":"11111111-1111-1111-1111-111111111111"}]'

-- A: old client, named arguments (PostgREST style), 9 parameters.
create temp table res(k text, r jsonb);
insert into res select 'A_named9', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  p_waiter_name => 'Ali', p_notes => null, p_job_type => 'new_order',
  p_order_type => 'table', p_local_order_id => ('A-' || :'tag'));
-- A2: same call again: must replay, not create a second order.
insert into res select 'A_replay', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  p_waiter_name => 'Ali', p_notes => null, p_job_type => 'new_order',
  p_order_type => 'table', p_local_order_id => ('A-' || :'tag'));
-- B: positional 9 arguments.
insert into res select 'B_pos9', public.create_table_order_with_print_jobs(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, :'items'::jsonb,
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ali', null, 'new_order', 'table', ('B-' || :'tag'));
-- C: minimal named call (defaults), no local id (online order).
insert into res select 'C_min', public.create_table_order_with_print_jobs(
  p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1,
  p_items => :'items'::jsonb);
select md5(:'tag')::uuid as rid \gset
-- D: the live approve_waiter_order_request (8 positional arguments inside).
insert into public.waiter_order_requests (id, seller_id, table_number, status, items_draft, customer_notes)
values (:'rid', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1,
        'pending_waiter_approval', :'items'::jsonb, 'not');
insert into res select 'D_approve', public.approve_waiter_order_request(
  (:'rid')::uuid, null);

select 'CALLS ' || k || ' keys=' || (select string_agg(x, ',' order by x) from jsonb_object_keys(
  case jsonb_typeof(r) when 'object' then r else '{}'::jsonb end) x) ||
  ' order=' || (r ? 'order_id' or (r->'print_result') ? 'order_id')::text
from res order by k;
select 'ORDERS_FOR_LOCAL ' || count(*) filter (where local_order_id = ('A-' || :'tag')) || '/'
  || count(*) filter (where local_order_id = ('B-' || :'tag')) from public.orders;
select 'JOB_STATUS ' || coalesce(string_agg(distinct status, ','), '') from public.print_jobs
  where order_id in (select id from public.orders where local_order_id in (('A-' || :'tag'),('B-' || :'tag')));
