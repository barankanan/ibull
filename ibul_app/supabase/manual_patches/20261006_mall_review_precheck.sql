-- Read-only precheck. Do not wrap in a transaction that writes.

select 'catalog' as check_name, role_key,
       ('mall_review' = any(coalesce(modules, '{}'::text[]))) as has_mall_review
from public.admin_role_catalog
where role_key in ('admin', 'admin_store_ops', 'super_admin')
order by role_key;

select 'application_admin_policy' as check_name,
       pg_get_expr(pol.polqual, pol.polrelid) as expression
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'mall_applications'
  and pol.polname = 'mall_applications_select_admin';

select 'storage_admin_policy' as check_name,
       pg_get_expr(pol.polqual, pol.polrelid) as expression
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'storage'
  and c.relname = 'objects'
  and pol.polname = 'mall_application_docs_admin_select';

select p.proname as check_name,
       (position('current_admin_has_module' in pg_get_functiondef(p.oid)) > 0) as uses_mall_review_helper,
       (position('is_admin_user' in pg_get_functiondef(p.oid)) > 0) as uses_is_admin_user
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'admin_approve_mall_application',
    'admin_reject_mall_application',
    'admin_request_mall_application_info'
  )
order by p.proname;
