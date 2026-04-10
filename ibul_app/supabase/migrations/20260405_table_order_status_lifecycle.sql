-- =============================================================================
-- Migration: table_order_status_lifecycle
-- Date: 2026-04-05
-- Purpose: Restoran operasyon sistemi için genişletilmiş sipariş durumu yaşam
--          döngüsü. Mevcut 'done'/'sent' kısıtlamasını koruyarak yeni
--          'kitchen', 'ready', 'served' durumlarını ekler.
-- =============================================================================
--
-- Mevcut durum haritası (Phase 1 Flutter UI):
--   'new' / 'waiting'  → Yeni Sipariş (kırmızı)
--   'sent' / 'done'    → Mutfağa İletildi (turuncu)
--   'preparing'        → Hazırlanıyor (teal)
--   'served'           → Servis Edildi (yeşil) [Phase 2]
--   'closed'           → Kapatıldı (silinmeden önce)
--
-- =============================================================================

-- 1) Mevcut check kısıtlamasını kaldır (isim farklı olabilir)
--    Supabase schema editor'da elle oluşturulmuşsa aşağıdaki DROP çalışmaz;
--    Editor'dan manuel kaldırmanız gerekebilir.
DO $$
BEGIN
  -- PostgreSQL 9.1+ ile pg_constraint üzerinden constraint adını bul ve düşür
  DECLARE
    v_constraint_name text;
  BEGIN
    SELECT conname
    INTO v_constraint_name
    FROM pg_constraint c
    JOIN pg_class r ON c.conrelid = r.oid
    JOIN pg_namespace n ON r.relnamespace = n.oid
    WHERE n.nspname = 'public'
      AND r.relname = 'table_orders'
      AND c.contype = 'c'
      AND c.consrc LIKE '%status%'
    LIMIT 1;

    IF v_constraint_name IS NOT NULL THEN
      EXECUTE format(
        'ALTER TABLE public.table_orders DROP CONSTRAINT %I',
        v_constraint_name
      );
    END IF;
  END;
END $$;

-- 2) Yeni genişletilmiş check kısıtlamasını ekle
--    Phase 1 statuses: draft, new, waiting, sent, done, preparing, closed
--    Phase 2 statuses: kitchen, ready, served
ALTER TABLE public.table_orders
  ADD CONSTRAINT table_orders_status_check
  CHECK (status IN (
    'draft',       -- garson taslak (istemci tarafı / henüz gönderilmedi)
    'new',         -- müşteri QR siparişi geldi, garson bekliyor
    'waiting',     -- müşteri QR siparişi bekliyor (new synonimy)
    'sent',        -- mutfağa iletildi (eski DB'lerde = done)
    'done',        -- mutfağa iletildi / legacy terminal
    'preparing',   -- mutfakta hazırlanıyor
    'kitchen',     -- mutfağa iletildi (Phase 2 kesin ad)
    'ready',       -- hazır, servis bekliyor
    'served',      -- servis edildi
    'closed'       -- adisyon kapatıldı (genellikle delete ile)
  ));

-- 3) İndeks: status bazlı sorgu için
CREATE INDEX IF NOT EXISTS idx_table_orders_seller_status
  ON public.table_orders (seller_id, status);

-- 4) İndeks: masa bazlı aktif sipariş sorgusu için
CREATE INDEX IF NOT EXISTS idx_table_orders_seller_table_status
  ON public.table_orders (seller_id, table_number, status);

-- 5) Opsiyonel: sent → done normalizasyonu (eski kayıtlar için)
--    İstersen: UPDATE public.table_orders SET status = 'done' WHERE status = 'sent';
--    Phase 2'de flutter tarafında 'kitchen' statüsüne geçince bu güncelleme yapılabilir.
