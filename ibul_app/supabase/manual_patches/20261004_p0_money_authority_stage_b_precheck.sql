-- READ ONLY. Run before stage B, after the new web build is serving traffic.

select 'stage_a_rpcs' as check_name, p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'create_marketplace_order',
    'create_seller_external_cargo_order',
    'marketplace_server_shipping_fee',
    'request_marketplace_refund',
    'cancel_marketplace_order_if_unpaid'
  )
order by p.proname;

select 'orders_money_columns' as check_name, c.column_name
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'orders'
  and c.column_name in (
    'subtotal_amount', 'shipping_amount', 'discount_amount', 'total_amount',
    'customer_delivery_fee', 'seller_delivery_fee', 'total_delivery_fee',
    'payment_status'
  )
order by c.column_name;

select 'is_admin_user_uuid' as check_name,
       to_regprocedure('public.is_admin_user(uuid)') is not null as present;

select 'categories_bucket' as check_name, id, public
from storage.buckets
where id = 'categories';

select 'seller_ops_schema' as check_name,
       to_regnamespace('seller_ops') is not null as present;
