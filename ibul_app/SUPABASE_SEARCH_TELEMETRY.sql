create extension if not exists pgcrypto;

create table if not exists public.search_telemetry (
  id uuid primary key default gen_random_uuid(),
  query text not null,
  normalized_query text not null,
  source text not null default 'search_results',
  user_id uuid references auth.users(id) on delete set null,
  viewer_key text,
  is_registered boolean not null default false,
  delivery_address text,
  city text,
  district text,
  result_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

alter table if exists public.search_telemetry
  add column if not exists viewer_key text;

create index if not exists idx_search_telemetry_created_at
  on public.search_telemetry(created_at desc);

create index if not exists idx_search_telemetry_city_district
  on public.search_telemetry(city, district, created_at desc);

create index if not exists idx_search_telemetry_normalized_query
  on public.search_telemetry(normalized_query);

create index if not exists idx_search_telemetry_viewer_key
  on public.search_telemetry(viewer_key);

grant usage on schema public to anon, authenticated;
grant select, insert on public.search_telemetry to anon, authenticated;

alter table public.search_telemetry enable row level security;

drop policy if exists "search_telemetry_insert_public" on public.search_telemetry;
create policy "search_telemetry_insert_public"
on public.search_telemetry
for insert
to anon, authenticated
with check (
  user_id is null or auth.uid() = user_id
);

drop policy if exists "search_telemetry_select_authenticated" on public.search_telemetry;
create policy "search_telemetry_select_authenticated"
on public.search_telemetry
for select
to authenticated
using (true);
