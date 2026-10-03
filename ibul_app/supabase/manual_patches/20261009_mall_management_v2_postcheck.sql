-- Read-only. Beklenen: her mağazanın tek birincil şubesi ve IBL- kodu var; RPC'ler anon'a kapalı.

select (select count(*) from public.stores) as stores,
       (select count(*) from public.store_branches where is_primary) as primary_branches,
       (select count(*) from public.store_branches where branch_code !~ '^IBL-[A-HJ-NP-Z2-9]{6}$') as bad_codes;

select c.relname, c.relrowsecurity as rls
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('store_branches', 'mall_branch_links', 'mall_campaigns', 'mall_analytics_events')
order by c.relname;

select p.proname,
       has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('mall_find_store_branches', 'request_mall_branch_link', 'respond_mall_branch_link',
    'cancel_mall_branch_link', 'mall_store_links', 'seller_mall_link_requests', 'set_mall_media',
    'set_mall_floor_plan', 'set_mall_unit_position', 'upsert_mall_campaign', 'delete_mall_campaign',
    'create_mall_ad', 'submit_mall_ad', 'mall_ad_campaigns', 'track_mall_event', 'mall_event_stats',
    'mall_member_directory', 'update_mall_member', 'invite_mall_member', 'mall_recent_activity')
order by p.proname;

select policyname from pg_policies
where schemaname = 'storage' and policyname like 'mall_media_member_%'
order by policyname;
