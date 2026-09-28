-- iBUL Araç / Galerici dikeyi — şema
-- Mevcut products/orders/stores tablolarını çoğaltmaz.
-- Galeri mağazası = public.stores (category = 'Galerici').

create extension if not exists pgcrypto;

create or replace function public.vehicle_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.vehicle_galleries (
  seller_id uuid primary key references public.stores (seller_id) on delete cascade,
  about text,
  verified_gallery boolean not null default false,
  appointment_enabled boolean not null default true,
  rental_enabled boolean not null default true,
  sale_enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  listing_type text not null check (listing_type in ('sale', 'rental', 'both')),
  status text not null default 'draft' check (status in (
    'draft', 'pending_review', 'active', 'reserved', 'sold', 'rented',
    'return_pending', 'maintenance', 'inactive'
  )),
  sale_price numeric(12,2),
  negotiable boolean not null default true,
  financing boolean not null default false,
  trade_in boolean not null default false,
  home_delivery_sale boolean not null default false,
  description text,
  city text,
  district text,
  cover_url text,
  search_text text not null default '',
  view_count integer not null default 0,
  favorite_count integer not null default 0,
  ai_payload jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vehicle_listings_sale_price_chk check (
    listing_type = 'rental' or sale_price is null or sale_price >= 0
  )
);

create table if not exists public.vehicle_specs (
  listing_id uuid primary key references public.vehicle_listings (id) on delete cascade,
  brand text not null,
  model text not null,
  version text,
  year integer not null check (year between 1950 and 2100),
  body_type text,
  fuel text,
  transmission text,
  engine_cc integer,
  power_hp integer,
  drive text,
  doors integer,
  seats integer,
  color text,
  mileage_km integer check (mileage_km is null or mileage_km >= 0),
  mileage_verified boolean not null default false,
  has_damage boolean not null default false,
  tramer_amount numeric(12,2),
  replaced_parts text,
  painted_parts text,
  heavy_damage boolean not null default false,
  has_expertise boolean not null default false,
  service_history text,
  warranty text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  slot text not null default 'other',
  bucket text not null default 'vehicle-media',
  object_path text not null,
  url text not null,
  sort_order integer not null default 0,
  is_cover boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_damage_records (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  part_name text not null,
  severity text,
  note text,
  photo_url text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_maintenance_records (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  kind text not null check (kind in (
    'service', 'maintenance', 'inspection', 'insurance', 'tire', 'expertise', 'km'
  )),
  title text not null,
  notes text,
  occurred_on date,
  odometer_km integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_rental_settings (
  listing_id uuid primary key references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  daily_price numeric(12,2) not null check (daily_price >= 0),
  weekly_price numeric(12,2),
  monthly_price numeric(12,2),
  deposit numeric(12,2) not null default 0 check (deposit >= 0),
  min_days integer not null default 1 check (min_days >= 1),
  max_days integer not null default 30 check (max_days >= 1),
  km_limit_per_day integer,
  extra_km_price numeric(12,2),
  gallery_pickup boolean not null default true,
  map_point_delivery boolean not null default false,
  home_delivery boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vehicle_rental_days_chk check (max_days >= min_days)
);

create table if not exists public.vehicle_delivery_zones (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  label text not null,
  min_km numeric(8,2) not null default 0,
  max_km numeric(8,2) not null,
  fee numeric(12,2) not null check (fee >= 0),
  is_airport boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vehicle_delivery_zone_km_chk check (max_km >= min_km)
);

create table if not exists public.vehicle_delivery_points (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  label text not null,
  address text,
  lat double precision not null,
  lng double precision not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_reservations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete restrict,
  seller_id uuid not null references public.stores (seller_id) on delete restrict,
  customer_id uuid not null references public.users (id) on delete restrict,
  status text not null default 'pending_docs' check (status in (
    'pending_payment', 'pending_docs', 'confirmed', 'reserved',
    'active_rental', 'return_pending', 'completed', 'cancelled'
  )),
  pickup_at timestamptz not null,
  return_at timestamptz not null,
  delivery_mode text not null check (delivery_mode in (
    'gallery_pickup', 'map_point', 'home_delivery'
  )),
  delivery_address text,
  delivery_lat double precision,
  delivery_lng double precision,
  rental_days integer not null,
  rental_subtotal numeric(12,2) not null,
  delivery_fee numeric(12,2) not null default 0,
  deposit numeric(12,2) not null default 0,
  total numeric(12,2) not null,
  payment_status text not null default 'unpaid' check (payment_status in (
    'unpaid', 'authorized', 'paid', 'refunded', 'failed'
  )),
  order_id text,
  handover_code_hash text,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vehicle_reservation_window_chk check (return_at > pickup_at)
);

create table if not exists public.vehicle_kyc_documents (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.vehicle_reservations (id) on delete cascade,
  customer_id uuid not null references public.users (id) on delete cascade,
  doc_type text not null check (doc_type in ('identity', 'driver_license', 'other')),
  status text not null default 'submitted' check (status in ('submitted', 'verified', 'rejected')),
  bucket text not null default 'vehicle-documents',
  object_path text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_returns (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.vehicle_reservations (id) on delete cascade,
  listing_id uuid not null references public.vehicle_listings (id) on delete restrict,
  seller_id uuid not null,
  customer_id uuid not null,
  returned_at timestamptz not null default timezone('utc', now()),
  odometer_km integer,
  fuel_level text,
  damage_note text,
  photo_urls text[] not null default '{}',
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_quotes (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  customer_id uuid not null references public.users (id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending' check (status in (
    'pending', 'accepted', 'rejected', 'countered'
  )),
  counter_amount numeric(12,2),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_quote_events (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.vehicle_quotes (id) on delete cascade,
  actor_id uuid not null,
  action text not null,
  amount numeric(12,2),
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_appointments (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  customer_id uuid not null references public.users (id) on delete cascade,
  kind text not null check (kind in ('gallery', 'customer_location', 'meeting_point')),
  status text not null default 'pending' check (status in (
    'pending', 'confirmed', 'rejected', 'completed', 'cancelled'
  )),
  scheduled_at timestamptz not null,
  address text,
  lat double precision,
  lng double precision,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  customer_id uuid not null references public.users (id) on delete cascade,
  last_message text,
  last_message_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (listing_id, customer_id)
);

create table if not exists public.vehicle_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.vehicle_conversations (id) on delete cascade,
  sender_id uuid not null,
  body text,
  media_url text,
  action_type text,
  action_payload jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_favorites (
  user_id uuid not null references public.users (id) on delete cascade,
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, listing_id)
);

create table if not exists public.vehicle_analytics_events (
  id bigint generated by default as identity primary key,
  listing_id uuid not null references public.vehicle_listings (id) on delete cascade,
  seller_id uuid not null,
  event_type text not null check (event_type in (
    'view', 'favorite', 'chat', 'phone', 'quote', 'appointment', 'sale', 'rental'
  )),
  actor_id uuid,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_vehicle_listings_seller on public.vehicle_listings (seller_id, status);
create index if not exists idx_vehicle_listings_public on public.vehicle_listings (status, listing_type, created_at desc);
create index if not exists idx_vehicle_listings_city on public.vehicle_listings (city, district) where status = 'active';
create index if not exists idx_vehicle_listings_search on public.vehicle_listings (search_text);
create index if not exists idx_vehicle_specs_brand_model on public.vehicle_specs (brand, model, year);
create index if not exists idx_vehicle_specs_filters on public.vehicle_specs (fuel, transmission, body_type, color);
create index if not exists idx_vehicle_media_listing on public.vehicle_media (listing_id, sort_order);
create index if not exists idx_vehicle_reservations_listing_window
  on public.vehicle_reservations (listing_id, pickup_at, return_at);
create index if not exists idx_vehicle_reservations_customer on public.vehicle_reservations (customer_id, created_at desc);
create index if not exists idx_vehicle_reservations_seller on public.vehicle_reservations (seller_id, status);
create index if not exists idx_vehicle_quotes_listing on public.vehicle_quotes (listing_id, status);
create index if not exists idx_vehicle_appointments_seller on public.vehicle_appointments (seller_id, scheduled_at);
create index if not exists idx_vehicle_conversations_seller on public.vehicle_conversations (seller_id, last_message_at desc);
create index if not exists idx_vehicle_analytics_listing on public.vehicle_analytics_events (listing_id, event_type, created_at desc);

drop trigger if exists vehicle_galleries_set_updated_at on public.vehicle_galleries;
create trigger vehicle_galleries_set_updated_at
before update on public.vehicle_galleries
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_listings_set_updated_at on public.vehicle_listings;
create trigger vehicle_listings_set_updated_at
before update on public.vehicle_listings
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_specs_set_updated_at on public.vehicle_specs;
create trigger vehicle_specs_set_updated_at
before update on public.vehicle_specs
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_rental_settings_set_updated_at on public.vehicle_rental_settings;
create trigger vehicle_rental_settings_set_updated_at
before update on public.vehicle_rental_settings
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_reservations_set_updated_at on public.vehicle_reservations;
create trigger vehicle_reservations_set_updated_at
before update on public.vehicle_reservations
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_quotes_set_updated_at on public.vehicle_quotes;
create trigger vehicle_quotes_set_updated_at
before update on public.vehicle_quotes
for each row execute function public.vehicle_set_updated_at();

drop trigger if exists vehicle_appointments_set_updated_at on public.vehicle_appointments;
create trigger vehicle_appointments_set_updated_at
before update on public.vehicle_appointments
for each row execute function public.vehicle_set_updated_at();

create or replace function public.vehicle_refresh_search_text()
returns trigger
language plpgsql
as $$
declare
  v_spec public.vehicle_specs%rowtype;
begin
  select * into v_spec from public.vehicle_specs where listing_id = new.id;
  new.search_text := lower(trim(concat_ws(
    ' ',
    coalesce(v_spec.brand, ''),
    coalesce(v_spec.model, ''),
    coalesce(v_spec.version, ''),
    coalesce(v_spec.year::text, ''),
    coalesce(v_spec.fuel, ''),
    coalesce(v_spec.transmission, ''),
    coalesce(v_spec.body_type, ''),
    coalesce(v_spec.color, ''),
    coalesce(new.city, ''),
    coalesce(new.district, '')
  )));
  return new;
end;
$$;

drop trigger if exists vehicle_listings_search_text on public.vehicle_listings;
create trigger vehicle_listings_search_text
before insert or update of city, district, listing_type, status
on public.vehicle_listings
for each row execute function public.vehicle_refresh_search_text();

create or replace function public.vehicle_refresh_search_text_from_specs()
returns trigger
language plpgsql
as $$
begin
  update public.vehicle_listings
  set search_text = lower(trim(concat_ws(
    ' ',
    coalesce(new.brand, ''),
    coalesce(new.model, ''),
    coalesce(new.version, ''),
    coalesce(new.year::text, ''),
    coalesce(new.fuel, ''),
    coalesce(new.transmission, ''),
    coalesce(new.body_type, ''),
    coalesce(new.color, ''),
    coalesce(l.city, ''),
    coalesce(l.district, '')
  )))
  from public.vehicle_listings l
  where l.id = new.listing_id
    and public.vehicle_listings.id = new.listing_id;
  return new;
end;
$$;

drop trigger if exists vehicle_specs_search_text on public.vehicle_specs;
create trigger vehicle_specs_search_text
after insert or update on public.vehicle_specs
for each row execute function public.vehicle_refresh_search_text_from_specs();
