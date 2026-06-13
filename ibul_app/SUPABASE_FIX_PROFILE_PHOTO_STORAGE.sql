-- Profil fotoğrafı storage RLS doğrulama / hotfix notu
-- Hata: StorageException 403 — new row violates row-level security policy
--
-- Kök neden (kod tarafı, 2026-06-13 düzeltildi):
--   uploadProfilePhotoBytes yolu `profiles/{uid}/...` idi.
--   store-images INSERT policy ilk klasörün auth.uid()::text olmasını bekler:
--     (storage.foldername(name))[1] = auth.uid()::text
--   Bu yüzden doğru yol: `{uid}/profiles/{timestamp}.jpg`
--
-- Mevcut policy (SUPABASE_FIX_SELLER.sql) zaten {uid}/... yollarını kapsar.
-- Bu dosya prod'da policy varlığını doğrular; eksikse seller policy setini uygular.

-- Bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-images', 'store-images', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- INSERT: authenticated, ilk klasör = auth.uid()
DROP POLICY IF EXISTS "Sellers can upload store images" ON storage.objects;
CREATE POLICY "Sellers can upload store images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- SELECT: public read (profil foto public URL için)
DROP POLICY IF EXISTS "Public can view store images" ON storage.objects;
CREATE POLICY "Public can view store images"
ON storage.objects FOR SELECT
USING (bucket_id = 'store-images');

-- UPDATE (upsert:true profil foto yenileme)
DROP POLICY IF EXISTS "Sellers can update their own store images" ON storage.objects;
CREATE POLICY "Sellers can update their own store images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- DELETE (opsiyonel temizlik)
DROP POLICY IF EXISTS "Sellers can delete their own store images" ON storage.objects;
CREATE POLICY "Sellers can delete their own store images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'store-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Doğrulama (read-only):
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'storage' AND tablename = 'objects'
--   AND policyname ILIKE '%store images%';
