-- Migration: Product Security & SKU Unique Constraints
-- 1. Yalnızca yetkili yöneticilerin (admin/superadmin) ürünleri 'Aktif' statüsüne geçirebilmesini sağlar.
-- 2. Aynı satıcının (seller_id) aynı SKU ile birden fazla ürün oluşturmasını engeller (boş SKU'lar hariç).

-- ====================================================================================
-- AŞAMA 2: Admin Onay Güvenliği (Trigger)
-- Satıcılar REST API (Supabase) üzerinden 'Aktif' ürün ekleyemesin/güncelleyemesin.
-- ====================================================================================

CREATE OR REPLACE FUNCTION public.check_product_status_guard()
RETURNS TRIGGER AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- Mevcut kullanıcının (auth.uid) admin veya superadmin olup olmadığını kontrol et
    SELECT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() 
          AND role IN ('admin', 'superadmin', 'system')
    ) INTO v_is_admin;
    
    -- Eğer işlem yapan kişi admin değilse ve ürünü Aktif yapmaya çalışıyorsa:
    IF NOT COALESCE(v_is_admin, FALSE) THEN
        -- status 'Aktif' veya 'active' olarak geliyorsa güvenli state'e zorla
        IF NEW.status IN ('Aktif', 'active', 'aktif') THEN
            NEW.status := 'pending_approval';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_check_product_status_guard ON public.products;
CREATE TRIGGER trg_check_product_status_guard
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.check_product_status_guard();


-- ====================================================================================
-- AŞAMA 3: SKU Çakışması ve Mükerrer Ürün Koruması
-- Aynı satıcıya ait SKU'lar tekil olmalıdır. Farklı satıcılar aynı SKU'yu kullanabilir.
-- Boş (empty string) veya NULL SKU'lar bu kısıtlamadan muaf tutulur.
-- ====================================================================================

-- DİKKAT: CREATE INDEX CONCURRENTLY, transaction bloğu (BEGIN; COMMIT;) içinde çalışmaz!
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_products_seller_sku_unique 
ON public.products (seller_id, btrim(sku)) 
WHERE sku IS NOT NULL AND btrim(sku) != '';

