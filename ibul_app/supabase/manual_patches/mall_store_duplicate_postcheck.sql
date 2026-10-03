-- Cleanup sonrası. Silme olmadığı için satır sayısı değişmemeli.
select 'approved_teknosa_links' as check_name, count(*)::text as value
from public.mall_branch_links l
join public.store_branches b on b.id = l.branch_id
join public.stores s on s.seller_id = b.store_id
where l.status = 'approved' and s.business_name ilike '%teknosa%'
union all
select 'open_duplicate_mall_branch', count(*)::text from (
  select mall_id, branch_id from public.mall_branch_links
  where status in ('pending', 'approved') group by 1, 2 having count(*) > 1) d;
