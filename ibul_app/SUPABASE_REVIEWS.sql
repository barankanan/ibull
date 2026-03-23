create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_name text not null default 'Kullanıcı',
  product_name text not null,
  store_name text not null,
  seller_id text,
  product_image_url text,
  product_code text,
  rating numeric(2,1) not null check (rating >= 0 and rating <= 5),
  comment text not null,
  image_urls jsonb not null default '[]'::jsonb,
  likes integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.seller_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_name text not null default 'Kullanıcı',
  store_name text not null,
  seller_id text,
  rating numeric(2,1) not null check (rating >= 0 and rating <= 5),
  comment text not null,
  image_urls jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_product_reviews_product_name
  on public.product_reviews (lower(product_name));
create index if not exists idx_product_reviews_store_name
  on public.product_reviews (lower(store_name));
create index if not exists idx_product_reviews_seller_id
  on public.product_reviews (seller_id);
create index if not exists idx_seller_reviews_store_name
  on public.seller_reviews (lower(store_name));
create index if not exists idx_seller_reviews_seller_id
  on public.seller_reviews (seller_id);

alter table public.product_reviews enable row level security;
alter table public.seller_reviews enable row level security;

drop policy if exists "product_reviews_public_read" on public.product_reviews;
create policy "product_reviews_public_read"
on public.product_reviews
for select
to public
using (true);

drop policy if exists "product_reviews_auth_insert" on public.product_reviews;
create policy "product_reviews_auth_insert"
on public.product_reviews
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "seller_reviews_public_read" on public.seller_reviews;
create policy "seller_reviews_public_read"
on public.seller_reviews
for select
to public
using (true);

drop policy if exists "seller_reviews_auth_insert" on public.seller_reviews;
create policy "seller_reviews_auth_insert"
on public.seller_reviews
for insert
to authenticated
with check (auth.uid() = user_id);
