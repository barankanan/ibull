alter table public.ad_credit_codes
  add column if not exists credit_amount numeric(12,2),
  add column if not exists is_active boolean not null default true,
  add column if not exists usage_limit integer not null default 1,
  add column if not exists used_count integer not null default 0,
  add column if not exists seller_id uuid references public.users(id) on delete set null,
  add column if not exists last_redeemed_by uuid references public.users(id) on delete set null,
  add column if not exists last_redeemed_at timestamptz;

update public.ad_credit_codes
set credit_amount = coalesce(credit_amount, amount),
    is_active = case
      when status in ('disabled', 'expired') then false
      else coalesce(is_active, true)
    end,
    usage_limit = case
      when usage_limit < 1 then 1
      else usage_limit
    end,
    used_count = greatest(
      coalesce(used_count, 0),
      case when status = 'redeemed' then 1 else 0 end
    ),
    seller_id = coalesce(seller_id, target_seller_id),
    last_redeemed_by = coalesce(last_redeemed_by, redeemed_by),
    last_redeemed_at = coalesce(last_redeemed_at, redeemed_at)
where credit_amount is null
   or seller_id is null
   or used_count = 0
   or usage_limit = 1
   or last_redeemed_by is null
   or last_redeemed_at is null;

alter table public.ad_credit_codes
  alter column credit_amount set not null;

create index if not exists idx_ad_credit_codes_seller_usage
  on public.ad_credit_codes(seller_id, is_active, created_at desc);

create index if not exists idx_ad_credit_codes_usage_state
  on public.ad_credit_codes(is_active, used_count, usage_limit, created_at desc);

create table if not exists public.ad_credit_redemptions (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.ad_credit_codes(id) on delete cascade,
  code text not null,
  seller_id uuid not null references public.users(id) on delete cascade,
  redeemed_by uuid not null references public.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  credited_amount numeric(12,2) not null check (credited_amount > 0),
  wallet_transaction_id text
    references public.ad_wallet_transactions(id) on delete set null,
  campaign_id text references public.campaigns(id) on delete set null,
  status text not null default 'succeeded',
  note text,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists idx_ad_credit_redemptions_code_seller
  on public.ad_credit_redemptions(code_id, seller_id);

create index if not exists idx_ad_credit_redemptions_seller_date
  on public.ad_credit_redemptions(seller_id, redeemed_at desc);

create index if not exists idx_ad_credit_redemptions_code_date
  on public.ad_credit_redemptions(code_id, redeemed_at desc);

alter table public.ad_credit_redemptions enable row level security;

drop policy if exists "ad_credit_codes_admin_select" on public.ad_credit_codes;
create policy "ad_credit_codes_admin_select"
on public.ad_credit_codes
for select
using (
  public.is_admin_user()
  or redeemed_by = auth.uid()
  or target_seller_id = auth.uid()
  or seller_id = auth.uid()
);

drop policy if exists "ad_credit_redemptions_admin_select" on public.ad_credit_redemptions;
create policy "ad_credit_redemptions_admin_select"
on public.ad_credit_redemptions
for select
using (public.is_admin_user() or seller_id = auth.uid() or redeemed_by = auth.uid());

create or replace function public.preview_ad_credit_code(p_code text)
returns table(
  code text,
  credit_amount numeric,
  status text,
  target_seller_id uuid,
  note text,
  can_redeem boolean,
  reason text,
  is_active boolean,
  usage_limit integer,
  used_count integer,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_code_row public.ad_credit_codes%rowtype;
  v_already_used boolean := false;
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
      'not_found'::text,
      false,
      0,
      0,
      null::timestamptz;
    return;
  end if;

  if v_code_row.expires_at is not null and v_code_row.expires_at < now() then
    update public.ad_credit_codes
    set status = 'expired',
        is_active = false,
        updated_at = now()
    where id = v_code_row.id
      and status <> 'expired';
    return query
    select
      v_code_row.code,
      coalesce(v_code_row.credit_amount, v_code_row.amount),
      'expired'::text,
      coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
      v_code_row.note,
      false,
      'expired'::text,
      false,
      v_code_row.usage_limit,
      v_code_row.used_count,
      v_code_row.expires_at;
    return;
  end if;

  select exists(
    select 1
    from public.ad_credit_redemptions redemptions
    where redemptions.code_id = v_code_row.id
      and redemptions.seller_id = v_user_id
  )
  into v_already_used;

  if coalesce(v_code_row.seller_id, v_code_row.target_seller_id) is not null
     and coalesce(v_code_row.seller_id, v_code_row.target_seller_id) <> v_user_id
     and not public.is_admin_user() then
    return query
    select
      v_code_row.code,
      coalesce(v_code_row.credit_amount, v_code_row.amount),
      v_code_row.status,
      coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
      v_code_row.note,
      false,
      'assigned_to_another_seller'::text,
      v_code_row.is_active,
      v_code_row.usage_limit,
      v_code_row.used_count,
      v_code_row.expires_at;
    return;
  end if;

  if v_already_used then
    return query
    select
      v_code_row.code,
      coalesce(v_code_row.credit_amount, v_code_row.amount),
      'redeemed'::text,
      coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
      v_code_row.note,
      false,
      'already_used_by_seller'::text,
      false,
      v_code_row.usage_limit,
      greatest(v_code_row.used_count, 1),
      v_code_row.expires_at;
    return;
  end if;

  if not coalesce(v_code_row.is_active, true)
     or v_code_row.status = 'disabled' then
    return query
    select
      v_code_row.code,
      coalesce(v_code_row.credit_amount, v_code_row.amount),
      v_code_row.status,
      coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
      v_code_row.note,
      false,
      'inactive'::text,
      false,
      v_code_row.usage_limit,
      v_code_row.used_count,
      v_code_row.expires_at;
    return;
  end if;

  if v_code_row.used_count >= v_code_row.usage_limit then
    return query
    select
      v_code_row.code,
      coalesce(v_code_row.credit_amount, v_code_row.amount),
      'redeemed'::text,
      coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
      v_code_row.note,
      false,
      'usage_limit_reached'::text,
      false,
      v_code_row.usage_limit,
      v_code_row.used_count,
      v_code_row.expires_at;
    return;
  end if;

  return query
  select
    v_code_row.code,
    coalesce(v_code_row.credit_amount, v_code_row.amount),
    'active'::text,
    coalesce(v_code_row.seller_id, v_code_row.target_seller_id),
    v_code_row.note,
    true,
    'ready'::text,
    true,
    v_code_row.usage_limit,
    v_code_row.used_count,
    v_code_row.expires_at;
end;
$$;

create or replace function public.redeem_ad_credit_code(p_code text)
returns table(
  code text,
  credit_amount numeric,
  balance_after numeric,
  wallet_transaction_id text,
  redemption_id uuid,
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
  v_redemption_id uuid := gen_random_uuid();
  v_new_used_count integer := 0;
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
        is_active = false,
        updated_at = now()
    where id = v_code_row.id;
    raise exception 'CREDIT_CODE_EXPIRED';
  end if;

  if coalesce(v_code_row.seller_id, v_code_row.target_seller_id) is not null
     and coalesce(v_code_row.seller_id, v_code_row.target_seller_id) <> v_user_id
     and not public.is_admin_user() then
    raise exception 'CREDIT_CODE_NOT_ASSIGNED_TO_THIS_SELLER';
  end if;

  if exists (
    select 1
    from public.ad_credit_redemptions redemptions
    where redemptions.code_id = v_code_row.id
      and redemptions.seller_id = v_user_id
  ) then
    raise exception 'CREDIT_CODE_ALREADY_USED_BY_THIS_SELLER';
  end if;

  if not coalesce(v_code_row.is_active, true)
     or v_code_row.status = 'disabled' then
    raise exception 'CREDIT_CODE_INACTIVE';
  end if;

  if v_code_row.used_count >= v_code_row.usage_limit then
    update public.ad_credit_codes
    set is_active = false,
        status = 'redeemed',
        updated_at = now()
    where id = v_code_row.id;
    raise exception 'CREDIT_CODE_USAGE_LIMIT_REACHED';
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
    coalesce(v_code_row.credit_amount, v_code_row.amount),
    v_current_balance,
    v_current_balance + coalesce(v_code_row.credit_amount, v_code_row.amount),
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

  insert into public.ad_credit_redemptions (
    id,
    code_id,
    code,
    seller_id,
    redeemed_by,
    redeemed_at,
    credited_amount,
    wallet_transaction_id,
    status,
    note,
    metadata
  ) values (
    v_redemption_id,
    v_code_row.id,
    v_code_row.code,
    v_user_id,
    v_user_id,
    now(),
    coalesce(v_code_row.credit_amount, v_code_row.amount),
    v_wallet_transaction_id,
    'succeeded',
    coalesce(v_code_row.note, 'Admin reklam kredisi kodu kullanildi'),
    jsonb_build_object(
      'credit_code_batch_id', v_code_row.batch_id,
      'credit_code_id', v_code_row.id
    )
  );

  v_new_used_count := v_code_row.used_count + 1;

  update public.ad_credit_codes
  set used_count = v_new_used_count,
      is_active = case
        when v_new_used_count >= usage_limit then false
        else true
      end,
      status = case
        when v_new_used_count >= usage_limit then 'redeemed'
        else 'active'
      end,
      redeemed_by = case
        when v_new_used_count >= usage_limit then v_user_id
        else redeemed_by
      end,
      redeemed_at = case
        when v_new_used_count >= usage_limit then now()
        else redeemed_at
      end,
      redeemed_wallet_transaction_id = case
        when v_new_used_count >= usage_limit then v_wallet_transaction_id
        else redeemed_wallet_transaction_id
      end,
      last_redeemed_by = v_user_id,
      last_redeemed_at = now(),
      updated_at = now()
  where id = v_code_row.id;

  return query
  select
    v_code_row.code,
    coalesce(v_code_row.credit_amount, v_code_row.amount),
    v_current_balance + coalesce(v_code_row.credit_amount, v_code_row.amount),
    v_wallet_transaction_id,
    v_redemption_id,
    v_user_id;
end;
$$;

grant execute on function public.preview_ad_credit_code(text) to authenticated;
grant execute on function public.redeem_ad_credit_code(text) to authenticated;
