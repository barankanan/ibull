-- Vehicle rental operations: approval, cancel/refund, overlap, private docs.
-- Extends existing vehicle_reservations / vehicle_rental_settings. No parallel booking table.

alter table public.vehicle_rental_settings
  add column if not exists requires_approval boolean not null default true,
  add column if not exists instant_booking boolean not null default false,
  add column if not exists min_driver_age integer,
  add column if not exists min_license_years integer,
  add column if not exists cancellation_policy jsonb not null default jsonb_build_object(
    'full_refund_hours', 24,
    'half_refund_hours', 12,
    'full_percent', 100,
    'half_percent', 50,
    'late_percent', 0
  );

alter table public.vehicle_reservations
  add column if not exists dropoff_mode text,
  add column if not exists dropoff_address text,
  add column if not exists dropoff_lat double precision,
  add column if not exists dropoff_lng double precision,
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists customer_birth_date date,
  add column if not exists customer_email text,
  add column if not exists customer_note text,
  add column if not exists seller_note text,
  add column if not exists reject_reason text,
  add column if not exists cancel_reason text,
  add column if not exists cancel_actor text,
  add column if not exists rental_code text,
  add column if not exists cancellation_policy jsonb,
  add column if not exists refund_amount numeric(12,2),
  add column if not exists refund_reason text,
  add column if not exists refunded_at timestamptz,
  add column if not exists confirmed_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists documents_retention_until timestamptz;

do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.vehicle_reservations'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%pending_docs%'
  loop
    execute 'alter table public.vehicle_reservations drop constraint ' || quote_ident(r.conname);
  end loop;
  for r in
    select conname from pg_constraint
    where conrelid = 'public.vehicle_reservations'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%unpaid%'
      and pg_get_constraintdef(oid) ilike '%payment_status%'
  loop
    execute 'alter table public.vehicle_reservations drop constraint ' || quote_ident(r.conname);
  end loop;
  for r in
    select conname from pg_constraint
    where conrelid = 'public.vehicle_kyc_documents'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%driver_license%'
  loop
    execute 'alter table public.vehicle_kyc_documents drop constraint ' || quote_ident(r.conname);
  end loop;
end $$;

alter table public.vehicle_reservations
  add constraint vehicle_reservations_status_chk check (status in (
    'pending_payment', 'pending_docs', 'pending_seller_review', 'confirmed',
    'reserved', 'active_rental', 'return_pending', 'completed', 'cancelled',
    'rejected', 'refund_pending', 'seller_cancelled'
  ));

alter table public.vehicle_reservations
  add constraint vehicle_reservations_payment_chk check (payment_status in (
    'unpaid', 'pending', 'authorized', 'paid', 'failed',
    'refunded', 'partially_refunded', 'refund_pending'
  ));

alter table public.vehicle_kyc_documents
  add constraint vehicle_kyc_doc_type_chk check (doc_type in (
    'identity', 'driver_license', 'other',
    'identity_front', 'identity_back',
    'driver_license_front', 'driver_license_back'
  ));

alter table public.vehicle_kyc_documents
  add column if not exists rejection_reason text,
  add column if not exists retention_until timestamptz;

create unique index if not exists vehicle_reservations_rental_code_uidx
  on public.vehicle_reservations (rental_code)
  where rental_code is not null;

create table if not exists public.vehicle_rental_blocks (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  kind text not null check (kind in ('maintenance', 'blocked', 'manual_reservation')),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint vehicle_rental_block_window_chk check (end_at > start_at)
);

create index if not exists vehicle_rental_blocks_listing_idx
  on public.vehicle_rental_blocks (listing_id, start_at, end_at);

create table if not exists public.vehicle_rental_refunds (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.vehicle_reservations (id) on delete cascade,
  payment_id text,
  amount numeric(12,2) not null check (amount >= 0),
  reason text,
  status text not null default 'refund_pending' check (status in (
    'refund_pending', 'refunded', 'failed'
  )),
  provider_refund_id text,
  created_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz
);

create table if not exists public.vehicle_rental_handover (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.vehicle_reservations (id) on delete cascade,
  stage text not null check (stage in ('pickup', 'return')),
  front_url text,
  rear_url text,
  right_url text,
  left_url text,
  interior_url text,
  odometer_km integer,
  fuel_level text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (reservation_id, stage)
);

create table if not exists public.vehicle_rental_booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.vehicle_reservations (id) on delete cascade,
  actor_id uuid,
  action text not null,
  from_status text,
  to_status text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.vehicle_rental_blocks enable row level security;
alter table public.vehicle_rental_refunds enable row level security;
alter table public.vehicle_rental_handover enable row level security;
alter table public.vehicle_rental_booking_events enable row level security;

drop policy if exists vehicle_rental_blocks_select on public.vehicle_rental_blocks;
create policy vehicle_rental_blocks_select on public.vehicle_rental_blocks
for select using (
  auth.uid() = seller_id
  or public.vehicle_is_admin()
  or exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id and l.status in ('active', 'reserved', 'rented')
  )
);

drop policy if exists vehicle_rental_blocks_seller_write on public.vehicle_rental_blocks;
create policy vehicle_rental_blocks_seller_write on public.vehicle_rental_blocks
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_rental_refunds_party on public.vehicle_rental_refunds;
create policy vehicle_rental_refunds_party on public.vehicle_rental_refunds
for select using (
  public.vehicle_is_admin()
  or exists (
    select 1 from public.vehicle_reservations r
    where r.id = booking_id
      and (r.customer_id = auth.uid() or r.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_rental_handover_party on public.vehicle_rental_handover;
create policy vehicle_rental_handover_party on public.vehicle_rental_handover
for select using (
  public.vehicle_is_admin()
  or exists (
    select 1 from public.vehicle_reservations r
    where r.id = reservation_id
      and (r.customer_id = auth.uid() or r.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_rental_events_party on public.vehicle_rental_booking_events;
create policy vehicle_rental_events_party on public.vehicle_rental_booking_events
for select using (
  public.vehicle_is_admin()
  or exists (
    select 1 from public.vehicle_reservations r
    where r.id = booking_id
      and (r.customer_id = auth.uid() or r.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_kyc_seller_select on public.vehicle_kyc_documents;
create policy vehicle_kyc_seller_select on public.vehicle_kyc_documents
for select using (
  exists (
    select 1 from public.vehicle_reservations r
    where r.id = reservation_id and r.seller_id = auth.uid()
  )
);

drop policy if exists vehicle_docs_seller_read on storage.objects;
create policy vehicle_docs_seller_read on storage.objects
for select using (
  bucket_id = 'vehicle-documents'
  and exists (
    select 1
    from public.vehicle_kyc_documents d
    join public.vehicle_reservations r on r.id = d.reservation_id
    where d.object_path = name
      and r.seller_id = auth.uid()
  )
);

grant select on public.vehicle_rental_blocks to anon, authenticated;
grant select, insert, update, delete on public.vehicle_rental_blocks to authenticated;
grant select on public.vehicle_rental_refunds to authenticated;
grant select on public.vehicle_rental_handover to authenticated;
grant select on public.vehicle_rental_booking_events to authenticated;
grant select, insert on public.vehicle_rental_handover to authenticated;
