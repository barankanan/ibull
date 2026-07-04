-- Admin operasyon giderleri (Finans > Giderler).
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- Yatırım hareketleri admin_investment_* tablolarında ayrı tutulur.

create extension if not exists pgcrypto;

create table if not exists public.admin_expenses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  amount numeric(14, 2) not null default 0,
  expense_date date not null default current_date,
  type text not null default 'one_time',
  recurrence text null,
  status text not null default 'paid',
  payment_method text null,
  vendor text null,
  invoice_url text null,
  note text null,
  created_by uuid null references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  constraint admin_expenses_amount_nonneg check (amount >= 0),
  constraint admin_expenses_type_check check (
    type in ('one_time', 'recurring')
  ),
  constraint admin_expenses_status_check check (
    status in ('paid', 'pending', 'cancelled')
  ),
  constraint admin_expenses_recurrence_check check (
    recurrence is null
    or recurrence in ('weekly', 'monthly', 'yearly')
  ),
  constraint admin_expenses_recurring_recurrence_check check (
    type = 'one_time'
    or recurrence is not null
  )
);

alter table public.admin_expenses
  add column if not exists title text;

alter table public.admin_expenses
  add column if not exists category text;

alter table public.admin_expenses
  add column if not exists amount numeric(14, 2) not null default 0;

alter table public.admin_expenses
  add column if not exists expense_date date not null default current_date;

alter table public.admin_expenses
  add column if not exists type text not null default 'one_time';

alter table public.admin_expenses
  add column if not exists recurrence text null;

alter table public.admin_expenses
  add column if not exists status text not null default 'paid';

alter table public.admin_expenses
  add column if not exists payment_method text null;

alter table public.admin_expenses
  add column if not exists vendor text null;

alter table public.admin_expenses
  add column if not exists invoice_url text null;

alter table public.admin_expenses
  add column if not exists note text null;

alter table public.admin_expenses
  add column if not exists created_by uuid null;

alter table public.admin_expenses
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table public.admin_expenses
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.admin_expenses
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists idx_admin_expenses_expense_date
  on public.admin_expenses (expense_date desc);

create index if not exists idx_admin_expenses_category
  on public.admin_expenses (category);

create index if not exists idx_admin_expenses_status
  on public.admin_expenses (status);

create index if not exists idx_admin_expenses_created_at
  on public.admin_expenses (created_at desc);

create or replace function public.set_updated_at_admin_finance()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists admin_expenses_set_updated_at on public.admin_expenses;
create trigger admin_expenses_set_updated_at
before update on public.admin_expenses
for each row execute function public.set_updated_at_admin_finance();

alter table public.admin_expenses enable row level security;

drop policy if exists "admin_expenses_select" on public.admin_expenses;
create policy "admin_expenses_select"
on public.admin_expenses
for select
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_expenses_manage" on public.admin_expenses;
create policy "admin_expenses_manage"
on public.admin_expenses
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
