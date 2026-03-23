-- Clean demo/test IHIZ pool orders (external cargo test records)
-- Run in Supabase SQL Editor with admin privileges.
-- Scope: only IBUL-EXT orders that still sit in active courier flow.

begin;

-- 1) Preview candidates before delete
with target_orders as (
  select distinct o.id, o.order_number, o.created_at
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  where o.order_number like 'IBUL-EXT-%'
    and lower(coalesce(oi.status, '')) in ('ready_to_ship', 'out_for_delivery')
)
select *
from target_orders
order by created_at desc;

-- 2) Delete target orders
-- order_items and history rows are removed by cascade FKs.
with target_orders as (
  select distinct o.id
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  where o.order_number like 'IBUL-EXT-%'
    and lower(coalesce(oi.status, '')) in ('ready_to_ship', 'out_for_delivery')
)
delete from public.orders o
where o.id in (select id from target_orders);

commit;
