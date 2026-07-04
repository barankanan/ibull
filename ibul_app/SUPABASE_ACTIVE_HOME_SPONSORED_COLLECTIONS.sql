-- Güvenli ana sayfa sponsorlu koleksiyon okuma.
--
-- Müşteri yalnızca SECURITY DEFINER RPC ile güvenli kolonları okur.
-- campaigns / campaign_assets / campaign_targets tablolarına anon SELECT açılmaz.

-- ── 1. Eski geniş policy ve view temizliği (idempotent) ────────
drop policy if exists campaigns_public_read_active_collection_boost on public.campaigns;
drop policy if exists campaign_assets_public_read_active_collection on public.campaign_assets;
drop policy if exists campaign_targets_public_read_active_collection on public.campaign_targets;
drop view if exists public.active_home_sponsored_collection_ads;

-- ── 2. Güvenli RPC ─────────────────────────────────────────────
-- Önceki sürüm rank_score döndürüyordu; CREATE OR REPLACE return type değiştiremez.
drop function if exists public.fetch_active_home_sponsored_collections(integer);

create or replace function public.fetch_active_home_sponsored_collections(
  p_limit integer default 6
)
returns table (
  campaign_id text,
  seller_id uuid,
  store_id text,
  collection_id text,
  title text,
  cover_url text,
  placement text,
  starts_at timestamptz,
  ends_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  with bounded_limit as (
    select greatest(1, least(coalesce(p_limit, 6), 20)) as row_limit
  ),
  active_campaigns as (
    select
      c.id,
      c.seller_id,
      c.store_id,
      c.name,
      c.starts_at,
      c.ends_at,
      (
        c.bid_amount
        * case when c.is_premium_placement_enabled then 1.2 else 1.0 end
      ) as computed_rank_score
    from public.campaigns c
    where c.type = 'collection_boost'
      and c.status in ('approved', 'active', 'scheduled')
      and c.starts_at <= now()
      and c.ends_at >= now()
  ),
  ranked_assets as (
    select
      ac.id as campaign_id,
      ac.seller_id,
      ac.store_id,
      ac.name,
      ac.starts_at,
      ac.ends_at,
      ac.computed_rank_score,
      a.entity_id as collection_id,
      coalesce(nullif(trim(a.title), ''), ac.name) as title,
      coalesce(
        nullif(trim(a.thumbnail_url), ''),
        nullif(trim(a.media_url), '')
      ) as cover_url,
      row_number() over (
        partition by ac.id
        order by a.priority desc, a.created_at asc
      ) as asset_rank
    from active_campaigns ac
    inner join public.campaign_assets a
      on a.campaign_id = ac.id
    left join public.campaign_targets t
      on t.campaign_id = ac.id
    where coalesce(a.entity_id, '') <> ''
      and (
        (
          coalesce(t.placements, '[]'::jsonb) = '[]'::jsonb
          and coalesce(a.placements, '[]'::jsonb) = '[]'::jsonb
        )
        or coalesce(t.placements, '[]'::jsonb) @> '["home_feed"]'::jsonb
        or coalesce(a.placements, '[]'::jsonb) @> '["home_feed"]'::jsonb
      )
  ),
  ordered_results as (
    select
      ra.campaign_id,
      ra.seller_id,
      ra.store_id,
      ra.collection_id,
      ra.title,
      ra.cover_url,
      'home_feed'::text as placement,
      ra.starts_at,
      ra.ends_at,
      ra.computed_rank_score
    from ranked_assets ra
    where ra.asset_rank = 1
    order by ra.computed_rank_score desc, ra.starts_at desc
    limit (select row_limit from bounded_limit)
  )
  select
    o.campaign_id,
    o.seller_id,
    o.store_id,
    o.collection_id,
    o.title,
    o.cover_url,
    o.placement,
    o.starts_at,
    o.ends_at
  from ordered_results o;
$$;

revoke all on function public.fetch_active_home_sponsored_collections(integer) from public;
grant execute on function public.fetch_active_home_sponsored_collections(integer)
  to anon, authenticated;

comment on function public.fetch_active_home_sponsored_collections(integer) is
  'Müşteri ana sayfası: aktif collection_boost kampanyalarını güvenli kolonlarla döndürür. '
  'Budget/bid/rank/spend/metadata/targeting içermez. Sıralama sunucu tarafında yapılır.';
