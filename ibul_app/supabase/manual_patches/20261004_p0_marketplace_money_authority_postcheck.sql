-- READ ONLY. Run after 20261004_p0_marketplace_money_authority.sql.
-- Expected results are described in the check_name column. This file writes nothing.

select 'authenticated_orders_insert_absent' as check_name,
       not exists (
         select 1
         from information_schema.role_table_grants
         where table_schema = 'public'
           and table_name = 'orders'
           and privilege_type = 'INSERT'
           and grantee in ('anon', 'authenticated')
       ) as ok;

select 'authenticated_order_items_insert_absent' as check_name,
       not exists (
         select 1
         from information_schema.role_table_grants
         where table_schema = 'public'
           and table_name = 'order_items'
           and privilege_type = 'INSERT'
           and grantee in ('anon', 'authenticated')
       ) as ok;

select 'orders_insert_policies_absent' as check_name,
       not exists (
         select 1
         from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public'
           and cls.relname = 'orders'
           and pol.polcmd = 'a'
           and pol.polname in ('orders_user_insert', 'orders_restaurant_insert')
       ) as ok;

select 'marketplace_rpc_authenticated_execute' as check_name,
       has_function_privilege(
         'authenticated',
         'public.create_marketplace_order(jsonb,jsonb,jsonb,uuid,text,text,text,text,text,text)',
         'execute'
       ) as ok;

select 'marketplace_rpc_anon_execute_absent' as check_name,
       not has_function_privilege(
         'anon',
         'public.create_marketplace_order(jsonb,jsonb,jsonb,uuid,text,text,text,text,text,text)',
         'execute'
       ) as ok;

select 'external_cargo_rpc_authenticated_execute' as check_name,
       has_function_privilege(
         'authenticated',
         'public.create_seller_external_cargo_order(jsonb,text,text,text,text,text,text,double precision,double precision,text,text,text,text,text)',
         'execute'
       ) as ok;

select 'money_guard_trigger' as check_name,
       exists (
         select 1
         from pg_trigger tg
         join pg_class cls on cls.oid = tg.tgrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public'
           and cls.relname = 'orders'
           and tg.tgname = 'trg_orders_money_authority'
           and not tg.tgisinternal
       ) as ok;

select 'order_items_money_guard_trigger' as check_name,
       exists (
         select 1
         from pg_trigger tg
         join pg_class cls on cls.oid = tg.tgrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public'
           and cls.relname = 'order_items'
           and tg.tgname = 'trg_order_items_money_authority'
           and not tg.tgisinternal
       ) as ok;

select 'create_paid_order_absent' as check_name,
       to_regprocedure('seller_ops.create_paid_order(uuid,uuid,text,text,text,numeric,numeric,numeric,jsonb,text,jsonb)') is null as ok;

select 'refund_order_return_absent' as check_name,
       to_regprocedure('seller_ops.refund_order_return(uuid,uuid,text,text,numeric,boolean,jsonb)') is null as ok;

select 'create_order_from_cart_absent' as check_name,
       to_regprocedure('public.create_order_from_cart(text,jsonb,jsonb,text,text,text,text,text,numeric)') is null as ok;

select 'categories_anon_write_absent' as check_name,
       not exists (
         select 1
         from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage'
           and cls.relname = 'objects'
           and pol.polname in (
             'categories_public_insert',
             'categories_public_update',
             'categories_public_delete'
           )
       ) as ok;

select 'categories_admin_write_present' as check_name,
       exists (
         select 1
         from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage'
           and cls.relname = 'objects'
           and pol.polname = 'categories_admin_insert'
       ) as ok;
