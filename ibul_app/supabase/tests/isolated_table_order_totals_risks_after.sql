-- AFTER the draft is applied. Every line starts with OK or FAIL.
\set ON_ERROR_STOP on
\set R 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
\set STAFF 'cccccccc-cccc-cccc-cccc-cccccccccccc'
\set NOPERM 'dddddddd-dddd-dddd-dddd-dddddddddddd'
\set S '11111111-1111-1111-1111-111111111111'
\set A '[{"name":"Zeytin Salatası","product_id":"p1","quantity":1,"price":200,"station_id":"11111111-1111-1111-1111-111111111111"},{"name":"Tavuk Tava","product_id":"p2","quantity":2,"price":300,"station_id":"11111111-1111-1111-1111-111111111111"}]'

-- 1. Applying the function changed no stored row.
select public.t_check('history_untouched_by_apply',
  public.t_fingerprint('old-%') = (select v from public.t_kv where k = 'fp_old'), 'orders, lines and history rows created before the fix');

-- 2. The same old sends arrive again after the fix (lost reply / offline resend).
select public.t_send(:'R', 2, 'old-closed', :'A'::jsonb)->>'idempotent_replay' as r1 \gset
select public.t_send(:'R', 1, 'old-open', :'A'::jsonb)->>'idempotent_replay' as r2 \gset
select public.t_send(:'STAFF', 1, 'old-staff', :'A'::jsonb)->>'idempotent_replay' as r3 \gset
select public.t_check('old_zero_rows_not_rewritten_on_replay',
  :'r1' = 'true' and :'r2' = 'true' and :'r3' = 'true'
  and public.t_fingerprint('old-%') = (select v from public.t_kv where k = 'fp_old'),
  'replay=' || :'r1' || ',' || :'r2' || ',' || :'r3' || ' old-open ' || public.t_show('old-open'));

-- 3. A new order: header and lines once.
select public.t_send(:'R', 1, 'new-1', :'A'::jsonb)->>'order_id' as n1 \gset
select public.t_check('new_order_total_written_once',
  public.t_show('new-1') like '800.00/800.00 sum=800.00 lines=200.00:200.00,600.00:600.00 seller_items=0%', public.t_show('new-1'));

-- 4. Same amount twice? Resend the new order three times.
select public.t_fingerprint('new-1') as fp_n1 \gset
select (public.t_send(:'R', 1, 'new-1', :'A'::jsonb)->>'order_id') = :'n1'
   and (public.t_send(:'R', 1, 'new-1', :'A'::jsonb)->>'order_id') = :'n1'
   and (public.t_send(:'R', 1, 'new-1', :'A'::jsonb)->>'idempotent_replay') = 'true' as same \gset
select public.t_check('resend_does_not_add_amount_again',
  :'same' and public.t_fingerprint('new-1') = :'fp_n1'
  and (select count(*) from public.orders where local_order_id = 'new-1') = 1
  and (select count(*) from public.order_items oi join public.orders o on o.id = oi.order_id where o.local_order_id = 'new-1') = 2,
  public.t_show('new-1'));

-- 5. Staff under the production write guard.
select public.t_send(:'STAFF', 1, 'new-staff', :'A'::jsonb) as st \gset
select public.t_check('staff_with_permission_still_can_order',
  public.t_show('new-staff') like '800.00/800.00 sum=800.00%', coalesce(:'st'::jsonb->>'error', public.t_show('new-staff')));
select coalesce(public.t_send(:'NOPERM', 1, 'np-after', :'A'::jsonb)->>'error', '') as np \gset
select public.t_check('staff_without_permission_same_refusal',
  :'np' is not distinct from (select v from public.t_kv where k = 'noperm_before')
  and not exists(select 1 from public.orders where local_order_id in ('np-before', 'np-after')),
  'before="' || coalesce((select v from public.t_kv where k = 'noperm_before'), 'null') || '" after="' || coalesce(:'np', 'null') || '"');

-- 6. Line kinds: free, mixed service (parent carries the price), weight price with
--    decimals, three decimals, 99 pieces.
select coalesce(public.t_send(:'R', 1, 'types-1', jsonb_build_array(
  jsonb_build_object('name', 'İkram Çay', 'product_id', 'p1', 'quantity', 2, 'price', 0, 'station_id', :'S'),
  jsonb_build_object('name', 'Karışık Servis', 'quantity', 2, 'price', 720, 'station_id', :'S',
    'child_items', '[{"product_name":"Beyti","quantity":1,"unit_price":460,"line_total":460},{"product_name":"Ciğer","quantity":1,"unit_price":260,"line_total":260}]'::jsonb),
  jsonb_build_object('name', 'Kuzu Pirzola 250 gr', 'product_id', 'p2', 'quantity', 3, 'price', 187.5, 'amount_label', '250 gr', 'station_id', :'S'),
  jsonb_build_object('name', 'Üç ondalık', 'quantity', 3, 'price', 33.333, 'station_id', :'S'),
  jsonb_build_object('name', 'Doksan dokuz', 'quantity', 99, 'price', 1.01, 'station_id', :'S')))->>'error', '') as terr \gset
select public.t_check('line_kinds_free_mixed_weight_decimal',
  public.t_show('types-1') like '2202.49/2202.49 sum=2202.49 lines=0.00:0.00,99.99:99.99,100.00:100.00,562.50:562.50,1440.00:1440.00 %',
  coalesce(nullif(:'terr', ''), public.t_show('types-1')));
select coalesce(public.t_send(:'R', 1, 'all-free', jsonb_build_array(
  jsonb_build_object('name', 'İkram', 'product_id', 'p1', 'quantity', 1, 'price', 0, 'station_id', :'S')))->>'error', '') as ferr \gset
select public.t_check('all_free_order_stays_zero',
  public.t_show('all-free') like '0/0 sum=0.00 lines=0.00:0.00 %' or public.t_show('all-free') like '0.00/0.00 sum=0.00 lines=0.00:0.00 %',
  coalesce(nullif(:'ferr', ''), public.t_show('all-free')));
-- KNOWN LIMIT (same number the app derives today): a mixed-service parent sent with price 0
-- and prices only on its children counts as 0. Six such lines exist in production (13–17 Nov).
select coalesce(public.t_send(:'R', 1, 'ms-zero-parent', jsonb_build_array(
  jsonb_build_object('name', 'Karışık Servis', 'quantity', 1, 'price', 0, 'station_id', :'S',
    'child_items', '[{"product_name":"Beyti","quantity":1,"unit_price":460,"line_total":460}]'::jsonb),
  jsonb_build_object('name', 'Ayran', 'product_id', 'p1', 'quantity', 1, 'price', 100, 'station_id', :'S')))->>'error', '') as merr \gset
select public.t_check('KNOWN_LIMIT_mixed_parent_price_zero_counts_zero',
  public.t_show('ms-zero-parent') like '100.00/100.00 sum=100.00 %', coalesce(nullif(:'merr', ''), public.t_show('ms-zero-parent')) || ' (children 460 not counted)');

-- 7. The customer-request approval path calls the same wrapper from inside another function.
insert into public.waiter_order_requests (id, seller_id, table_number, status, items_draft, customer_notes)
values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', :'R', 1, 'pending_waiter_approval', :'A'::jsonb, 'qr');
select set_config('ibul.test_uid', :'R', false) \gset
begin;
select (public.approve_waiter_order_request('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', null)->'print_result'->>'order_id') as qr \gset
select coalesce(current_setting('ibul.marketplace_order_rpc', true), '') as flag_after \gset
commit;
select public.t_check('approval_path_total_once_and_money_flag_restored',
  (select total_amount = 800 and subtotal_amount = 800 from public.orders where id = :'qr'::uuid) and :'flag_after' <> 'on',
  'header=' || (select total_amount::text from public.orders where id = :'qr'::uuid) || ' flag_after_call="' || :'flag_after' || '"');

-- 8. Money columns stay locked for a plain client right after an order in the same transaction.
begin;
select public.t_send(:'R', 1, 'lock-1', :'A'::jsonb)->>'order_id' as lk \gset
select coalesce(current_setting('ibul.marketplace_order_rpc', true), '') as flag2 \gset
commit;
do $$ begin
  begin
    perform set_config('ibul.test_uid', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
    update public.orders set total_amount = 1 where local_order_id = 'lock-1';
    perform public.t_check('client_cannot_change_total', false, 'update was accepted');
  exception when others then
    perform public.t_check('client_cannot_change_total', sqlerrm = 'ORDER_MONEY_COLUMNS_LOCKED', sqlerrm);
  end;
  begin
    update public.order_items set total_price = 1 where order_id = (select id from public.orders where local_order_id = 'lock-1');
    perform public.t_check('client_cannot_change_line_total', false, 'update was accepted');
  exception when others then
    perform public.t_check('client_cannot_change_line_total', sqlerrm = 'ORDER_MONEY_COLUMNS_LOCKED', sqlerrm);
  end;
end $$;
select public.t_check('money_flag_not_left_on', :'flag2' <> 'on', 'flag after the RPC in the same transaction="' || :'flag2' || '"');

-- 9. Finance before closing: nothing new on the "online" side.
select public.t_check('finance_online_sum_unchanged_by_new_orders',
  (select online::text from public.t_finance()) = (select v from public.t_kv where k = 'online_before'),
  'online=' || (select online from public.t_finance()) || ' before=' || (select v from public.t_kv where k = 'online_before'));

-- 10. Edit a NEW order with the production edit RPC (quantity 2 -> 3, no new line).
select public.t_send(:'R', 2, 'new-edit', :'A'::jsonb)->>'order_id' as ne \gset
select set_config('ibul.test_uid', :'R', false) \gset
select public.update_restaurant_table_order(
  p_restaurant_id => :'R'::uuid, p_order_id => :'ne'::uuid,
  p_items => '[{"name":"Zeytin Salatası","product_id":"p1","quantity":1,"price":200,"station_id":"11111111-1111-1111-1111-111111111111"},{"name":"Tavuk Tava","product_id":"p2","quantity":3,"price":300,"station_id":"11111111-1111-1111-1111-111111111111"}]'::jsonb,
  p_revision_key => 'rev-new-edit', p_waiter_id => :'R'::uuid, p_waiter_name => 'Sahip') is not null as edited \gset
select public.t_check('edit_after_fix_total_consistent',
  public.t_show('new-edit') like '1100.00/1100.00 sum=1100.00 lines=200.00:200.00,900.00:900.00 seller_items=0%'
  or public.t_show('new-edit') like '1100/1100 sum=1100.00 lines=200:200,900:900 seller_items=0%', public.t_show('new-edit'));

-- 11. Close both tables with the production close RPC; table 1 by staff.
select set_config('ibul.test_uid', :'STAFF', false) \gset
select public.close_table_with_history(:'R'::uuid, 1, 'cash', null, :'STAFF'::uuid, 'Garson', 'sess-t1') as close1 \gset
select set_config('ibul.test_uid', :'R', false) \gset
select public.close_table_with_history(:'R'::uuid, 2, 'card', null, :'R'::uuid, 'Sahip', 'sess-t2') as close2 \gset
select public.t_check('close_writes_each_order_once',
  (select count(*) = count(distinct h.original_order_id) from public.table_order_history h)
  and (select count(*) from public.table_order_history h where h.original_order_id is null) = 0
  and (select bool_and(coalesce(h.grand_total, 0) = o.total_amount) from public.table_order_history h join public.orders o on o.id = h.original_order_id),
  'history: ' || (select string_agg(o.local_order_id || '=' || coalesce(h.grand_total::text, 'null'), ', ' order by h.created_at, h.id)
     from public.table_order_history h join public.orders o on o.id = h.original_order_id));
select public.t_check('old_open_zero_order_closes_as_zero_not_guessed',
  (select coalesce(h.grand_total, 0) = 0 from public.table_order_history h join public.orders o on o.id = h.original_order_id where o.local_order_id = 'old-open')
  and (select total_amount = 0 from public.orders where local_order_id = 'old-open'),
  'old-open ' || public.t_show('old-open') || ' (the app shows 800 from the lines, marked "kalemlerden")');
select public.t_check('customer_request_table_orders_row_not_counted_again',
  (select count(*) from public.table_order_history h where h.original_order_id in (select id from public.table_orders)) = 0
  and (select count(*) from public.table_orders where status <> 'archived') = 0,
  'legacy table_orders rows archived, none copied to history');

-- 12. Close again (double tap / retry): nothing new.
select count(*) as hbefore from public.table_order_history \gset
select public.close_table_with_history(:'R'::uuid, 1, 'cash', null, :'STAFF'::uuid, 'Garson', 'sess-t1') as close1b \gset
select public.t_check('second_close_adds_nothing',
  (select count(*) from public.table_order_history) = :hbefore, 'history rows ' || :hbefore || ' -> ' || (select count(*) from public.table_order_history));

-- 13. The app's finance sum after closing: every closed order exactly once.
select public.t_check('finance_no_double_count',
  (select tables = true_sales from public.t_finance())
  and (select online::text from public.t_finance()) = (select v from public.t_kv where k = 'online_before'),
  (select 'tables=' || tables || ' true_closed_sales=' || true_sales || ' online=' || online from public.t_finance())
  || ' online_before=' || (select v from public.t_kv where k = 'online_before'));

-- 14. History made before the fix is still exactly what it was.
select public.t_check('old_closed_history_identical_at_end',
  public.t_fingerprint('old-closed') = (select v from public.t_kv where k = 'fp_old_closed')
  and public.t_fingerprint('old-edit') = (select v from public.t_kv where k = 'fp_old_edit'),
  'old-closed ' || public.t_show('old-closed') || ' | old-edit ' || public.t_show('old-edit'));

select 'AFTER finance      online=' || online || ' tables=' || tables || ' true_closed_sales=' || true_sales from public.t_finance();
