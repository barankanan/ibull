-- IHIZ Kurye kayit + basvuru + admin onay akisi
-- Bu script'i Supabase SQL Editor'da calistirin.

create extension if not exists "uuid-ossp";

alter table public.users
  add column if not exists is_ihiz_approved boolean default false;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'ihiz-courier-documents',
  'ihiz-courier-documents',
  true,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.ihiz_courier_applications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  full_name text not null,
  phone text not null,
  tc_number text not null,
  birth_date text,
  license_type text,
  motor_type text,
  criminal_record text,
  company_type text,
  tax_number text,
  city text,
  district text,
  availability text,
  email text not null,
  note text,
  push_notifications_enabled boolean default true,
  sound_alerts_enabled boolean default true,
  night_mode_enabled boolean default false,
  face_id_enabled boolean default true,
  payment_account_holder text,
  payment_iban text,
  payment_bank_name text,
  driver_license_front_file_name text,
  driver_license_front_file_size bigint default 0,
  driver_license_front_url text,
  driver_license_back_file_name text,
  driver_license_back_file_size bigint default 0,
  driver_license_back_url text,
  vehicle_registration_file_name text,
  vehicle_registration_file_size bigint default 0,
  vehicle_registration_url text,
  rejection_reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now()),
  approved_at timestamp with time zone,
  constraint ihiz_courier_applications_status_check
    check (status in ('pending', 'approved', 'rejected'))
);

alter table public.ihiz_courier_applications
  add column if not exists driver_license_front_url text;

alter table public.ihiz_courier_applications
  add column if not exists driver_license_back_url text;

alter table public.ihiz_courier_applications
  add column if not exists vehicle_registration_url text;

alter table public.ihiz_courier_applications
  add column if not exists payment_account_holder text;

alter table public.ihiz_courier_applications
  add column if not exists payment_iban text;

alter table public.ihiz_courier_applications
  add column if not exists payment_bank_name text;

alter table public.ihiz_courier_applications
  add column if not exists push_notifications_enabled boolean default true;

alter table public.ihiz_courier_applications
  add column if not exists sound_alerts_enabled boolean default true;

alter table public.ihiz_courier_applications
  add column if not exists night_mode_enabled boolean default false;

alter table public.ihiz_courier_applications
  add column if not exists face_id_enabled boolean default true;

create unique index if not exists ihiz_courier_applications_user_id_uq
  on public.ihiz_courier_applications(user_id);

create index if not exists ihiz_courier_applications_status_idx
  on public.ihiz_courier_applications(status);

create index if not exists ihiz_courier_applications_created_at_idx
  on public.ihiz_courier_applications(created_at desc);

alter table public.ihiz_courier_applications enable row level security;

drop policy if exists "IHIZ users can read own applications" on public.ihiz_courier_applications;
create policy "IHIZ users can read own applications"
  on public.ihiz_courier_applications
  for select
  using (auth.uid() = user_id);

drop policy if exists "IHIZ users can insert own applications" on public.ihiz_courier_applications;
create policy "IHIZ users can insert own applications"
  on public.ihiz_courier_applications
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "IHIZ users can update own applications" on public.ihiz_courier_applications;
create policy "IHIZ users can update own applications"
  on public.ihiz_courier_applications
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "IHIZ admins can manage applications" on public.ihiz_courier_applications;
create policy "IHIZ admins can manage applications"
  on public.ihiz_courier_applications
  for all
  using (
    exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and (
          users.role in ('admin', 'super_admin')
          or users.role like 'admin_%'
        )
    )
  )
  with check (
    exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and (
          users.role in ('admin', 'super_admin')
          or users.role like 'admin_%'
        )
    )
  );

drop policy if exists "IHIZ courier docs read public" on storage.objects;
create policy "IHIZ courier docs read public"
  on storage.objects
  for select
  using (bucket_id = 'ihiz-courier-documents');

drop policy if exists "IHIZ courier docs upload own folder" on storage.objects;
create policy "IHIZ courier docs upload own folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'ihiz-courier-documents'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "IHIZ courier docs update own folder" on storage.objects;
create policy "IHIZ courier docs update own folder"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'ihiz-courier-documents'
    and split_part(name, '/', 1) = auth.uid()::text
  )
  with check (
    bucket_id = 'ihiz-courier-documents'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "IHIZ courier docs delete own folder" on storage.objects;
create policy "IHIZ courier docs delete own folder"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'ihiz-courier-documents'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- Destek Merkezi (kurye -> admin Destek & Sikayet)
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

alter table public.support_tickets enable row level security;

drop policy if exists "IHIZ support tickets select own or admin" on public.support_tickets;
create policy "IHIZ support tickets select own or admin"
  on public.support_tickets
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and (
          users.role in ('admin', 'super_admin')
          or users.role like 'admin_%'
        )
    )
  );

drop policy if exists "IHIZ support tickets insert own" on public.support_tickets;
create policy "IHIZ support tickets insert own"
  on public.support_tickets
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "IHIZ support tickets update admin" on public.support_tickets;
create policy "IHIZ support tickets update admin"
  on public.support_tickets
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and (
          users.role in ('admin', 'super_admin')
          or users.role like 'admin_%'
        )
    )
  )
  with check (
    exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and (
          users.role in ('admin', 'super_admin')
          or users.role like 'admin_%'
        )
    )
  );
