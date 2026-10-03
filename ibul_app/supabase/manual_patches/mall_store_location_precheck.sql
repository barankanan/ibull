-- Salt okunur. mall_store_location_architecture.sql + store_location_change_moderation.sql öncesi durum.
select 'link_system_applied' as check_name,
       (to_regclass('public.mall_branch_link_documents') is not null)::text as value
union all select 'location_type_column', exists (select 1 from information_schema.columns
  where table_schema = 'public' and table_name = 'store_branches' and column_name = 'location_type')::text
union all select 'open_duplicates_mall_branch', count(*)::text from (
  select mall_id, branch_id from public.mall_branch_links where status in ('pending', 'approved')
  group by 1, 2 having count(*) > 1) d
union all select 'open_duplicates_mall_store', count(*)::text from (
  select l.mall_id, b.store_id, count(distinct l.branch_id) from public.mall_branch_links l
  join public.store_branches b on b.id = l.branch_id where l.status = 'approved'
  group by 1, 2 having count(*) > 1) d
union all select 'duplicate_floor_levels', count(*)::text from (
  select mall_id, level_number from public.mall_floors where level_number is not null group by 1, 2 having count(*) > 1) d
union all select 'branch_open_unique_index', exists (select 1 from pg_indexes
  where schemaname = 'public' and indexname = 'mall_branch_links_branch_open_unique')::text
union all select 'approved_links', coalesce(string_agg(m.name || ' / ' || s.business_name || ' / ' || f.name || ' / ' || u.unit_code, '; '), '-')
  from public.mall_branch_links l join public.malls m on m.id = l.mall_id
  join public.mall_units u on u.id = l.mall_unit_id join public.mall_floors f on f.id = u.floor_id
  join public.store_branches b on b.id = l.branch_id join public.stores s on s.seller_id = b.store_id
  where l.status = 'approved'
union all select 'branches_without_primary', count(*)::text from public.stores s
  where not exists (select 1 from public.store_branches b where b.store_id = s.seller_id and b.is_primary)
union all select 'location_change_open_policies', coalesce(string_agg(policyname, ', '), '-') from pg_policies
  where tablename = 'store_location_change_requests' and qual = 'true'
union all select 'pending_location_changes', count(*)::text from public.store_location_change_requests where status = 'pending'
union all select 'seller_applications_pending', count(*)::text from public.seller_applications where status = 'pending';
