-- TEST CHECKOUT — not applied automatically.
-- Rollback is at the bottom of this file.
-- Default server flag is OFF. Authenticated clients cannot flip it.

alter table public.orders
  add column if not exists is_test boolean not null default false;

comment on column public.orders.is_test is
  'True only for create_marketplace_test_order. Never means paid.';

create index if not exists idx_orders_is_test
  on public.orders (is_test)
  where is_test;

create table if not exists public.marketplace_runtime_flags (
  flag_key text primary key,
  enabled boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.marketplace_runtime_flags (flag_key, enabled)
values ('test_checkout', false)
on conflict (flag_key) do nothing;

alter table public.marketplace_runtime_flags enable row level security;

revoke all on table public.marketplace_runtime_flags from public;
revoke all on table public.marketplace_runtime_flags from anon;
revoke all on table public.marketplace_runtime_flags from authenticated;

create or replace function public.marketplace_test_checkout_enabled()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select enabled
      from public.marketplace_runtime_flags
      where flag_key = 'test_checkout'
    ),
    false
  );
$$;

revoke all on function public.marketplace_test_checkout_enabled() from public;
grant execute on function public.marketplace_test_checkout_enabled() to authenticated;

create or replace function public.orders_reject_client_is_test()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(new.is_test, false)
     and current_user in ('anon', 'authenticated', 'authenticator') then
    raise exception 'CLIENT_TEST_FLAG_REJECTED' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_reject_client_is_test on public.orders;
create trigger trg_orders_reject_client_is_test
before insert or update of is_test on public.orders
for each row
execute function public.orders_reject_client_is_test();

create or replace function public.create_marketplace_test_order(
  p_items jsonb,
  p_delivery_address jsonb default '{}'::jsonb,
  p_address_id uuid default null,
  p_delivery_type text default 'standard',
  p_delivery_slot text default null,
  p_coupon_code text default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_forbidden text;
  v_raw jsonb;
  v_id uuid;
  v_replay boolean;
  v_is_test boolean;
  v_payment text;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  if not public.marketplace_test_checkout_enabled() then
    raise exception 'TEST_CHECKOUT_DISABLED' using errcode = '42501';
  end if;

  v_forbidden := public.marketplace_payload_forbidden_key(p_items);
  if v_forbidden is not null then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;
  v_forbidden := public.marketplace_payload_forbidden_key(p_delivery_address);
  if v_forbidden is not null then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;

  v_raw := public.create_marketplace_order(
    p_items,
    coalesce(p_delivery_address, '{}'::jsonb),
    p_address_id,
    p_delivery_type,
    p_delivery_slot,
    p_coupon_code,
    p_idempotency_key,
    null,
    null
  );

  v_id := nullif(coalesce(v_raw->>'id', v_raw->>'order_id'), '')::uuid;
  if v_id is null then
    raise exception 'ORDER_ID_MISSING' using errcode = '22023';
  end if;

  v_replay := coalesce((v_raw->>'idempotent_replay')::boolean, false);
  select o.is_test, o.payment_status
    into v_is_test, v_payment
  from public.orders o
  where o.id = v_id;

  if v_replay and coalesce(v_is_test, false) is not true then
    raise exception 'IDEMPOTENCY_KEY_NOT_TEST' using errcode = '42501';
  end if;
  if lower(coalesce(v_payment, '')) in ('paid', 'refunded') then
    raise exception 'TEST_ORDER_PAYMENT_LOCKED' using errcode = '42501';
  end if;

  update public.orders
  set is_test = true
  where id = v_id
    and payment_status = 'pending'
    and user_id = v_user
    and lower(coalesce(payment_status, '')) not in ('paid', 'refunded');

  if not found then
    raise exception 'TEST_ORDER_NOT_PENDING' using errcode = '42501';
  end if;

  return v_raw || jsonb_build_object(
    'is_test', true,
    'payment_status', 'pending'
  );
end;
$$;

revoke all on function public.create_marketplace_test_order(
  jsonb, jsonb, uuid, text, text, text, text
) from public;
revoke all on function public.create_marketplace_test_order(
  jsonb, jsonb, uuid, text, text, text, text
) from anon;
grant execute on function public.create_marketplace_test_order(
  jsonb, jsonb, uuid, text, text, text, text
) to authenticated;

-- Rollback (manual, not executed):
-- drop function if exists public.create_marketplace_test_order(jsonb, jsonb, uuid, text, text, text, text);
-- drop trigger if exists trg_orders_reject_client_is_test on public.orders;
-- drop function if exists public.orders_reject_client_is_test();
-- drop function if exists public.marketplace_test_checkout_enabled();
-- drop table if exists public.marketplace_runtime_flags;
-- drop index if exists public.idx_orders_is_test;
-- alter table public.orders drop column if exists is_test;
