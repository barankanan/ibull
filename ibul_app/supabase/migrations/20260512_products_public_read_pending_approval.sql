-- Allow anonymous shoppers to read listings that are live or awaiting moderation.
-- App lists both in SupabaseService.publicCatalogProductStatuses.

drop policy if exists "Public can view active products" on public.products;
drop policy if exists "Active products are viewable by everyone." on public.products;

create policy "Public can view active products"
on public.products
for select
using (status in ('Aktif', 'pending_approval'));

-- Store preview RPC used the old single-status filter.
create or replace function public.get_store_preview_products(
  p_seller_ids text[] default '{}',
  p_per_store_limit integer default 5
)
returns table(
  id text,
  seller_id text,
  name text,
  brand text,
  image_url text,
  image_urls text[],
  price numeric,
  discount_price numeric,
  description text,
  status text,
  created_at timestamptz,
  stores jsonb
)
language sql
stable
as $$
  with ranked_products as (
    select
      p.id::text as id,
      p.seller_id::text as seller_id,
      p.name,
      p.brand,
      p.image_url,
      p.image_urls::text[] as image_urls,
      p.price,
      p.discount_price,
      p.description,
      p.status,
      p.created_at,
      jsonb_build_object('business_name', s.business_name) as stores,
      row_number() over (
        partition by p.seller_id
        order by p.created_at desc
      ) as row_num
    from public.products p
    left join public.stores s on s.seller_id = p.seller_id
    where p.status in ('Aktif', 'pending_approval')
      -- seller_id uuid, RPC param text[] → metin üzerinden eşleştir
      and p.seller_id::text = any(coalesce(p_seller_ids, '{}'))
  )
  select
    id,
    seller_id,
    name,
    brand,
    image_url,
    image_urls,
    price,
    discount_price,
    description,
    status,
    created_at,
    stores
  from ranked_products
  where row_num <= greatest(1, least(coalesce(p_per_store_limit, 5), 20))
  order by seller_id, created_at desc;
$$;
