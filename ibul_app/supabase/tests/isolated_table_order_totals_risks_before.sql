-- BEFORE the draft: today's production behaviour, recorded for comparison.
\set ON_ERROR_STOP on
\set R 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
\set STAFF 'cccccccc-cccc-cccc-cccc-cccccccccccc'
\set NOPERM 'dddddddd-dddd-dddd-dddd-dddddddddddd'
\set A '[{"name":"Zeytin Salatası","product_id":"p1","quantity":1,"price":200,"station_id":"11111111-1111-1111-1111-111111111111"},{"name":"Tavuk Tava","product_id":"p2","quantity":2,"price":300,"station_id":"11111111-1111-1111-1111-111111111111"}]'
create table if not exists public.t_kv(k text primary key, v text);

-- an order that was created AND closed before the fix (table 2)
select public.t_send(:'R', 2, 'old-closed', :'A'::jsonb) \gset c_
select set_config('ibul.test_uid', :'R', false) \gset
select public.close_table_with_history(:'R'::uuid, 2, 'cash', null, :'R'::uuid, 'Sahip', 'sess-old-closed') \gset c_

-- an order edited before the fix: the edit RPC adds one line (existing production behaviour)
select public.t_send(:'R', 2, 'old-edit', :'A'::jsonb) \gset e_
select public.update_restaurant_table_order(
  p_restaurant_id => :'R'::uuid,
  p_order_id => (select id from public.orders where local_order_id = 'old-edit'),
  p_items => (:'A'::jsonb || '[{"name":"Ek Ürün","quantity":1,"price":50,"station_id":"11111111-1111-1111-1111-111111111111"}]'::jsonb),
  p_revision_key => 'rev-old-edit', p_waiter_id => :'R'::uuid, p_waiter_name => 'Sahip') \gset e_
select public.close_table_with_history(:'R'::uuid, 2, 'cash', null, :'R'::uuid, 'Sahip', 'sess-old-edit') \gset e_

-- an order still OPEN when the fix lands (table 1)
select public.t_send(:'R', 1, 'old-open', :'A'::jsonb) \gset o_
-- staff without order permission
insert into public.t_kv values ('noperm_before', public.t_send(:'NOPERM', 1, 'np-before', :'A'::jsonb)->>'error');
insert into public.t_kv values ('staff_before', public.t_show('old-open'));
select public.t_send(:'STAFF', 1, 'old-staff', :'A'::jsonb) \gset s_

insert into public.t_kv values ('fp_old', public.t_fingerprint('old-%'));
insert into public.t_kv values ('fp_old_closed', public.t_fingerprint('old-closed')), ('fp_old_edit', public.t_fingerprint('old-edit'));
insert into public.t_kv select 'online_before', online::text from public.t_finance();
insert into public.t_kv select 'tables_before', tables::text from public.t_finance();
insert into public.t_kv select 'true_before', true_sales::text from public.t_finance();

select 'BEFORE old-closed  ' || public.t_show('old-closed');
select 'BEFORE old-edit    ' || public.t_show('old-edit');
select 'BEFORE old-open    ' || public.t_show('old-open');
select 'BEFORE old-staff   ' || public.t_show('old-staff');
select 'BEFORE noperm      ' || (select v from public.t_kv where k = 'noperm_before');
select 'BEFORE history     ' || string_agg(coalesce(o.local_order_id, '?') || '=' || coalesce(h.grand_total::text, 'null'), ', ' order by h.created_at, h.id)
  from public.table_order_history h left join public.orders o on o.id = h.original_order_id;
select 'BEFORE finance     online=' || online || ' tables=' || tables || ' true_closed_sales=' || true_sales
  || '  (online+tables=' || (online + tables) || ')' from public.t_finance();
