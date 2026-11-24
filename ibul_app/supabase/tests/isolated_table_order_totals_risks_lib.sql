-- Helpers for run_isolated_table_order_totals_risks.sh. THROWAWAY PostgreSQL only.
\set ON_ERROR_STOP on

-- Production triggers on the money tables (names and order as read on 2026-11-24).
drop trigger if exists restaurant_staff_write_guard on public.orders;
drop trigger if exists trg_orders_money_authority on public.orders;
drop trigger if exists trg_orders_updated_at on public.orders;
drop trigger if exists restaurant_staff_write_guard on public.order_items;
drop trigger if exists trg_order_items_money_authority on public.order_items;
drop trigger if exists trg_order_items_updated_at on public.order_items;
drop trigger if exists restaurant_staff_write_guard on public.table_order_history;
create trigger restaurant_staff_write_guard before insert or delete or update on public.orders
  for each row execute function public.guard_restaurant_staff_order_write();
create trigger trg_orders_money_authority before insert or update on public.orders
  for each row execute function public.orders_money_authority_guard();
create trigger trg_orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();
create trigger restaurant_staff_write_guard before insert or delete or update on public.order_items
  for each row execute function public.guard_restaurant_staff_order_write();
create trigger trg_order_items_money_authority before insert or update on public.order_items
  for each row execute function public.order_items_money_authority_guard();
create trigger trg_order_items_updated_at before update on public.order_items
  for each row execute function public.set_updated_at();
create trigger restaurant_staff_write_guard before insert or delete or update on public.table_order_history
  for each row execute function public.guard_restaurant_staff_order_write();

-- One call of the order RPC as a given signed-in user. Returns the reply or the error text.
create or replace function public.t_send(p_uid uuid, p_table integer, p_local text, p_items jsonb)
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('ibul.test_uid', p_uid::text, true);
  begin
    v := public.create_table_order_with_print_jobs(
      p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => p_table,
      p_items => p_items, p_waiter_id => p_uid, p_waiter_name => 'T', p_local_order_id => p_local);
  exception when others then
    v := jsonb_build_object('error', sqlerrm);
  end;
  return v;
end $$;

-- "header/subtotal | unit*qty sum | total_price:line_total… | items with seller_id"
create or replace function public.t_show(p_local text) returns text language sql stable as $$
  select coalesce((
    select o.total_amount::text || '/' || o.subtotal_amount::text
      || ' sum=' || (select coalesce(sum(round(oi.unit_price * oi.quantity, 2)), 0) from public.order_items oi where oi.order_id = o.id)::text
      || ' lines=' || coalesce((select string_agg(oi.total_price::text || ':' || coalesce(oi.line_total::text, 'null'), ',' order by oi.unit_price, oi.quantity, oi.product_name) from public.order_items oi where oi.order_id = o.id), '-')
      || ' seller_items=' || (select count(*) from public.order_items oi where oi.order_id = o.id and oi.seller_id is not null)
      || ' status=' || o.status
    from public.orders o where o.local_order_id = p_local), 'NO_ORDER')
$$;

-- The app's finance reads, as SQL (finance_repository.dart getSalesRevenue):
--  online = order_items.total_price where seller_id = store, not cancelled
--  table  = per closed-history row: grand_total when > 0, otherwise the lines (unit_price * quantity)
create or replace function public.t_finance() returns table(online numeric, tables numeric, true_sales numeric)
language sql stable as $$
  select
    (select coalesce(sum(oi.total_price), 0) from public.order_items oi
      where oi.seller_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' and oi.status not in ('cancelled','canceled')),
    (select coalesce(sum(case when coalesce(h.grand_total, 0) > 0.009 then h.grand_total
        else (select coalesce(sum(oi.unit_price * oi.quantity), 0) from public.order_items oi where oi.order_id = h.original_order_id) end), 0)
       from public.table_order_history h where h.seller_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    (select coalesce(sum(round(oi.unit_price * oi.quantity, 2)), 0) from public.order_items oi
       join public.orders o on o.id = oi.order_id
      where o.status = 'closed' and o.restaurant_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
$$;

-- Fingerprint of every money-bearing row of a set of orders (and their history rows).
create or replace function public.t_fingerprint(p_like text) returns text language sql stable as $$
  select md5(
    coalesce((select string_agg(o.id::text || o.status || o.total_amount || '/' || o.subtotal_amount || '/' || o.discount_amount || '/' || o.shipping_amount, '|' order by o.id)
       from public.orders o where o.local_order_id like p_like), '') || '#' ||
    coalesce((select string_agg(oi.id::text || oi.quantity || '/' || oi.unit_price || '/' || oi.total_price || '/' || coalesce(oi.line_total::text, 'null') || '/' || coalesce(oi.seller_id::text, 'null'), '|' order by oi.id)
       from public.order_items oi join public.orders o on o.id = oi.order_id where o.local_order_id like p_like), '') || '#' ||
    coalesce((select string_agg(h.id::text || coalesce(h.grand_total::text, 'null') || h.archived_orders::text, '|' order by h.id)
       from public.table_order_history h join public.orders o on o.id = h.original_order_id where o.local_order_id like p_like), ''))
$$;

create table if not exists public.t_result(n serial, name text, ok boolean, detail text);
create or replace function public.t_check(p_name text, p_ok boolean, p_detail text) returns text language plpgsql as $$
begin
  insert into public.t_result(name, ok, detail) values (p_name, coalesce(p_ok, false), p_detail);
  return (case when coalesce(p_ok, false) then 'OK   ' else 'FAIL ' end) || p_name || ' :: ' || coalesce(p_detail, '');
end $$;
