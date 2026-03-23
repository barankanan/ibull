create table if not exists public.store_location_change_requests (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  business_name text,
  address text,
  city text,
  district text,
  current_lat double precision,
  current_lng double precision,
  requested_lat double precision not null,
  requested_lng double precision not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  rejected_at timestamptz
);

create index if not exists idx_store_location_change_requests_seller_id
  on public.store_location_change_requests (seller_id);

create index if not exists idx_store_location_change_requests_status
  on public.store_location_change_requests (status);

alter table public.store_location_change_requests enable row level security;

drop policy if exists "store_location_change_requests_select_own" on public.store_location_change_requests;
create policy "store_location_change_requests_select_own"
on public.store_location_change_requests
for select
to authenticated
using (auth.uid() = seller_id);

drop policy if exists "store_location_change_requests_insert_own" on public.store_location_change_requests;
create policy "store_location_change_requests_insert_own"
on public.store_location_change_requests
for insert
to authenticated
with check (auth.uid() = seller_id);

drop policy if exists "store_location_change_requests_delete_own_pending" on public.store_location_change_requests;
create policy "store_location_change_requests_delete_own_pending"
on public.store_location_change_requests
for delete
to authenticated
using (auth.uid() = seller_id and status = 'pending');

-- Admin panel service-role ile kullaniliyorsa ek policy gerekmez.
-- Eğer admin authenticated role ile çalisiyorsa gecici olarak su policy'leri de aç:

drop policy if exists "store_location_change_requests_admin_select_all" on public.store_location_change_requests;
create policy "store_location_change_requests_admin_select_all"
on public.store_location_change_requests
for select
to authenticated
using (true);

drop policy if exists "store_location_change_requests_admin_update_all" on public.store_location_change_requests;
create policy "store_location_change_requests_admin_update_all"
on public.store_location_change_requests
for update
to authenticated
using (true)
with check (true);
