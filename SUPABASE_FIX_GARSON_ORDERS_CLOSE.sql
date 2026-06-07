-- =============================================================================
-- FIX: Garson Close — `orders` tablosunu da temizle (schema-safe, v2)
-- Dosya: SUPABASE_FIX_GARSON_ORDERS_CLOSE.sql
-- Tarih: 2026-06-07  13:37
--
-- SORUN:
--   close_table_orders ve close_table_with_history RPC'leri yalnızca
--   `table_orders` üzerinde çalışıyor.  Garson board ise hem `table_orders`
--   hem de `orders` tablosunu okuyor.  Close sonrası `orders` tablosundaki
--   satırlar olduğu gibi kalıyor → refresh sonrası masa "kendiliğinden
--   açılmış" gibi görünüyor.
--
-- ŞEMA KRİTİK NOT (CANLI DB):
--   public.orders ŞU KOLONLARA SAHİP DEĞİL:
--     • table_number            (kullanılmıyor)
--   Sahip OLDUĞU ilgili kolonlar:
--     • table_id      (uuid)    → FK to public.store_tables.id
--     • restaurant_id (uuid)    → seller's canonical UUID
--     • user_id       (uuid)    → auth.uid() at insert time (waiter/seller)
--     • status        (text)    → canonical lifecycle state
--     • order_status  (text)    → nullable, legacy mirror of `status`
--   Kanıt: 20260607_fix_create_table_order_with_print_jobs_impl_orders_schema.sql
--
-- ÇÖZÜM (schema-safe):
--   Her iki RPC'ye, `table_orders` işleminden sonra `orders` tablosunda
--     restaurant_id = p_seller_id
--     AND table_id IN (SELECT id FROM store_tables WHERE seller_id = p_seller_id
--                                                    AND table_number = p_table_number)
--   şartını sağlayan aktif satırları `status='closed'` ile güncelleyen bir
--   blok ekleniyor.  `table_number` kolonu hiç referanslanmıyor → derleme
--   güvenli.  `table_id` filtresi sayesinde başka masaların siparişleri
--   yanlışlıkla kapatılmıyor.
--
-- YETKİLENDİRME NOTU (owner + aktif garson):
--   Önceki versiyon `IF auth.uid() <> p_seller_id THEN 42501` ile owner dışı
--   tüm garson/sub-admin hesaplarını reddediyordu. Uygulama ise garson
--   girişinde `store_sub_admins` kaydını email/telefon eşleşmesiyle buluyor.
--   Bu sürümde RPC, aşağıdaki aktörleri yetkili kabul eder:
--     • auth.uid() = p_seller_id  → mağaza sahibi
--     • `store_sub_admins.status='active'` ve current `users` satırının
--       email/telefonu eşleşiyor → aktif garson/sub-admin
--   İzin filtresi:
--     • permissions içinde `manageOrders` VEYA `viewOrders`
--   Not: `viewOrders` burada geriye dönük uyumluluk için kabul ediliyor;
--   eski davet akışları varsayılan olarak yalnızca bu yetkiyi seçebiliyor.
--
-- UYGULAMA:
--   Supabase Dashboard → SQL Editor → bu dosyanın tamamını yapıştırın → RUN.
--   OR REPLACE kullanıldığı için tekrar çalıştırmak güvenlidir.
-- =============================================================================


-- ─── 0) Drop existing functions to allow return-type change ─────────────────
-- Eski `close_table_with_history` versiyonu `RETURNS void` ile tanımlandığı
-- için CREATE OR REPLACE return type'ı değiştiremez (PG error 42P13).
-- Aynı önlemi `close_table_orders` için de alıyoruz; o da daha eski bir
-- hotfix'te jsonb dışında bir tip ile yayılmış olabilir.
-- IF EXISTS sayesinde bu blok, fonksiyon yoksa sessizce geçer.
DROP FUNCTION IF EXISTS public.close_table_orders(
  uuid, integer, text, text, uuid, text, text
);
DROP FUNCTION IF EXISTS public.close_table_with_history(
  uuid, integer, text, text, uuid, text, text
);


-- ─── ŞEMA KRİTİK NOT (cast kuralları) ────────────────────────────────────────
--   Canlı DB üzerinde yapılan diagnostic sorgu kanıtı (42883 hatası ile):
--     • public.table_orders.seller_id  → TEXT
--     • public.orders.restaurant_id    → UUID
--     • public.store_tables.seller_id  → büyük olasılıkla UUID (henüz hata
--       vermedi); ancak DEFENSİF olarak ::text karşılaştırması yapıyoruz
--       — UUID kolonun text karşılaştırması güvenli/legal, tersi değil.
--   Bu yüzden: TEXT kolonlarına `p_seller_id::text` cast ediyoruz; UUID
--   kolonlara cast ETMİYORUZ.


-- ─── 1) close_table_orders — orders UPDATE bloğu ekleniyor ───────────────────
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
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order                 record;
  v_grand_total           numeric(12,2) := 0;
  v_session               text;
  v_archived_count        integer := 0;
  v_table_orders_updated  integer := 0;
  v_orders_updated        integer := 0;
  v_actor_authorized      boolean := false;
  v_actor_email           text := '';
  v_actor_phone           text := '';
BEGIN
  IF p_seller_id IS NULL OR p_table_number <= 0 THEN
    RAISE EXCEPTION 'Geçersiz parametre.' USING ERRCODE = '22023';
  END IF;

  v_actor_email := lower(trim(COALESCE(
    NULLIF(current_setting('request.jwt.claim.email', true), ''),
    NULLIF(auth.jwt() ->> 'email', ''),
    NULLIF(auth.jwt() -> 'user_metadata' ->> 'email', ''),
    NULLIF((
      SELECT u.email
      FROM public.users u
      WHERE u.id = auth.uid()
      LIMIT 1
    ), ''),
    ''
  )));
  v_actor_phone := trim(COALESCE(
    NULLIF(current_setting('request.jwt.claim.phone', true), ''),
    NULLIF(auth.jwt() ->> 'phone', ''),
    NULLIF((
      SELECT u.phone
      FROM public.users u
      WHERE u.id = auth.uid()
      LIMIT 1
    ), ''),
    ''
  ));

  SELECT (
    auth.uid() = p_seller_id
    OR EXISTS (
      SELECT 1
      FROM public.store_sub_admins sa
      WHERE sa.store_id = p_seller_id
        AND sa.status = 'active'
        AND (
          (
            sa.email IS NOT NULL
            AND trim(sa.email) <> ''
            AND v_actor_email <> ''
            AND lower(trim(sa.email)) = v_actor_email
          )
          OR (
            sa.phone IS NOT NULL
            AND trim(sa.phone) <> ''
            AND v_actor_phone <> ''
            AND trim(sa.phone) = v_actor_phone
          )
        )
        AND (
          sa.permissions IS NULL
          OR cardinality(sa.permissions) = 0
          OR 'manageOrders' = ANY(sa.permissions)
          OR 'viewOrders' = ANY(sa.permissions)
        )
    )
  )
  INTO v_actor_authorized;

  IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;

  v_session := COALESCE(p_session_key, 'manual-' || gen_random_uuid()::text);

  -- ── table_orders kapatma (mevcut davranış) ──────────────────────────────
  -- UPDATE-only path: status='archived' (DELETE trigger döngüsünden kaçınmak için).
  -- ⚠️ table_orders.seller_id TEXT → p_seller_id::text cast'i zorunlu.
  -- ⚠️ Bazı canlı kurulumlarda aşağıdaki kolonlar YOK:
  --      • total_amount
  --      • session_key
  --      • payment_method
  --      • payment_note
  --    Bu yüzden:
  --      • grand_total hesaplamasını `items` JSONB içinden türetiyoruz
  --      • table_orders UPDATE yalnızca status/updated_at alanlarını yazar
  WITH active_orders AS (
    SELECT
      t.id,
      COALESCE(
        (
          SELECT SUM(
            COALESCE(
              NULLIF(item ->> 'line_total', '')::numeric,
              COALESCE(NULLIF(item ->> 'price', '')::numeric, 0)
              * COALESCE(NULLIF(item ->> 'quantity', '')::numeric, 1)
            )
          )
          FROM jsonb_array_elements(COALESCE(t.items, '[]'::jsonb)) AS item
        ),
        0
      )::numeric(12,2) AS order_total
    FROM public.table_orders
    AS t
    WHERE seller_id = p_seller_id::text
      AND table_number = p_table_number
      AND COALESCE(status, '') NOT IN ('archived','closed','cancelled','canceled','completed','complete','paid')
    FOR UPDATE
  ),
  updated AS (
    UPDATE public.table_orders
    SET status        = 'archived',
        updated_at    = TIMEZONE('utc', NOW())
    WHERE id IN (SELECT id FROM active_orders)
    RETURNING id
  )
  SELECT
    COALESCE((SELECT COUNT(*) FROM updated), 0),
    COALESCE((SELECT SUM(order_total) FROM active_orders), 0)
  INTO v_table_orders_updated, v_grand_total
  ;

  v_archived_count := v_table_orders_updated;

  -- ── BUG-FIX (Reopen Bug) ────────────────────────────────────────────────
  --   public.orders → status='closed' for the SAME physical table only.
  --   Strict scoping rules:
  --     1) restaurant_id = p_seller_id  (canonical seller identity, UUID)
  --     2) table_id      IN (resolved store_tables.id list)
  --     3) order_type='table' OR delivery_type='table'
  --     4) NOT already terminal
  --   table_number kolonu HİÇ referanslanmıyor (kolon yok).
  --   store_tables.seller_id için defensif `::text` karşılaştırması — UUID
  --   olsa bile text cast'i güvenli; TEXT ise zorunlu.
  WITH target_ids AS (
    SELECT id
    FROM public.store_tables
    WHERE seller_id::text = p_seller_id::text
      AND table_number    = p_table_number
  ),
  closed_orders AS (
    UPDATE public.orders o
    SET status       = 'closed',
        order_status = 'closed',
        updated_at   = TIMEZONE('utc', NOW())
    WHERE o.restaurant_id = p_seller_id
      AND (o.order_type = 'table' OR o.delivery_type = 'table')
      AND o.table_id IN (SELECT id FROM target_ids)
      AND COALESCE(o.status, '') NOT IN (
        'closed','paid','cancelled','canceled',
        'completed','complete','archived','payment_completed'
      )
    RETURNING o.id
  )
  SELECT COUNT(*) INTO v_orders_updated FROM closed_orders;

  RETURN jsonb_build_object(
    'archived_count',       v_archived_count,
    'table_orders_updated', v_table_orders_updated,
    'orders_updated',       v_orders_updated,
    'grand_total',          v_grand_total,
    'session_key',          v_session
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_table_orders(
  uuid, integer, text, text, uuid, text, text
) TO authenticated;


-- ─── 2) close_table_with_history — orders UPDATE bloğu ekleniyor ─────────────
CREATE OR REPLACE FUNCTION public.close_table_with_history(
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
DECLARE
  v_history_id          uuid;
  v_grand_total         numeric(12,2) := 0;
  v_session             text;
  v_table_orders_count  integer := 0;
  v_orders_updated      integer := 0;
  v_actor_authorized    boolean := false;
  v_actor_email         text := '';
  v_actor_phone         text := '';
BEGIN
  IF p_seller_id IS NULL OR p_table_number <= 0 THEN
    RAISE EXCEPTION 'Geçersiz parametre.' USING ERRCODE = '22023';
  END IF;

  v_actor_email := lower(trim(COALESCE(
    NULLIF(current_setting('request.jwt.claim.email', true), ''),
    NULLIF(auth.jwt() ->> 'email', ''),
    NULLIF(auth.jwt() -> 'user_metadata' ->> 'email', ''),
    NULLIF((
      SELECT u.email
      FROM public.users u
      WHERE u.id = auth.uid()
      LIMIT 1
    ), ''),
    ''
  )));
  v_actor_phone := trim(COALESCE(
    NULLIF(current_setting('request.jwt.claim.phone', true), ''),
    NULLIF(auth.jwt() ->> 'phone', ''),
    NULLIF((
      SELECT u.phone
      FROM public.users u
      WHERE u.id = auth.uid()
      LIMIT 1
    ), ''),
    ''
  ));

  SELECT (
    auth.uid() = p_seller_id
    OR EXISTS (
      SELECT 1
      FROM public.store_sub_admins sa
      WHERE sa.store_id = p_seller_id
        AND sa.status = 'active'
        AND (
          (
            sa.email IS NOT NULL
            AND trim(sa.email) <> ''
            AND v_actor_email <> ''
            AND lower(trim(sa.email)) = v_actor_email
          )
          OR (
            sa.phone IS NOT NULL
            AND trim(sa.phone) <> ''
            AND v_actor_phone <> ''
            AND trim(sa.phone) = v_actor_phone
          )
        )
        AND (
          sa.permissions IS NULL
          OR cardinality(sa.permissions) = 0
          OR 'manageOrders' = ANY(sa.permissions)
          OR 'viewOrders' = ANY(sa.permissions)
        )
    )
  )
  INTO v_actor_authorized;

  IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;

  v_session := COALESCE(p_session_key, 'history-' || gen_random_uuid()::text);

  -- 1) table_orders snapshot → archive
  -- ⚠️ table_orders.seller_id TEXT → p_seller_id::text cast'i zorunlu.
  -- ⚠️ `table_orders.total_amount` her canlı DB'de yok; bu yüzden archive
  --    grand_total değerini `items` JSONB toplamından hesaplıyoruz.
  WITH src AS (
    SELECT *
    FROM public.table_orders
    WHERE seller_id    = p_seller_id::text
      AND table_number = p_table_number
      AND COALESCE(status, '') NOT IN ('archived','closed','cancelled','canceled','completed','complete','paid')
    FOR UPDATE
  )
  INSERT INTO public.table_order_history (
    seller_id, table_number, session_key,
    payment_method, payment_note,
    waiter_id, waiter_name,
    grand_total, archived_orders, archived_at
  )
  SELECT
    p_seller_id,
    p_table_number,
    v_session,
    p_payment_method,
    p_payment_note,
    p_waiter_id,
    p_waiter_name,
    COALESCE(
      SUM(
        COALESCE(
          (
            SELECT SUM(
              COALESCE(
                NULLIF(item ->> 'line_total', '')::numeric,
                COALESCE(NULLIF(item ->> 'price', '')::numeric, 0)
                * COALESCE(NULLIF(item ->> 'quantity', '')::numeric, 1)
              )
            )
            FROM jsonb_array_elements(COALESCE(src.items, '[]'::jsonb)) AS item
          ),
          0
        )
      ),
      0
    ),
    COALESCE(jsonb_agg(to_jsonb(src) ORDER BY src.created_at), '[]'::jsonb),
    TIMEZONE('utc', NOW())
  FROM src
  RETURNING id, grand_total
  INTO v_history_id, v_grand_total;

  IF v_history_id IS NULL THEN
    v_grand_total := 0;
    RAISE LOG '[close_table_with_history] no active table_orders to archive for seller=% table=%', p_seller_id, p_table_number;
  END IF;

  -- 2) table_orders → status='archived' (DELETE trigger döngüsünden kaçınmak için).
  -- ⚠️ Bazı canlı DB'lerde session_key/payment_method/payment_note kolonları
  --    yok; bu yüzden yalnızca status + updated_at yazıyoruz.
  -- ⚠️ table_orders.seller_id TEXT → cast.
  WITH updated AS (
    UPDATE public.table_orders
    SET status         = 'archived',
        updated_at     = TIMEZONE('utc', NOW())
    WHERE seller_id    = p_seller_id::text
      AND table_number = p_table_number
      AND COALESCE(status, '') NOT IN ('archived','closed','cancelled','canceled','completed','complete','paid')
    RETURNING id
  )
  SELECT COUNT(*) INTO v_table_orders_count FROM updated;

  -- 3) ── BUG-FIX (Reopen Bug) ────────────────────────────────────────────
  --   public.orders → status='closed' (schema-safe, table_id ile sınırlı).
  --   store_tables.seller_id defensif `::text` karşılaştırma.
  WITH target_ids AS (
    SELECT id
    FROM public.store_tables
    WHERE seller_id::text = p_seller_id::text
      AND table_number    = p_table_number
  ),
  closed_orders AS (
    UPDATE public.orders o
    SET status       = 'closed',
        order_status = 'closed',
        updated_at   = TIMEZONE('utc', NOW())
    WHERE o.restaurant_id = p_seller_id
      AND (o.order_type = 'table' OR o.delivery_type = 'table')
      AND o.table_id IN (SELECT id FROM target_ids)
      AND COALESCE(o.status, '') NOT IN (
        'closed','paid','cancelled','canceled',
        'completed','complete','archived','payment_completed'
      )
    RETURNING o.id
  )
  SELECT COUNT(*) INTO v_orders_updated FROM closed_orders;

  RETURN jsonb_build_object(
    'history_id',           v_history_id,
    'grand_total',          v_grand_total,
    'session_key',          v_session,
    'table_orders_updated', v_table_orders_count,
    'orders_updated',       v_orders_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_table_with_history(
  uuid, integer, text, text, uuid, text, text
) TO authenticated;


-- ─── 3) PostgREST cache reload — yeni return shape için ──────────────────────
NOTIFY pgrst, 'reload schema';


-- =============================================================================
-- SCHEMA-SAFETY DOĞRULAMASI (manuel, çalıştırmadan önce çalıştır):
--
--   1) public.orders'ta table_number kolonu YOK olmalı (bu fix bunu varsayar):
--      SELECT column_name FROM information_schema.columns
--      WHERE table_schema='public' AND table_name='orders'
--        AND column_name IN ('table_number','table_id','restaurant_id','user_id',
--                            'status','order_status','order_type','delivery_type');
--      → table_number YOK, diğerleri olmalı.
--
--   2) Test: belirli bir (seller_id, table_number) için kapatma sayımı.
--      SELECT jsonb_pretty(public.close_table_orders(
--        '<seller-uuid>'::uuid, <table_number>::int));
--      → orders_updated alanı kapatılan müşteri sipariş sayısını gösterir.
-- =============================================================================
