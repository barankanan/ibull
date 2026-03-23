-- 1. 'stores' tablosuna 'seller_videos' kolonunu ekleyin (Eğer yoksa)
ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS seller_videos text[] DEFAULT '{}';

-- 2. 'product_videos' adında bir storage bucket oluşturun (Eğer yoksa)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('product_videos', 'product_videos', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage Politikaları (Video yükleme ve okuma izinleri)

-- Herkesin videoları görmesine izin ver
CREATE POLICY "Public Videos Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'product_videos');

-- Sadece giriş yapmış kullanıcıların video yüklemesine izin ver
CREATE POLICY "Authenticated Video Upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'product_videos' 
  AND auth.role() = 'authenticated'
);

-- Kullanıcıların kendi yükledikleri videoları güncellemesine/silmesine izin ver
CREATE POLICY "Owner Video Update" 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'product_videos' 
  AND auth.uid() = owner
);

CREATE POLICY "Owner Video Delete" 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'product_videos' 
  AND auth.uid() = owner
);
