-- Migration: Harden orders against Payment Bypass and Price Tampering
-- Phase 18D: Complete Security Enforcements

BEGIN;

-------------------------------------------------------------------------------
-- 1. HARDEN ORDERS TABLE (API ACCESS)
-------------------------------------------------------------------------------
-- Keep the insert policy for legacy clients but restrict mass assignment in triggers.
-- We must drop and recreate to ensure it's secure.
DROP POLICY IF EXISTS "orders_user_insert" ON public.orders;
CREATE POLICY "orders_user_insert" ON public.orders
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-------------------------------------------------------------------------------
-- 2. HARDEN TABLE_ORDERS (GARSON BOARD)
-------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can insert" ON public.table_orders;
DROP POLICY IF EXISTS "table_orders_authenticated_all" ON public.table_orders;
DROP POLICY IF EXISTS "Seller can delete own" ON public.table_orders;
DROP POLICY IF EXISTS "Seller can read own" ON public.table_orders;
DROP POLICY IF EXISTS "Seller can update own" ON public.table_orders;

-- SELECT (Waiters, sub-admins, and Sellers can view their own store's tables)
CREATE POLICY "table_orders_select" ON public.table_orders
FOR SELECT TO authenticated
USING (public.user_can_access_restaurant(seller_id::uuid));

-- INSERT 
CREATE POLICY "table_orders_insert" ON public.table_orders
FOR INSERT TO authenticated
WITH CHECK (public.user_can_access_restaurant(seller_id::uuid));

-- UPDATE (Cannot change seller_id to steal orders)
CREATE POLICY "table_orders_update" ON public.table_orders
FOR UPDATE TO authenticated
USING (public.user_can_access_restaurant(seller_id::uuid))
WITH CHECK (public.user_can_access_restaurant(seller_id::uuid));

-- DELETE 
CREATE POLICY "table_orders_delete" ON public.table_orders
FOR DELETE TO authenticated
USING (public.user_can_access_restaurant(seller_id::uuid));

-------------------------------------------------------------------------------
-- 3. ADD PAYMENT & STATUS GUARD TRIGGER TO ORDERS
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.orders_status_guard()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.role() = 'authenticated' THEN
    
    -- Guard 1: Card payments can NEVER be marked as 'paid' via REST API by ANY authenticated user.
    -- Must be processed by the PSP webhook (service_role).
    IF NEW.payment_method = 'card' AND NEW.status = 'paid' THEN
       IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'paid') THEN
           RAISE EXCEPTION 'Kredi kartı ödemeleri sadece sistem tarafından onaylanabilir (Payment Bypass Guard).';
       END IF;
    END IF;

    -- Guard 2: Customers can NEVER mark their own orders as 'paid' via REST API.
    IF NEW.status = 'paid' THEN
       IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'paid')) THEN
           IF NEW.user_id = auth.uid() AND (NEW.restaurant_id IS NULL OR NEW.restaurant_id != auth.uid()) THEN
              RAISE EXCEPTION 'Müşteriler siparişi doğrudan ödenmiş olarak işaretleyemez.';
           END IF;
       END IF;
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_orders_status_guard ON public.orders;
CREATE TRIGGER trg_orders_status_guard
  BEFORE INSERT OR UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.orders_status_guard();

-------------------------------------------------------------------------------
-- 4. HARDEN CREATE_ORDER_FROM_CART RPC (PRICE MANIPULATION FIX)
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_order_from_cart(p_idempotency_key text, p_items jsonb, p_delivery_address jsonb DEFAULT '{}'::jsonb, p_delivery_type text DEFAULT 'standard'::text, p_delivery_slot text DEFAULT NULL::text, p_payment_method text DEFAULT 'card'::text, p_payment_card_name text DEFAULT NULL::text, p_payment_card_last4 text DEFAULT NULL::text, p_shipping_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_order_id uuid;
  v_order_number text;
  v_subtotal numeric(12,2) := 0;
  v_item jsonb;
  v_product_id text;
  v_qty int;
  v_unit_price numeric(12,2);
  v_seller_id uuid;
  v_product_name text;
  v_store_name text;
  v_stock int;
  v_existing_order_id uuid;
  v_safe_shipping numeric(12,2) := 0;
  v_quote jsonb;
  v_options jsonb;
  v_option jsonb;
  v_found_option boolean := false;
begin
  if v_user_id is null then
    raise exception 'Giriş yapmanız gerekiyor.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş verilecek ürün bulunamadı.';
  end if;

  if nullif(trim(coalesce(p_idempotency_key, '')), '') is not null then
    select o.id
    into v_existing_order_id
    from public.orders o
    where o.user_id = v_user_id
      and o.idempotency_key = trim(p_idempotency_key)
    limit 1;

    if v_existing_order_id is not null then
      return jsonb_build_object(
        'order_id', v_existing_order_id,
        'idempotent_replay', true
      );
    end if;
  end if;

  v_order_number := 'IBUL-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := trim(coalesce(v_item->>'product_id', ''));
    v_qty := greatest(1, coalesce((v_item->>'quantity')::int, 1));

    select
      p.seller_id,
      p.name,
      coalesce(s.business_name, p.store_name),
      coalesce(nullif(p.discount_price, 0), p.price, 0),
      coalesce(p.stock, 0)
    into v_seller_id, v_product_name, v_store_name, v_unit_price, v_stock
    from public.products p
    left join public.stores s on s.seller_id = p.seller_id
    where p.id::text = v_product_id
    for update;

    if not found then
      raise exception 'Sepetinizdeki bazı ürünler artık satışta değil.';
    end if;

    if v_stock < v_qty then
      raise exception 'Bu ürün şu anda stokta yok.';
    end if;

    v_subtotal := v_subtotal + (v_unit_price * v_qty);
  end loop;

  -- Kargo bedelini sunucudaki güvenilir verilerden doğrula
  IF p_delivery_type IN ('takeaway', 'store_pickup') THEN
     v_safe_shipping := 0;
  ELSE
     -- Get secure delivery quote
     v_quote := public.hybrid_delivery_quote(
        p_actor_user_id := v_user_id,
        p_source := 'checkout_rpc',
        p_seller_id := v_seller_id,
        p_customer_address := coalesce(p_delivery_address, '{}'::jsonb),
        p_payer_mode := 'customer_pays'
     );
     
     if coalesce(v_quote->>'ok', 'false') <> 'true' then
        raise exception 'Teslimat bölgeniz için kargo teklifi alınamadı (Hata: %)', coalesce(v_quote->>'error', 'Unknown');
     end if;
     
     v_options := v_quote->'options';
     
     for v_option in select * from jsonb_array_elements(v_options)
     loop
        if v_option->>'shipment_type' = p_delivery_type and (v_option->>'is_available')::boolean = true then
           v_safe_shipping := (v_option->>'customer_delivery_fee')::numeric;
           v_found_option := true;
           exit;
        end if;
     end loop;

     if not v_found_option then
        raise exception 'Seçtiğiniz teslimat türü (%s) adresiniz için geçerli değil veya kargo teklifi alınamadı.', p_delivery_type;
     end if;
     
     -- Enforce server quote (Prevent client from sending 0 or low fees)
     if coalesce(p_shipping_amount, 0) < v_safe_shipping then
        raise exception 'İletilen kargo tutarı, sunucu hesaplamasıyla uyuşmuyor (Sunucu: %, İstemci: %).', v_safe_shipping, p_shipping_amount;
     end if;
     
     -- Accept client's shipping amount ONLY if it is >= server quote (to prevent any edge case undercharging)
     v_safe_shipping := greatest(v_safe_shipping, coalesce(p_shipping_amount, 0));
  END IF;

  insert into public.orders (
    user_id,
    order_number,
    status,
    payment_method,
    payment_card_name,
    payment_card_last4,
    delivery_type,
    delivery_slot,
    delivery_address,
    subtotal_amount,
    shipping_amount,
    discount_amount,
    total_amount,
    idempotency_key
  ) values (
    v_user_id,
    v_order_number,
    'confirmed', -- Always forced to 'confirmed' by server
    coalesce(nullif(trim(p_payment_method), ''), 'card'),
    p_payment_card_name,
    p_payment_card_last4,
    p_delivery_type,
    p_delivery_slot,
    coalesce(p_delivery_address, '{}'::jsonb),
    v_subtotal,
    v_safe_shipping,
    0,
    v_subtotal + v_safe_shipping, -- Securely calculated total
    nullif(trim(coalesce(p_idempotency_key, '')), '')
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := trim(coalesce(v_item->>'product_id', ''));
    v_qty := greatest(1, coalesce((v_item->>'quantity')::int, 1));

    select p.seller_id, p.name, coalesce(s.business_name, p.store_name), coalesce(nullif(p.discount_price, 0), p.price, 0), coalesce(p.stock, 0)
    into v_seller_id, v_product_name, v_store_name, v_unit_price, v_stock
    from public.products p
    left join public.stores s on s.seller_id = p.seller_id
    where p.id::text = v_product_id;

    update public.products
    set stock = greatest(0, coalesce(stock, 0) - v_qty),
        updated_at = now()
    where id::text = v_product_id
      and coalesce(stock, 0) >= v_qty;

    insert into public.order_items (
      order_id, seller_id, product_id, product_name, store_name, quantity, unit_price, total_price, status
    ) values (
      v_order_id, v_seller_id, v_product_id, v_product_name, v_store_name, v_qty, v_unit_price, v_unit_price * v_qty, 'new'
    );
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id, 'order_number', v_order_number, 'subtotal_amount', v_subtotal, 'total_amount', v_subtotal + v_safe_shipping, 'idempotent_replay', false
  );
end;
$function$;

COMMIT;
