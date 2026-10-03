-- Sistem Düzeni içerik merkezi.
-- Geriye uyumlu: veri silmez, mevcut kolonları değiştirmez.
--
-- 1) list_daily_deal_products / list_discoverable_coupons canlı şemada yok
--    (PostgREST PGRST202). 20260916_coupon_engine_wheel.sql içindeki tanımlar
--    yeniden uygulanır. Keşif listesi çark kuponlarını herkese açmaz.
-- 2) app_categories (mobil ana sayfa kısayolları) için kalıcı sıra kolonu ve
--    yalnızca admin yazabilen RLS.

create or replace function public.list_daily_deal_products(p_limit integer default 12)
returns table (
  id text,
  name text,
  brand text,
  image_url text,
  price numeric,
  discount_price numeric,
  discount_percent numeric,
  stock integer,
  seller_id uuid,
  store_name text,
  main_category text,
  sub_category text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.brand,
    p.image_url,
    p.price::numeric,
    p.discount_price::numeric,
    case
      when p.price > 0 and p.discount_price > 0 and p.discount_price < p.price
        then round((1 - p.discount_price / p.price) * 100)
      else 0
    end as discount_percent,
    p.stock,
    p.seller_id,
    s.business_name,
    p.main_category,
    p.sub_category
  from public.products p
  left join public.stores s on s.seller_id = p.seller_id
  where lower(coalesce(p.status, '')) in ('aktif', 'active')
    and (
      lower(coalesce(p.approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
      or lower(coalesce(p.admin_approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
    )
    and coalesce(p.stock, 0) > 0
    and p.discount_price is not null
    and p.discount_price > 0
    and p.price is not null
    and p.discount_price < p.price
    and coalesce(s.is_store_open, true) = true
    and coalesce(s.is_holiday_mode, false) = false
    and coalesce(s.accept_new_orders, true) = true
  order by
    (1 - p.discount_price / nullif(p.price, 0)) desc,
    p.created_at desc
  limit greatest(coalesce(p_limit, 12), 1);
$$;

create or replace function public.list_discoverable_coupons()
returns table (
  id uuid,
  name text,
  description text,
  code text,
  source_type text,
  discount_type text,
  discount_value numeric,
  max_discount numeric,
  min_order_amount numeric,
  starts_at timestamptz,
  ends_at timestamptz,
  store_id uuid,
  store_name text,
  scope_type text,
  effective_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.name,
    c.description,
    c.code,
    c.source_type,
    c.discount_type,
    c.discount_value,
    c.max_discount,
    c.min_order_amount,
    c.starts_at,
    c.ends_at,
    c.store_id,
    s.business_name,
    c.scope_type,
    public.coupon_effective_status(
      c.approval_status, c.lifecycle_status, c.starts_at, c.ends_at, timezone('utc', now())
    )
  from public.coupon_campaigns c
  left join public.stores s on s.seller_id = c.store_id
  where c.is_public = true
    and c.wheel_enabled = false
    and public.coupon_is_redeemable(
      c.approval_status, c.lifecycle_status, c.starts_at, c.ends_at, timezone('utc', now())
    )
    and (c.total_usage_limit is null or c.used_count < c.total_usage_limit)
  order by c.starts_at desc;
$$;

revoke all on function public.list_daily_deal_products(integer) from public;
revoke all on function public.list_discoverable_coupons() from public;
grant execute on function public.list_daily_deal_products(integer) to anon, authenticated;
grant execute on function public.list_discoverable_coupons() to anon, authenticated;

-- Mobil ana sayfa kısayolları
alter table public.app_categories add column if not exists sort_order integer;

with ordered as (
  select id, row_number() over (order by id) as rn
  from public.app_categories
  where sort_order is null
)
update public.app_categories a
set sort_order = o.rn
from ordered o
where a.id = o.id;

-- Mobil menüde daha önce hiç görünmeyen seed kayıtları yayına girmesin.
update public.app_categories
set is_active = false
where category_key not in (
  'yakin_lokasyon', 'urun_listele', 'gorsel_zeka', 'urun_parcala',
  'bana_ozel', 'hizli_yemek', 'yapay_zeka', 'yakinda'
);

alter table public.app_categories enable row level security;

drop policy if exists app_categories_public_read on public.app_categories;
create policy app_categories_public_read
  on public.app_categories
  for select
  using (true);

drop policy if exists app_categories_admin_write on public.app_categories;
create policy app_categories_admin_write
  on public.app_categories
  for all
  to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Kontrol (salt okuma): app_categories üzerinde başka gevşek yazma politikası
-- kalmadığını doğrulayın.
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies where schemaname = 'public' and tablename = 'app_categories';

notify pgrst, 'reload schema';
