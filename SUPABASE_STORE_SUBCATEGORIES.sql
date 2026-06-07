create table if not exists public.store_sub_categories (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores(seller_id) on delete cascade,
  main_category text not null,
  name text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.store_sub_categories enable row level security;

drop policy if exists "Sellers can view their own store sub categories."
on public.store_sub_categories;
create policy "Sellers can view their own store sub categories."
on public.store_sub_categories
for select
using (auth.uid() = seller_id);

drop policy if exists "Sellers can insert their own store sub categories."
on public.store_sub_categories;
create policy "Sellers can insert their own store sub categories."
on public.store_sub_categories
for insert
with check (auth.uid() = seller_id);

drop policy if exists "Sellers can update their own store sub categories."
on public.store_sub_categories;
create policy "Sellers can update their own store sub categories."
on public.store_sub_categories
for update
using (auth.uid() = seller_id);

drop policy if exists "Sellers can delete their own store sub categories."
on public.store_sub_categories;
create policy "Sellers can delete their own store sub categories."
on public.store_sub_categories
for delete
using (auth.uid() = seller_id);

create unique index if not exists store_sub_categories_unique_name_idx
on public.store_sub_categories (
  seller_id,
  main_category,
  lower(btrim(name))
);

create index if not exists store_sub_categories_lookup_idx
on public.store_sub_categories (seller_id, main_category, is_active, sort_order);

alter table public.products
add column if not exists sub_category_id uuid references public.store_sub_categories(id) on delete set null;

create index if not exists products_sub_category_id_idx
on public.products (seller_id, main_category, sub_category_id);

with distinct_product_sub_categories as (
  select
    p.seller_id,
    p.main_category,
    btrim(p.sub_category) as name,
    min(p.created_at) as first_seen_at
  from public.products p
  where coalesce(btrim(p.sub_category), '') <> ''
    and p.seller_id is not null
    and coalesce(btrim(p.main_category), '') <> ''
  group by p.seller_id, p.main_category, btrim(p.sub_category)
),
ranked_product_sub_categories as (
  select
    seller_id,
    main_category,
    name,
    row_number() over (
      partition by seller_id, main_category
      order by first_seen_at nulls last, lower(name)
    ) - 1 as sort_order
  from distinct_product_sub_categories
)
insert into public.store_sub_categories (
  seller_id,
  main_category,
  name,
  sort_order,
  is_active
)
select
  ranked.seller_id,
  ranked.main_category,
  ranked.name,
  ranked.sort_order,
  true
from ranked_product_sub_categories ranked
where not exists (
  select 1
  from public.store_sub_categories existing
  where existing.seller_id = ranked.seller_id
    and existing.main_category = ranked.main_category
    and lower(btrim(existing.name)) = lower(btrim(ranked.name))
);

update public.products p
set sub_category_id = sc.id
from public.store_sub_categories sc
where p.sub_category_id is null
  and p.seller_id = sc.seller_id
  and coalesce(btrim(p.main_category), '') = sc.main_category
  and lower(coalesce(btrim(p.sub_category), '')) = lower(btrim(sc.name));
