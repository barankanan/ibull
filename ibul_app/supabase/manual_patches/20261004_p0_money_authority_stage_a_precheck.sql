-- READ ONLY. One result set. Do not apply Stage A when all_required is false.
-- Writes nothing.

with checks as (
  select * from (values
    ('orders_table', 'true', (to_regclass('public.orders') is not null)::text, 'critical'),
    ('order_items_table', 'true', (to_regclass('public.order_items') is not null)::text, 'critical'),
    ('products_table', 'true', (to_regclass('public.products') is not null)::text, 'critical'),
    ('stores_table', 'true', (to_regclass('public.stores') is not null)::text, 'critical'),
    ('products_id_text', 'text', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'products' and c.column_name = 'id'
    ), 'critical'),
    ('products_price_float', 'float8', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'products' and c.column_name = 'price'
    ), 'critical'),
    ('products_discount_price_float', 'float8', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'products' and c.column_name = 'discount_price'
    ), 'critical'),
    ('products_seller_id_uuid', 'uuid', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'products' and c.column_name = 'seller_id'
    ), 'critical'),
    ('stores_seller_id_uuid', 'uuid', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'stores' and c.column_name = 'seller_id'
    ), 'critical'),
    ('stores_id_absent', 'absent', (
      select case when count(*) = 0 then 'absent' else 'present' end
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'stores' and c.column_name = 'id'
    ), 'critical'),
    ('orders_billing_address_absent', 'absent', (
      select case when count(*) = 0 then 'absent' else 'present' end
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'orders' and c.column_name = 'billing_address'
    ), 'critical'),
    ('order_items_main_category_absent', 'absent', (
      select case when count(*) = 0 then 'absent' else 'present' end
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'order_items' and c.column_name = 'main_category'
    ), 'critical'),
    ('products_store_name_absent', 'absent', (
      select case when count(*) = 0 then 'absent' else 'present' end
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'products' and c.column_name = 'store_name'
    ), 'critical'),
    ('stores_business_name', 'present', (
      select case when count(*) = 1 then 'present' else 'absent' end
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'stores' and c.column_name = 'business_name'
    ), 'critical'),
    ('order_items_station_id_uuid', 'uuid', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'order_items' and c.column_name = 'station_id'
    ), 'critical'),
    ('order_items_product_id_text', 'text', (
      select c.udt_name from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'order_items' and c.column_name = 'product_id'
    ), 'critical'),
    ('hybrid_delivery_quote_signature',
      'p_actor_user_id uuid, p_source text, p_seller_id uuid, p_customer_address jsonb, p_weather text, p_is_night boolean, p_surge_level text, p_payer_mode payer_mode, p_selected_company_id uuid',
      (
        select pg_get_function_identity_arguments(p.oid)
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'hybrid_delivery_quote'
        limit 1
      ),
      'critical'),
    ('is_admin_user_uuid', 'target_user_id uuid', (
      select pg_get_function_identity_arguments(p.oid)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'is_admin_user'
      limit 1
    ), 'critical'),
    ('auth_orders_insert', 'false', has_table_privilege('authenticated', 'public.orders', 'INSERT')::text, 'info'),
    ('auth_order_items_insert', 'false', has_table_privilege('authenticated', 'public.order_items', 'INSERT')::text, 'info'),
    ('marketplace_rpc_absent_or_new', 'ok', (
      select case
        when to_regprocedure('public.create_marketplace_order(jsonb,jsonb,uuid,text,text,text,text,text,text)') is not null then 'ok'
        when to_regprocedure('public.create_marketplace_order(jsonb,jsonb,jsonb,uuid,text,text,text,text,text,text)') is not null then 'old_signature'
        when count(*) = 0 then 'ok'
        else 'other'
      end
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'create_marketplace_order'
    ), 'critical'),
    ('seller_ops_product_id_type', 'uuid_column_text_catalog', (
      select coalesce(c.udt_name, 'missing')
      from information_schema.columns c
      where c.table_schema = 'seller_ops' and c.table_name = 'order_items' and c.column_name = 'product_id'
    ), 'high')
  ) as t(check_name, expected, actual, severity)
)
select check_name, expected, actual,
       (actual is not distinct from expected) as ok,
       severity
from checks
union all
select 'ALL_REQUIRED_CHECKS_OK', 'true',
       (select bool_and(actual is not distinct from expected) from checks where severity = 'critical')::text,
       (select bool_and(actual is not distinct from expected) from checks where severity = 'critical'),
       'critical';
