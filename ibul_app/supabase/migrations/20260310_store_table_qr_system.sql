-- Store table QR system for restaurant table-based ordering.
-- Safe to run multiple times.

create extension if not exists pgcrypto;

create table if not exists public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores(seller_id) on delete cascade,
  table_number integer not null,
  qr_token text not null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint store_tables_table_number_positive check (table_number > 0)
);

create unique index if not exists idx_store_tables_unique_table
  on public.store_tables (seller_id, table_number);

create unique index if not exists idx_store_tables_unique_token
  on public.store_tables (seller_id, qr_token);

create index if not exists idx_store_tables_seller_active
  on public.store_tables (seller_id, is_active, table_number);

alter table public.store_tables enable row level security;

drop policy if exists "Public can read active store tables for QR" on public.store_tables;
create policy "Public can read active store tables for QR"
  on public.store_tables
  for select
  using (is_active = true);

drop policy if exists "Seller can manage own store tables" on public.store_tables;
create policy "Seller can manage own store tables"
  on public.store_tables
  for all
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

create or replace function public.set_store_tables_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_store_tables_updated_at on public.store_tables;
create trigger trg_store_tables_updated_at
before update on public.store_tables
for each row
execute procedure public.set_store_tables_updated_at();
