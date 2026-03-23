alter table if exists public.products
add column if not exists accessories text[] default '{}';

create index if not exists idx_products_accessories
on public.products using gin (accessories);
