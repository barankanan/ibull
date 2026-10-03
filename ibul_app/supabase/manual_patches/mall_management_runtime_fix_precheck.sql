-- mall_management_runtime_fix.sql öncesi. Yalnız okur, hiçbir şey yazmaz.
-- Beklenen (2026-10-03 remote): note_column=false, mall_store_links probe=42703, eksik RPC listesi dolu,
-- önkoşul fonksiyonları ve pending_review status değeri mevcut.

select 'note_column' as check_name,
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'mall_branch_links' and column_name = 'note')::text as value
union all
select 'missing_rpcs', coalesce(string_agg(w.n, ','), '')
from (values ('request_mall_store_link'), ('mall_setup_summary'), ('mall_publication_missing'),
             ('request_mall_publication'), ('cancel_mall_publication'), ('admin_mall_publication_queue'),
             ('admin_review_mall_publication'), ('public_mall_detail')) w(n)
where not exists (select 1 from pg_proc p where p.proname = w.n and p.pronamespace = 'public'::regnamespace)
union all
select 'note_readers', coalesce(string_agg(p.proname, ','), '')
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('mall_store_links', 'seller_mall_link_requests')
  and pg_get_functiondef(p.oid) like '%l.note%'
union all
select 'prerequisites', string_agg(p.proname, ',' order by p.proname)
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('is_admin_user', 'mall_member_has_role', 'mall_any_role', 'mall_management_assert_role')
union all
select 'status_allows_pending_review',
       (pg_get_constraintdef(c.oid) like '%pending_review%')::text
from pg_constraint c
where c.conrelid = 'public.malls'::regclass and c.conname = 'malls_status_check'
union all
select 'publication_table', (to_regclass('public.mall_publication_requests') is not null)::text
union all
select 'mall_' || m.name, m.status || ' verified=' || coalesce(m.is_verified, false)::text
       || ' lat=' || coalesce(m.latitude::text, 'null') || ' lng=' || coalesce(m.longitude::text, 'null')
from public.malls m;
