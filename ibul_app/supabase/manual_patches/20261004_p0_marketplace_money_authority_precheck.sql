-- READ ONLY. Run in the SQL editor before 20261004_p0_marketplace_money_authority.sql.
-- This file does not insert, update, delete, alter, drop, or create anything.
-- Do not supabase db push. Do not apply this as a migration.

select 'orders_table' as check_name,
       to_regclass('public.orders') is not null as present;

select 'order_items_table' as check_name,
       to_regclass('public.order_items') is not null as present;

select 'products_table' as check_name,
       to_regclass('public.products') is not null as present;

select 'stores_table' as check_name,
       to_regclass('public.stores') is not null as present;

select 'orders_money_columns' as check_name,
       c.column_name,
       c.data_type
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'orders'
  and c.column_name in (
    'user_id',
    'order_number',
    'status',
    'payment_method',
    'subtotal_amount',
    'shipping_amount',
    'discount_amount',
    'total_amount',
    'customer_delivery_fee',
    'seller_delivery_fee',
    'total_delivery_fee',
    'idempotency_key',
    'payment_status'
  )
order by c.column_name;

select 'order_items_money_columns' as check_name,
       c.column_name,
       c.data_type
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'order_items'
  and c.column_name in (
    'order_id',
    'seller_id',
    'product_id',
    'quantity',
    'unit_price',
    'total_price',
    'station_id'
  )
order by c.column_name;

select 'product_price_columns' as check_name,
       c.column_name
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'products'
  and c.column_name in (
    'price',
    'discount_price',
    'stock',
    'seller_id',
    'status',
    'approval_status',
    'admin_approval_status',
    'sku'
  )
order by c.column_name;

select 'orders_policies' as check_name, pol.polname, pol.polcmd
from pg_policy pol
join pg_class cls on cls.oid = pol.polrelid
join pg_namespace ns on ns.oid = cls.relnamespace
where ns.nspname = 'public'
  and cls.relname in ('orders', 'order_items')
order by cls.relname, pol.polname;

select 'orders_insert_grants' as check_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('orders', 'order_items')
  and privilege_type = 'INSERT'
  and grantee in ('anon', 'authenticated', 'public')
order by table_name, grantee;

select 'orders_triggers' as check_name, tg.tgname
from pg_trigger tg
join pg_class cls on cls.oid = tg.tgrelid
join pg_namespace ns on ns.oid = cls.relnamespace
where ns.nspname = 'public'
  and cls.relname in ('orders', 'order_items')
  and not tg.tgisinternal
order by tg.tgname;

select 'rpc_names' as check_name, n.nspname, p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in (
  'create_marketplace_order',
  'create_seller_external_cargo_order',
  'create_order_from_cart',
  'create_paid_order',
  'refund_order_return',
  'is_admin_user',
  'hybrid_delivery_quote',
  'can_access_order_as_seller'
)
order by n.nspname, p.proname;

select 'seller_ops_schema' as check_name,
       to_regnamespace('seller_ops') is not null as present;

select 'categories_bucket' as check_name, id, public
from storage.buckets
where id = 'categories';

select 'is_admin_user' as check_name,
       to_regprocedure('public.is_admin_user()') is not null as no_arg,
       to_regprocedure('public.is_admin_user(uuid)') is not null as uuid_arg;

select 'hybrid_delivery_quote' as check_name,
       to_regprocedure('public.hybrid_delivery_quote(uuid,text,uuid,jsonb,text,boolean,text,public.payer_mode,uuid)') is not null as present;
