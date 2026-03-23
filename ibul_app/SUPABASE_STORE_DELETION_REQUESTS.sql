create extension if not exists pgcrypto;

alter table public.stores
add column if not exists is_deletion_requested boolean not null default false;

create table if not exists public.store_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  status text not null default 'pending',
  admin_note text,
  created_at timestamptz not null default timezone('utc', now()),
  approved_at timestamptz,
  rejected_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint store_deletion_requests_status_check
    check (status in ('pending', 'approved', 'rejected'))
);

create unique index if not exists idx_store_deletion_requests_pending_unique
  on public.store_deletion_requests (seller_id)
  where status = 'pending';

create index if not exists idx_store_deletion_requests_status
  on public.store_deletion_requests(status, created_at desc);

create or replace function public.touch_store_deletion_request_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_store_deletion_requests_updated_at on public.store_deletion_requests;
create trigger trg_store_deletion_requests_updated_at
before update on public.store_deletion_requests
for each row
execute function public.touch_store_deletion_request_updated_at();

alter table public.store_deletion_requests enable row level security;

drop policy if exists "store_deletion_requests_select_own" on public.store_deletion_requests;
create policy "store_deletion_requests_select_own"
on public.store_deletion_requests
for select
to authenticated
using (
  auth.uid() = seller_id
  or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
);

drop policy if exists "store_deletion_requests_insert_own" on public.store_deletion_requests;
create policy "store_deletion_requests_insert_own"
on public.store_deletion_requests
for insert
to authenticated
with check (
  auth.uid() = seller_id
  or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
);

drop policy if exists "store_deletion_requests_update_admin" on public.store_deletion_requests;
create policy "store_deletion_requests_update_admin"
on public.store_deletion_requests
for update
to authenticated
using (
  coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
)
with check (
  coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
);
