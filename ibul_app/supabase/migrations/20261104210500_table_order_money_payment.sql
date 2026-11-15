-- DO NOT APPLY to production unless the operator names this file and says
-- Bu migration'ı production'a uygula.
-- Keeps the owner remaining-balance check from
-- 20261103214000_guard_table_payment_owner_balance.sql.
-- Plain numbers stay numbers. The two stored display labels ₺544 and
-- 1500 TL are read as those amounts. Any other price text raises 22023
-- instead of 22P02. Done orders stay in the open bill. Terminal statuses
-- used by the garson board are left out. No payment or order row is deleted.

create or replace function public.ibul_table_order_money(p_text text)
returns numeric
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v text := btrim(coalesce(p_text, ''));
begin
  if v = '' then
    return null;
  end if;
  if v ~ '^-?[0-9]+(\.[0-9]+)?$' then
    return v::numeric;
  end if;
  if v ~ '^₺[0-9]+(\.[0-9]+)?$' then
    return substr(v, 2)::numeric;
  end if;
  if v ~ '^[0-9]+(\.[0-9]+)? TL$' then
    return btrim(replace(v, ' TL', ''))::numeric;
  end if;
  raise exception 'Sipariş fiyatı sayı değil.' using errcode = '22023';
end;
$$;

revoke all on function public.ibul_table_order_money(text) from public, anon;

create or replace function public.guard_table_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
  v_order_total numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_remaining numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  v_is_owner := exists (
    select 1 from public.stores s
    where s.seller_id = auth.uid()
      and s.seller_id = new.seller_id
  );
  if not v_is_owner then
    perform public.restaurant_staff_may_operate(
      new.seller_id, 'takePartialPayment', new.table_number
    );
    if new.client_request_id is null or btrim(new.client_request_id) = '' then
      raise exception 'Ödeme isteği kimliği zorunlu.' using errcode = '22023';
    end if;
    if new.waiter_id is not null and new.waiter_id is distinct from auth.uid() then
      raise exception 'Garson kimliği geçersiz.' using errcode = '42501';
    end if;
  end if;
  if new.amount is null or new.amount <= 0 then
    raise exception 'Ödeme tutarı geçersiz.' using errcode = '22023';
  end if;
  new.amount := round(new.amount, 2);
  if new.amount <= 0 then
    raise exception 'Ödeme tutarı geçersiz.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(
      new.seller_id::text || ':' || new.table_number::text || ':' || coalesce(new.session_key, ''),
      0
    )
  );
  if new.client_request_id is not null and exists (
    select 1 from public.table_payments
    where seller_id = new.seller_id
      and client_request_id = new.client_request_id
  ) then
    raise exception 'IBUL_PAYMENT_REPLAY' using errcode = 'P0002';
  end if;
  perform 1
  from public.table_orders
  where seller_id = new.seller_id::text
    and table_number = new.table_number
    and lower(btrim(coalesce(status, ''))) not in (
      'delivered', 'cancelled', 'canceled', 'closed', 'paid',
      'completed', 'complete', 'completed_payment',
      'payment_completed', 'archived'
    )
  for update;
  select coalesce(sum(
    coalesce(
      public.ibul_table_order_money(nullif(item ->> 'line_total', '')),
      coalesce(public.ibul_table_order_money(nullif(item ->> 'price', '')), 0)
      * coalesce(public.ibul_table_order_money(nullif(item ->> 'quantity', '')), 1)
    )
  ), 0)
  into v_order_total
  from public.table_orders o
  cross join lateral jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) item
  where o.seller_id = new.seller_id::text
    and o.table_number = new.table_number
    and lower(btrim(coalesce(o.status, ''))) not in (
      'delivered', 'cancelled', 'canceled', 'closed', 'paid',
      'completed', 'complete', 'completed_payment',
      'payment_completed', 'archived'
    );
  select coalesce(sum(amount), 0)
  into v_paid
  from public.table_payments
  where seller_id = new.seller_id
    and table_number = new.table_number
    and session_key = new.session_key;
  v_remaining := round(v_order_total - v_paid, 2);
  if v_remaining <= 0 or new.amount > v_remaining + 0.009 then
    raise exception 'Ödeme kalan bakiyeyi aşıyor.' using errcode = '22023';
  end if;
  insert into public.restaurant_staff_operation_log (
    actor_id, seller_id, table_number, operation, summary
  ) values (
    auth.uid(), new.seller_id, new.table_number, 'takePartialPayment',
    jsonb_build_object(
      'amount', new.amount,
      'remaining_after', v_remaining - new.amount
    )
  );
  return new;
end;
$$;

revoke all on function public.guard_table_payment() from public, anon;
grant execute on function public.guard_table_payment() to authenticated;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.guard_table_payment() to service_role;
  end if;
end $$;
