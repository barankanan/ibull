-- İBUL performans indeksleri ve vitrin sorgu optimizasyonları.
-- Idempotent: güvenle birden fazla kez çalıştırılabilir.
-- Mevcut tabloları değiştirmez; sadece eksik indeksleri ekler.

-- ---------------------------------------------------------------------------
-- products — mağaza menüsü, satıcı paneli, kategori listeleri
-- ---------------------------------------------------------------------------

-- Mağaza menüsü: seller_id + status + created_at (getMenuProductsBySellerId)
create index if not exists idx_products_seller_status_created_at
on public.products (seller_id, status, created_at desc);

-- Kategori/alt kategori listeleri
create index if not exists idx_products_status_sub_category_created_at
on public.products (status, sub_category, created_at desc);

-- Güncelleme zamanına göre sıralama
create index if not exists idx_products_updated_at
on public.products (updated_at desc);

-- Barkod / model kodu aramaları (kolon varsa indeks oluşur)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'barcode'
  ) then
    execute 'create index if not exists idx_products_barcode on public.products (barcode)';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'model_code'
  ) then
    execute 'create index if not exists idx_products_model_code on public.products (model_code)';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- order_items — satıcı sipariş listeleri, hakediş hesapları
-- ---------------------------------------------------------------------------

create index if not exists idx_order_items_seller_created_at
on public.order_items (seller_id, created_at desc);

create index if not exists idx_order_items_product_id_status
on public.order_items (product_id, status);

-- ---------------------------------------------------------------------------
-- campaigns — reklam yönetimi filtreleri
-- ---------------------------------------------------------------------------

create index if not exists idx_campaigns_seller_status
on public.campaigns (seller_id, status);

create index if not exists idx_campaigns_type_status
on public.campaigns (type, status);

-- ---------------------------------------------------------------------------
-- ad_revenue — gelir raporları (tablo varsa)
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.ad_revenue') is not null then
    execute 'create index if not exists idx_ad_revenue_seller_created_at on public.ad_revenue (seller_id, created_at desc)';
    execute 'create index if not exists idx_ad_revenue_campaign_id on public.ad_revenue (campaign_id)';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- seller_payouts — hakediş dönem sorguları (ek bileşik indeks)
-- ---------------------------------------------------------------------------

create index if not exists idx_seller_payouts_seller_period_status
on public.seller_payouts (seller_id, period_start, period_end, status);

-- ---------------------------------------------------------------------------
-- admin_expenses — finans raporları (ek bileşik indeks)
-- ---------------------------------------------------------------------------

create index if not exists idx_admin_expenses_date_status_category
on public.admin_expenses (expense_date desc, status, category);
