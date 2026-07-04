-- İBUL ürün yükleme teşhisi (Supabase SQL Editor)
-- RLS policy değiştirmeden önce yalnızca okuma/teşhis amaçlıdır.

-- 1) Toplam ürün sayısı
select count(*) as total_products from public.products;

-- 2) Aktif ürün sayısı (vitrin status kuralı)
select count(*) as active_products
from public.products
where lower(btrim(coalesce(status, ''))) in ('aktif', 'active');

-- 3) Onaylı ürün sayısı (approval + admin_approval)
select count(*) as approved_products
from public.products
where public.is_public_catalog_product(status, approval_status, admin_approval_status);

-- 4) Anon/public vitrinde görünür ürün (RLS ile aynı kural)
select count(*) as public_catalog_products
from public.products
where public.is_public_catalog_product(status, approval_status, admin_approval_status);

-- 5) Status dağılımı
select status, count(*) as cnt
from public.products
group by status
order by cnt desc;

-- 6) Approval alanları dağılımı
select
  coalesce(approval_status, '(null)') as approval_status,
  coalesce(admin_approval_status, '(null)') as admin_approval_status,
  count(*) as cnt
from public.products
group by 1, 2
order by cnt desc;

-- 7) Aktif ama onaysız (filtrede düşen tipik kayıtlar)
select id, name, status, approval_status, admin_approval_status, seller_id, created_at
from public.products
where lower(btrim(coalesce(status, ''))) in ('aktif', 'active')
  and not public.is_public_catalog_product(status, approval_status, admin_approval_status)
order by created_at desc
limit 50;

-- 8) Seller/store ilişkisi bozuk ürünler
select p.id, p.name, p.seller_id, s.seller_id as store_seller_id, s.business_name
from public.products p
left join public.stores s on s.seller_id = p.seller_id
where p.seller_id is not null
  and s.seller_id is null
limit 50;

-- 9) image_url null/boş ürünler
select count(*) as missing_image_url
from public.products
where coalesce(btrim(image_url), '') = '';

-- 10) Anon rolü ile okuma simülasyonu (service role DEĞİL — SQL Editor postgres ise tam sayı gösterir)
-- Uygulama anon key ile test için REST:
-- GET /rest/v1/products?select=id,status,approval_status&limit=5
-- Header: apikey: <ANON_KEY>, Authorization: Bearer <ANON_KEY>

-- 11) Örnek vitrin ürünleri
select id, name, status, approval_status, admin_approval_status, main_category, price, image_url
from public.products
where public.is_public_catalog_product(status, approval_status, admin_approval_status)
order by created_at desc
limit 20;
