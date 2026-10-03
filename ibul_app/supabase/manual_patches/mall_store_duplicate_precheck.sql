-- Salt okunur. Primall new içindeki Teknosa tekrarını raporlar. DELETE YOK.
-- 2026-10-03 audit: Tek approved satır var; unit_code = '2'. UI "Teknosa — 2" bunu mağaza sayısı sanıyordu.
select 'approved_teknosa_links' as check_name,
       count(*)::text as value
from public.mall_branch_links l
join public.store_branches b on b.id = l.branch_id
join public.stores s on s.seller_id = b.store_id
where l.status = 'approved' and s.business_name ilike '%teknosa%'
union all
select 'open_duplicate_mall_branch', count(*)::text from (
  select mall_id, branch_id from public.mall_branch_links
  where status in ('pending', 'approved') group by 1, 2 having count(*) > 1) d
union all
select 'teknosa_canonical',
       coalesce((
         select l.id::text || ' status=' || l.status || ' unit=' || coalesce(l.unit_code, '?') || ' source=' || l.request_source
         from public.mall_branch_links l
         join public.store_branches b on b.id = l.branch_id
         join public.stores s on s.seller_id = b.store_id
         where s.business_name ilike '%teknosa%'
         order by (l.status = 'approved') desc, l.requested_at
         limit 1
       ), '-')
union all
select 'branch_open_unique', exists (
  select 1 from pg_indexes where schemaname = 'public' and indexname = 'mall_branch_links_branch_open_unique')::text;
