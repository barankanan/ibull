-- Seller-scoped customer address book for Kargo Çıkışı.
-- Does not touch orders, order_items, courier, ihiz, or print tables.

create extension if not exists pgcrypto;

create table if not exists public.seller_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  customer_phone text not null,
  city text not null,
  district text not null,
  building text,
  address text not null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint seller_saved_addresses_name_not_blank
    check (char_length(btrim(customer_name)) > 0),
  constraint seller_saved_addresses_phone_not_blank
    check (char_length(btrim(customer_phone)) > 0),
  constraint seller_saved_addresses_city_not_blank
    check (char_length(btrim(city)) > 0),
  constraint seller_saved_addresses_district_not_blank
    check (char_length(btrim(district)) > 0),
  constraint seller_saved_addresses_address_not_blank
    check (char_length(btrim(address)) > 0)
);

create index if not exists idx_seller_saved_addresses_seller_created
  on public.seller_saved_addresses (seller_id, created_at desc);

create or replace function public.touch_seller_saved_addresses_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_seller_saved_addresses_updated_at
  on public.seller_saved_addresses;
create trigger trg_seller_saved_addresses_updated_at
before update on public.seller_saved_addresses
for each row
execute function public.touch_seller_saved_addresses_updated_at();

alter table public.seller_saved_addresses enable row level security;

drop policy if exists "seller_saved_addresses_select_own"
  on public.seller_saved_addresses;
create policy "seller_saved_addresses_select_own"
on public.seller_saved_addresses
for select
to authenticated
using (auth.uid() = seller_id);

drop policy if exists "seller_saved_addresses_insert_own"
  on public.seller_saved_addresses;
create policy "seller_saved_addresses_insert_own"
on public.seller_saved_addresses
for insert
to authenticated
with check (auth.uid() = seller_id);

drop policy if exists "seller_saved_addresses_update_own"
  on public.seller_saved_addresses;
create policy "seller_saved_addresses_update_own"
on public.seller_saved_addresses
for update
to authenticated
using (auth.uid() = seller_id)
with check (auth.uid() = seller_id);

drop policy if exists "seller_saved_addresses_delete_own"
  on public.seller_saved_addresses;
create policy "seller_saved_addresses_delete_own"
on public.seller_saved_addresses
for delete
to authenticated
using (auth.uid() = seller_id);

revoke all on public.seller_saved_addresses from public, anon;
grant select, insert, update, delete on public.seller_saved_addresses
  to authenticated;

notify pgrst, 'reload schema';
