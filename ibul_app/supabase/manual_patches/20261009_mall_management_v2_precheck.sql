-- Read-only. Beklenen: core uygulanmış (mall_floors, mall_units var), v2 nesneleri yok.

select to_regclass('public.mall_floors') as mall_floors,
       to_regclass('public.mall_units') as mall_units,
       to_regclass('public.store_branches') as store_branches,
       to_regclass('public.mall_branch_links') as mall_branch_links,
       to_regclass('public.mall_campaigns') as mall_campaigns,
       to_regclass('public.mall_analytics_events') as mall_analytics_events;

select count(*) as stores_without_seller from public.stores where seller_id is null;

select count(*) as mall_feature_campaigns from public.campaigns where type = 'mall_feature';

select tgname from pg_trigger
where tgrelid in ('public.stores'::regclass, 'public.campaigns'::regclass) and not tgisinternal
order by tgname;
