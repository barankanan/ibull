-- products.product_type: required by Flutter product create/publish payloads (PGRST204 when missing).
-- Complements specifications._ibul_product_type for template rows (no duplicate semantics:
-- column is canonical for writes; specs key remains for mixed-service metadata resolution).

begin;

alter table public.products
  add column if not exists product_type text not null default 'product';

comment on column public.products.product_type is
  'Product kind: product (default), service_template, menu_template, or legacy mixed_service_template.';

-- Existing rows (add column applies default; normalize any stray nulls).
update public.products
set product_type = 'product'
where product_type is null;

-- Backfill template kinds already stored in specifications JSON (do not overwrite explicit column values).
update public.products p
set product_type = v.raw_type
from (
  select
    id,
    lower(trim(specifications->>'_ibul_product_type')) as raw_type
  from public.products
  where specifications is not null
    and specifications ? '_ibul_product_type'
    and nullif(trim(specifications->>'_ibul_product_type'), '') is not null
) as v
where p.id = v.id
  and v.raw_type in (
    'product',
    'service_template',
    'menu_template',
    'mixed_service_template'
  )
  and (
    p.product_type is null
    or p.product_type = 'product'
  );

create index if not exists idx_products_product_type
  on public.products (product_type);

-- PostgREST schema cache (Supabase): reload after DDL.
notify pgrst, 'reload schema';

commit;
