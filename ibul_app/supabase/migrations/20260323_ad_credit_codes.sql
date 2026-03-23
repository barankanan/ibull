create table if not exists public.ad_credit_codes (
  id uuid primary key default gen_random_uuid(),
  batch_id text not null,
  code text not null unique,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'active'
    check (status in ('active', 'redeemed', 'disabled', 'expired')),
  created_by uuid references public.users(id) on delete set null,
  target_seller_id uuid references public.users(id) on delete set null,
  redeemed_by uuid references public.users(id) on delete set null,
  redeemed_wallet_transaction_id text
    references public.ad_wallet_transactions(id) on delete set null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz,
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_ad_credit_codes_batch_id
  on public.ad_credit_codes(batch_id, created_at desc);

create index if not exists idx_ad_credit_codes_target_seller
  on public.ad_credit_codes(target_seller_id, status, created_at desc);

create index if not exists idx_ad_credit_codes_status
  on public.ad_credit_codes(status, created_at desc);

alter table public.ad_credit_codes enable row level security;

drop policy if exists "ad_credit_codes_admin_select" on public.ad_credit_codes;
create policy "ad_credit_codes_admin_select"
on public.ad_credit_codes
for select
using (
  public.is_admin_user()
  or redeemed_by = auth.uid()
  or target_seller_id = auth.uid()
);

drop policy if exists "ad_credit_codes_admin_insert" on public.ad_credit_codes;
create policy "ad_credit_codes_admin_insert"
on public.ad_credit_codes
for insert
with check (public.is_admin_user());

drop policy if exists "ad_credit_codes_admin_update" on public.ad_credit_codes;
create policy "ad_credit_codes_admin_update"
on public.ad_credit_codes
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists "ad_credit_codes_admin_delete" on public.ad_credit_codes;
create policy "ad_credit_codes_admin_delete"
on public.ad_credit_codes
for delete
using (public.is_admin_user());

create or replace function public.preview_ad_credit_code(p_code text)
returns table(
  code text,
  amount numeric,
  status text,
  target_seller_id uuid,
  note text,
  can_redeem boolean,
  reason text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_code_row public.ad_credit_codes%rowtype;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_code_row
  from public.ad_credit_codes
  where upper(code) = upper(trim(p_code))
  limit 1;

  if not found then
    return query
    select
      upper(trim(p_code)),
      0::numeric,
      'missing'::text,
      null::uuid,
      null::text,
      false,
      'not_found'::text;
    return;
  end if;

  if v_code_row.expires_at is not null and v_code_row.expires_at < now() then
    return query
    select
      v_code_row.code,
      v_code_row.amount,
      'expired'::text,
      v_code_row.target_seller_id,
      v_code_row.note,
      false,
      'expired'::text;
    return;
  end if;

  if v_code_row.status = 'redeemed' then
    return query
    select
      v_code_row.code,
      v_code_row.amount,
      v_code_row.status,
      v_code_row.target_seller_id,
      v_code_row.note,
      false,
      case
        when v_code_row.redeemed_by = v_user_id then 'redeemed_by_current_seller'
        else 'redeemed'
      end;
    return;
  end if;

  if v_code_row.status <> 'active' then
    return query
    select
      v_code_row.code,
      v_code_row.amount,
      v_code_row.status,
      v_code_row.target_seller_id,
      v_code_row.note,
      false,
      'inactive'::text;
    return;
  end if;

  if v_code_row.target_seller_id is not null
     and v_code_row.target_seller_id <> v_user_id
     and not public.is_admin_user() then
    return query
    select
      v_code_row.code,
      v_code_row.amount,
      v_code_row.status,
      v_code_row.target_seller_id,
      v_code_row.note,
      false,
      'assigned_to_another_seller'::text;
    return;
  end if;

  return query
  select
    v_code_row.code,
    v_code_row.amount,
    v_code_row.status,
    v_code_row.target_seller_id,
    v_code_row.note,
    true,
    'ready'::text;
end;
$$;

create or replace function public.redeem_ad_credit_code(p_code text)
returns table(
  code text,
  amount numeric,
  balance_after numeric,
  wallet_transaction_id text,
  seller_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_code_row public.ad_credit_codes%rowtype;
  v_current_balance numeric(12,2) := 0;
  v_wallet_transaction_id text := 'wallet-' || replace(gen_random_uuid()::text, '-', '');
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select *
  into v_code_row
  from public.ad_credit_codes
  where upper(code) = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'INVALID_CREDIT_CODE';
  end if;

  if v_code_row.expires_at is not null and v_code_row.expires_at < now() then
    update public.ad_credit_codes
    set status = 'expired',
        updated_at = now()
    where id = v_code_row.id;
    raise exception 'CREDIT_CODE_EXPIRED';
  end if;

  if v_code_row.status <> 'active' then
    raise exception 'CREDIT_CODE_NOT_ACTIVE';
  end if;

  if v_code_row.target_seller_id is not null
     and v_code_row.target_seller_id <> v_user_id
     and not public.is_admin_user() then
    raise exception 'CREDIT_CODE_NOT_ASSIGNED_TO_THIS_SELLER';
  end if;

  select coalesce(balance_after, 0)
  into v_current_balance
  from public.ad_wallet_transactions
  where seller_id = v_user_id
  order by created_at desc
  limit 1;

  insert into public.ad_wallet_transactions (
    id,
    seller_id,
    type,
    status,
    amount,
    balance_before,
    balance_after,
    reference,
    approved_by,
    note,
    metadata,
    created_at
  ) values (
    v_wallet_transaction_id,
    v_user_id,
    'bonus_credit',
    'succeeded',
    v_code_row.amount,
    v_current_balance,
    v_current_balance + v_code_row.amount,
    v_code_row.code,
    v_code_row.created_by,
    coalesce(v_code_row.note, 'Admin reklam kredisi kodu kullanildi'),
    jsonb_build_object(
      'credit_code', v_code_row.code,
      'credit_code_batch_id', v_code_row.batch_id,
      'credit_code_id', v_code_row.id
    ),
    now()
  );

  update public.ad_credit_codes
  set status = 'redeemed',
      redeemed_by = v_user_id,
      redeemed_at = now(),
      redeemed_wallet_transaction_id = v_wallet_transaction_id,
      updated_at = now()
  where id = v_code_row.id;

  return query
  select
    v_code_row.code,
    v_code_row.amount,
    v_current_balance + v_code_row.amount,
    v_wallet_transaction_id,
    v_user_id;
end;
$$;

grant execute on function public.preview_ad_credit_code(text) to authenticated;
grant execute on function public.redeem_ad_credit_code(text) to authenticated;
