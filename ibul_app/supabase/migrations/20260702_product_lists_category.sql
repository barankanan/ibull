-- product_lists.category / sub_category — Flutter ProductList sync payload uyumu.
-- Supabase Dashboard'da çalıştırdıktan sonra gerekirse:
--   NOTIFY pgrst, 'reload schema';
-- veya Project Settings → API → Reload schema cache.

alter table public.product_lists
  add column if not exists category text,
  add column if not exists sub_category text;

comment on column public.product_lists.category is
  'Liste ana kategorisi (sponsorlu liste / filtre için).';
comment on column public.product_lists.sub_category is
  'Liste alt kategorisi.';

create index if not exists idx_product_lists_category_visibility
  on public.product_lists(category, visibility, updated_at desc);
