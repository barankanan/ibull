-- Store Campaigns / Coupons table
-- Satıcı panelinden oluşturulan kampanyalar; satıcı profilinde mağaza kuponları olarak gösterilir.
create table if not exists public.store_campaigns (
  id uuid default uuid_generate_v4() primary key,
  seller_id uuid references auth.users(id) on delete cascade not null,
  
  -- Tip: yuzde_indirim, sabit_tutar, al_get, ikinci_urun, ucretsiz_kargo, kupon
  type text not null,
  name text not null,
  description text,
  
  -- Kupon kodu (kupon tipi için zorunlu)
  coupon_code text,
  auto_generate_code boolean default false,
  single_use boolean default false,
  
  -- İndirim
  discount_type text not null, -- 'percent' | 'fixed'
  discount_value double precision not null,
  min_cart_amount double precision default 0,
  max_discount double precision,
  free_shipping boolean default false,
  
  -- Tarih
  start_date timestamp with time zone not null,
  end_date timestamp with time zone not null,
  
  -- Limit
  usage_limit int,
  per_user_limit int,
  usage_count int default 0,
  
  -- Ürün kapsamı: null veya [] = tüm ürünler; dolu = sadece bu product_id'ler
  product_ids jsonb default '[]'::jsonb,
  scope text default 'all', -- 'all' | 'categories' | 'products' | 'brands'
  
  status text default 'active', -- 'active' | 'inactive' | 'expired'
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.store_campaigns enable row level security;

create policy "Anyone can view active store campaigns"
  on public.store_campaigns for select
  using (status = 'active' and end_date > now());

create policy "Sellers can manage their own campaigns"
  on public.store_campaigns for all
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

create index if not exists idx_store_campaigns_seller on public.store_campaigns(seller_id);
create index if not exists idx_store_campaigns_status on public.store_campaigns(status);
create index if not exists idx_store_campaigns_dates on public.store_campaigns(start_date, end_date);
