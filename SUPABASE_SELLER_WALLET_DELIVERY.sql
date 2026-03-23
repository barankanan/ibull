-- Seller wallet + delivery reserve/capture/release
-- Run in Supabase SQL Editor once.

begin;

create extension if not exists pgcrypto;

alter table public.orders
  add column if not exists total_delivery_fee numeric(12,2) not null default 0,
  add column if not exists customer_delivery_fee numeric(12,2) not null default 0,
  add column if not exists seller_delivery_fee numeric(12,2) not null default 0,
  add column if not exists wallet_reserve_status text not null default 'none';

create table if not exists public.seller_wallets (
  seller_id uuid primary key references public.users(id) on delete cascade,
  available_balance numeric(14,2) not null default 0,
  reserved_balance numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint seller_wallets_non_negative
    check (available_balance >= 0 and reserved_balance >= 0)
);

create table if not exists public.seller_wallet_holds (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.users(id) on delete cascade,
  reference_id text not null,
  source_type text not null,
  amount numeric(14,2) not null check (amount > 0),
  captured_amount numeric(14,2) not null default 0 check (captured_amount >= 0),
  status text not null default 'active'
    check (status in ('active', 'partially_captured', 'captured', 'released')),
  idempotency_key text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  captured_at timestamptz,
  released_at timestamptz
);

create index if not exists idx_seller_wallet_holds_seller_status
  on public.seller_wallet_holds(seller_id, status, created_at desc);

create table if not exists public.seller_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.users(id) on delete cascade,
  hold_id uuid references public.seller_wallet_holds(id) on delete set null,
  reference_id text,
  txn_type text not null
    check (txn_type in ('top_up','reserve','capture','release','refund','partial_refund','promo_credit','manual_adjustment')),
  direction text not null check (direction in ('debit','credit')),
  amount numeric(14,2) not null check (amount > 0),
  balance_available_after numeric(14,2) not null,
  balance_reserved_after numeric(14,2) not null,
  idempotency_key text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_seller_wallet_tx_seller_created
  on public.seller_wallet_transactions(seller_id, created_at desc);

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  );
$$;

grant execute on function public.is_admin_user(uuid) to authenticated;

create or replace function public._prevent_wallet_tx_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'seller_wallet_transactions is immutable';
end;
$$;

drop trigger if exists trg_prevent_wallet_tx_update on public.seller_wallet_transactions;
create trigger trg_prevent_wallet_tx_update
before update on public.seller_wallet_transactions
for each row execute function public._prevent_wallet_tx_mutation();

drop trigger if exists trg_prevent_wallet_tx_delete on public.seller_wallet_transactions;
create trigger trg_prevent_wallet_tx_delete
before delete on public.seller_wallet_transactions
for each row execute function public._prevent_wallet_tx_mutation();

alter table public.seller_wallets enable row level security;
alter table public.seller_wallet_holds enable row level security;
alter table public.seller_wallet_transactions enable row level security;

drop policy if exists "seller_wallets_select_own" on public.seller_wallets;
create policy "seller_wallets_select_own"
on public.seller_wallets
for select to authenticated
using (seller_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists "seller_wallet_holds_select_own" on public.seller_wallet_holds;
create policy "seller_wallet_holds_select_own"
on public.seller_wallet_holds
for select to authenticated
using (seller_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists "seller_wallet_tx_select_own" on public.seller_wallet_transactions;
create policy "seller_wallet_tx_select_own"
on public.seller_wallet_transactions
for select to authenticated
using (seller_id = auth.uid() or public.is_admin_user(auth.uid()));

create or replace function public.wallet_get_seller_balance(
  p_seller_id uuid default auth.uid()
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.seller_wallets%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if auth.uid() <> p_seller_id and not public.is_admin_user(auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  insert into public.seller_wallets (seller_id)
  values (p_seller_id)
  on conflict (seller_id) do nothing;

  select *
  into v_wallet
  from public.seller_wallets
  where seller_id = p_seller_id;

  return jsonb_build_object(
    'ok', true,
    'seller_id', p_seller_id,
    'available_balance', coalesce(v_wallet.available_balance, 0),
    'reserved_balance', coalesce(v_wallet.reserved_balance, 0)
  );
end;
$$;

grant execute on function public.wallet_get_seller_balance(uuid) to authenticated;

create or replace function public.wallet_topup_seller(
  p_seller_id uuid,
  p_amount numeric,
  p_idempotency_key text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.seller_wallets%rowtype;
  v_existing_tx public.seller_wallet_transactions%rowtype;
  v_amount numeric(14,2) := round(coalesce(p_amount, 0)::numeric, 2);
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if auth.uid() <> p_seller_id and not public.is_admin_user(auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if v_amount <= 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid_amount');
  end if;
  if coalesce(trim(p_idempotency_key), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'idempotency_required');
  end if;

  select *
  into v_existing_tx
  from public.seller_wallet_transactions
  where idempotency_key = p_idempotency_key
  limit 1;
  if found then
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_existing_tx.seller_id,
      'available_balance', v_existing_tx.balance_available_after,
      'reserved_balance', v_existing_tx.balance_reserved_after
    );
  end if;

  insert into public.seller_wallets (seller_id)
  values (p_seller_id)
  on conflict (seller_id) do nothing;

  select *
  into v_wallet
  from public.seller_wallets
  where seller_id = p_seller_id
  for update;

  update public.seller_wallets
  set
    available_balance = available_balance + v_amount,
    updated_at = now()
  where seller_id = p_seller_id
  returning * into v_wallet;

  insert into public.seller_wallet_transactions(
    seller_id, txn_type, direction, amount,
    balance_available_after, balance_reserved_after,
    idempotency_key, metadata
  ) values (
    p_seller_id, 'top_up', 'credit', v_amount,
    v_wallet.available_balance, v_wallet.reserved_balance,
    p_idempotency_key, coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object(
    'ok', true,
    'seller_id', p_seller_id,
    'available_balance', v_wallet.available_balance,
    'reserved_balance', v_wallet.reserved_balance
  );
end;
$$;

grant execute on function public.wallet_topup_seller(uuid, numeric, text, jsonb) to authenticated;

create or replace function public.wallet_reserve_seller_delivery(
  p_seller_id uuid,
  p_amount numeric,
  p_reference_id text,
  p_source_type text,
  p_idempotency_key text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.seller_wallets%rowtype;
  v_existing_tx public.seller_wallet_transactions%rowtype;
  v_existing_hold public.seller_wallet_holds%rowtype;
  v_hold public.seller_wallet_holds%rowtype;
  v_amount numeric(14,2) := round(coalesce(p_amount, 0)::numeric, 2);
  v_order_id uuid;
  v_order_user_id uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if v_amount <= 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid_amount');
  end if;
  if coalesce(trim(p_reference_id), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'reference_required');
  end if;
  if coalesce(trim(p_idempotency_key), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'idempotency_required');
  end if;

  if lower(coalesce(p_source_type, '')) = 'ibul_internal' then
    begin
      v_order_id := p_reference_id::uuid;
    exception when others then
      return jsonb_build_object('ok', false, 'error', 'invalid_order_reference');
    end;

    select o.user_id
    into v_order_user_id
    from public.orders o
    where o.id = v_order_id;

    if v_order_user_id is null then
      return jsonb_build_object('ok', false, 'error', 'order_not_found');
    end if;
    if auth.uid() <> v_order_user_id and auth.uid() <> p_seller_id and not public.is_admin_user(auth.uid()) then
      return jsonb_build_object('ok', false, 'error', 'not_authorized');
    end if;
    if not exists (
      select 1
      from public.order_items oi
      where oi.order_id = v_order_id
        and oi.seller_id = p_seller_id
    ) then
      return jsonb_build_object('ok', false, 'error', 'seller_not_in_order');
    end if;
  else
    if auth.uid() <> p_seller_id and not public.is_admin_user(auth.uid()) then
      return jsonb_build_object('ok', false, 'error', 'not_authorized');
    end if;
  end if;

  select *
  into v_existing_tx
  from public.seller_wallet_transactions
  where idempotency_key = p_idempotency_key
  limit 1;
  if found then
    select *
    into v_existing_hold
    from public.seller_wallet_holds
    where id = v_existing_tx.hold_id;
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_existing_tx.seller_id,
      'hold_id', v_existing_tx.hold_id,
      'available_balance', v_existing_tx.balance_available_after,
      'reserved_balance', v_existing_tx.balance_reserved_after,
      'status', coalesce(v_existing_hold.status, 'active')
    );
  end if;

  insert into public.seller_wallets (seller_id)
  values (p_seller_id)
  on conflict (seller_id) do nothing;

  select *
  into v_wallet
  from public.seller_wallets
  where seller_id = p_seller_id
  for update;

  if coalesce(v_wallet.available_balance, 0) < v_amount then
    return jsonb_build_object(
      'ok', false,
      'error', 'insufficient_wallet_balance',
      'available_balance', coalesce(v_wallet.available_balance, 0),
      'required_amount', v_amount
    );
  end if;

  insert into public.seller_wallet_holds(
    seller_id, reference_id, source_type, amount, status, idempotency_key, metadata
  ) values (
    p_seller_id, p_reference_id, p_source_type, v_amount, 'active',
    p_idempotency_key, coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_hold;

  update public.seller_wallets
  set
    available_balance = available_balance - v_amount,
    reserved_balance = reserved_balance + v_amount,
    updated_at = now()
  where seller_id = p_seller_id
  returning * into v_wallet;

  insert into public.seller_wallet_transactions(
    seller_id, hold_id, reference_id, txn_type, direction, amount,
    balance_available_after, balance_reserved_after,
    idempotency_key, metadata
  ) values (
    p_seller_id, v_hold.id, p_reference_id, 'reserve', 'debit', v_amount,
    v_wallet.available_balance, v_wallet.reserved_balance,
    p_idempotency_key, coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object(
    'ok', true,
    'seller_id', p_seller_id,
    'hold_id', v_hold.id,
    'available_balance', v_wallet.available_balance,
    'reserved_balance', v_wallet.reserved_balance,
    'status', v_hold.status
  );
end;
$$;

grant execute on function public.wallet_reserve_seller_delivery(uuid, numeric, text, text, text, jsonb) to authenticated;

create or replace function public.wallet_capture_seller_delivery(
  p_hold_id uuid,
  p_amount numeric default null,
  p_idempotency_key text default null,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold public.seller_wallet_holds%rowtype;
  v_wallet public.seller_wallets%rowtype;
  v_existing_tx public.seller_wallet_transactions%rowtype;
  v_capture_amount numeric(14,2);
  v_remaining numeric(14,2);
  v_idempotency text := coalesce(trim(p_idempotency_key), '');
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_hold_id is null then
    return jsonb_build_object('ok', false, 'error', 'hold_required');
  end if;

  if v_idempotency = '' then
    v_idempotency := 'capture-' || p_hold_id::text || '-' || extract(epoch from now())::bigint::text;
  end if;

  select *
  into v_existing_tx
  from public.seller_wallet_transactions
  where idempotency_key = v_idempotency
  limit 1;
  if found then
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_existing_tx.seller_id,
      'hold_id', p_hold_id,
      'available_balance', v_existing_tx.balance_available_after,
      'reserved_balance', v_existing_tx.balance_reserved_after
    );
  end if;

  select *
  into v_hold
  from public.seller_wallet_holds
  where id = p_hold_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'hold_not_found');
  end if;
  if auth.uid() <> v_hold.seller_id and not public.is_admin_user(auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if v_hold.status = 'released' then
    return jsonb_build_object('ok', false, 'error', 'hold_released');
  end if;

  v_remaining := round((v_hold.amount - v_hold.captured_amount)::numeric, 2);
  if v_remaining <= 0 then
    return jsonb_build_object('ok', true, 'seller_id', v_hold.seller_id, 'hold_id', v_hold.id, 'status', v_hold.status);
  end if;

  v_capture_amount := round(coalesce(p_amount, v_remaining)::numeric, 2);
  if v_capture_amount <= 0 then
    return jsonb_build_object('ok', false, 'error', 'invalid_capture_amount');
  end if;
  if v_capture_amount > v_remaining then
    v_capture_amount := v_remaining;
  end if;

  select *
  into v_wallet
  from public.seller_wallets
  where seller_id = v_hold.seller_id
  for update;

  update public.seller_wallets
  set
    reserved_balance = greatest(reserved_balance - v_capture_amount, 0),
    updated_at = now()
  where seller_id = v_hold.seller_id
  returning * into v_wallet;

  update public.seller_wallet_holds
  set
    captured_amount = captured_amount + v_capture_amount,
    status = case
      when captured_amount + v_capture_amount >= amount then 'captured'
      else 'partially_captured'
    end,
    captured_at = case
      when captured_amount + v_capture_amount >= amount then now()
      else captured_at
    end,
    updated_at = now(),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('capture_reason', p_reason)
  where id = v_hold.id
  returning * into v_hold;

  insert into public.seller_wallet_transactions(
    seller_id, hold_id, reference_id, txn_type, direction, amount,
    balance_available_after, balance_reserved_after,
    idempotency_key, metadata
  ) values (
    v_hold.seller_id, v_hold.id, v_hold.reference_id, 'capture', 'debit', v_capture_amount,
    v_wallet.available_balance, v_wallet.reserved_balance,
    v_idempotency, jsonb_build_object('reason', p_reason)
  );

  return jsonb_build_object(
    'ok', true,
    'seller_id', v_hold.seller_id,
    'hold_id', v_hold.id,
    'captured_amount', v_capture_amount,
    'status', v_hold.status,
    'available_balance', v_wallet.available_balance,
    'reserved_balance', v_wallet.reserved_balance
  );
end;
$$;

grant execute on function public.wallet_capture_seller_delivery(uuid, numeric, text, text) to authenticated;

create or replace function public.wallet_capture_seller_delivery_by_reference(
  p_seller_id uuid,
  p_reference_id text,
  p_idempotency_key text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold_id uuid;
begin
  select h.id
  into v_hold_id
  from public.seller_wallet_holds h
  where h.seller_id = p_seller_id
    and h.reference_id = p_reference_id
    and h.status in ('active', 'partially_captured')
  order by h.created_at asc
  limit 1;

  if v_hold_id is null then
    return jsonb_build_object('ok', true, 'status', 'no_active_hold');
  end if;

  return public.wallet_capture_seller_delivery(
    v_hold_id,
    null,
    p_idempotency_key,
    p_reason
  );
end;
$$;

grant execute on function public.wallet_capture_seller_delivery_by_reference(uuid, text, text, text) to authenticated;

create or replace function public.wallet_release_seller_delivery(
  p_hold_id uuid,
  p_idempotency_key text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold public.seller_wallet_holds%rowtype;
  v_wallet public.seller_wallets%rowtype;
  v_existing_tx public.seller_wallet_transactions%rowtype;
  v_release_amount numeric(14,2);
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_hold_id is null then
    return jsonb_build_object('ok', false, 'error', 'hold_required');
  end if;
  if coalesce(trim(p_idempotency_key), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'idempotency_required');
  end if;

  select *
  into v_existing_tx
  from public.seller_wallet_transactions
  where idempotency_key = p_idempotency_key
  limit 1;
  if found then
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_existing_tx.seller_id,
      'hold_id', p_hold_id,
      'available_balance', v_existing_tx.balance_available_after,
      'reserved_balance', v_existing_tx.balance_reserved_after
    );
  end if;

  select *
  into v_hold
  from public.seller_wallet_holds
  where id = p_hold_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'hold_not_found');
  end if;
  if auth.uid() <> v_hold.seller_id and not public.is_admin_user(auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if v_hold.status = 'released' then
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_hold.seller_id,
      'hold_id', v_hold.id,
      'status', v_hold.status
    );
  end if;

  v_release_amount := round(greatest(v_hold.amount - v_hold.captured_amount, 0)::numeric, 2);
  if v_release_amount <= 0 then
    update public.seller_wallet_holds
    set status = case when status = 'active' then 'captured' else status end,
        updated_at = now()
    where id = v_hold.id
    returning * into v_hold;
    return jsonb_build_object(
      'ok', true,
      'seller_id', v_hold.seller_id,
      'hold_id', v_hold.id,
      'status', v_hold.status
    );
  end if;

  select *
  into v_wallet
  from public.seller_wallets
  where seller_id = v_hold.seller_id
  for update;

  update public.seller_wallets
  set
    reserved_balance = greatest(reserved_balance - v_release_amount, 0),
    available_balance = available_balance + v_release_amount,
    updated_at = now()
  where seller_id = v_hold.seller_id
  returning * into v_wallet;

  update public.seller_wallet_holds
  set
    status = 'released',
    released_at = now(),
    updated_at = now(),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('release_reason', p_reason)
  where id = v_hold.id
  returning * into v_hold;

  insert into public.seller_wallet_transactions(
    seller_id, hold_id, reference_id, txn_type, direction, amount,
    balance_available_after, balance_reserved_after,
    idempotency_key, metadata
  ) values (
    v_hold.seller_id, v_hold.id, v_hold.reference_id, 'release', 'credit', v_release_amount,
    v_wallet.available_balance, v_wallet.reserved_balance,
    p_idempotency_key, jsonb_build_object('reason', p_reason)
  );

  return jsonb_build_object(
    'ok', true,
    'seller_id', v_hold.seller_id,
    'hold_id', v_hold.id,
    'released_amount', v_release_amount,
    'status', v_hold.status,
    'available_balance', v_wallet.available_balance,
    'reserved_balance', v_wallet.reserved_balance
  );
end;
$$;

grant execute on function public.wallet_release_seller_delivery(uuid, text, text) to authenticated;

create or replace function public.wallet_release_seller_delivery_by_reference(
  p_seller_id uuid,
  p_reference_id text,
  p_idempotency_key text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold_id uuid;
begin
  select h.id
  into v_hold_id
  from public.seller_wallet_holds h
  where h.seller_id = p_seller_id
    and h.reference_id = p_reference_id
    and h.status in ('active', 'partially_captured')
  order by h.created_at asc
  limit 1;

  if v_hold_id is null then
    return jsonb_build_object('ok', true, 'status', 'no_active_hold');
  end if;

  return public.wallet_release_seller_delivery(
    v_hold_id,
    p_idempotency_key,
    p_reason
  );
end;
$$;

grant execute on function public.wallet_release_seller_delivery_by_reference(uuid, text, text, text) to authenticated;

commit;
