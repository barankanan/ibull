-- READ ONLY. Run after stage B. Every ok column should be true.

select 'authenticated_orders_insert_absent' as check_name,
       not exists (
         select 1 from information_schema.role_table_grants
         where table_schema = 'public' and table_name = 'orders'
           and privilege_type = 'INSERT' and grantee in ('anon', 'authenticated')
       ) as ok;

select 'authenticated_order_items_insert_absent' as check_name,
       not exists (
         select 1 from information_schema.role_table_grants
         where table_schema = 'public' and table_name = 'order_items'
           and privilege_type = 'INSERT' and grantee in ('anon', 'authenticated')
       ) as ok;

select 'old_insert_policies_absent' as check_name,
       not exists (
         select 1
         from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public'
           and (
             (cls.relname = 'orders' and pol.polname in ('orders_user_insert', 'orders_restaurant_insert'))
             or (cls.relname = 'order_items' and pol.polname in ('order_items_buyer_insert', 'order_items_restaurant_insert'))
           )
       ) as ok;

select 'money_guards_active' as check_name,
       exists (
         select 1 from pg_trigger tg
         join pg_class cls on cls.oid = tg.tgrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public' and cls.relname = 'orders'
           and tg.tgname = 'trg_orders_money_authority' and not tg.tgisinternal
       )
       and exists (
         select 1 from pg_trigger tg
         join pg_class cls on cls.oid = tg.tgrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'public' and cls.relname = 'order_items'
           and tg.tgname = 'trg_order_items_money_authority' and not tg.tgisinternal
       ) as ok;

select 'legacy_rpcs_absent' as check_name,
       to_regprocedure('public.create_order_from_cart(text,jsonb,jsonb,text,text,text,text,text,numeric)') is null
       and to_regprocedure('seller_ops.create_paid_order(uuid,uuid,text,text,text,numeric,numeric,numeric,jsonb,text,jsonb)') is null
       and to_regprocedure('seller_ops.refund_order_return(uuid,uuid,text,text,numeric,boolean,jsonb)') is null
       as ok;

select 'categories_anon_write_absent' as check_name,
       not exists (
         select 1
         from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage' and cls.relname = 'objects'
           and pol.polname in (
             'categories_public_insert',
             'categories_public_update',
             'categories_public_delete'
           )
       ) as ok;

select 'new_checkout_rpc_still_present' as check_name,
       to_regprocedure('public.create_marketplace_order(jsonb,jsonb,uuid,text,text,text,text,text,text)') is not null as ok;

select 'categories_auth_insert_absent' as check_name,
       not exists (
         select 1 from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage' and cls.relname = 'objects'
           and pol.polname = 'categories_auth_insert'
       ) as ok;

select 'categories_auth_update_absent' as check_name,
       not exists (
         select 1 from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage' and cls.relname = 'objects'
           and pol.polname = 'categories_auth_update'
       ) as ok;

select 'categories_auth_delete_absent' as check_name,
       not exists (
         select 1 from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage' and cls.relname = 'objects'
           and pol.polname = 'categories_auth_delete'
       ) as ok;

select 'categories_admin_insert_present' as check_name,
       exists (
         select 1 from pg_policy pol
         join pg_class cls on cls.oid = pol.polrelid
         join pg_namespace ns on ns.oid = cls.relnamespace
         where ns.nspname = 'storage' and cls.relname = 'objects'
           and pol.polname = 'categories_admin_insert'
           and pg_get_expr(pol.polwithcheck, pol.polrelid) like '%is_admin_user(auth.uid())%'
       ) as ok;
