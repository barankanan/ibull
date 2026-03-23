-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. USERS Table (Public Profile)
create table public.users (
  id uuid references auth.users not null primary key,
  email text,
  display_name text,
  photo_url text,
  phone text,
  role text default 'user', -- 'user', 'seller', 'admin'
  is_seller_approved boolean default false,
  
  -- User Profile Fields
  weight float,
  height float,
  gender text,
  birth_date text,
  style text,
  address text,
  favorites jsonb default '[]'::jsonb, -- Array of product IDs
  
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Enable Row Level Security (RLS)
alter table public.users enable row level security;

-- Policies for Users
create policy "Public profiles are viewable by everyone." on public.users
  for select using (true);

create policy "Users can insert their own profile." on public.users
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on public.users
  for update using (auth.uid() = id);

-- 2. SELLER APPLICATIONS Table
create table public.seller_applications (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.users(id),
  status text default 'pending', -- 'pending', 'approved', 'rejected'
  
  -- Application Data
  business_name text,
  business_type text,
  tax_number text,
  category text,
  has_physical_store boolean,
  contact_name text,
  user_email text,
  user_name text,
  email text,
  phone text,
  address text,
  city text,
  district text,
  postal_code text,
  bank_name text,
  iban text,
  account_holder text,
  
  created_at timestamp with time zone default timezone('utc'::text, now()),
  approved_at timestamp with time zone
);

alter table public.seller_applications enable row level security;

create policy "Users can view their own applications." on public.seller_applications
  for select using (auth.uid() = user_id);

create policy "Users can insert their own applications." on public.seller_applications
  for insert with check (auth.uid() = user_id);

-- 3. STORES Table
create table public.stores (
  seller_id uuid references public.users(id) primary key,
  
  -- Store Info
  business_name text,
  business_type text,
  tax_number text,
  category text,
  has_physical_store boolean,
  contact_name text,
  email text,
  phone text,
  address text,
  city text,
  district text,
  postal_code text,
  
  -- Financial
  bank_name text,
  iban text,
  account_holder text,
  
  -- Profile & Visuals
  logo_url text,
  cover_url text,
  gallery_images text[] default '{}',
  banners text[] default '{}',
  slogan text,
  description text,
  whatsapp text,
  support_phone text,
  instagram text,
  facebook text,
  twitter text,
  website text,
  
  -- Settings
  working_hours text,
  is_store_open boolean default true,
  accept_new_orders boolean default true,
  allow_messaging boolean default true,
  is_holiday_mode boolean default false,
  
  rating float default 0.0,
  is_verified boolean default false,
  
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.stores enable row level security;

create policy "Stores are viewable by everyone." on public.stores
  for select using (true);

create policy "Sellers can update their own store." on public.stores
  for update using (auth.uid() = seller_id);

create policy "Sellers can insert their own store." on public.stores
  for insert with check (auth.uid() = seller_id);

-- 4. PRODUCTS Table
create table public.products (
  id text primary key, -- Keeping text ID to match app logic (timestamp strings) or change to uuid
  seller_id uuid references public.stores(seller_id),
  
  name text,
  brand text,
  main_category text,
  sub_category text,
  price float,
  discount_price float,
  stock int,
  sku text,
  status text default 'pending_approval', -- 'Aktif', 'Taslak', 'pending_approval', 'rejected'
  
  image_url text,
  image_urls text[] default '{}',
  description text,
  
  -- Variant Data (Simplified JSONB storage)
  variants jsonb default '[]'::jsonb,
  category_attributes jsonb default '{}'::jsonb,
  
  created_at timestamp with time zone default timezone('utc'::text, now()),
  approved_at timestamp with time zone,
  rejected_at timestamp with time zone,
  rejection_reason text
);

alter table public.products enable row level security;

create policy "Active products are viewable by everyone." on public.products
  for select using (status = 'Aktif');

create policy "Sellers can view all their products." on public.products
  for select using (auth.uid() = seller_id);

create policy "Sellers can insert their own products." on public.products
  for insert with check (auth.uid() = seller_id);

create policy "Sellers can update their own products." on public.products
  for update using (auth.uid() = seller_id);

create policy "Sellers can delete their own products." on public.products
  for delete using (auth.uid() = seller_id);

-- 5. STORAGE BUCKETS (Run these in Storage > Buckets section or via API if supported)
-- You need to create these buckets manually in Supabase Dashboard:
-- 'store-images' (public)
-- 'product-images' (public)
-- 'seller-documents' (private)

-- Storage Policies (Example for 'store-images')
-- INSERT: auth.role() = 'authenticated'
-- SELECT: true (Public)
