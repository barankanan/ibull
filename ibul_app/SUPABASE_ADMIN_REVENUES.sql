-- Admin manuel gelir kayıtları (Finans > Gelir > Gelir Ekle).
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- Otomatik sipariş/reklam/kargo gelirleriyle çift sayım yapılmaz; yalnızca manuel kayıtlar.

create extension if not exists pgcrypto;

create table if not exists public.admin_revenues (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  amount numeric(14, 2) not null default 0,
  revenue_date date not null default current_date,
  status text not null default 'received',
  type text not null default 'one_time',
  recurrence text null,
  source text null,
  payment_method text null,
  reference_no text null,
  note text null,
  created_by uuid null references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  constraint admin_revenues_amount_nonneg check (amount >= 0),
  constraint admin_revenues_title_nonempty check (length(trim(title)) > 0),
  constraint admin_revenues_category_nonempty check (length(trim(category)) > 0),
  constraint admin_revenues_type_check check (type in ('one_time', 'recurring')),
  constraint admin_revenues_status_check check (
    status in ('received', 'pending', 'cancelled')
  ),
  constraint admin_revenues_recurrence_check check (
    recurrence is null
    or recurrence in ('weekly', 'monthly', 'yearly')
  ),
  constraint admin_revenues_recurring_recurrence_check check (
    type = 'one_time'
    or recurrence is not null
  )
);

alter table public.admin_revenues
  add column if not exists title text;

alter table public.admin_revenues
  add column if not exists category text;

alter table public.admin_revenues
  add column if not exists amount numeric(14, 2) not null default 0;

alter table public.admin_revenues
  add column if not exists revenue_date date not null default current_date;

alter table public.admin_revenues
  add column if not exists status text not null default 'received';

alter table public.admin_revenues
  add column if not exists type text not null default 'one_time';

alter table public.admin_revenues
  add column if not exists recurrence text null;

alter table public.admin_revenues
  add column if not exists source text null;

alter table public.admin_revenues
  add column if not exists payment_method text null;

alter table public.admin_revenues
  add column if not exists reference_no text null;

alter table public.admin_revenues
  add column if not exists note text null;

alter table public.admin_revenues
  add column if not exists created_by uuid null;

alter table public.admin_revenues
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table public.admin_revenues
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.admin_revenues
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists idx_admin_revenues_revenue_date
  on public.admin_revenues (revenue_date desc);

create index if not exists idx_admin_revenues_category
  on public.admin_revenues (category);

create index if not exists idx_admin_revenues_status
  on public.admin_revenues (status);

create index if not exists idx_admin_revenues_created_at
  on public.admin_revenues (created_at desc);

drop trigger if exists admin_revenues_set_updated_at on public.admin_revenues;
create trigger admin_revenues_set_updated_at
before update on public.admin_revenues
for each row execute function public.set_updated_at_admin_finance();

grant select, insert, update, delete on table public.admin_revenues to authenticated;

alter table public.admin_revenues enable row level security;

drop policy if exists "admin_revenues_select" on public.admin_revenues;
drop policy if exists "admin_revenues_insert" on public.admin_revenues;
drop policy if exists "admin_revenues_update" on public.admin_revenues;
drop policy if exists "admin_revenues_delete" on public.admin_revenues;

create policy "admin_revenues_select"
on public.admin_revenues for select to authenticated
using (public.current_admin_can_access_finance());

create policy "admin_revenues_insert"
on public.admin_revenues for insert to authenticated
with check (public.current_admin_can_access_finance());

create policy "admin_revenues_update"
on public.admin_revenues for update to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "admin_revenues_delete"
on public.admin_revenues for delete to authenticated
using (public.current_admin_can_access_finance());
