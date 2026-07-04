-- Ana sayfa sorgu performansı için indeksler.
-- Idempotent: tablo/kolon yoksa atlanır; RLS/visibility kurallarını gevşetmez.
-- Mevcut projede products.category_id YOK — main_category / sub_category kullanılır.
-- Reklam tablosu: public.campaigns (ad_campaigns değil).

-- ---------------------------------------------------------------------------
-- products — ana sayfa vitrin / kategori / satıcı listeleri
-- ---------------------------------------------------------------------------

-- Ana sayfa feed: status + created_at (getInitialHomeProducts)
create index if not exists idx_products_home_status_created_at
  on public.products (status, created_at desc);

-- Kategori bazlı vitrin (main_category — category_id değil)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'main_category'
  ) then
    execute $sql$
      create index if not exists idx_products_home_main_category_created_at
      on public.products (status, main_category, created_at desc)
    $sql$;
  end if;
end $$;

-- Satıcı + durum (hızlı teslimat / mağaza ürünleri)
create index if not exists idx_products_home_seller_status_created_at
  on public.products (seller_id, status, created_at desc);

-- Onay kolonları varsa vitrin bileşik indeks (SUPABASE_PUBLIC_PRODUCT_VISIBILITY_FIX ile uyumlu)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'approval_status'
  ) then
    execute $sql$
      create index if not exists idx_products_home_public_catalog
      on public.products (status, approval_status, admin_approval_status, created_at desc)
    $sql$;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- campaigns — ana sayfa home_feature / collection_boost reklamları
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.campaigns') is not null then
    execute $sql$
      create index if not exists idx_campaigns_home_type_status_dates
      on public.campaigns (type, status, starts_at, ends_at)
    $sql$;

    execute $sql$
      create index if not exists idx_campaigns_home_active_window
      on public.campaigns (starts_at, ends_at)
      where status in ('active', 'approved', 'scheduled')
    $sql$;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- stores — hızlı teslimat konum sorgusu (getStoresForFastDelivery)
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stores'
      and column_name = 'store_lat'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stores'
      and column_name = 'store_lng'
  ) then
    execute $sql$
      create index if not exists idx_stores_geo_coords
      on public.stores (seller_id)
      where store_lat is not null and store_lng is not null
    $sql$;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- product_images — yalnızca tablo mevcutsa (bu projede çoğu ortamda yok)
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.product_images') is not null then
    execute $sql$
      create index if not exists idx_product_images_product_sort
      on public.product_images (product_id, sort_order)
    $sql$;
  end if;
end $$;
