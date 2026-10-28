-- İBUL Canlı Veritabanı (Supabase) Salt Okunur Denetim Sorguları
-- Bu dosya production üzerinde SQL Editor aracılığıyla manuel çalıştırılıp
-- çıktıların değerlendirilmesi amacıyla hazırlanmıştır. VERİ DEĞİŞTİRMEZ.

-- 1. products Tablosu Trigger Denetimi
-- Admin onayı/statü kontrolü yapan mevcut bir trigger olup olmadığını kontrol eder.
SELECT 
    tgname AS trigger_name,
    tgenabled AS is_enabled,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'public.products'::regclass;

-- 2. products Tablosu RLS (Insert/Update) Politikaları
-- 'Aktif' statüsünün doğrudan INSERT veya UPDATE edilebilmesine karşı
-- WITH CHECK kısıtlamalarını inceler.
SELECT 
    policyname, 
    cmd AS operation, 
    qual AS using_condition, 
    with_check AS check_condition
FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public';

-- 3. SKU Unique Constraint ve İndeks Kontrolü
-- Mükerrer SKU'ları engelleyecek bir indeks olup olmadığını doğrular.
SELECT 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename = 'products' AND schemaname = 'public' 
  AND indexdef ILIKE '%sku%';

-- 4. products Tablosunun Gerçek Kolon Tipleri ve Varsayılanları
-- status kolonunun default değerini ve varlığını doğrular.
SELECT 
    column_name, 
    data_type, 
    column_default 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'products' 
  AND column_name IN ('sku', 'seller_id', 'status');

-- 5. Mükerrer SKU Analizi (Büyük/Küçük Harf ve Boşluk Farklılıkları Dahil)
-- Boş/NULL SKU'lar hariç, aynı satıcının aynı SKU'yu (trimlenmiş) kaç kez kullandığını bulur.
-- RLS kısıtlaması olmadan tüm kayıtları tarar (Admin/Postgres yetkisi ile).
SELECT 
    seller_id, 
    btrim(sku) AS normalized_sku, 
    COUNT(*) AS duplicate_count
FROM public.products
WHERE sku IS NOT NULL AND btrim(sku) != ''
GROUP BY seller_id, btrim(sku)
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 6. Gerçek status Değerlerinin Dağılımı
-- Veritabanında şu an hangi statü değerlerinin ('Aktif', 'active', 'pending_approval' vs.) kullanıldığını listeler.
SELECT 
    status, 
    COUNT(*) AS status_count 
FROM public.products 
GROUP BY status 
ORDER BY status_count DESC;
