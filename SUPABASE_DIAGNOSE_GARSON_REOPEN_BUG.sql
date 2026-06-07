-- ============================================================================
-- DIAGNOSE: "Bahçe 1 kapatıldı" → refresh → masa geri açılıyor
-- ============================================================================
-- Bu script masa kapatma akışının HANGİ adımında sessiz fail olduğunu tespit
-- eder.  Önce 1 numaralı sorguyu çalıştırın; sonra 2/3/4/5'i sırasıyla
-- ekrandaki sonuca göre yorumlayın.
--
-- KULLANIM:
--   1. Supabase Dashboard > SQL Editor > "Run as: <senin seller user'ın>"
--      seçeneğiyle çalıştırın.  Anonymous role ile auth.uid() NULL döner
--      ve teşhis bozulur.  Eğer dashboard impersonation desteklemiyorsa,
--      uygulamayı çalıştırıp aynı sorguları console'da olur:
--      Supabase.instance.client.rpc('debug_whoami') ile döndürebiliriz.
--
--   2. Aşağıda <SELLER_ID> yerine UI'da "Satıcı ID: 7264153b..." olarak
--      görünen ID'nin TAM HALİNİ yazın (8 hex değil, 32 hex + tireler).
--      Bu ID'yi bulmak için Supabase Auth > Users sayfasından kullanıcı
--      email'inize karşılık gelen UUID'yi alın.
--
--   3. Aşağıda <TABLE_NUMBER> yerine kapatmaya çalıştığınız fiziksel masa
--      numarasını yazın (örneğin 1 — yani "Bahçe 1").
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- 1) Identity sanity check: kullanıcı kim?  Sub-admin mı, sahip mi?
-- ──────────────────────────────────────────────────────────────────────────
SELECT
  auth.uid() AS my_auth_uid,
  current_user AS sql_role,
  (SELECT email FROM auth.users WHERE id = auth.uid()) AS my_email;
-- Beklenen: auth.uid() NOT NULL ve UI'daki Satıcı ID ile aynı olmalı.
-- Eğer NULL → SQL editor anon role kullanıyor, dashboard'tan
--   "Run as authenticated user" seçeneğini kullanın.


-- ──────────────────────────────────────────────────────────────────────────
-- 2) store_tables: kullanıcının auth.uid()'i ile match eden masa var mı?
-- ──────────────────────────────────────────────────────────────────────────
SELECT
  id,
  seller_id,
  table_number,
  CASE
    WHEN seller_id::text = auth.uid()::text THEN 'OWN'
    ELSE 'OTHER_SELLER (sub-admin scenario)'
  END AS ownership
FROM public.store_tables
WHERE seller_id::text = '<SELLER_ID>'  -- UI'daki Satıcı ID
ORDER BY table_number;
-- Yorum:
--   • Eğer 14 satır görüyorsanız ve hepsi OWN → identity match OK.
--   • Eğer satırlar OTHER_SELLER → bu kullanıcı sub-admin/garson, RLS
--     onun adına orders UPDATE'lerini bloklayacak.


-- ──────────────────────────────────────────────────────────────────────────
-- 3) "Bahçe 1" için orders tablosunda hâlâ aktif satır var mı?
-- ──────────────────────────────────────────────────────────────────────────
WITH target AS (
  SELECT id AS table_id
  FROM public.store_tables
  WHERE seller_id::text = '<SELLER_ID>'
    AND table_number = <TABLE_NUMBER>
)
SELECT
  o.id,
  o.status,
  o.order_status,
  o.table_id,
  o.restaurant_id,
  o.created_at,
  CASE
    WHEN o.restaurant_id::text = auth.uid()::text THEN 'RLS_PASS'
    ELSE 'RLS_BLOCK (orders.restaurant_id <> auth.uid())'
  END AS rls_visibility,
  CASE
    WHEN o.status IN ('closed','paid','cancelled','canceled','completed',
                      'complete','archived','payment_completed','completed_payment')
    THEN 'TERMINAL'
    ELSE 'ACTIVE — bug source'
  END AS state_classification
FROM public.orders o
JOIN target t ON o.table_id = t.table_id
ORDER BY o.created_at DESC;
-- Yorum:
--   • ACTIVE satır varsa → bunlar refresh sonrası masayı geri açan satırlardır.
--   • RLS_BLOCK işaretli satır varsa → kullanıcı bu satırı UPDATE EDEMEZ
--     (auth.uid() <> restaurant_id) → silently fail.


-- ──────────────────────────────────────────────────────────────────────────
-- 4) table_orders tarafında aynı masa için aktif satır var mı?
-- ──────────────────────────────────────────────────────────────────────────
SELECT
  id,
  seller_id,
  table_number,
  status,
  created_at,
  CASE
    WHEN seller_id::text = auth.uid()::text THEN 'RLS_PASS'
    ELSE 'RLS_BLOCK'
  END AS rls_visibility
FROM public.table_orders
WHERE seller_id::text = '<SELLER_ID>'
  AND table_number = <TABLE_NUMBER>
ORDER BY created_at DESC;
-- Yorum:
--   • Eğer hiç satır yoksa → table_orders DELETE başarıyla geçmiş.
--   • Eğer hâlâ satır varsa → DELETE de RLS-blok edilmiş veya RPC sessizce
--     fail etmiş.


-- ──────────────────────────────────────────────────────────────────────────
-- 5) RPC dry-run: close_table_orders bu kullanıcı için çalışıyor mu?
-- ──────────────────────────────────────────────────────────────────────────
SELECT public.close_table_orders(
  p_seller_id := '<SELLER_ID>'::uuid,
  p_table_number := <TABLE_NUMBER>
) AS rpc_result;
-- Yorum:
--   • Hata gelirse (örn. permission denied / 42501) → RPC içindeki
--     `if auth.uid() <> p_seller_id then raise` kısmı tetikleniyor.
--     Bu da kullanıcının sub-admin olduğunu (yani auth.uid() ile
--     p_seller_id'in eşleşmediğini) kesin olarak doğrular.
--   • Sonuç JSON'unda orders_closed=0 ve table_orders_deleted=0 ise →
--     RLS sessizce blokluyor.


-- ──────────────────────────────────────────────────────────────────────────
-- ÇÖZÜM ÇERÇEVESİ (sorgulardan sonra):
-- ──────────────────────────────────────────────────────────────────────────
-- • 2'de OTHER_SELLER görürseniz → kullanıcı sub-admin/garson.  Çözüm:
--     - RPC ve RLS politikalarını sub_admins (veya analog) tablosuyla
--       enriched şekilde "sub-admin parent_seller adına çalışabilsin"
--       diye genişletin.  Pratik: SECURITY DEFINER RPC içinde `auth.uid()`
--       check'ini parent-id resolution'ı destekleyecek şekilde gevşetin.
--
-- • 3'te RLS_BLOCK görürseniz → orders RLS politikası `auth.uid() =
--     restaurant_id` USING/WITH CHECK clause'una sahip.  Kullanıcı bu
--     satırı asla UPDATE edemez.  RPC üzerinden SECURITY DEFINER ile
--     bypass etmek gerekir (zaten close_table_orders böyle yapıyor —
--     ama auth.uid() check'ini geçmek lazım).
--
-- • 4'te aktif table_orders varsa → DELETE de fail.  Aynı kök neden:
--     auth.uid() mismatch.
--
-- • 5'te 42501 hata gelirse → KÖK NEDEN DOĞRULANDI: identity mismatch.
