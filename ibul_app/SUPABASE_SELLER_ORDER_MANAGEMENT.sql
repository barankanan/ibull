create extension if not exists pgcrypto;

create schema if not exists seller_ops;

create type seller_ops.order_status as enum (
  'NEW',
  'PREPARING',
  'READY_TO_SHIP',
  'SHIPPED',
  'DELIVERED',
  'CANCELED',
  'RETURN_REQUESTED',
  'RETURN_APPROVED',
  'RETURN_SHIPPED_BACK',
  'RETURN_RECEIVED',
  'REFUNDED'
);

create type seller_ops.payment_status as enum (
  'PENDING',
  'PAID',
  'FAILED',
  'REFUNDED'
);

create type seller_ops.shipment_status as enum (
  'NONE',
  'LABEL_CREATED',
  'SHIPPED',
  'IN_TRANSIT',
  'DELIVERED'
);

create type seller_ops.return_status as enum (
  'RETURN_REQUESTED',
  'RETURN_REJECTED',
  'RETURN_APPROVED',
  'RETURN_SHIPPED_BACK',
  'RETURN_RECEIVED',
  'CLOSED'
);

create type seller_ops.refund_status as enum (
  'PENDING',
  'SUCCESS',
  'FAILED'
);

create sequence if not exists seller_ops.order_no_seq start 1000000;

create or replace function seller_ops.generate_order_no()
returns text
language plpgsql
as $$
begin
  return 'IBUL-' || lpad(nextval('seller_ops.order_no_seq')::text, 7, '0');
end;
$$;

create or replace function seller_ops.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists seller_ops.sellers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  store_name text not null,
  created_at timestamptz not null default now(),
  unique (owner_user_id)
);

create table if not exists seller_ops.orders (
  id uuid primary key default gen_random_uuid(),
  order_no text not null unique default seller_ops.generate_order_no(),
  buyer_user_id uuid not null references auth.users(id) on delete restrict,
  seller_id uuid not null references seller_ops.sellers(id) on delete restrict,
  status seller_ops.order_status not null default 'NEW',
  payment_status seller_ops.payment_status not null default 'PENDING',
  currency text not null default 'TRY',
  subtotal numeric(12,2) not null default 0,
  shipping_fee numeric(12,2) not null default 0,
  commission_rate numeric(5,4) not null default 0,
  commission_amount numeric(12,2) not null default 0,
  net_amount numeric(12,2) not null default 0,
  shipping_address jsonb not null default '{}'::jsonb,
  buyer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists seller_ops.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references seller_ops.orders(id) on delete cascade,
  product_id uuid not null,
  variant_id uuid,
  title text not null,
  sku text,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null default 0,
  total_price numeric(12,2) not null default 0,
  weight_gram integer,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references seller_ops.orders(id) on delete cascade,
  provider text not null,
  provider_payment_id text,
  amount numeric(12,2) not null,
  currency text not null default 'TRY',
  status seller_ops.payment_status not null default 'PENDING',
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references seller_ops.orders(id) on delete cascade,
  seller_id uuid not null references seller_ops.sellers(id) on delete cascade,
  carrier text,
  tracking_no text,
  label_url text,
  status seller_ops.shipment_status not null default 'NONE',
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists seller_ops.shipment_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references seller_ops.shipments(id) on delete cascade,
  code text not null,
  description text not null,
  location text,
  occurred_at timestamptz not null,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references seller_ops.orders(id) on delete cascade,
  seller_id uuid not null references seller_ops.sellers(id) on delete cascade,
  status seller_ops.return_status not null default 'RETURN_REQUESTED',
  reason text not null,
  details text,
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  received_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.refunds (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null unique references seller_ops.returns(id) on delete cascade,
  provider text not null,
  provider_refund_id text,
  amount numeric(12,2) not null,
  status seller_ops.refund_status not null default 'PENDING',
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  seller_id uuid references seller_ops.sellers(id) on delete cascade,
  order_id uuid references seller_ops.orders(id) on delete cascade,
  action text not null,
  from_status text,
  to_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists seller_ops.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references seller_ops.orders(id) on delete cascade,
  status seller_ops.order_status not null,
  note text,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_seller_ops_orders_seller_created_at
  on seller_ops.orders (seller_id, created_at desc);
create index if not exists idx_seller_ops_orders_buyer_created_at
  on seller_ops.orders (buyer_user_id, created_at desc);
create index if not exists idx_seller_ops_orders_status
  on seller_ops.orders (status);
create index if not exists idx_seller_ops_order_items_order_id
  on seller_ops.order_items (order_id);
create index if not exists idx_seller_ops_payments_order_id
  on seller_ops.payments (order_id);
create index if not exists idx_seller_ops_shipments_seller_id
  on seller_ops.shipments (seller_id, created_at desc);
create index if not exists idx_seller_ops_shipment_events_shipment_id_occurred_at
  on seller_ops.shipment_events (shipment_id, occurred_at desc);
create index if not exists idx_seller_ops_returns_seller_id_requested_at
  on seller_ops.returns (seller_id, requested_at desc);
create index if not exists idx_seller_ops_notifications_user_created_at
  on seller_ops.notifications (user_id, created_at desc);
create index if not exists idx_seller_ops_audit_logs_seller_created_at
  on seller_ops.audit_logs (seller_id, created_at desc);
create index if not exists idx_seller_ops_order_status_history_order_created_at
  on seller_ops.order_status_history (order_id, created_at desc);

drop trigger if exists trg_seller_ops_orders_updated_at on seller_ops.orders;
create trigger trg_seller_ops_orders_updated_at
before update on seller_ops.orders
for each row execute function seller_ops.set_updated_at();

drop trigger if exists trg_seller_ops_shipments_updated_at on seller_ops.shipments;
create trigger trg_seller_ops_shipments_updated_at
before update on seller_ops.shipments
for each row execute function seller_ops.set_updated_at();

create or replace function seller_ops.current_seller_id(p_actor_user_id uuid)
returns uuid
language sql
stable
as $$
  select id
  from seller_ops.sellers
  where owner_user_id = p_actor_user_id
  limit 1;
$$;

create or replace function seller_ops.assert_seller_access(p_actor_user_id uuid, p_seller_id uuid)
returns void
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_seller_id uuid;
begin
  v_seller_id := seller_ops.current_seller_id(p_actor_user_id);
  if v_seller_id is null or v_seller_id <> p_seller_id then
    raise exception using errcode = '42501', message = 'SELLER_ACCESS_DENIED';
  end if;
end;
$$;

create or replace function seller_ops.is_valid_order_transition(
  p_from seller_ops.order_status,
  p_to seller_ops.order_status
)
returns boolean
language plpgsql
immutable
as $$
begin
  if p_from = p_to then
    return true;
  end if;

  return case p_from
    when 'NEW' then p_to in ('PREPARING', 'CANCELED')
    when 'PREPARING' then p_to in ('READY_TO_SHIP', 'CANCELED')
    when 'READY_TO_SHIP' then p_to in ('SHIPPED', 'CANCELED')
    when 'SHIPPED' then p_to in ('DELIVERED', 'RETURN_REQUESTED')
    when 'DELIVERED' then p_to in ('RETURN_REQUESTED')
    when 'RETURN_REQUESTED' then p_to in ('RETURN_APPROVED', 'CANCELED')
    when 'RETURN_APPROVED' then p_to in ('RETURN_SHIPPED_BACK')
    when 'RETURN_SHIPPED_BACK' then p_to in ('RETURN_RECEIVED')
    when 'RETURN_RECEIVED' then p_to in ('REFUNDED')
    else false
  end;
end;
$$;

create or replace function seller_ops.log_order_transition(
  p_order_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_from text,
  p_to text,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_seller_id uuid;
begin
  select seller_id into v_seller_id from seller_ops.orders where id = p_order_id;

  insert into seller_ops.audit_logs (
    actor_user_id,
    seller_id,
    order_id,
    action,
    from_status,
    to_status,
    metadata
  )
  values (
    p_actor_user_id,
    v_seller_id,
    p_order_id,
    p_action,
    p_from,
    p_to,
    coalesce(p_metadata, '{}'::jsonb)
  );

  if p_to is not null then
    insert into seller_ops.order_status_history (order_id, status, note, actor_user_id)
    values (p_order_id, p_to::seller_ops.order_status, p_note, p_actor_user_id);
  end if;
end;
$$;

create or replace function seller_ops.create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = seller_ops, public
as $$
  insert into seller_ops.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
$$;

create or replace function seller_ops.create_paid_order(
  p_actor_user_id uuid,
  p_seller_id uuid,
  p_payment_provider text,
  p_provider_payment_id text,
  p_currency text,
  p_subtotal numeric,
  p_shipping_fee numeric,
  p_commission_rate numeric,
  p_shipping_address jsonb,
  p_buyer_note text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order_id uuid;
  v_order_no text;
  v_commission numeric(12,2);
  v_net numeric(12,2);
  v_item jsonb;
  v_total numeric(12,2);
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception using errcode = '22023', message = 'ORDER_ITEMS_REQUIRED';
  end if;
  if p_subtotal <= 0 then
    raise exception using errcode = '22023', message = 'INVALID_SUBTOTAL';
  end if;

  v_commission := round((p_subtotal * p_commission_rate)::numeric, 2);
  v_net := round((p_subtotal - v_commission)::numeric, 2);
  v_total := round((p_subtotal + p_shipping_fee)::numeric, 2);

  insert into seller_ops.orders (
    buyer_user_id,
    seller_id,
    status,
    payment_status,
    currency,
    subtotal,
    shipping_fee,
    commission_rate,
    commission_amount,
    net_amount,
    shipping_address,
    buyer_note
  )
  values (
    p_actor_user_id,
    p_seller_id,
    'NEW',
    'PAID',
    coalesce(nullif(p_currency, ''), 'TRY'),
    p_subtotal,
    p_shipping_fee,
    p_commission_rate,
    v_commission,
    v_net,
    coalesce(p_shipping_address, '{}'::jsonb),
    p_buyer_note
  )
  returning id, order_no into v_order_id, v_order_no;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into seller_ops.order_items (
      order_id,
      product_id,
      variant_id,
      title,
      sku,
      quantity,
      unit_price,
      total_price,
      weight_gram
    )
    values (
      v_order_id,
      (v_item->>'product_id')::uuid,
      nullif(v_item->>'variant_id', '')::uuid,
      coalesce(v_item->>'title', 'Ürün'),
      v_item->>'sku',
      coalesce((v_item->>'quantity')::int, 1),
      coalesce((v_item->>'unit_price')::numeric, 0),
      coalesce((v_item->>'total_price')::numeric, 0),
      nullif(v_item->>'weight_gram', '')::int
    );
  end loop;

  insert into seller_ops.payments (
    order_id,
    provider,
    provider_payment_id,
    amount,
    currency,
    status,
    raw
  )
  values (
    v_order_id,
    p_payment_provider,
    p_provider_payment_id,
    v_total,
    coalesce(nullif(p_currency, ''), 'TRY'),
    'PAID',
    jsonb_build_object('source', 'create_order')
  );

  perform seller_ops.log_order_transition(
    v_order_id,
    p_actor_user_id,
    'create_order',
    null,
    'NEW',
    'Ödeme onayı sonrası sipariş oluşturuldu.',
    jsonb_build_object('payment_provider', p_payment_provider)
  );

  perform seller_ops.create_notification(
    (select owner_user_id from seller_ops.sellers where id = p_seller_id),
    'order_new',
    'Yeni sipariş düştü',
    v_order_no || ' numaralı sipariş paneline düştü.',
    jsonb_build_object('order_id', v_order_id, 'order_no', v_order_no)
  );

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', 'NEW'
  );
end;
$$;

create or replace function seller_ops.seller_accept_order(
  p_actor_user_id uuid,
  p_order_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
begin
  select * into v_order from seller_ops.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_order.seller_id);
  if not seller_ops.is_valid_order_transition(v_order.status, 'PREPARING') then
    raise exception using errcode = '22023', message = 'INVALID_STATUS_TRANSITION';
  end if;

  update seller_ops.orders set status = 'PREPARING' where id = p_order_id;
  perform seller_ops.log_order_transition(
    p_order_id,
    p_actor_user_id,
    'seller_accept_order',
    v_order.status::text,
    'PREPARING',
    'Satıcı siparişi kabul etti.'
  );
  perform seller_ops.create_notification(
    v_order.buyer_user_id,
    'order_preparing',
    'Siparişin hazırlanıyor',
    v_order.order_no || ' siparişi satıcı tarafından onaylandı.',
    jsonb_build_object('order_id', p_order_id, 'order_no', v_order.order_no)
  );
  return jsonb_build_object('order_id', p_order_id, 'status', 'PREPARING');
end;
$$;

create or replace function seller_ops.mark_order_preparing(
  p_actor_user_id uuid,
  p_order_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
begin
  select * into v_order from seller_ops.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_order.seller_id);
  if v_order.status not in ('NEW', 'PREPARING') then
    raise exception using errcode = '22023', message = 'INVALID_STATUS_TRANSITION';
  end if;
  update seller_ops.orders set status = 'PREPARING' where id = p_order_id;
  perform seller_ops.log_order_transition(
    p_order_id,
    p_actor_user_id,
    'mark_preparing',
    v_order.status::text,
    'PREPARING',
    coalesce(p_note, 'Sipariş üretim / toplama aşamasına alındı.')
  );
  return jsonb_build_object('order_id', p_order_id, 'status', 'PREPARING');
end;
$$;

create or replace function seller_ops.create_dummy_shipment_label(
  p_actor_user_id uuid,
  p_order_id uuid,
  p_carrier text
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
  v_shipment_id uuid;
  v_label_url text;
begin
  select * into v_order from seller_ops.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_order.seller_id);
  if v_order.status not in ('PREPARING', 'READY_TO_SHIP') then
    raise exception using errcode = '22023', message = 'INVALID_STATUS_TRANSITION';
  end if;

  v_label_url := 'https://dummy-labels.ibul.local/' || p_order_id::text || '.pdf';

  insert into seller_ops.shipments (order_id, seller_id, carrier, label_url, status)
  values (p_order_id, v_order.seller_id, p_carrier, v_label_url, 'LABEL_CREATED')
  on conflict (order_id) do update
    set carrier = excluded.carrier,
        label_url = excluded.label_url,
        status = 'LABEL_CREATED'
  returning id into v_shipment_id;

  update seller_ops.orders set status = 'READY_TO_SHIP' where id = p_order_id;
  perform seller_ops.log_order_transition(
    p_order_id,
    p_actor_user_id,
    'create_shipment_label',
    v_order.status::text,
    'READY_TO_SHIP',
    'Kargo etiketi üretildi.',
    jsonb_build_object('carrier', p_carrier, 'label_url', v_label_url)
  );

  return jsonb_build_object(
    'order_id', p_order_id,
    'status', 'READY_TO_SHIP',
    'shipment_id', v_shipment_id,
    'label_url', v_label_url
  );
end;
$$;

create or replace function seller_ops.mark_order_shipped(
  p_actor_user_id uuid,
  p_order_id uuid,
  p_carrier text,
  p_tracking_no text
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
  v_shipment_id uuid;
begin
  select * into v_order from seller_ops.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_order.seller_id);
  if not seller_ops.is_valid_order_transition(v_order.status, 'SHIPPED') then
    raise exception using errcode = '22023', message = 'INVALID_STATUS_TRANSITION';
  end if;
  if coalesce(nullif(p_tracking_no, ''), '') = '' then
    raise exception using errcode = '22023', message = 'TRACKING_NO_REQUIRED';
  end if;

  insert into seller_ops.shipments (
    order_id,
    seller_id,
    carrier,
    tracking_no,
    status,
    shipped_at
  )
  values (
    p_order_id,
    v_order.seller_id,
    p_carrier,
    p_tracking_no,
    'SHIPPED',
    now()
  )
  on conflict (order_id) do update
    set carrier = excluded.carrier,
        tracking_no = excluded.tracking_no,
        status = 'SHIPPED',
        shipped_at = now(),
        updated_at = now()
  returning id into v_shipment_id;

  update seller_ops.orders set status = 'SHIPPED' where id = p_order_id;

  insert into seller_ops.shipment_events (
    shipment_id,
    code,
    description,
    occurred_at,
    raw_payload
  )
  values (
    v_shipment_id,
    'SELLER_HANDOFF',
    'Paket taşıyıcıya teslim edildi.',
    now(),
    jsonb_build_object('carrier', p_carrier, 'tracking_no', p_tracking_no)
  );

  perform seller_ops.log_order_transition(
    p_order_id,
    p_actor_user_id,
    'mark_shipped',
    v_order.status::text,
    'SHIPPED',
    'Sipariş kargoya verildi.',
    jsonb_build_object('carrier', p_carrier, 'tracking_no', p_tracking_no)
  );

  perform seller_ops.create_notification(
    v_order.buyer_user_id,
    'order_shipped',
    'Siparişin kargoya verildi',
    v_order.order_no || ' siparişi için takip numarası oluşturuldu.',
    jsonb_build_object('order_id', p_order_id, 'tracking_no', p_tracking_no, 'carrier', p_carrier)
  );

  return jsonb_build_object(
    'order_id', p_order_id,
    'status', 'SHIPPED',
    'shipment_id', v_shipment_id,
    'tracking_no', p_tracking_no,
    'carrier', p_carrier
  );
end;
$$;

create or replace function seller_ops.ingest_shipment_event(
  p_order_id uuid,
  p_code text,
  p_description text,
  p_location text,
  p_occurred_at timestamptz,
  p_raw_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
  v_shipment seller_ops.shipments%rowtype;
  v_new_order_status seller_ops.order_status;
  v_new_shipment_status seller_ops.shipment_status;
begin
  select * into v_order from seller_ops.orders where id = p_order_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;

  select * into v_shipment from seller_ops.shipments where order_id = p_order_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'SHIPMENT_NOT_FOUND';
  end if;

  insert into seller_ops.shipment_events (
    shipment_id,
    code,
    description,
    location,
    occurred_at,
    raw_payload
  )
  values (
    v_shipment.id,
    p_code,
    p_description,
    p_location,
    coalesce(p_occurred_at, now()),
    coalesce(p_raw_payload, '{}'::jsonb)
  );

  if upper(p_code) in ('IN_TRANSIT', 'TRANSFER', 'BRANCH') then
    v_new_shipment_status := 'IN_TRANSIT';
  elsif upper(p_code) in ('DELIVERED') then
    v_new_shipment_status := 'DELIVERED';
    v_new_order_status := 'DELIVERED';
  else
    v_new_shipment_status := v_shipment.status;
  end if;

  update seller_ops.shipments
    set status = v_new_shipment_status,
        delivered_at = case when v_new_shipment_status = 'DELIVERED' then now() else delivered_at end
  where id = v_shipment.id;

  if v_new_order_status is not null and v_order.status <> v_new_order_status then
    update seller_ops.orders set status = v_new_order_status where id = p_order_id;
    perform seller_ops.log_order_transition(
      p_order_id,
      null,
      'ingest_shipment_event',
      v_order.status::text,
      v_new_order_status::text,
      p_description,
      jsonb_build_object('code', p_code, 'location', p_location)
    );
    perform seller_ops.create_notification(
      v_order.buyer_user_id,
      'shipment_event',
      'Kargo güncellemesi',
      p_description,
      jsonb_build_object('order_id', p_order_id, 'shipment_id', v_shipment.id, 'code', p_code)
    );
  end if;

  return jsonb_build_object('shipment_id', v_shipment.id, 'code', p_code, 'status', coalesce(v_new_order_status::text, v_order.status::text));
end;
$$;

create or replace function seller_ops.request_order_return(
  p_actor_user_id uuid,
  p_order_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_order seller_ops.orders%rowtype;
  v_return_id uuid;
begin
  select * into v_order from seller_ops.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'ORDER_NOT_FOUND';
  end if;
  if v_order.buyer_user_id <> p_actor_user_id then
    raise exception using errcode = '42501', message = 'BUYER_ACCESS_DENIED';
  end if;
  if not seller_ops.is_valid_order_transition(v_order.status, 'RETURN_REQUESTED') then
    raise exception using errcode = '22023', message = 'INVALID_STATUS_TRANSITION';
  end if;

  insert into seller_ops.returns (order_id, seller_id, status, reason, details)
  values (p_order_id, v_order.seller_id, 'RETURN_REQUESTED', p_reason, p_details)
  returning id into v_return_id;

  update seller_ops.orders set status = 'RETURN_REQUESTED' where id = p_order_id;
  perform seller_ops.log_order_transition(
    p_order_id,
    p_actor_user_id,
    'request_return',
    v_order.status::text,
    'RETURN_REQUESTED',
    p_reason,
    jsonb_build_object('details', p_details)
  );
  perform seller_ops.create_notification(
    (select owner_user_id from seller_ops.sellers where id = v_order.seller_id),
    'return_requested',
    'İade talebi geldi',
    v_order.order_no || ' siparişi için iade talebi oluşturuldu.',
    jsonb_build_object('order_id', p_order_id, 'return_id', v_return_id)
  );
  return jsonb_build_object('return_id', v_return_id, 'status', 'RETURN_REQUESTED');
end;
$$;

create or replace function seller_ops.approve_order_return(
  p_actor_user_id uuid,
  p_return_id uuid,
  p_approve boolean,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_return seller_ops.returns%rowtype;
  v_order seller_ops.orders%rowtype;
  v_next_return_status seller_ops.return_status;
  v_next_order_status seller_ops.order_status;
begin
  select * into v_return from seller_ops.returns where id = p_return_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'RETURN_NOT_FOUND';
  end if;
  select * into v_order from seller_ops.orders where id = v_return.order_id for update;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_return.seller_id);

  if p_approve then
    v_next_return_status := 'RETURN_APPROVED';
    v_next_order_status := 'RETURN_APPROVED';
  else
    v_next_return_status := 'RETURN_REJECTED';
    v_next_order_status := 'DELIVERED';
  end if;

  update seller_ops.returns
    set status = v_next_return_status,
        approved_at = case when p_approve then now() else approved_at end,
        closed_at = case when not p_approve then now() else closed_at end
  where id = p_return_id;

  update seller_ops.orders set status = v_next_order_status where id = v_order.id;

  perform seller_ops.log_order_transition(
    v_order.id,
    p_actor_user_id,
    'approve_return',
    v_order.status::text,
    v_next_order_status::text,
    coalesce(p_note, case when p_approve then 'İade talebi onaylandı.' else 'İade talebi reddedildi.' end)
  );

  perform seller_ops.create_notification(
    v_order.buyer_user_id,
    'return_reviewed',
    case when p_approve then 'İade talebin onaylandı' else 'İade talebin reddedildi' end,
    coalesce(p_note, 'İade sürecinin güncel durumu paneline işlendi.'),
    jsonb_build_object('order_id', v_order.id, 'return_id', p_return_id, 'approved', p_approve)
  );

  return jsonb_build_object('return_id', p_return_id, 'status', v_next_return_status::text);
end;
$$;

create or replace function seller_ops.receive_order_return(
  p_actor_user_id uuid,
  p_return_id uuid,
  p_mark_shipped_back boolean default false,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_return seller_ops.returns%rowtype;
  v_order seller_ops.orders%rowtype;
  v_next_return_status seller_ops.return_status;
  v_next_order_status seller_ops.order_status;
begin
  select * into v_return from seller_ops.returns where id = p_return_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'RETURN_NOT_FOUND';
  end if;
  select * into v_order from seller_ops.orders where id = v_return.order_id for update;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_return.seller_id);

  if p_mark_shipped_back then
    v_next_return_status := 'RETURN_SHIPPED_BACK';
    v_next_order_status := 'RETURN_SHIPPED_BACK';
  else
    v_next_return_status := 'RETURN_RECEIVED';
    v_next_order_status := 'RETURN_RECEIVED';
  end if;

  update seller_ops.returns
    set status = v_next_return_status,
        received_at = case when not p_mark_shipped_back then now() else received_at end
  where id = p_return_id;

  update seller_ops.orders set status = v_next_order_status where id = v_order.id;

  perform seller_ops.log_order_transition(
    v_order.id,
    p_actor_user_id,
    'receive_return',
    v_order.status::text,
    v_next_order_status::text,
    coalesce(p_note, case when p_mark_shipped_back then 'Müşteri iadeyi kargoya verdi.' else 'İade paketi teslim alındı.' end)
  );

  return jsonb_build_object('return_id', p_return_id, 'status', v_next_return_status::text);
end;
$$;

create or replace function seller_ops.refund_order_return(
  p_actor_user_id uuid,
  p_return_id uuid,
  p_provider text,
  p_provider_refund_id text,
  p_amount numeric,
  p_success boolean,
  p_raw jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = seller_ops, public
as $$
declare
  v_return seller_ops.returns%rowtype;
  v_order seller_ops.orders%rowtype;
  v_refund_status seller_ops.refund_status;
begin
  select * into v_return from seller_ops.returns where id = p_return_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'RETURN_NOT_FOUND';
  end if;
  select * into v_order from seller_ops.orders where id = v_return.order_id for update;
  perform seller_ops.assert_seller_access(p_actor_user_id, v_return.seller_id);

  v_refund_status := case when p_success then 'SUCCESS' else 'FAILED' end;

  insert into seller_ops.refunds (
    return_id,
    provider,
    provider_refund_id,
    amount,
    status,
    raw
  )
  values (
    p_return_id,
    p_provider,
    p_provider_refund_id,
    p_amount,
    v_refund_status,
    coalesce(p_raw, '{}'::jsonb)
  )
  on conflict (return_id) do update
    set provider = excluded.provider,
        provider_refund_id = excluded.provider_refund_id,
        amount = excluded.amount,
        status = excluded.status,
        raw = excluded.raw;

  if p_success then
    update seller_ops.returns set status = 'CLOSED', closed_at = now() where id = p_return_id;
    update seller_ops.orders set status = 'REFUNDED', payment_status = 'REFUNDED' where id = v_order.id;
    update seller_ops.payments set status = 'REFUNDED' where order_id = v_order.id;
    perform seller_ops.log_order_transition(
      v_order.id,
      p_actor_user_id,
      'refund',
      v_order.status::text,
      'REFUNDED',
      'İade geri ödemesi tamamlandı.',
      jsonb_build_object('amount', p_amount, 'provider', p_provider)
    );
  end if;

  perform seller_ops.create_notification(
    v_order.buyer_user_id,
    'refund_update',
    case when p_success then 'Geri ödeme tamamlandı' else 'Geri ödeme başarısız' end,
    v_order.order_no || ' siparişi için geri ödeme sonucu güncellendi.',
    jsonb_build_object('order_id', v_order.id, 'return_id', p_return_id, 'refund_status', v_refund_status::text)
  );

  return jsonb_build_object('return_id', p_return_id, 'refund_status', v_refund_status::text);
end;
$$;

alter table seller_ops.sellers enable row level security;
alter table seller_ops.orders enable row level security;
alter table seller_ops.order_items enable row level security;
alter table seller_ops.payments enable row level security;
alter table seller_ops.shipments enable row level security;
alter table seller_ops.shipment_events enable row level security;
alter table seller_ops.returns enable row level security;
alter table seller_ops.refunds enable row level security;
alter table seller_ops.notifications enable row level security;
alter table seller_ops.audit_logs enable row level security;
alter table seller_ops.order_status_history enable row level security;

create policy sellers_select_own on seller_ops.sellers
for select to authenticated
using (owner_user_id = auth.uid());

create policy sellers_update_own on seller_ops.sellers
for update to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy orders_select_seller_or_buyer on seller_ops.orders
for select to authenticated
using (
  buyer_user_id = auth.uid()
  or seller_id = seller_ops.current_seller_id(auth.uid())
);

create policy orders_update_seller_only on seller_ops.orders
for update to authenticated
using (seller_id = seller_ops.current_seller_id(auth.uid()))
with check (seller_id = seller_ops.current_seller_id(auth.uid()));

create policy orders_insert_buyer on seller_ops.orders
for insert to authenticated
with check (buyer_user_id = auth.uid());

create policy order_items_select_by_related_order on seller_ops.order_items
for select to authenticated
using (
  exists (
    select 1
    from seller_ops.orders o
    where o.id = order_items.order_id
      and (
        o.buyer_user_id = auth.uid()
        or o.seller_id = seller_ops.current_seller_id(auth.uid())
      )
  )
);

create policy order_items_insert_by_related_order on seller_ops.order_items
for insert to authenticated
with check (
  exists (
    select 1
    from seller_ops.orders o
    where o.id = order_items.order_id
      and o.buyer_user_id = auth.uid()
  )
);

create policy payments_select_buyer_or_seller on seller_ops.payments
for select to authenticated
using (
  exists (
    select 1
    from seller_ops.orders o
    where o.id = payments.order_id
      and (
        o.buyer_user_id = auth.uid()
        or o.seller_id = seller_ops.current_seller_id(auth.uid())
      )
  )
);

create policy shipments_select_related_parties on seller_ops.shipments
for select to authenticated
using (
  seller_id = seller_ops.current_seller_id(auth.uid())
  or exists (
    select 1
    from seller_ops.orders o
    where o.id = shipments.order_id
      and o.buyer_user_id = auth.uid()
  )
);

create policy shipments_update_seller_only on seller_ops.shipments
for update to authenticated
using (seller_id = seller_ops.current_seller_id(auth.uid()))
with check (seller_id = seller_ops.current_seller_id(auth.uid()));

create policy shipment_events_select_related_parties on seller_ops.shipment_events
for select to authenticated
using (
  exists (
    select 1
    from seller_ops.shipments s
    join seller_ops.orders o on o.id = s.order_id
    where s.id = shipment_events.shipment_id
      and (
        s.seller_id = seller_ops.current_seller_id(auth.uid())
        or o.buyer_user_id = auth.uid()
      )
  )
);

create policy returns_select_related_parties on seller_ops.returns
for select to authenticated
using (
  seller_id = seller_ops.current_seller_id(auth.uid())
  or exists (
    select 1 from seller_ops.orders o
    where o.id = returns.order_id and o.buyer_user_id = auth.uid()
  )
);

create policy returns_update_seller_only on seller_ops.returns
for update to authenticated
using (seller_id = seller_ops.current_seller_id(auth.uid()))
with check (seller_id = seller_ops.current_seller_id(auth.uid()));

create policy returns_insert_buyer on seller_ops.returns
for insert to authenticated
with check (
  exists (
    select 1 from seller_ops.orders o
    where o.id = returns.order_id
      and o.buyer_user_id = auth.uid()
  )
);

create policy refunds_select_related_parties on seller_ops.refunds
for select to authenticated
using (
  exists (
    select 1
    from seller_ops.returns r
    join seller_ops.orders o on o.id = r.order_id
    where r.id = refunds.return_id
      and (
        r.seller_id = seller_ops.current_seller_id(auth.uid())
        or o.buyer_user_id = auth.uid()
      )
  )
);

create policy notifications_select_own on seller_ops.notifications
for select to authenticated
using (user_id = auth.uid());

create policy notifications_update_own on seller_ops.notifications
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy audit_logs_select_related_parties on seller_ops.audit_logs
for select to authenticated
using (
  seller_id = seller_ops.current_seller_id(auth.uid())
  or exists (
    select 1 from seller_ops.orders o
    where o.id = audit_logs.order_id and o.buyer_user_id = auth.uid()
  )
);

create policy order_status_history_select_related_parties on seller_ops.order_status_history
for select to authenticated
using (
  exists (
    select 1 from seller_ops.orders o
    where o.id = order_status_history.order_id
      and (
        o.buyer_user_id = auth.uid()
        or o.seller_id = seller_ops.current_seller_id(auth.uid())
      )
  )
);
