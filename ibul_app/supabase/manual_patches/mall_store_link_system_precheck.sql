-- mall_store_link_system.sql öncesi, salt okunur. Beklenen: runtime_fix_applied=true, links_with_null_unit=0.
select 'runtime_fix_applied' as check_name,
       (to_regprocedure('public.mall_setup_summary(uuid)') is not null
        and exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = 'mall_branch_links' and column_name = 'note'))::text as value
union all
select 'link_rows', count(*)::text from public.mall_branch_links
union all
select 'link_columns', string_agg(column_name || ':' || is_nullable, ', ' order by ordinal_position)
  from information_schema.columns where table_schema = 'public' and table_name = 'mall_branch_links'
union all
select 'documents_table', (to_regclass('public.mall_branch_link_documents') is not null)::text
union all
select 'seller_documents_bucket_private', coalesce((select (not public)::text from storage.buckets where id = 'seller-documents'), 'missing')
union all
select 'respond_signatures', string_agg(oid::regprocedure::text, ', ')
  from pg_proc where pronamespace = 'public'::regnamespace and proname = 'respond_mall_branch_link'
union all
select 'teknosa_branch', coalesce((select status || ' ' || branch_code from public.store_branches
                                   where id = '65f9be3c-8f25-42ce-9f02-1801f5ecb362'), 'missing')
union all
select 'mall_' || name, status || ' verified=' || is_verified || ' lat=' || coalesce(latitude::text, '-') from public.malls;
