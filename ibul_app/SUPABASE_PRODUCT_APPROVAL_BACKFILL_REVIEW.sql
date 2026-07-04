-- Eski Aktif ürünler için approval backfill (MANUEL İNCELEME SONRASI).
-- Idempotent kolon ekleri + yorumlu UPDATE blokları.
-- Otomatik çalıştırmayın; önce SELECT ile etkilenecek kayıtları doğrulayın.
--
-- Önkoşul: ibul_app/SUPABASE_PUBLIC_PRODUCT_VISIBILITY_FIX.sql uygulanmış olmalı.

-- ---------------------------------------------------------------------------
-- Opsiyonel kolonlar (yoksa ekle)
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists approval_status text;

alter table public.products
  add column if not exists admin_approval_status text;

alter table public.products
  add column if not exists approved_by uuid references public.users (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 1) Etkilenecek kayıtları önce inceleyin (READ-ONLY)
-- ---------------------------------------------------------------------------
-- select id, name, status, approval_status, admin_approval_status, approved_at
-- from public.products
-- where lower(btrim(coalesce(status, ''))) in ('aktif', 'active')
--   and approval_status is null
--   and admin_approval_status is null
-- order by created_at desc;

-- ---------------------------------------------------------------------------
-- 2) DİKKAT: Sadece gerçekten admin onaylı eski Aktif ürünler için kullanın.
--    Onay bekleyen / reddedilen / taslak ürünleri ASLA backfill etmeyin.
-- ---------------------------------------------------------------------------
-- update public.products
-- set approval_status = 'approved',
--     admin_approval_status = 'approved',
--     updated_at = timezone('utc'::text, now())
-- where lower(btrim(coalesce(status, ''))) in ('aktif', 'active')
--   and approval_status is null
--   and admin_approval_status is null;

-- ---------------------------------------------------------------------------
-- 3) Backfill sonrası doğrulama (READ-ONLY)
-- ---------------------------------------------------------------------------
-- select count(*) as still_missing_approval
-- from public.products
-- where lower(btrim(coalesce(status, ''))) in ('aktif', 'active')
--   and approval_status is null
--   and admin_approval_status is null;

-- select count(*) as public_ready
-- from public.products
-- where public.is_public_catalog_product(
--   status,
--   approval_status,
--   admin_approval_status
-- );
