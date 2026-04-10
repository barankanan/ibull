alter table if exists public.products
  add column if not exists specifications jsonb;
