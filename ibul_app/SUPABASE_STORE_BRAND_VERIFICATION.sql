-- Marka / mağaza doğrulama başvuruları ve onaylanmış mağaza rozeti altyapısı.

alter table public.stores
  add column if not exists is_brand_verified boolean not null default false;

create table if not exists public.store_brand_verification_applications (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  status text not null default 'draft' check (
    status in ('draft', 'submitted', 'needs_info', 'approved', 'rejected')
  ),
  full_name text not null default '',
  brand_name text not null default '',
  company_title text not null default '',
  mersis_no text not null default '',
  tax_no text not null default '',
  company_founded_at date,
  website text,
  email text not null default '',
  phone text not null default '',
  trade_registry_no text,
  store_note text,
  tax_plate_path text,
  trade_registry_path text,
  brand_registration_path text,
  identity_document_path text,
  accepted_accuracy boolean not null default false,
  accepted_review boolean not null default false,
  admin_note text,
  rejection_reason text,
  store_name text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_store_brand_verification_seller_id
  on public.store_brand_verification_applications (seller_id);

create index if not exists idx_store_brand_verification_status
  on public.store_brand_verification_applications (status);

create unique index if not exists idx_store_brand_verification_active_per_seller
  on public.store_brand_verification_applications (seller_id)
  where status in ('draft', 'submitted', 'needs_info');

create or replace function public.set_store_brand_verification_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_store_brand_verification_updated_at
  on public.store_brand_verification_applications;
create trigger trg_store_brand_verification_updated_at
before update on public.store_brand_verification_applications
for each row execute function public.set_store_brand_verification_updated_at();

alter table public.store_brand_verification_applications enable row level security;

drop policy if exists "brand_verification_select_own"
  on public.store_brand_verification_applications;
create policy "brand_verification_select_own"
on public.store_brand_verification_applications
for select
to authenticated
using (auth.uid() = seller_id);

drop policy if exists "brand_verification_insert_own"
  on public.store_brand_verification_applications;
create policy "brand_verification_insert_own"
on public.store_brand_verification_applications
for insert
to authenticated
with check (auth.uid() = seller_id);

drop policy if exists "brand_verification_update_own"
  on public.store_brand_verification_applications;
create policy "brand_verification_update_own"
on public.store_brand_verification_applications
for update
to authenticated
using (
  auth.uid() = seller_id
  and status in ('draft', 'needs_info', 'rejected')
)
with check (auth.uid() = seller_id);

drop policy if exists "brand_verification_admin_select_all"
  on public.store_brand_verification_applications;
create policy "brand_verification_admin_select_all"
on public.store_brand_verification_applications
for select
to authenticated
using (true);

drop policy if exists "brand_verification_admin_update_all"
  on public.store_brand_verification_applications;
create policy "brand_verification_admin_update_all"
on public.store_brand_verification_applications
for update
to authenticated
using (true)
with check (true);
