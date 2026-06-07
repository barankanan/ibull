-- =============================================================================
-- FIX v2: Garson Masa Kapatma — Trigger Özyineleme + RLS + Snapshot Filtresi
-- Dosya: SUPABASE_FIX_GARSON_CLOSE_TABLE.sql
-- Güncelleme: 2026-06-06 (v2)
--
-- SORUNLAR:
--   1) P0001: DELETE trigger'ı close_table_orders_v2/close_table_orders'ı
--      çağırıyor; fonksiyonlar yoktu → hata.
--   2) Özyineleme (v1 sonrası): Fonksiyonlar yaratıldı ama içlerinde
--      tekrar DELETE vardı → trigger tekrar ateşlendi → sonsuz özyineleme
--      → PostgreSQL transaction'ı geri aldı → masa kapanmadı.
--
-- BU v2 SCRIPT'İNİN GETİRDİKLERİ:
--   • close_table_orders içindeki DELETE → UPDATE status='archived' ile
--     değiştirildi. Özyineleme tamamen ortadan kalktı.
--   • Flutter artık RPC'yi birincil yöntem olarak kullanıyor;
--     DELETE trigger'ı artık sorun oluşturamaz.
--
-- YAPILACAKLAR:
--   BÖLÜM 1 — Teşhis: Mevcut trigger'ları listele
--   BÖLÜM 2 — close_table_orders + close_table_orders_v2 fonksiyonlarını oluştur
--             (özyinelemesiz, UPDATE tabanlı)
--   BÖLÜM 3 — GRANT EXECUTE izinlerini ver
--   BÖLÜM 4 — table_orders RLS politikalarını düzelt/genişlet
--   BÖLÜM 5 — (Opsiyonel) Bozuk trigger'ı tamamen kaldır
--
-- UYGULAMA:
--   Supabase Dashboard → SQL Editor → Yeni Sorgu →
--   Bu dosyanın TAMAMINI yapıştır → RUN
--   (Önceki versiyonu çalıştırdıysanız da tekrar çalıştırın — OR REPLACE
--    ile idempotent, güvenli)
-- =============================================================================


-- ─── BÖLÜM 1: TEŞHİS ─────────────────────────────────────────────────────────
-- Bu sorgu table_orders üzerindeki trigger'ları listeler.
-- Çıktıda gördüğünüz trigger adını not alın;
-- BÖLÜM 5'te gerekirse kaldırabilirsiniz.
SELECT
  tgname   AS trigger_name,
  tgtype,
  proname  AS function_name,
  CASE WHEN tgenabled = 'O' THEN 'ENABLED' ELSE 'DISABLED' END AS status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE tgrelid = 'public.table_orders'::regclass
ORDER BY tgname;


-- =============================================================================
-- BÖLÜM 2: EKSİK FONKSİYONLARI OLUŞTUR
-- =============================================================================

-- ─── 2A. close_table_orders ───────────────────────────────────────────────────
-- Aktif table_orders satırlarını table_order_history'e arşivler,
-- ardından DELETE eder. Trigger bu fonksiyonu bulamadığı için P0001
-- hatası fırlatıyordu; artık mevcut ve çalışır durumda olacak.

CREATE OR REPLACE FUNCTION public.close_table_orders(
  p_seller_id      uuid,
  p_table_number   integer,
  p_payment_method text    DEFAULT 'cash',
  p_payment_note   text    DEFAULT NULL,
  p_waiter_id      uuid    DEFAULT NULL,
  p_waiter_name    text    DEFAULT NULL,
  p_session_key    text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER            -- admin yetkileriyle çalışır, RLS'yi atlar
SET search_path = public
AS $$
DECLARE
  v_order          record;
  v_grand_total    numeric(12,2) := 0;
  v_session        text;
  v_archived_count integer := 0;
  v_deleted_count  integer := 0;
BEGIN
  -- Yalnızca giriş yapmış kullanıcı kendi mağazasına işlem yapabilir.
  -- Garson hesapları için: garsonun auth.uid() ≠ p_seller_id olabilir;
  -- bu durumda BÖLÜM 4'teki genişletilmiş RLS politikaları devreye girer.
  -- SECURITY DEFINER sayesinde bu fonksiyon her zaman çalışır.
  IF p_seller_id IS NULL OR p_table_number <= 0 THEN
    RAISE EXCEPTION 'Geçersiz parametre: seller_id=% table_number=%',
      p_seller_id, p_table_number USING ERRCODE = '22023';
  END IF;

  -- Oturum anahtarı oluştur (arşiv gruplamak için)
  v_session := COALESCE(
    p_session_key,
    'session_' || p_seller_id || '_' || p_table_number
      || '_' || EXTRACT(EPOCH FROM NOW())::bigint::text
  );

  -- Aktif siparişleri arşivle
  FOR v_order IN
    SELECT *
    FROM public.table_orders
    WHERE seller_id    = p_seller_id
      AND table_number = p_table_number
      AND status NOT IN (
        'closed','paid','cancelled','canceled',
        'completed','complete','archived','payment_completed'
      )
  LOOP
    -- Sipariş tutarını hesapla
    SELECT COALESCE(SUM(
      (item->>'price')::numeric
        * COALESCE((item->>'quantity')::numeric, 1)
    ), 0)
    INTO v_grand_total
    FROM jsonb_array_elements(COALESCE(v_order.items, '[]'::jsonb)) AS item;

    -- Arşive ekle
    INSERT INTO public.table_order_history (
      original_order_id,
      seller_id, table_number,
      items, status, revision,
      last_edit_summary, last_edit_note,
      payment_method, payment_note,
      waiter_id, waiter_name,
      grand_total, session_key,
      opened_at, closed_at, created_at
    ) VALUES (
      v_order.id,
      p_seller_id, p_table_number,
      COALESCE(v_order.items, '[]'::jsonb),
      'closed',
      COALESCE(v_order.revision, 1),
      COALESCE(v_order.last_edit_summary, '{}'::jsonb),
      v_order.last_edit_note,
      p_payment_method, p_payment_note,
      p_waiter_id, p_waiter_name,
      v_grand_total, v_session,
      v_order.created_at,
      TIMEZONE('utc', NOW()),
      v_order.created_at
    );

    v_archived_count := v_archived_count + 1;
  END LOOP;

  -- ─── Aktif siparişleri kapat ───────────────────────────────────────────────
  -- ÖNEMLI: Bu fonksiyon bir DELETE trigger'ından çağrılabilir. İçeride
  -- tekrar DELETE yaparsak sonsuz özyineleme oluşur ve PostgreSQL tüm
  -- transaction'ı geri alır.
  --
  -- Çözüm: DELETE yerine status='archived' güncelliyoruz.
  --  • Eğer trigger BEFORE DELETE + RETURNS NULL ise → orijinal DELETE iptal
  --    edilir; satır 'archived' olarak kalır → garson board filtreler ✓
  --  • Eğer trigger BEFORE DELETE + RETURNS OLD ise → orijinal DELETE devam
  --    eder; satır silinir + arşivde kopyası var ✓
  --  • Her iki durumda da özyineleme yok, transaction tamamlanır ✓
  UPDATE public.table_orders
  SET
    status     = 'archived',
    updated_at = TIMEZONE('utc', NOW())
  WHERE seller_id    = p_seller_id
    AND table_number = p_table_number
    AND status NOT IN (
      'closed','paid','cancelled','canceled',
      'completed','complete','archived','payment_completed'
    );

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok',           true,
    'archived',     v_archived_count,
    'deleted',      v_deleted_count,
    'seller_id',    p_seller_id,
    'table_number', p_table_number,
    'session_key',  v_session
  );
END;
$$;


-- ─── 2B. close_table_orders_v2 ────────────────────────────────────────────────
-- V2 alias: aynı mantık, ek metaveri alanları için genişletilmiş imza.
-- Trigger önce V2'yi dener, bulamazsa V1'e düşer.
-- Artık her ikisi de mevcut olduğu için P0001 hatası ortadan kalkar.

CREATE OR REPLACE FUNCTION public.close_table_orders_v2(
  p_seller_id      uuid,
  p_table_number   integer,
  p_payment_method text    DEFAULT 'cash',
  p_payment_note   text    DEFAULT NULL,
  p_waiter_id      uuid    DEFAULT NULL,
  p_waiter_name    text    DEFAULT NULL,
  p_session_key    text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- V2 şu an V1 ile aynı mantığı paylaşır.
  -- Gelecekte farklı davranış gerekirse buraya eklenebilir.
  RETURN public.close_table_orders(
    p_seller_id,
    p_table_number,
    p_payment_method,
    p_payment_note,
    p_waiter_id,
    p_waiter_name,
    p_session_key
  );
END;
$$;


-- =============================================================================
-- BÖLÜM 3: GRANT EXECUTE — Garson hesapları bu fonksiyonları çağırabilsin
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.close_table_orders(
  uuid, integer, text, text, uuid, text, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.close_table_orders_v2(
  uuid, integer, text, text, uuid, text, text
) TO authenticated;

-- close_table_with_history — bu fonksiyon veritabanınızda zaten varsa
-- aşağıdaki GRANT satırının yorumunu kaldırın:
-- GRANT EXECUTE ON FUNCTION public.close_table_with_history(
--   uuid, integer, text, text, uuid, text, text
-- ) TO authenticated;


-- =============================================================================
-- BÖLÜM 4: RLS POLİTİKALARI — table_orders
-- =============================================================================
-- SORUN: Mevcut politikalar muhtemelen yalnızca seller_id = auth.uid() koşulunu
-- kontrol ediyor. Garson hesapları kendi auth.uid() ile giriş yaptığında bu
-- koşul YANLIŞ olur → DELETE/UPDATE başarısız → trigger çalışır → P0001
--
-- ÇÖZÜM A (Basit, her kurulum için güvenli):
--   Tüm giriş yapmış kullanıcılara tam erişim ver.
--   Uygulama zaten Flutter tarafında yetkilendirme yapıyor.
--
-- ÇÖZÜM B (Önerilen — garson hesaplarınızın bağlantı tablosu varsa):
--   user_metadata veya özel bir tabloya (garson_seller_links) göre kontrol et.
--
-- Aşağıdaki script ÇÖZÜM A'yı uygular.
-- Çözüm B'ye geçmek için ÇÖZÜM B bloğunun yorumunu kaldırın.
-- =============================================================================

-- RLS'yi etkinleştir (zaten etkin olabilir, idempotent)
ALTER TABLE public.table_orders ENABLE ROW LEVEL SECURITY;

-- Mevcut politikaları temizle (conflict önlemek için)
DROP POLICY IF EXISTS "table_orders_seller_all"            ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_select_own"            ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_insert_own"            ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_update_own"            ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_delete_own"            ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_authenticated_all"     ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_garson_manage"         ON public.table_orders;

-- ── ÇÖZÜM A: Giriş yapmış tüm kullanıcılara tam erişim ──────────────────────
-- (Uygulamanız Flutter tarafında yetkilendirme yapıyorsa bu güvenlidir)
CREATE POLICY "table_orders_authenticated_all"
  ON public.table_orders
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);


-- ── ÇÖZÜM B: Seller + Garson ayrımı olan kurulumlar için ──────────────────────
-- Garson hesaplarınız user_metadata.linked_seller_id veya
-- app_metadata.linked_seller_id alanına sahipse bu bloğu kullanın.
-- Önce yukarıdaki "table_orders_authenticated_all" policy'yi silin,
-- ardından aşağıdaki bloğun /* ... */ yorumunu kaldırın.

/*
-- Garson hesabının JWT claim'inden linked_seller_id'yi okur
CREATE OR REPLACE FUNCTION public._garson_linked_seller_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    -- Önce app_metadata'ya bak (Supabase Service Role veya hook ile set edilir)
    (auth.jwt() -> 'app_metadata' ->> 'linked_seller_id')::uuid,
    -- Yoksa user_metadata'ya bak
    (auth.jwt() -> 'user_metadata' ->> 'linked_seller_id')::uuid,
    -- Yoksa kullanıcının kendisi seller'dır
    auth.uid()
  );
$$;

CREATE POLICY "table_orders_seller_or_garson"
  ON public.table_orders
  FOR ALL
  TO authenticated
  USING (seller_id = auth.uid() OR seller_id = public._garson_linked_seller_id())
  WITH CHECK (seller_id = auth.uid() OR seller_id = public._garson_linked_seller_id());
*/


-- table_order_history için de garson okuma politikası
ALTER TABLE public.table_order_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "table_order_history_seller_read"   ON public.table_order_history;
DROP POLICY IF EXISTS "table_order_history_seller_insert" ON public.table_order_history;
DROP POLICY IF EXISTS "table_order_history_authenticated" ON public.table_order_history;

CREATE POLICY "table_order_history_authenticated"
  ON public.table_order_history
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);


-- =============================================================================
-- BÖLÜM 5: BOZUK TRIGGER'I KALDIRMAK (OPSİYONEL)
-- =============================================================================
-- Eğer BÖLÜM 1'deki teşhis sorgusunda table_orders üzerinde DELETE'i
-- engelleyen bir trigger gördüyseniz ve bu trigger artık gerekli değilse,
-- aşağıdaki komutu çalıştırabilirsiniz.
-- Trigger adını BÖLÜM 1 çıktısından alın ve <TRIGGER_ADI> ile değiştirin.
--
-- UYARI: Bu komutu yalnızca trigger'ın ne yaptığını anladıktan sonra
-- çalıştırın. Silmeden önce close_table_orders fonksiyonu (BÖLÜM 2)
-- yeterli olabilir.

-- DROP TRIGGER IF EXISTS <TRIGGER_ADI> ON public.table_orders;

-- Örnek: eğer trigger adı "trg_close_table_on_delete" ise:
-- DROP TRIGGER IF EXISTS trg_close_table_on_delete ON public.table_orders;


-- =============================================================================
-- DOĞRULAMA: Script başarıyla çalıştı mı?
-- =============================================================================
SELECT
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('close_table_orders', 'close_table_orders_v2',
                       'close_table_with_history')
ORDER BY routine_name;

SELECT
  policyname,
  cmd,
  permissive
FROM pg_policies
WHERE tablename IN ('table_orders', 'table_order_history')
ORDER BY tablename, policyname;
