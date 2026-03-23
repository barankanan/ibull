-- Urun sorgulari ve arama ekranlari icin performans indeksleri
-- Supabase SQL Editor uzerinden bir kez calistirilmasi yeterli.

create index if not exists idx_products_status_created_at
on public.products (status, created_at desc);

create index if not exists idx_products_status_main_category_created_at
on public.products (status, main_category, created_at desc);

create index if not exists idx_products_status_brand_created_at
on public.products (status, brand, created_at desc);

create index if not exists idx_products_stock
on public.products (stock);

create extension if not exists pg_trgm;

create index if not exists idx_products_name_trgm
on public.products using gin (name gin_trgm_ops);

create index if not exists idx_products_keywords_trgm
on public.products using gin (keywords gin_trgm_ops);
