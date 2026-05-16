
-- Güvenle tekrar çalıştırılabilir: mevcut politikalar önce silinir, sonra yeniden oluşturulur.
-- Hata 42710 "policy already exists" bu dosyanın eski sürümünden kaynaklanıyordu.

-- Fix missing 'documents' column in seller_applications
ALTER TABLE public.seller_applications
ADD COLUMN IF NOT EXISTS documents jsonb DEFAULT '{}'::jsonb;

-- Bucket'lar (yoksa oluştur)
INSERT INTO storage.buckets (id, name, public)
VALUES ('seller-documents', 'seller-documents', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('store-images', 'store-images', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- NOT: storage.objects tablosunda ALTER/RLS açma YAPMAYIN.
-- Supabase hosted projede "must be owner of table objects" (42501) hatası verir.
-- RLS zaten Supabase tarafından storage.objects üzerinde açıktır.

-- ---------------------------------------------------------------------------
-- 1. seller-documents (Private)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can upload their own seller documents" ON storage.objects;
CREATE POLICY "Users can upload their own seller documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'seller-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can view their own seller documents" ON storage.objects;
CREATE POLICY "Users can view their own seller documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'seller-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Admins can view all seller documents" ON storage.objects;
CREATE POLICY "Admins can view all seller documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'seller-documents'
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  )
);

-- Eski/alternatif isimler (SUPABASE_PERMISSIONS.sql ile çakışmayı temizle)
DROP POLICY IF EXISTS "Users can upload seller documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own seller documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own seller documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own seller documents" ON storage.objects;

-- ---------------------------------------------------------------------------
-- 2. store-images (Public) — logo, banner, galeri, servis kapağı
-- Yol: {seller_uid}/logos|covers|gallery|banners|service-template-covers/...
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can upload store images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can upload store images" ON storage.objects;
CREATE POLICY "Sellers can upload store images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Everyone can view store images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view store images" ON storage.objects;
CREATE POLICY "Public can view store images"
ON storage.objects FOR SELECT
USING (bucket_id = 'store-images');

DROP POLICY IF EXISTS "Sellers can update their own store images" ON storage.objects;
CREATE POLICY "Sellers can update their own store images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Sellers can delete their own store images" ON storage.objects;
CREATE POLICY "Sellers can delete their own store images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------------
-- 3. product-images (Public)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Sellers can upload product images" ON storage.objects;
CREATE POLICY "Sellers can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Everyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Sellers can update their own product images" ON storage.objects;
CREATE POLICY "Sellers can update their own product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Sellers can delete their own product images" ON storage.objects;
CREATE POLICY "Sellers can delete their own product images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
