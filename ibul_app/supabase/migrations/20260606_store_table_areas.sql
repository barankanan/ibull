-- Dining areas for store tables (Salon/Bahçe/Teras...) + display labels.
-- Safe to run multiple times.

create extension if not exists pgcrypto;

-- Areas (dining zones). Keep name unique per seller.
create table if not exists public.store_table_areas (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores(seller_id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint store_table_areas_name_nonempty check (char_length(trim(name)) > 0)
);

create unique index if not exists idx_store_table_areas_unique_name
  on public.store_table_areas (seller_id, lower(name));

create index if not exists idx_store_table_areas_seller_active
  on public.store_table_areas (seller_id, is_active, name);

alter table public.store_table_areas enable row level security;

drop policy if exists "Public can read active table areas" on public.store_table_areas;
create policy "Public can read active table areas"
  on public.store_table_areas
  for select
  using (is_active = true);

drop policy if exists "Seller can manage own table areas" on public.store_table_areas;
create policy "Seller can manage own table areas"
  on public.store_table_areas
  for all
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

-- Ensure store_tables has area + display fields (non-breaking: keep table_number semantics).
alter table public.store_tables
  add column if not exists area_id uuid references public.store_table_areas(id) on delete set null;

alter table public.store_tables
  add column if not exists area_name text;

alter table public.store_tables
  add column if not exists area_table_number integer;

alter table public.store_tables
  add column if not exists table_name text;

alter table public.store_tables
  add column if not exists display_label text;

create index if not exists idx_store_tables_area_lookup
  on public.store_tables (seller_id, area_id, is_active, table_number);

-- Updated_at trigger already exists for store_tables; reuse it for areas.
drop trigger if exists trg_store_table_areas_updated_at on public.store_table_areas;
create trigger trg_store_table_areas_updated_at
before update on public.store_table_areas
for each row
execute procedure public.set_store_tables_updated_at();

-- Backfill: create default area ("Salon") per seller that already has tables.
insert into public.store_table_areas (seller_id, name)
select distinct st.seller_id, 'Salon'::text
from public.store_tables st
where st.seller_id is not null
  and not exists (
    select 1
    from public.store_table_areas a
    where a.seller_id = st.seller_id
      and lower(a.name) = lower('Salon')
  );

-- Backfill store_tables: attach to default area if missing.
update public.store_tables st
set
  area_id = coalesce(
    st.area_id,
    (
      select a.id
      from public.store_table_areas a
      where a.seller_id = st.seller_id
        and lower(a.name) = lower('Salon')
      limit 1
    )
  )
where st.area_id is null;

-- Backfill display fields (safe, idempotent).
update public.store_tables st
set
  area_name = coalesce(st.area_name, a.name),
  area_table_number = coalesce(st.area_table_number, st.table_number),
  table_name = coalesce(st.table_name, (a.name || ' ' || st.table_number::text)),
  display_label = coalesce(st.display_label, (a.name || ' ' || st.table_number::text))
from public.store_table_areas a
where st.area_id = a.id
  and st.seller_id = a.seller_id;

