-- Checkout / sipariş oluşturma güvenlik sertleştirmesi
-- Uygulama: Supabase SQL Editor veya migration pipeline
-- Not: Flutter tarafında client doğrulaması eklendi; bu dosya atomik DB katmanını hedefler.

-- 1) Idempotency anahtarı (çift sipariş koruması)
alter table public.orders
  add column if not exists idempotency_key text;

create unique index if not exists idx_orders_user_idempotency
  on public.orders (user_id, idempotency_key)
  where idempotency_key is not null;

-- 2) Yardımcı: ürün müşteri sepeti/checkout için uygun mu?
create or replace function public.is_customer_checkout_eligible_product(p_product_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.products p
    where p.id::text = p_product_id
      and lower(coalesce(p.status, '')) in ('aktif', 'active')
      and lower(coalesce(p.approval_status, p.admin_approval_status, '')) in (
        'approved', 'onaylandi', 'onaylandı', 'onayli'
      )
      and coalesce(p.stock, 0) > 0
  );
$$;

revoke all on function public.is_customer_checkout_eligible_product(text) from public;
grant execute on function public.is_customer_checkout_eligible_product(text) to authenticated;

-- 3) Atomik sipariş oluşturma RPC (öneri — Flutter entegrasyonu ayrı adım)
-- p_items jsonb örneği:
-- [{"product_id":"uuid","quantity":2}]
create or replace function public.create_order_from_cart(
  p_idempotency_key text,
  p_items jsonb,
  p_delivery_address jsonb default '{}'::jsonb,
  p_delivery_type text default 'standard',
  p_delivery_slot text default null,
  p_payment_method text default 'card',
  p_payment_card_name text default null,
  p_payment_card_last4 text default null,
  p_shipping_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

  -- Ön doğrulama + subtotal
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := trim(coalesce(v_item->>'product_id', ''));
    v_qty := greatest(1, coalesce((v_item->>'quantity')::int, 1));

    if v_product_id = '' then
      raise exception 'Sepetinizdeki bazı ürünler artık satışta değil.';
    end if;

    if not public.is_customer_checkout_eligible_product(v_product_id) then
      raise exception 'Bu ürün şu anda satışta değil.';
    end if;

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
    'confirmed',
    coalesce(nullif(trim(p_payment_method), ''), 'card'),
    p_payment_card_name,
    p_payment_card_last4,
    p_delivery_type,
    p_delivery_slot,
    coalesce(p_delivery_address, '{}'::jsonb),
    v_subtotal,
    coalesce(p_shipping_amount, 0),
    0,
    v_subtotal + coalesce(p_shipping_amount, 0),
    nullif(trim(coalesce(p_idempotency_key, '')), '')
  )
  returning id into v_order_id;

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

    if v_stock < v_qty then
      raise exception 'Bu ürün şu anda stokta yok.';
    end if;

    update public.products
    set stock = greatest(0, coalesce(stock, 0) - v_qty),
        updated_at = now()
    where id::text = v_product_id
      and coalesce(stock, 0) >= v_qty;

    if not found then
      raise exception 'Bu ürün şu anda stokta yok.';
    end if;

    insert into public.order_items (
      order_id,
      seller_id,
      product_id,
      product_name,
      store_name,
      quantity,
      unit_price,
      total_price,
      status
    ) values (
      v_order_id,
      v_seller_id,
      v_product_id,
      v_product_name,
      v_store_name,
      v_qty,
      v_unit_price,
      v_unit_price * v_qty,
      'new'
    );
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal_amount', v_subtotal,
    'total_amount', v_subtotal + coalesce(p_shipping_amount, 0),
    'idempotent_replay', false
  );
exception
  when others then
    raise;
end;
$$;

revoke all on function public.create_order_from_cart(
  text, jsonb, jsonb, text, text, text, text, text, numeric
) from public;
grant execute on function public.create_order_from_cart(
  text, jsonb, jsonb, text, text, text, text, text, numeric
) to authenticated;

comment on function public.create_order_from_cart is
  'Atomik checkout: auth kontrolü, ürün görünürlük/stok/fiyat DB doğrulaması, order+items+stok düşümü, idempotency.';
