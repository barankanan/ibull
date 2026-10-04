-- READ ONLY. One result set. Run after Stage A.
-- Production already has no authenticated INSERT on orders or order_items.
-- Stage A must leave that unchanged and must not install the money trigger.

with checks as (
  select * from (values
    ('marketplace_rpc', 'present', (
      case when to_regprocedure('public.create_marketplace_order(jsonb,jsonb,uuid,text,text,text,text,text,text)') is not null
        then 'present' else 'absent' end
    ), 'critical'),
    ('external_cargo_rpc', 'present', (
      case when to_regprocedure('public.create_seller_external_cargo_order(jsonb,text,text,text,text,text,text,double precision,double precision,text,text,text,text,text)') is not null
        then 'present' else 'absent' end
    ), 'critical'),
    ('shipping_helper', 'present', (
      case when to_regprocedure('public.marketplace_server_shipping_fee(uuid,jsonb)') is not null
        then 'present' else 'absent' end
    ), 'critical'),
    ('station_parser', 'present', (
      case when to_regprocedure('public.marketplace_parse_station_id(text)') is not null
        then 'present' else 'absent' end
    ), 'critical'),
    ('refund_request_rpc', 'present', (
      case when to_regprocedure('public.request_marketplace_refund(uuid)') is not null
        then 'present' else 'absent' end
    ), 'critical'),
    ('marketplace_execute_authenticated', 'true', (
      has_function_privilege(
        'authenticated',
        'public.create_marketplace_order(jsonb,jsonb,uuid,text,text,text,text,text,text)',
        'execute'
      )
    )::text, 'critical'),
    ('marketplace_execute_anon', 'false', (
      has_function_privilege(
        'anon',
        'public.create_marketplace_order(jsonb,jsonb,uuid,text,text,text,text,text,text)',
        'execute'
      )
    )::text, 'critical'),
    ('auth_orders_insert_still_false', 'false',
      has_table_privilege('authenticated', 'public.orders', 'INSERT')::text, 'critical'),
    ('auth_order_items_insert_still_false', 'false',
      has_table_privilege('authenticated', 'public.order_items', 'INSERT')::text, 'critical'),
    ('money_trigger_absent', 'absent', (
      select case when count(*) = 0 then 'absent' else 'present' end
      from pg_trigger tg
      join pg_class cls on cls.oid = tg.tgrelid
      join pg_namespace ns on ns.oid = cls.relnamespace
      where ns.nspname = 'public' and cls.relname = 'orders'
        and tg.tgname = 'trg_orders_money_authority' and not tg.tgisinternal
    ), 'critical')
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
