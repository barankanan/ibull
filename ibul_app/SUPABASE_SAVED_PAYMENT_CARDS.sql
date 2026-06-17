-- Saved payment cards (tokenized metadata only — never raw PAN/CVV)
-- Safe to run multiple times.

create extension if not exists pgcrypto;

create table if not exists public.saved_payment_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  provider_card_token text not null,
  card_holder_name text,
  card_alias text,
  card_brand text,
  card_last4 text not null,
  exp_month int,
  exp_year int,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint saved_payment_cards_last4_len
    check (char_length(card_last4) = 4),
  constraint saved_payment_cards_exp_month_range
    check (exp_month is null or (exp_month between 1 and 12)),
  constraint saved_payment_cards_exp_year_range
    check (exp_year is null or exp_year >= 2000)
);

create unique index if not exists idx_saved_payment_cards_user_provider_token_active
  on public.saved_payment_cards(user_id, provider, provider_card_token)
  where is_active = true and deleted_at is null;

create index if not exists idx_saved_payment_cards_user_active
  on public.saved_payment_cards(user_id, is_default desc, created_at desc)
  where is_active = true and deleted_at is null;

create or replace function public.touch_saved_payment_cards_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_saved_payment_cards_updated_at on public.saved_payment_cards;
create trigger trg_saved_payment_cards_updated_at
before update on public.saved_payment_cards
for each row
execute function public.touch_saved_payment_cards_updated_at();

alter table public.saved_payment_cards enable row level security;

drop policy if exists "saved_payment_cards_select_own" on public.saved_payment_cards;
create policy "saved_payment_cards_select_own"
on public.saved_payment_cards
for select
to authenticated
using (
  auth.uid() = user_id
  and is_active = true
  and deleted_at is null
);

drop policy if exists "saved_payment_cards_insert_own" on public.saved_payment_cards;
create policy "saved_payment_cards_insert_own"
on public.saved_payment_cards
for insert
to authenticated
with check (
  auth.uid() = user_id
  and is_active = true
  and deleted_at is null
);

drop policy if exists "saved_payment_cards_update_own" on public.saved_payment_cards;
create policy "saved_payment_cards_update_own"
on public.saved_payment_cards
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
