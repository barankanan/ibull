create extension if not exists pgcrypto;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_type text not null default 'user',
  category text not null default 'Genel',
  subject text not null,
  description text not null,
  status text not null default 'open',
  priority text not null default 'medium',
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint support_tickets_status_check
    check (status in ('open', 'in_progress', 'closed', 'resolved')),
  constraint support_tickets_priority_check
    check (priority in ('low', 'medium', 'high')),
  constraint support_tickets_user_type_check
    check (user_type in ('user', 'seller', 'admin'))
);

create index if not exists idx_support_tickets_user_id
  on public.support_tickets(user_id, created_at desc);

create index if not exists idx_support_tickets_status
  on public.support_tickets(status, created_at desc);

create index if not exists idx_support_tickets_category
  on public.support_tickets(category, created_at desc);

create or replace function public.touch_support_ticket_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_support_tickets_updated_at on public.support_tickets;
create trigger trg_support_tickets_updated_at
before update on public.support_tickets
for each row
execute function public.touch_support_ticket_updated_at();

alter table public.support_tickets enable row level security;

drop policy if exists "support_tickets_select_own" on public.support_tickets;
create policy "support_tickets_select_own"
on public.support_tickets
for select
to authenticated
using (
  auth.uid() = user_id
  or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
);

drop policy if exists "support_tickets_insert_own" on public.support_tickets;
create policy "support_tickets_insert_own"
on public.support_tickets
for insert
to authenticated
with check (
  auth.uid() = user_id
  or coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
);

drop policy if exists "support_tickets_update_admin" on public.support_tickets;
create policy "support_tickets_update_admin"
on public.support_tickets
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
