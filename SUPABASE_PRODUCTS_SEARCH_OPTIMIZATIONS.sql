begin;

create extension if not exists pg_trgm;

create or replace function public.normalize_tr_text(input text)
returns text
language sql
immutable
as $$
  select trim(
    regexp_replace(
      lower(
        translate(
          coalesce(input, ''),
          'ÇĞİIÖŞÜçğıiöşü',
          'cgiiosucgiiosu'
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  );
$$;

alter table public.products
  add column if not exists name_norm text,
  add column if not exists brand_norm text,
  add column if not exists store_name_norm text,
  add column if not exists search_text_norm text;

update public.products
set
  name_norm = public.normalize_tr_text(name),
  brand_norm = public.normalize_tr_text(brand),
  store_name_norm = public.normalize_tr_text(store),
  search_text_norm = public.normalize_tr_text(
    concat_ws(' ', name, brand, store, category, sub_category)
  )
where
  name_norm is distinct from public.normalize_tr_text(name)
  or brand_norm is distinct from public.normalize_tr_text(brand)
  or store_name_norm is distinct from public.normalize_tr_text(store)
  or search_text_norm is distinct from public.normalize_tr_text(
    concat_ws(' ', name, brand, store, category, sub_category)
  );

create or replace function public.set_products_search_norm_fields()
returns trigger
language plpgsql
as $$
begin
  new.name_norm := public.normalize_tr_text(new.name);
  new.brand_norm := public.normalize_tr_text(new.brand);
  new.store_name_norm := public.normalize_tr_text(new.store);
  new.search_text_norm := public.normalize_tr_text(
    concat_ws(' ', new.name, new.brand, new.store, new.category, new.sub_category)
  );
  return new;
end;
$$;

drop trigger if exists trg_products_search_norm_fields on public.products;
create trigger trg_products_search_norm_fields
before insert or update of name, brand, store, category, sub_category
on public.products
for each row
execute function public.set_products_search_norm_fields();

create index if not exists idx_products_seller_created_id
  on public.products (seller_id, created_at desc, id desc);

create index if not exists idx_products_store_name_norm
  on public.products (store_name_norm);

create index if not exists idx_products_search_text_trgm
  on public.products
  using gin (search_text_norm gin_trgm_ops);

create index if not exists idx_product_questions_seller_created
  on public.product_questions (seller_id, created_at desc);

create index if not exists idx_product_questions_store_created
  on public.product_questions (store_name, created_at desc);

create index if not exists idx_product_questions_unanswered
  on public.product_questions (created_at desc)
  where answer is null or btrim(answer) = '';

create index if not exists idx_product_reviews_seller_created
  on public.product_reviews (seller_id, created_at desc);

create index if not exists idx_product_reviews_store_created
  on public.product_reviews (store_name, created_at desc);

create index if not exists idx_seller_reviews_seller_created
  on public.seller_reviews (seller_id, created_at desc);

create index if not exists idx_seller_reviews_store_created
  on public.seller_reviews (store_name, created_at desc);

commit;
