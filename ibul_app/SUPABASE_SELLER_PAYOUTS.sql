-- Satıcı hakediş kayıtları (Admin > Finans > Hakedişler).
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- Canlı hakediş order_items üzerinden hesaplanır; bu tablo ödeme durumu kaydı tutar.

create extension if not exists pgcrypto;

create table if not exists public.seller_payouts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.users (id) on delete cascade,
  store_id uuid null references public.stores (seller_id) on delete set null,
  store_name text null,
  period_start date not null,
  period_end date not null,
  gross_amount numeric(14, 2) not null default 0,
  commission_amount numeric(14, 2) not null default 0,
  refund_amount numeric(14, 2) not null default 0,
  deductions_amount numeric(14, 2) not null default 0,
  net_payout_amount numeric(14, 2) not null default 0,
  order_count int not null default 0,
  item_count int not null default 0,
  status text not null default 'pending',
  payment_method text null,
  payment_reference text null,
  paid_at timestamptz null,
  approved_at timestamptz null,
  approved_by uuid null references public.users (id) on delete set null,
  paid_by uuid null references public.users (id) on delete set null,
  note text null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  constraint seller_payouts_gross_nonneg check (gross_amount >= 0),
  constraint seller_payouts_commission_nonneg check (commission_amount >= 0),
  constraint seller_payouts_refund_nonneg check (refund_amount >= 0),
  constraint seller_payouts_deductions_nonneg check (deductions_amount >= 0),
  constraint seller_payouts_net_nonneg check (net_payout_amount >= 0),
  constraint seller_payouts_status_check check (
    status in ('pending', 'approved', 'paid', 'disputed', 'cancelled')
  )
);

alter table public.seller_payouts
  add column if not exists seller_id uuid;

alter table public.seller_payouts
  add column if not exists store_id uuid null;

alter table public.seller_payouts
  add column if not exists store_name text null;

alter table public.seller_payouts
  add column if not exists period_start date not null default current_date;

alter table public.seller_payouts
  add column if not exists period_end date not null default current_date;

alter table public.seller_payouts
  add column if not exists gross_amount numeric(14, 2) not null default 0;

alter table public.seller_payouts
  add column if not exists commission_amount numeric(14, 2) not null default 0;

alter table public.seller_payouts
  add column if not exists refund_amount numeric(14, 2) not null default 0;

alter table public.seller_payouts
  add column if not exists deductions_amount numeric(14, 2) not null default 0;

alter table public.seller_payouts
  add column if not exists net_payout_amount numeric(14, 2) not null default 0;

alter table public.seller_payouts
  add column if not exists order_count int not null default 0;

alter table public.seller_payouts
  add column if not exists item_count int not null default 0;

alter table public.seller_payouts
  add column if not exists status text not null default 'pending';

alter table public.seller_payouts
  add column if not exists payment_method text null;

alter table public.seller_payouts
  add column if not exists payment_reference text null;

alter table public.seller_payouts
  add column if not exists paid_at timestamptz null;

alter table public.seller_payouts
  add column if not exists approved_at timestamptz null;

alter table public.seller_payouts
  add column if not exists approved_by uuid null;

alter table public.seller_payouts
  add column if not exists paid_by uuid null;

alter table public.seller_payouts
  add column if not exists note text null;

alter table public.seller_payouts
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table public.seller_payouts
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.seller_payouts
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create unique index if not exists idx_seller_payouts_period_unique
  on public.seller_payouts (seller_id, period_start, period_end)
  where status <> 'cancelled';

create index if not exists idx_seller_payouts_seller_id
  on public.seller_payouts (seller_id);

create index if not exists idx_seller_payouts_store_id
  on public.seller_payouts (store_id);

create index if not exists idx_seller_payouts_status
  on public.seller_payouts (status);

create index if not exists idx_seller_payouts_period_start
  on public.seller_payouts (period_start desc);

create index if not exists idx_seller_payouts_period_end
  on public.seller_payouts (period_end desc);

create index if not exists idx_seller_payouts_created_at
  on public.seller_payouts (created_at desc);

create or replace function public.set_updated_at_admin_finance()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists seller_payouts_set_updated_at on public.seller_payouts;
create trigger seller_payouts_set_updated_at
before update on public.seller_payouts
for each row execute function public.set_updated_at_admin_finance();

alter table public.seller_payouts enable row level security;

drop policy if exists "seller_payouts_admin_select" on public.seller_payouts;
create policy "seller_payouts_admin_select"
on public.seller_payouts
for select
to authenticated
using (
  seller_id = auth.uid()
  or public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "seller_payouts_admin_manage" on public.seller_payouts;
create policy "seller_payouts_admin_manage"
on public.seller_payouts
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
