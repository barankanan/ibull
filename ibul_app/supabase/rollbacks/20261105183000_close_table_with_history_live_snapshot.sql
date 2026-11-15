-- Live pg_get_functiondef captured 2026-11-06 before any apply of
-- 20261105183000_close_table_history_order_id.sql.
-- Project ref: ihmixxzqnpamcwmrfibx
-- Database: PostgreSQL 17.6
-- Signature: close_table_with_history(uuid,integer,text,text,uuid,text,text)
-- Owner: postgres
-- SECURITY DEFINER, search_path=public
-- EXECUTE: anon, authenticated, postgres, service_role
-- Definition md5 reported by the database: 9a8fd33a7b70b81d39be66a019879808
--
-- Do not run this unless 20261105183000 was applied and must be undone.
-- This statement does not delete history, orders, or payments.
-- Restoring this body brings PostgreSQL 23502 back, because the INSERT
-- omits table_order_history.original_order_id.
--
-- This file was saved locally only. It was not executed.

CREATE OR REPLACE FUNCTION public.close_table_with_history(p_seller_id uuid, p_table_number integer, p_payment_method text DEFAULT 'cash'::text, p_payment_note text DEFAULT NULL::text, p_waiter_id uuid DEFAULT NULL::uuid, p_waiter_name text DEFAULT NULL::text, p_session_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

    perform public.restaurant_staff_may_operate(p_seller_id, 'closeBill', p_table_number);


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
$function$
;
