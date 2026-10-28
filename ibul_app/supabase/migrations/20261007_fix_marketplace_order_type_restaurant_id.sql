-- Migration to fix Hata 4: Online food orders not visible to Garson because restaurant_id and order_type are NULL

create or replace function public.create_marketplace_order(
  p_items jsonb,
  p_delivery_address jsonb default '{}'::jsonb,
  p_address_id uuid default null,
  p_delivery_type text default 'standard',
  p_delivery_slot text default null,
  p_coupon_code text default null,
  p_idempotency_key text default null,
  p_payment_card_name text default null,
  p_payment_card_last4 text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_key text;
  v_address jsonb;
  v_line jsonb;
  v_index int := 0;
  v_product_id text;
  v_qty int;
  v_unit numeric(12,2);
  v_seller uuid;
  v_name text;
  v_store text;
  v_business text;
  v_category text;
  v_image text;
  v_sku text;
  v_status text;
  v_approval text;
  v_stock int;
  v_subtotal numeric(12,2) := 0;
  v_customer_fee numeric(12,2) := 0;
  v_seller_fee numeric(12,2) := 0;
  v_total_fee numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_order_id uuid;
  v_order_number text;
  v_existing uuid;
  v_lines jsonb := '[]'::jsonb;
  v_coupon_items jsonb := '[]'::jsonb;
  v_seller_fees jsonb := '{}'::jsonb;
  v_seen_sellers uuid[] := array[]::uuid[];
  v_ship jsonb;
  v_quote jsonb;
  v_option jsonb;
  v_coupon jsonb;
  v_free_shipping boolean := false;
  v_restaurant_id uuid := null;
  v_order_type text := 'marketplace';
  v_has_food boolean := false;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  v_key := nullif(btrim(p_idempotency_key), '');
  if v_key is not null then
    select o.id
    into v_existing
    from public.orders o
    where o.user_id = v_user
      and o.idempotency_key = v_key
    limit 1;
    if v_existing is not null then
      return jsonb_build_object(
        'ok', true,
        'id', v_existing,
        'order_id', v_existing,
        'idempotent_replay', true,
        'payment_status', 'pending'
      );
    end if;
  end if;

  v_address := p_delivery_address;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := v_line->>'id';
    if v_product_id is null then
      v_product_id := v_line->>'product_id';
    end if;
    v_qty := (v_line->>'quantity')::int;
    if v_qty is null or v_qty <= 0 then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0002';
    end if;

    select
      p.seller_id,
      p.title,
      p.price,
      coalesce(nullif(btrim(p.store_name), ''), s.store_name),
      p.main_category,
      p.image_url,
      p.sku,
      p.status,
      p.approval_status,
      p.stock
    into
      v_seller, v_name, v_unit, v_store, v_category,
      v_image, v_sku, v_status, v_approval, v_stock
    from public.products p
    left join public.stores s on p.seller_id = s.seller_id
    where p.id = v_product_id
    limit 1;

    if v_seller is null then
      raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
    end if;

    if coalesce(v_category, '') = 'yemek' or coalesce(v_category, '') = 'food' then
      v_has_food := true;
    end if;

    select s.store_name
    into v_business
    from public.stores s
    where s.seller_id = v_seller
    limit 1;
    if v_business is not null and btrim(v_business) <> '' then
      v_store := v_business;
    end if;
    if lower(coalesce(v_status, '')) not in ('aktif', 'active')
       or lower(coalesce(v_approval, '')) not in (
         'approved', 'onaylandi', 'onaylandı', 'onayli'
       )
    then
      raise exception 'PRODUCT_NOT_FOR_SALE' using errcode = 'P0002';
    end if;
    if v_stock < v_qty or v_unit <= 0 then
      raise exception 'PRODUCT_OUT_OF_STOCK' using errcode = 'P0002';
    end if;

    update public.products
    set stock = stock - v_qty,
        updated_at = now()
    where id = v_product_id
      and coalesce(stock, 0) >= v_qty;
    if not found then
      raise exception 'PRODUCT_OUT_OF_STOCK' using errcode = 'P0002';
    end if;

    v_subtotal := v_subtotal + round(v_unit * v_qty, 2);
    v_index := v_index + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'seller_id', v_seller,
      'product_id', v_product_id,
      'product_name', coalesce(v_name, 'Ürün'),
      'store_name', v_store,
      'main_category', v_category,
      'product_image_url', v_image,
      'product_code', coalesce(v_sku, v_product_id),
      'quantity', v_qty,
      'unit_price', v_unit,
      'total_price', round(v_unit * v_qty, 2),
      'status', 'new',
      'shipment_step', 'confirmed',
      'cargo_company', 'ihız'
    ));
    v_coupon_items := v_coupon_items || jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'seller_id', v_seller,
      'main_category', v_category,
      'line_total', round(v_unit * v_qty, 2)
    ));

    if v_seller is not null and not v_seller = any (v_seen_sellers) then
      v_seen_sellers := v_seen_sellers || v_seller;
      v_ship := public.marketplace_server_shipping_fee(v_seller, v_address);
      begin
        v_quote := public.hybrid_delivery_quote(
          p_actor_user_id := v_user,
          p_source := 'checkout_rpc',
          p_seller_id := v_seller,
          p_customer_address := v_address,
          p_weather := 'clear',
          p_is_night := coalesce((v_ship->>'is_night')::boolean, false),
          p_surge_level := 'normal',
          p_payer_mode := 'customer_pays'::public.payer_mode,
          p_selected_company_id := null
        );
        if coalesce(v_quote->>'ok', 'false') = 'true' then
          for v_option in select value from jsonb_array_elements(coalesce(v_quote->'options', '[]'::jsonb))
          loop
            if coalesce((v_option->>'is_available')::boolean, false)
               and (v_option->>'customer_delivery_fee') is not null
            then
              v_ship := v_ship || jsonb_build_object(
                'customer_fee', (v_option->>'customer_delivery_fee')::numeric,
                'seller_fee', coalesce((v_option->>'seller_delivery_fee')::numeric, 0),
                'total_fee', coalesce((v_option->>'delivery_fee')::numeric, (v_option->>'customer_delivery_fee')::numeric),
                'source', 'hybrid_delivery_quote'
              );
              exit;
            end if;
          end loop;
        end if;
      exception
        when undefined_function or invalid_schema_name then
          null;
        when others then
          null;
      end;
      v_customer_fee := v_customer_fee + coalesce((v_ship->>'customer_fee')::numeric, 0);
      v_seller_fee := v_seller_fee + coalesce((v_ship->>'seller_fee')::numeric, 0);
      v_total_fee := v_total_fee + coalesce((v_ship->>'total_fee')::numeric, 0);
      v_seller_fees := v_seller_fees || jsonb_build_object(
        v_seller::text, coalesce((v_ship->>'seller_fee')::numeric, 0)
      );
    end if;
  end loop;

  if cardinality(v_seen_sellers) = 1 then
    v_restaurant_id := v_seen_sellers[1];
    if v_has_food then
      v_order_type := 'online';
    end if;
  end if;

  if nullif(btrim(coalesce(p_coupon_code, '')), '') is not null then
    if to_regprocedure('public.coupon_quote(jsonb)') is null then
      raise exception 'COUPON_ENGINE_UNAVAILABLE' using errcode = 'P0001';
    end if;
    v_coupon := public.coupon_quote(jsonb_build_object(
      'code', btrim(p_coupon_code),
      'items', v_coupon_items
    ));
    if coalesce((v_coupon->>'ok')::boolean, false) is not true then
      raise exception 'CLIENT_DISCOUNT_REJECTED' using errcode = '42501';
    end if;
    v_discount := least(
      coalesce((v_coupon->>'discount_amount')::numeric, 0),
      v_subtotal
    );
    v_free_shipping := coalesce((v_coupon->>'free_shipping')::boolean, false);
    if v_free_shipping then
      v_customer_fee := 0;
    end if;
  end if;

  v_order_number := 'IBUL-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');

  insert into public.orders (
    user_id,
    order_number,
    status,
    payment_status,
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
    currency,
    idempotency_key,
    customer_delivery_fee,
    seller_delivery_fee,
    total_delivery_fee,
    wallet_reserve_status,
    restaurant_id,
    order_type
  ) values (
    v_user,
    v_order_number,
    'confirmed',
    'pending',
    'card',
    p_payment_card_name,
    p_payment_card_last4,
    coalesce(nullif(btrim(p_delivery_type), ''), 'standard'),
    p_delivery_slot,
    v_address,
    v_subtotal,
    v_customer_fee,
    0,
    greatest(v_subtotal - v_discount, 0) + v_customer_fee,
    'TRY',
    v_key,
    v_customer_fee,
    v_seller_fee,
    v_total_fee,
    'none',
    v_restaurant_id,
    v_order_type
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id,
    seller_id,
    product_id,
    product_code,
    product_name,
    store_name,
    product_image_url,
    quantity,
    unit_price,
    total_price,
    status,
    shipment_step,
    cargo_company
  )
  select
    v_order_id,
    (line->>'seller_id')::uuid,
    line->>'product_id',
    line->>'product_code',
    line->>'product_name',
    line->>'store_name',
    line->>'product_image_url',
    (line->>'quantity')::int,
    (line->>'unit_price')::numeric,
    (line->>'total_price')::numeric,
    'new',
    'confirmed',
    'ihız'
  from jsonb_array_elements(v_lines) as line;

  if v_discount > 0 or v_free_shipping then
    v_coupon := public.coupon_apply_to_order(jsonb_build_object(
      'order_id', v_order_id,
      'code', btrim(p_coupon_code),
      'items', v_coupon_items,
      'idempotency_key', v_order_id::text || ':' || btrim(p_coupon_code)
    ));
    if coalesce((v_coupon->>'ok')::boolean, false) is not true then
      raise exception 'CLIENT_DISCOUNT_REJECTED' using errcode = '42501';
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_order_id,
    'order_id', v_order_id,
    'order_number', v_order_number,
    'status', 'confirmed',
    'payment_status', 'pending',
    'subtotal_amount', v_subtotal,
    'shipping_amount', v_customer_fee,
    'discount_amount', v_discount,
    'total_amount', greatest(v_subtotal - v_discount, 0) + v_customer_fee,
    'user_id', v_user,
    'seller_fee_by_seller', v_seller_fees,
    'delivery_pricing', jsonb_build_object(
      'customer_delivery_fee', v_customer_fee,
      'seller_delivery_fee', v_seller_fee,
      'total_delivery_fee', v_total_fee,
      'seller_fee_by_seller', v_seller_fees
    ),
    'items', (
      select coalesce(jsonb_agg(to_jsonb(oi)), '[]'::jsonb)
      from public.order_items oi
      where oi.order_id = v_order_id
    ),
    'idempotent_replay', false
  );
exception
  when unique_violation then
    if v_key is null then
      raise;
    end if;
    select o.id
    into v_existing
    from public.orders o
    where o.user_id = auth.uid()
      and o.idempotency_key = v_key
    limit 1;
    if v_existing is null then
      raise;
    end if;
    return jsonb_build_object(
      'ok', true,
      'id', v_existing,
      'order_id', v_existing,
      'idempotent_replay', true,
      'payment_status', 'pending'
    );
end;
$$;
