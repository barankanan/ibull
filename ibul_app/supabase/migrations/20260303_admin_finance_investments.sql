create table if not exists public.admin_investment_entries (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  amount numeric(14, 2) not null check (amount > 0),
  investment_date timestamptz not null,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_investment_allocations (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  amount numeric(14, 2) not null check (amount > 0),
  spent_at timestamptz not null,
  note text not null default '',
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_admin_investment_entries_date
  on public.admin_investment_entries (investment_date desc);

create index if not exists idx_admin_investment_allocations_spent_at
  on public.admin_investment_allocations (spent_at desc);

create or replace function public.set_updated_at_admin_finance()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists admin_investment_entries_set_updated_at on public.admin_investment_entries;
create trigger admin_investment_entries_set_updated_at
before update on public.admin_investment_entries
for each row execute function public.set_updated_at_admin_finance();

drop trigger if exists admin_investment_allocations_set_updated_at on public.admin_investment_allocations;
create trigger admin_investment_allocations_set_updated_at
before update on public.admin_investment_allocations
for each row execute function public.set_updated_at_admin_finance();

alter table public.admin_investment_entries enable row level security;
alter table public.admin_investment_allocations enable row level security;

drop policy if exists "admin_investment_entries_select" on public.admin_investment_entries;
create policy "admin_investment_entries_select"
on public.admin_investment_entries
for select
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_investment_entries_manage" on public.admin_investment_entries;
create policy "admin_investment_entries_manage"
on public.admin_investment_entries
for all
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_investment_allocations_select" on public.admin_investment_allocations;
create policy "admin_investment_allocations_select"
on public.admin_investment_allocations
for select
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_investment_allocations_manage" on public.admin_investment_allocations;
create policy "admin_investment_allocations_manage"
on public.admin_investment_allocations
for all
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);
