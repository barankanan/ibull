-- P0 marketplace money authority.
-- Apply once in the Supabase SQL editor.
-- Do not run supabase db push. Do not run migration repair.
-- This file was not applied to the remote database when it was added.
--
-- Client payloads cannot set price, shipping, discount, commission,
-- payment status, order status, or user id. Orders are created only by
-- SECURITY DEFINER functions. Authenticated and anonymous roles lose
-- direct INSERT on public.orders and public.order_items.

-- ---------------------------------------------------------------------------
-- Shared guards
-- ---------------------------------------------------------------------------

create or replace function public.marketplace_payload_forbidden_key(p_value jsonb)
returns text
language plpgsql
immutable
as $$
declare
  v_key text;
  v_child jsonb;
  v_found text;
  v_forbidden text[] := array[
    'unit_price', 'price', 'subtotal', 'subtotal_amount', 'total',
    'total_amount', 'total_price', 'discount', 'discount_amount',
    'payment_status', 'order_status', 'commission_rate', 'user_id',
    'status', 'paid'
  ];
begin
  if p_value is null then
    return null;
  end if;
  if jsonb_typeof(p_value) = 'object' then
    for v_key in select jsonb_object_keys(p_value)
    loop
      if v_key = any (v_forbidden) then
        return v_key;
      end if;
      if jsonb_typeof(p_value -> v_key) in ('object', 'array') then
        v_found := public.marketplace_payload_forbidden_key(p_value -> v_key);
        if v_found is not null then
          return v_found;
        end if;
      end if;
    end loop;
    return null;
  end if;
  if jsonb_typeof(p_value) = 'array' then
    for v_child in select value from jsonb_array_elements(p_value)
    loop
      v_found := public.marketplace_payload_forbidden_key(v_child);
      if v_found is not null then
        return v_found;
      end if;
    end loop;
  end if;
  return null;
end;
$$;

revoke all on function public.marketplace_payload_forbidden_key(jsonb) from public;
grant execute on function public.marketplace_payload_forbidden_key(jsonb) to authenticated;

create or replace function public.marketplace_haversine_km(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
returns numeric
language sql
immutable
as $$
  with delta as (
    select
      radians(p_lat2 - p_lat1) as dlat,
      radians(p_lng2 - p_lng1) as dlng,
      radians(p_lat1) as lat1,
      radians(p_lat2) as lat2
  ),
  angle as (
    select
      power(sin(dlat / 2), 2)
        + cos(lat1) * cos(lat2) * power(sin(dlng / 2), 2) as a
    from delta
  )
  select case
    when p_lat1 is null or p_lng1 is null or p_lat2 is null or p_lng2 is null
      then 2.2
    else greatest(
      0.3,
      least(
        50,
        6371 * 2 * atan2(sqrt(a), sqrt(greatest(0, 1 - a)))
      )
    )
  end
  from angle;
$$;

revoke all on function public.marketplace_haversine_km(double precision, double precision, double precision, double precision) from public;

-- Shipping numbers come from store coordinates and the server clock.
-- Client shipping_fee / shipping_amount keys are removed by the caller
-- before this function runs. They are not parameters.
create or replace function public.marketplace_server_shipping_fee(
  p_seller_id uuid,
  p_address jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_lat double precision;
  v_store_lng double precision;
  v_dest_lat double precision;
  v_dest_lng double precision;
  v_km numeric;
  v_hour int;
  v_night boolean;
  v_total numeric;
  v_customer numeric;
  v_seller numeric;
begin
  select s.store_lat, s.store_lng
  into v_store_lat, v_store_lng
  from public.stores s
  where s.seller_id = p_seller_id
  limit 1;

  v_dest_lat := nullif(coalesce(p_address->>'lat', p_address->>'latitude'), '')::double precision;
  v_dest_lng := nullif(coalesce(p_address->>'lng', p_address->>'longitude'), '')::double precision;
  v_km := public.marketplace_haversine_km(v_store_lat, v_store_lng, v_dest_lat, v_dest_lng);
  v_hour := extract(hour from timezone('Europe/Istanbul', clock_timestamp()))::int;
  v_night := v_hour >= 22 or v_hour < 6;
  v_total := round((28 + (v_km * 7) + case when v_night then 12 else 0 end)::numeric, 2);
  v_customer := case
    when v_km <= 3 then 35
    when v_km <= 6 then 45
    else 55
  end;
  v_customer := least(v_customer, v_total);
  v_seller := round((v_total - v_customer)::numeric, 2);
  return jsonb_build_object(
    'distance_km', v_km,
    'total_fee', v_total,
    'customer_fee', v_customer,
    'seller_fee', v_seller,
    'is_night', v_night
  );
exception
  when others then
    return jsonb_build_object(
      'distance_km', 2.2,
      'total_fee', round((28 + (2.2 * 7))::numeric, 2),
      'customer_fee', 35,
      'seller_fee', round((28 + (2.2 * 7) - 35)::numeric, 2),
      'is_night', false
    );
end;
$$;

revoke all on function public.marketplace_server_shipping_fee(uuid, jsonb) from public;
grant execute on function public.marketplace_server_shipping_fee(uuid, jsonb) to authenticated;

alter table public.orders
  add column if not exists payment_status text;

comment on column public.orders.payment_status is
  'Server-owned. Checkout writes pending. paid/refunded require the payment webhook session flag.';

-- ---------------------------------------------------------------------------
-- Direct client inserts cannot create monetary rows
-- ---------------------------------------------------------------------------

drop policy if exists "orders_user_insert" on public.orders;
drop policy if exists "orders_restaurant_insert" on public.orders;
drop policy if exists "order_items_buyer_insert" on public.order_items;
drop policy if exists "order_items_restaurant_insert" on public.order_items;

revoke insert on table public.orders from anon, authenticated;
revoke insert on table public.order_items from anon, authenticated;

create or replace function public.orders_money_authority_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rpc boolean := current_setting('ibul.marketplace_order_rpc', true) = 'on';
  v_webhook boolean := current_setting('ibul.payment_webhook', true) = 'on';
  v_service boolean := coalesce(auth.role(), '') = 'service_role';
  v_allowed boolean := false;
  v_courier boolean := false;
begin
  if v_rpc or v_service then
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode = '42501';
  end if;

  if auth.uid() is not null then
    if to_regprocedure('public.is_ihiz_courier_user(uuid)') is not null then
      execute 'select public.is_ihiz_courier_user($1)' into v_courier using auth.uid();
    end if;
    v_allowed := old.user_id = auth.uid()
      or coalesce(public.is_admin_user(auth.uid()), false)
      or coalesce(v_courier, false);
    if to_regprocedure('public.can_access_order_as_seller(uuid,uuid)') is not null then
      v_allowed := v_allowed or public.can_access_order_as_seller(old.id, auth.uid());
    end if;
    if not v_allowed then
      raise exception 'ORDER_UPDATE_DENIED' using errcode = '42501';
    end if;
  end if;

  if new.user_id is distinct from old.user_id
     or new.subtotal_amount is distinct from old.subtotal_amount
     or new.shipping_amount is distinct from old.shipping_amount
     or new.discount_amount is distinct from old.discount_amount
     or new.total_amount is distinct from old.total_amount
     or new.customer_delivery_fee is distinct from old.customer_delivery_fee
     or new.seller_delivery_fee is distinct from old.seller_delivery_fee
     or new.total_delivery_fee is distinct from old.total_delivery_fee
  then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
  end if;

  if new.payment_status is distinct from old.payment_status
     and lower(coalesce(new.payment_status, '')) in ('paid', 'refunded')
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;

  if lower(coalesce(new.status, '')) in ('paid', 'refunded')
     and lower(coalesce(old.status, '')) is distinct from lower(coalesce(new.status, ''))
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_money_authority on public.orders;
create trigger trg_orders_money_authority
  before insert or update on public.orders
  for each row
  execute function public.orders_money_authority_guard();

-- ---------------------------------------------------------------------------
-- Marketplace checkout RPC
-- ---------------------------------------------------------------------------

drop function if exists public.create_order_from_cart(
  text, jsonb, jsonb, text, text, text, text, text, numeric
);

create or replace function public.create_marketplace_order(
  p_items jsonb,
  p_delivery_address jsonb default '{}'::jsonb,
  p_billing_address jsonb default null,
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
  v_user uuid := auth.uid();
  v_forbidden text;
  v_address jsonb;
  v_saved jsonb;
  v_item jsonb;
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
  v_index int := 0;
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'ORDER_ITEMS_REQUIRED' using errcode = '22023';
  end if;

  v_forbidden := public.marketplace_payload_forbidden_key(p_items);
  if v_forbidden is not null then
    if v_forbidden in ('discount', 'discount_amount') then
      raise exception 'CLIENT_DISCOUNT_REJECTED' using errcode = '42501';
    end if;
    if v_forbidden in ('payment_status', 'order_status', 'status', 'paid') then
      raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
    end if;
    if v_forbidden = 'user_id' then
      raise exception 'CLIENT_IDENTITY_REJECTED' using errcode = '42501';
    end if;
    raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
  end if;
  v_forbidden := public.marketplace_payload_forbidden_key(p_delivery_address);
  if v_forbidden is not null then
    if v_forbidden = 'user_id' then
      raise exception 'CLIENT_IDENTITY_REJECTED' using errcode = '42501';
    end if;
    if v_forbidden in ('payment_status', 'order_status', 'status', 'paid') then
      raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
    end if;
    if v_forbidden in ('discount', 'discount_amount') then
      raise exception 'CLIENT_DISCOUNT_REJECTED' using errcode = '42501';
    end if;
    raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
  end if;

  if v_key is not null then
    select o.id into v_existing
    from public.orders o
    where o.user_id = v_user
      and o.idempotency_key = v_key
    limit 1;
    if v_existing is not null then
      return jsonb_build_object(
        'ok', true,
        'id', v_existing,
        'order_id', v_existing,
        'idempotent_replay', true
      );
    end if;
  end if;

  -- Ignore client shipping keys. Fee is calculated below.
  v_address := coalesce(p_delivery_address, '{}'::jsonb)
    - 'shipping' - 'shipping_fee' - 'shipping_amount'
    - 'customer_delivery_fee' - 'seller_delivery_fee' - 'total_delivery_fee';

  if p_address_id is not null and to_regclass('public.addresses') is not null then
    execute $addr$
      select to_jsonb(a)
      from public.addresses a
      where a.id = $1
        and (
          a.created_by = $2
          or exists (
            select 1 from public.user_saved_addresses usa
            where usa.address_id = a.id and usa.user_id = $2
          )
        )
    $addr$ into v_saved using p_address_id, v_user;
    if v_saved is null then
      raise exception 'ADDRESS_NOT_OWNED' using errcode = '42501';
    end if;
    v_address := v_address || jsonb_strip_nulls(jsonb_build_object(
      'lat', coalesce(v_saved->>'lat', v_saved->>'latitude'),
      'lng', coalesce(v_saved->>'lng', v_saved->>'longitude'),
      'city', coalesce(v_saved->>'city', v_address->>'city'),
      'district', coalesce(v_saved->>'district', v_address->>'district'),
      'address', coalesce(v_saved->>'address', v_saved->>'detail', v_address->>'address')
    ));
  end if;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := btrim(coalesce(v_item->>'product_id', ''));
    v_qty := greatest(1, least(999, coalesce((v_item->>'quantity')::int, 1)));
    if v_product_id = '' then
      raise exception 'ORDER_ITEMS_REQUIRED' using errcode = '22023';
    end if;

    select
      p.seller_id,
      p.name,
      p.store_name,
      coalesce(nullif(p.discount_price, 0), p.price, 0),
      coalesce(p.stock, 0),
      p.main_category,
      p.image_url,
      p.sku,
      p.status,
      coalesce(p.approval_status, p.admin_approval_status)
    into v_seller, v_name, v_store, v_unit, v_stock, v_category, v_image, v_sku, v_status, v_approval
    from public.products p
    where p.id::text = v_product_id
    for update;

    if not found or v_seller is null then
      raise exception 'PRODUCT_NOT_FOR_SALE' using errcode = 'P0002';
    end if;
    select s.business_name
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
    where id::text = v_product_id
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
          v_user,
          'checkout_rpc',
          v_seller,
          v_address,
          'clear',
          coalesce((v_ship->>'is_night')::boolean, false),
          'normal',
          'customer_pays'::public.payer_mode,
          null
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
    billing_address,
    subtotal_amount,
    shipping_amount,
    discount_amount,
    total_amount,
    currency,
    idempotency_key,
    customer_delivery_fee,
    seller_delivery_fee,
    total_delivery_fee,
    wallet_reserve_status
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
    coalesce(p_billing_address, v_address),
    v_subtotal,
    v_customer_fee,
    0,
    greatest(v_subtotal - v_discount, 0) + v_customer_fee,
    'TRY',
    v_key,
    v_customer_fee,
    v_seller_fee,
    v_total_fee,
    'none'
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id,
    seller_id,
    product_id,
    product_code,
    product_name,
    store_name,
    main_category,
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
    line->>'main_category',
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
end;
$$;

revoke all on function public.create_marketplace_order(
  jsonb, jsonb, jsonb, uuid, text, text, text, text, text, text
) from public, anon;
grant execute on function public.create_marketplace_order(
  jsonb, jsonb, jsonb, uuid, text, text, text, text, text, text
) to authenticated;

create or replace function public.cancel_marketplace_order_if_unpaid(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_payment text;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  select user_id, payment_status
  into v_owner, v_payment
  from public.orders
  where id = p_order_id
  for update;
  if not found or v_owner is distinct from v_user then
    raise exception 'ORDER_OWNER_MISMATCH' using errcode = '42501';
  end if;
  if lower(coalesce(v_payment, 'pending')) not in ('pending', '') then
    raise exception 'ORDER_NOT_CANCELLABLE' using errcode = '42501';
  end if;
  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  delete from public.order_items where order_id = p_order_id;
  delete from public.orders where id = p_order_id and user_id = v_user;
end;
$$;

revoke all on function public.cancel_marketplace_order_if_unpaid(uuid) from public, anon;
grant execute on function public.cancel_marketplace_order_if_unpaid(uuid) to authenticated;

comment on function public.create_marketplace_order(
  jsonb, jsonb, jsonb, uuid, text, text, text, text, text, text
) is
  'Checkout source of truth. Ignores client price, shipping, discount, status, and user id.';

drop trigger if exists trg_order_items_money_authority on public.order_items;
create or replace function public.order_items_money_authority_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rpc boolean := current_setting('ibul.marketplace_order_rpc', true) = 'on';
begin
  if v_rpc or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode = '42501';
  end if;
  if new.unit_price is distinct from old.unit_price
     or new.total_price is distinct from old.total_price
     or new.quantity is distinct from old.quantity
     or new.order_id is distinct from old.order_id
     or new.seller_id is distinct from old.seller_id
  then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger trg_order_items_money_authority
  before insert or update on public.order_items
  for each row
  execute function public.order_items_money_authority_guard();

-- Seller external cargo writes public.orders. The seller is auth.uid().
-- Client unit_price, shipping, discount, and paid are not parameters.
-- Customer delivery fee is 0 because the server charges the seller wallet,
-- not because the client sent shipping=0.
create or replace function public.create_seller_external_cargo_order(
  p_items jsonb,
  p_customer_name text,
  p_customer_phone text,
  p_address text,
  p_city text,
  p_district text,
  p_building text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_delivery_type text default 'ihiz_kurye_teslim',
  p_note text default null,
  p_external_reference text default null,
  p_idempotency_key text default null,
  p_cargo_company text default 'İHIZ'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid := auth.uid();
  v_forbidden text;
  v_item jsonb;
  v_product_id text;
  v_qty int;
  v_unit numeric(12,2);
  v_name text;
  v_store text;
  v_image text;
  v_sku text;
  v_status text;
  v_approval text;
  v_product_seller uuid;
  v_stock int;
  v_subtotal numeric(12,2) := 0;
  v_ship jsonb;
  v_seller_fee numeric(12,2) := 0;
  v_total_fee numeric(12,2) := 0;
  v_order_id uuid;
  v_order_number text;
  v_existing uuid;
  v_lines jsonb := '[]'::jsonb;
  v_index int := 0;
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_ref text := nullif(btrim(coalesce(p_external_reference, '')), '');
  v_address jsonb;
begin
  if v_seller is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.stores s where s.seller_id = v_seller) then
    raise exception 'SELLER_STORE_REQUIRED' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'ORDER_ITEMS_REQUIRED' using errcode = '22023';
  end if;
  v_forbidden := public.marketplace_payload_forbidden_key(p_items);
  if v_forbidden is not null then
    if v_forbidden in ('shipping', 'shipping_fee', 'shipping_amount') then
      raise exception 'CLIENT_SHIPPING_REJECTED' using errcode = '42501';
    end if;
    if v_forbidden in ('payment_status', 'order_status', 'status', 'paid') then
      raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
    end if;
    raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
  end if;
  if p_items::text ~* 'shipping_fee|shipping_amount|"shipping"|unit_price|total_price|subtotal|discount|payment_status|"paid"' then
    raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_customer_name, '')), '') is null
     or nullif(btrim(coalesce(p_customer_phone, '')), '') is null
     or nullif(btrim(coalesce(p_address, '')), '') is null
  then
    raise exception 'CUSTOMER_FIELDS_REQUIRED' using errcode = '22023';
  end if;

  if v_key is not null then
    select o.id into v_existing
    from public.orders o
    where o.user_id = v_seller and o.idempotency_key = v_key
    limit 1;
    if v_existing is not null then
      return jsonb_build_object('ok', true, 'id', v_existing, 'order_id', v_existing, 'idempotent_replay', true);
    end if;
  end if;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  select coalesce(s.business_name, 'Harici Sipariş') into v_store
  from public.stores s where s.seller_id = v_seller limit 1;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := btrim(coalesce(v_item->>'product_id', ''));
    v_qty := greatest(1, least(999, coalesce((v_item->>'quantity')::int, 1)));
    if v_product_id = '' then
      raise exception 'PRODUCT_REFERENCE_REQUIRED' using errcode = '22023';
    end if;
    select
      p.seller_id, p.name, coalesce(nullif(p.discount_price, 0), p.price, 0),
      coalesce(p.stock, 0), p.image_url, p.sku, p.status,
      coalesce(p.approval_status, p.admin_approval_status)
    into v_product_seller, v_name, v_unit, v_stock, v_image, v_sku, v_status, v_approval
    from public.products p
    where p.id::text = v_product_id
    for update;
    if not found or v_product_seller is distinct from v_seller or v_unit <= 0 then
      raise exception 'PRODUCT_NOT_FOR_SALE' using errcode = 'P0002';
    end if;
    if lower(coalesce(v_status, '')) not in ('aktif', 'active')
       or lower(coalesce(v_approval, '')) not in ('approved', 'onaylandi', 'onaylandı', 'onayli')
       or v_stock < v_qty
    then
      raise exception 'PRODUCT_NOT_FOR_SALE' using errcode = 'P0002';
    end if;
    update public.products
    set stock = stock - v_qty, updated_at = now()
    where id::text = v_product_id and coalesce(stock, 0) >= v_qty;
    if not found then
      raise exception 'PRODUCT_OUT_OF_STOCK' using errcode = 'P0002';
    end if;
    v_subtotal := v_subtotal + round(v_unit * v_qty, 2);
    v_index := v_index + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'product_name', coalesce(v_name, 'Ürün'),
      'product_code', coalesce(v_sku, v_product_id),
      'product_image_url', v_image,
      'quantity', v_qty,
      'unit_price', v_unit,
      'total_price', round(v_unit * v_qty, 2),
      'station_id', nullif(btrim(coalesce(v_item->>'station_id', '')), '')
    ));
  end loop;

  v_address := jsonb_strip_nulls(jsonb_build_object(
    'fullName', btrim(p_customer_name),
    'name', btrim(p_customer_name),
    'phone', btrim(p_customer_phone),
    'address', btrim(p_address),
    'detail', btrim(p_address),
    'building', nullif(btrim(coalesce(p_building, '')), ''),
    'city', btrim(coalesce(p_city, '')),
    'district', btrim(coalesce(p_district, '')),
    'lat', p_lat,
    'lng', p_lng,
    'note', nullif(btrim(coalesce(p_note, '')), '')
  ));
  v_ship := public.marketplace_server_shipping_fee(v_seller, v_address);
  v_total_fee := coalesce((v_ship->>'total_fee')::numeric, 0);
  v_seller_fee := v_total_fee;

  v_order_number := 'IBUL-EXT-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
  insert into public.orders (
    user_id, order_number, status, payment_status, payment_method,
    payment_card_name, payment_card_last4, delivery_type, delivery_slot,
    delivery_address, subtotal_amount, shipping_amount, discount_amount,
    total_amount, currency, idempotency_key, customer_delivery_fee,
    seller_delivery_fee, total_delivery_fee, wallet_reserve_status
  ) values (
    v_seller, v_order_number, 'confirmed', 'pending', 'external',
    'Harici kanal', '0000', coalesce(nullif(btrim(p_delivery_type), ''), 'ihiz_kurye_teslim'),
    'Harici Sipariş', v_address, v_subtotal, 0, 0, v_subtotal, 'TRY', v_key,
    0, v_seller_fee, v_total_fee, 'none'
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id, seller_id, product_id, product_code, product_name, store_name,
    product_image_url, quantity, unit_price, total_price, status, shipment_step,
    cargo_company, station_id
  )
  select
    v_order_id, v_seller, line->>'product_id', line->>'product_code',
    line->>'product_name', v_store, line->>'product_image_url',
    (line->>'quantity')::int, (line->>'unit_price')::numeric, (line->>'total_price')::numeric,
    'ready_to_ship', 'ready_to_ship', coalesce(nullif(btrim(p_cargo_company), ''), 'İHIZ'),
    nullif(line->>'station_id', '')
  from jsonb_array_elements(v_lines) as line;

  return jsonb_build_object(
    'ok', true,
    'id', v_order_id,
    'order_id', v_order_id,
    'order_number', v_order_number,
    'status', 'confirmed',
    'payment_status', 'pending',
    'subtotal_amount', v_subtotal,
    'shipping_amount', 0,
    'total_amount', v_subtotal,
    'seller_delivery_fee', v_seller_fee,
    'customer_delivery_fee', 0,
    'total_delivery_fee', v_total_fee,
    'external_reference', v_ref,
    'delivery_pricing', jsonb_build_object(
      'customer_delivery_fee', 0,
      'seller_delivery_fee', v_seller_fee,
      'total_delivery_fee', v_total_fee
    ),
    'items', (
      select coalesce(jsonb_agg(to_jsonb(oi)), '[]'::jsonb)
      from public.order_items oi where oi.order_id = v_order_id
    )
  );
end;
$$;

revoke all on function public.create_seller_external_cargo_order(
  jsonb, text, text, text, text, text, text, double precision, double precision,
  text, text, text, text, text
) from public, anon;
grant execute on function public.create_seller_external_cargo_order(
  jsonb, text, text, text, text, text, text, double precision, double precision,
  text, text, text, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- categories bucket: public read, admin write via users.role
-- ---------------------------------------------------------------------------

drop policy if exists "categories_public_insert" on storage.objects;
drop policy if exists "categories_public_update" on storage.objects;
drop policy if exists "categories_public_delete" on storage.objects;
drop policy if exists "categories_admin_insert" on storage.objects;
drop policy if exists "categories_admin_update" on storage.objects;
drop policy if exists "categories_admin_delete" on storage.objects;

drop policy if exists "categories_public_read" on storage.objects;
create policy "categories_public_read"
on storage.objects
for select
to public
using (bucket_id = 'categories');

create policy "categories_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'categories'
  and public.is_admin_user()
);

create policy "categories_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user()
)
with check (
  bucket_id = 'categories'
  and public.is_admin_user()
);

create policy "categories_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user()
);

-- ---------------------------------------------------------------------------
-- seller_ops: no client money, no client PAID, no client refund success
-- ---------------------------------------------------------------------------

do $seller_ops_patch$
begin
  if to_regclass('seller_ops.orders') is null
     or to_regclass('seller_ops.returns') is null
     or to_regclass('seller_ops.refunds') is null
  then
    raise notice 'seller_ops money tables missing; paid order and refund rewrite skipped';
    return;
  end if;

  execute $sql$
    drop function if exists seller_ops.create_paid_order(
      uuid, uuid, text, text, text, numeric, numeric, numeric, jsonb, text, jsonb
    );
    drop function if exists seller_ops.refund_order_return(
      uuid, uuid, text, text, numeric, boolean, jsonb
    );

    drop policy if exists orders_insert_buyer on seller_ops.orders;
    drop policy if exists order_items_insert_by_related_order on seller_ops.order_items;
    revoke insert on table seller_ops.orders from anon, authenticated;
    revoke insert on table seller_ops.order_items from anon, authenticated;
  $sql$;

  execute $sql$
    create or replace function seller_ops.block_client_money()
    returns trigger
    language plpgsql
    security definer
    set search_path = seller_ops, public
    as $fn$
    declare
      v_rpc boolean := current_setting('ibul.seller_ops_rpc', true) = 'on';
      v_webhook boolean := current_setting('ibul.payment_webhook', true) = 'on';
    begin
      if v_rpc or coalesce(auth.role(), '') = 'service_role' then
        if tg_op = 'UPDATE'
           and new.payment_status in ('PAID', 'REFUNDED')
           and old.payment_status is distinct from new.payment_status
           and not v_webhook
           and coalesce(auth.role(), '') <> 'service_role'
        then
          raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
        end if;
        return new;
      end if;
      if tg_op = 'INSERT' then
        raise exception 'SELLER_OPS_INSERT_RPC_ONLY' using errcode = '42501';
      end if;
      if new.buyer_user_id is distinct from old.buyer_user_id
         or new.subtotal is distinct from old.subtotal
         or new.shipping_fee is distinct from old.shipping_fee
         or new.commission_rate is distinct from old.commission_rate
         or new.commission_amount is distinct from old.commission_amount
         or new.net_amount is distinct from old.net_amount
         or new.payment_status is distinct from old.payment_status
      then
        raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
      end if;
      if new.status = 'REFUNDED' and old.status is distinct from 'REFUNDED' then
        raise exception 'CLIENT_REFUND_REJECTED' using errcode = '42501';
      end if;
      return new;
    end;
    $fn$;

    drop trigger if exists trg_seller_ops_money_authority on seller_ops.orders;
    create trigger trg_seller_ops_money_authority
      before insert or update on seller_ops.orders
      for each row
      execute function seller_ops.block_client_money();
  $sql$;

  execute $sql$
    create or replace function seller_ops.create_pending_order(
      p_actor_user_id uuid,
      p_seller_id uuid,
      p_items jsonb,
      p_shipping_address jsonb default '{}'::jsonb,
      p_buyer_note text default null,
      p_idempotency_key text default null
    )
    returns jsonb
    language plpgsql
    security definer
    set search_path = seller_ops, public
    as $fn$
    declare
      v_forbidden text;
      v_item jsonb;
      v_product_id text;
      v_qty int;
      v_unit numeric(12,2);
      v_title text;
      v_sku text;
      v_seller uuid;
      v_subtotal numeric(12,2) := 0;
      v_ship jsonb;
      v_shipping numeric(12,2) := 0;
      v_commission_rate numeric(5,4) := 0.1200;
      v_commission numeric(12,2);
      v_order_id uuid;
      v_order_no text;
    begin
      if auth.uid() is not null and auth.uid() is distinct from p_actor_user_id then
        raise exception 'CLIENT_IDENTITY_REJECTED' using errcode = '42501';
      end if;
      if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then
        raise exception 'AUTH_REQUIRED' using errcode = '42501';
      end if;
      if p_actor_user_id is null or p_seller_id is null then
        raise exception 'AUTH_REQUIRED' using errcode = '42501';
      end if;
      v_forbidden := public.marketplace_payload_forbidden_key(p_items);
      if v_forbidden is not null then
        raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
      end if;
      v_forbidden := public.marketplace_payload_forbidden_key(p_shipping_address);
      if v_forbidden is not null then
        raise exception 'CLIENT_PRICE_REJECTED' using errcode = '42501';
      end if;
      if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
        raise exception 'ORDER_ITEMS_REQUIRED' using errcode = '22023';
      end if;

      perform set_config('ibul.seller_ops_rpc', 'on', true);

      for v_item in select value from jsonb_array_elements(p_items)
      loop
        v_product_id := btrim(coalesce(v_item->>'product_id', ''));
        v_qty := greatest(1, least(999, coalesce((v_item->>'quantity')::int, 1)));
        select
          p.seller_id,
          p.name,
          p.sku,
          coalesce(nullif(p.discount_price, 0), p.price, 0)
        into v_seller, v_title, v_sku, v_unit
        from public.products p
        where p.id::text = v_product_id
        for update;
        if not found or v_seller is distinct from p_seller_id or v_unit <= 0 then
          raise exception 'PRODUCT_NOT_FOR_SALE' using errcode = 'P0002';
        end if;
        v_subtotal := v_subtotal + round(v_unit * v_qty, 2);
      end loop;

      v_ship := public.marketplace_server_shipping_fee(
        p_seller_id,
        coalesce(p_shipping_address, '{}'::jsonb)
          - 'shipping' - 'shipping_fee' - 'shipping_amount'
      );
      v_shipping := coalesce((v_ship->>'customer_fee')::numeric, 0);
      v_commission := round(v_subtotal * v_commission_rate, 2);

      insert into seller_ops.orders (
        buyer_user_id, seller_id, status, payment_status, currency,
        subtotal, shipping_fee, commission_rate, commission_amount, net_amount,
        shipping_address, buyer_note
      ) values (
        p_actor_user_id, p_seller_id, 'NEW', 'PENDING', 'TRY',
        v_subtotal, v_shipping, v_commission_rate, v_commission,
        round(v_subtotal - v_commission, 2),
        coalesce(p_shipping_address, '{}'::jsonb) - 'shipping' - 'shipping_fee' - 'shipping_amount',
        p_buyer_note
      )
      returning id, order_no into v_order_id, v_order_no;

      for v_item in select value from jsonb_array_elements(p_items)
      loop
        v_product_id := btrim(v_item->>'product_id');
        v_qty := greatest(1, least(999, coalesce((v_item->>'quantity')::int, 1)));
        select p.name, p.sku, coalesce(nullif(p.discount_price, 0), p.price, 0)
        into v_title, v_sku, v_unit
        from public.products p
        where p.id::text = v_product_id;
        insert into seller_ops.order_items (
          order_id, product_id, title, sku, quantity, unit_price, total_price
        ) values (
          v_order_id, v_product_id::uuid, coalesce(v_title, 'Ürün'), v_sku,
          v_qty, v_unit, round(v_unit * v_qty, 2)
        );
      end loop;

      insert into seller_ops.payments (
        order_id, provider, provider_payment_id, amount, currency, status, raw
      ) values (
        v_order_id, 'unverified', null, v_subtotal + v_shipping, 'TRY', 'PENDING',
        jsonb_build_object('source', 'create_pending_order', 'paid', false)
      );

      return jsonb_build_object(
        'ok', true,
        'order_id', v_order_id,
        'order_no', v_order_no,
        'payment_status', 'PENDING',
        'subtotal', v_subtotal,
        'shipping_fee', v_shipping
      );
    end;
    $fn$;

    revoke all on function seller_ops.create_pending_order(uuid, uuid, jsonb, jsonb, text, text)
      from public, anon;
    grant execute on function seller_ops.create_pending_order(uuid, uuid, jsonb, jsonb, text, text)
      to authenticated, service_role;
  $sql$;

  execute $sql$
    create or replace function seller_ops.request_return_refund(
      p_actor_user_id uuid,
      p_return_id uuid
    )
    returns jsonb
    language plpgsql
    security definer
    set search_path = seller_ops, public
    as $fn$
    declare
      v_return seller_ops.returns%rowtype;
      v_order seller_ops.orders%rowtype;
      v_paid numeric(12,2);
      v_already numeric(12,2);
      v_amount numeric(12,2);
    begin
      if auth.uid() is not null and auth.uid() is distinct from p_actor_user_id then
        raise exception 'CLIENT_IDENTITY_REJECTED' using errcode = '42501';
      end if;
      if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then
        raise exception 'AUTH_REQUIRED' using errcode = '42501';
      end if;

      select * into v_return from seller_ops.returns where id = p_return_id for update;
      if not found then
        raise exception 'RETURN_NOT_FOUND' using errcode = 'P0002';
      end if;
      select * into v_order from seller_ops.orders where id = v_return.order_id for update;
      perform seller_ops.assert_seller_access(p_actor_user_id, v_return.seller_id);
      if v_return.status not in ('RETURN_APPROVED', 'RETURN_RECEIVED') then
        raise exception 'RETURN_NOT_REFUNDABLE' using errcode = '42501';
      end if;

      select coalesce(amount, v_order.subtotal + v_order.shipping_fee)
      into v_paid
      from seller_ops.payments
      where order_id = v_order.id;

      select coalesce(sum(amount), 0)
      into v_already
      from seller_ops.refunds
      where return_id = p_return_id
        and status = 'SUCCESS';

      v_amount := round(greatest(coalesce(v_paid, 0) - coalesce(v_already, 0), 0), 2);
      if v_amount <= 0 then
        raise exception 'REFUNDABLE_BALANCE_EMPTY' using errcode = '42501';
      end if;

      perform set_config('ibul.seller_ops_rpc', 'on', true);
      insert into seller_ops.refunds (
        return_id, provider, provider_refund_id, amount, status, raw
      ) values (
        p_return_id, 'unverified', null, v_amount, 'PENDING',
        jsonb_build_object('source', 'request_return_refund', 'client_success', false)
      )
      on conflict (return_id) do update
        set amount = excluded.amount,
            status = 'PENDING',
            raw = excluded.raw
      where seller_ops.refunds.status is distinct from 'SUCCESS';

      return jsonb_build_object(
        'ok', true,
        'return_id', p_return_id,
        'refund_status', 'PENDING',
        'amount', v_amount
      );
    end;
    $fn$;

    revoke all on function seller_ops.request_return_refund(uuid, uuid) from public, anon;
    grant execute on function seller_ops.request_return_refund(uuid, uuid)
      to authenticated, service_role;

    create or replace function seller_ops.confirm_provider_refund(
      p_return_id uuid,
      p_provider text,
      p_provider_refund_id text
    )
    returns jsonb
    language plpgsql
    security definer
    set search_path = seller_ops, public
    as $fn$
    declare
      v_amount numeric(12,2);
      v_order_id uuid;
    begin
      if coalesce(auth.role(), '') <> 'service_role'
         and current_setting('ibul.payment_webhook', true) is distinct from 'on'
      then
        raise exception 'CLIENT_REFUND_REJECTED' using errcode = '42501';
      end if;
      select amount into v_amount
      from seller_ops.refunds
      where return_id = p_return_id
      for update;
      if not found then
        raise exception 'REFUND_NOT_FOUND' using errcode = 'P0002';
      end if;
      perform set_config('ibul.payment_webhook', 'on', true);
      perform set_config('ibul.seller_ops_rpc', 'on', true);
      update seller_ops.refunds
      set status = 'SUCCESS',
          provider = coalesce(nullif(btrim(p_provider), ''), provider),
          provider_refund_id = coalesce(p_provider_refund_id, provider_refund_id)
      where return_id = p_return_id;

      select order_id into v_order_id from seller_ops.returns where id = p_return_id;
      update seller_ops.orders
      set status = 'REFUNDED', payment_status = 'REFUNDED'
      where id = v_order_id;
      update seller_ops.payments
      set status = 'REFUNDED'
      where order_id = v_order_id;
      update seller_ops.returns
      set status = 'CLOSED', closed_at = now()
      where id = p_return_id;

      return jsonb_build_object(
        'ok', true,
        'return_id', p_return_id,
        'refund_status', 'SUCCESS',
        'amount', v_amount
      );
    end;
    $fn$;

    revoke all on function seller_ops.confirm_provider_refund(uuid, text, text)
      from public, anon, authenticated;
    grant execute on function seller_ops.confirm_provider_refund(uuid, text, text)
      to service_role;
  $sql$;
end
$seller_ops_patch$;
