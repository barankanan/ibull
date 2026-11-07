-- =============================================================================
-- Migration: record_table_payment_guard
-- Date: 2026-11-07
--
-- Caps a table collection at the still-open bill and makes the same client
-- action idempotent. Do not apply this file to production from automation.
-- Until it is applied, the client refuses an unbounded insert but concurrent
-- devices are not atomic.
-- =============================================================================

begin;

alter table public.table_payments
  add column if not exists idempotency_key text;

create unique index if not exists uq_table_payments_seller_idempotency
  on public.table_payments (seller_id, idempotency_key)
  where idempotency_key is not null and btrim(idempotency_key) <> '';

create or replace function public.garson_parse_money(p_raw text)
returns numeric
language plpgsql
immutable
as $$
declare
  v_text text := btrim(coalesce(p_raw, ''));
begin
  if v_text = '' then
    return 0;
  end if;
  v_text := regexp_replace(v_text, '[^0-9,.\-]', '', 'g');
  if v_text = '' or v_text = '-' or v_text = ',' or v_text = '.' then
    return 0;
  end if;
  if position(',' in v_text) > 0 and position('.' in v_text) > 0 then
    if position(',' in v_text) > position('.' in v_text) then
      v_text := replace(replace(v_text, '.', ''), ',', '.');
    else
      v_text := replace(v_text, ',', '');
    end if;
  elsif position(',' in v_text) > 0 then
    v_text := replace(replace(v_text, '.', ''), ',', '.');
  end if;
  return coalesce(v_text::numeric, 0);
exception
  when others then
    return 0;
end;
$$;

-- Mirrors MixedServiceOrder.normalizeOrderItem + itemLineTotal for a stored row:
-- a unit snapshot is multiplied by quantity; otherwise total_price/price is
-- already the line amount (the missing snapshot is divided by quantity and
-- multiplied back).
create or replace function public.garson_item_line_amount(p_item jsonb)
returns numeric
language plpgsql
immutable
as $$
declare
  v_qty numeric;
  v_unit numeric := 0;
  v_total numeric := 0;
  v_candidate text;
begin
  if p_item is null or jsonb_typeof(p_item) <> 'object' then
    return 0;
  end if;

  v_qty := public.garson_parse_money(p_item->>'quantity');
  if v_qty <= 0 then
    v_qty := 1;
  end if;

  foreach v_candidate in array array[
    'unit_price_snapshot',
    'unitPriceSnapshot',
    'unit_price',
    'unitPrice'
  ]
  loop
    v_unit := public.garson_parse_money(p_item->>v_candidate);
    exit when v_unit > 0;
  end loop;

  if v_unit > 0 then
    return round(v_unit * v_qty, 2);
  end if;

  v_total := public.garson_parse_money(
    coalesce(p_item->>'total_price', p_item->>'price')
  );
  if v_total > 0 then
    return round(v_total, 2);
  end if;

  return 0;
end;
$$;

create or replace function public.record_table_payment(
  p_seller_id uuid,
  p_table_number integer,
  p_session_key text,
  p_amount numeric,
  p_method text,
  p_idempotency_key text,
  p_is_closing boolean default false,
  p_paid_by text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_method text := lower(btrim(coalesce(p_method, '')));
  v_session text := btrim(coalesce(p_session_key, ''));
  v_existing public.table_payments%rowtype;
  v_inserted public.table_payments%rowtype;
  v_has_table_orders boolean := false;
  v_bill numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_opened timestamptz;
  v_window_start timestamptz;
  v_amount_kurus bigint;
  v_remaining_kurus bigint;
  v_orders_sql text;
  v_money_expr text;
  v_type_clause text := 'true';
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if to_regprocedure('public.user_can_access_restaurant(uuid)') is not null then
    if not public.user_can_access_restaurant(p_seller_id) then
      raise exception 'Bu restoran için ödeme yetkiniz yok.' using errcode = '42501';
    end if;
  elsif p_seller_id is distinct from auth.uid() then
    raise exception 'Bu restoran için ödeme yetkiniz yok.' using errcode = '42501';
  end if;

  if p_seller_id is null or p_table_number is null or p_table_number <= 0 then
    raise exception 'Masa numarası geçersiz.';
  end if;
  if v_session = '' then
    raise exception 'Ödeme oturumu bulunamadı.';
  end if;
  if v_key = '' or char_length(v_key) > 120 then
    raise exception 'Ödeme işlemi kimliği geçersiz.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Ödeme tutarı sıfırdan büyük olmalı.';
  end if;
  if v_method not in ('cash', 'card', 'online', 'mixed', 'complimentary', 'other') then
    raise exception 'Ödeme yöntemi geçersiz.';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_table_number);

  select *
  into v_existing
  from public.table_payments
  where seller_id = p_seller_id
    and idempotency_key = v_key
  limit 1;

  if found then
    if v_existing.table_number is distinct from p_table_number then
      raise exception 'Bu işlem kimliği başka bir masada kullanılmış.';
    end if;
    return to_jsonb(v_existing) || jsonb_build_object('replayed', true);
  end if;

  select exists (
    select 1
    from public.table_orders o
    where o.seller_id = p_seller_id
      and o.table_number = p_table_number
      and lower(coalesce(o.status, '')) not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived'
      )
  )
  into v_has_table_orders;

  if v_has_table_orders then
    select
      coalesce(sum(public.garson_item_line_amount(item)), 0),
      min(o.created_at)
    into v_bill, v_opened
    from public.table_orders o
    cross join lateral jsonb_array_elements(
      case
        when jsonb_typeof(o.items) = 'array' then o.items
        else '[]'::jsonb
      end
    ) as item
    where o.seller_id = p_seller_id
      and o.table_number = p_table_number
      and lower(coalesce(o.status, '')) not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived'
      );

    if v_opened is null then
      select min(o.created_at)
      into v_opened
      from public.table_orders o
      where o.seller_id = p_seller_id
        and o.table_number = p_table_number
        and lower(coalesce(o.status, '')) not in (
          'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
          'completed_payment', 'payment_completed', 'archived'
        );
    end if;
  elsif to_regclass('public.orders') is not null
    and to_regclass('public.order_items') is not null
    and to_regclass('public.store_tables') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = 'restaurant_id'
    )
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'orders'
        and column_name = 'table_id'
    )
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'order_items'
        and column_name = 'total_price'
    ) then
    v_money_expr := 'round(coalesce(nullif(oi.total_price, 0), coalesce(oi.quantity, 1) * coalesce(oi.unit_price, 0)), 2)';
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'order_items'
        and column_name = 'line_total'
    ) then
      v_money_expr := 'round(coalesce(nullif(oi.line_total, 0), nullif(oi.total_price, 0), coalesce(oi.quantity, 1) * coalesce(oi.unit_price, 0)), 2)';
    end if;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'orders' and column_name = 'order_type'
    ) and exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'orders' and column_name = 'delivery_type'
    ) then
      v_type_clause := '(ord.order_type = ''table'' or ord.delivery_type = ''table'')';
    elsif exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'orders' and column_name = 'order_type'
    ) then
      v_type_clause := 'ord.order_type = ''table''';
    elsif exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'orders' and column_name = 'delivery_type'
    ) then
      v_type_clause := 'ord.delivery_type = ''table''';
    end if;

    v_orders_sql := format(
      'select coalesce(sum(%s), 0), min(ord.created_at)
       from public.orders ord
       join public.store_tables st
         on st.id = ord.table_id
        and st.seller_id = $1
        and st.table_number = $2
       left join public.order_items oi on oi.order_id = ord.id
       where ord.restaurant_id = $1
         and %s
         and lower(coalesce(ord.status, '''')) not in (
           ''closed'', ''paid'', ''cancelled'', ''canceled'', ''completed'',
           ''complete'', ''completed_payment'', ''payment_completed'', ''archived''
         )',
      v_money_expr,
      v_type_clause
    );
    execute v_orders_sql into v_bill, v_opened using p_seller_id, p_table_number;
  end if;

  v_window_start := coalesce(
    v_opened,
    timezone('utc', now()) - interval '18 hours'
  );

  select coalesce(sum(amount), 0)
  into v_paid
  from public.table_payments
  where seller_id = p_seller_id
    and table_number = p_table_number
    and created_at >= v_window_start;

  v_amount_kurus := round(p_amount * 100)::bigint;
  v_remaining_kurus := round(coalesce(v_bill, 0) * 100)::bigint
    - round(coalesce(v_paid, 0) * 100)::bigint;
  if v_remaining_kurus < 0 then
    v_remaining_kurus := 0;
  end if;
  if v_amount_kurus <= 0 then
    raise exception 'Ödeme tutarı sıfırdan büyük olmalı.';
  end if;
  if v_amount_kurus > v_remaining_kurus then
    raise exception
      'Kalan tutardan fazla ödeme alınamaz. Kalan: %',
      trim(to_char(v_remaining_kurus / 100.0, 'FM999999990.00'))
      using errcode = 'P0001';
  end if;

  insert into public.table_payments (
    seller_id,
    table_number,
    session_key,
    amount,
    method,
    paid_by,
    waiter_id,
    waiter_name,
    note,
    is_closing,
    idempotency_key
  ) values (
    p_seller_id,
    p_table_number,
    v_session,
    round(p_amount, 2),
    v_method,
    nullif(btrim(coalesce(p_paid_by, '')), ''),
    p_waiter_id,
    nullif(btrim(coalesce(p_waiter_name, '')), ''),
    nullif(btrim(coalesce(p_note, '')), ''),
    coalesce(p_is_closing, false),
    v_key
  )
  returning * into v_inserted;

  return to_jsonb(v_inserted) || jsonb_build_object('replayed', false);
exception
  when unique_violation then
    select *
    into v_existing
    from public.table_payments
    where seller_id = p_seller_id
      and idempotency_key = v_key
    limit 1;
    if found then
      if v_existing.table_number is distinct from p_table_number then
        raise exception 'Bu işlem kimliği başka bir masada kullanılmış.';
      end if;
      return to_jsonb(v_existing) || jsonb_build_object('replayed', true);
    end if;
    raise;
end;
$$;

revoke all on function public.garson_parse_money(text) from public;
revoke all on function public.garson_item_line_amount(jsonb) from public;
revoke all on function public.record_table_payment(
  uuid, integer, text, numeric, text, text, boolean, text, uuid, text, text
) from public;

grant execute on function public.record_table_payment(
  uuid, integer, text, numeric, text, text, boolean, text, uuid, text, text
) to authenticated;

comment on function public.record_table_payment(
  uuid, integer, text, numeric, text, text, boolean, text, uuid, text, text
) is
  'Records one table payment under an advisory lock. Rejects amounts above the open bill and replays the same idempotency key.';

commit;
