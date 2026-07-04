-- Public vitrin görünürlüğü: status + approval birlikte zorunlu.
-- Idempotent — güvenle birden fazla kez çalıştırılabilir.
--
-- Kural:
--   status in ('Aktif', 'active')
--   AND (
--     approval_status in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
--     OR admin_approval_status in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
--   )
-- Null/boş approval alanları public DEĞİLDİR.
--
-- Geriye uyum backfill (manuel, inceleme sonrası):
--   update public.products
--   set approval_status = 'approved'
--   where lower(btrim(coalesce(status, ''))) in ('aktif', 'active')
--     and approval_status is null
--     and admin_approval_status is null;

-- ---------------------------------------------------------------------------
-- Approval kolonları (yoksa ekle)
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists approval_status text;

alter table public.products
  add column if not exists admin_approval_status text;

-- ---------------------------------------------------------------------------
-- Paylaşılan vitrin görünürlük fonksiyonu (RLS + RPC)
-- ---------------------------------------------------------------------------
create or replace function public.is_public_catalog_product(
  p_status text,
  p_approval_status text default null,
  p_admin_approval_status text default null
)
returns boolean
language sql
stable
as $$
  select
    lower(btrim(coalesce(p_status, ''))) in ('aktif', 'active')
    and (
      lower(btrim(coalesce(p_approval_status, ''))) in (
        'approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı'
      )
      or lower(btrim(coalesce(p_admin_approval_status, ''))) in (
        'approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı'
      )
    );
$$;

comment on function public.is_public_catalog_product(text, text, text) is
  'Customer storefront visibility: active status AND explicit approval required.';

-- ---------------------------------------------------------------------------
-- Public SELECT policy — yalnızca onaylı aktif ürünler
-- Seller kendi tüm ürünlerini ayrı policy ile görmeye devam eder.
-- ---------------------------------------------------------------------------
drop policy if exists "Public can view active products" on public.products;
drop policy if exists "Active products are viewable by everyone." on public.products;
drop policy if exists "Active products are viewable by everyone" on public.products;

create policy "Public can view active products"
on public.products
for select
using (
  public.is_public_catalog_product(
    status,
    approval_status,
    admin_approval_status
  )
);

-- ---------------------------------------------------------------------------
-- Mağaza önizleme RPC — aynı vitrin kuralı
-- ---------------------------------------------------------------------------
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
    where public.is_public_catalog_product(
      p.status,
      p.approval_status,
      p.admin_approval_status
    )
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

-- Vitrin sorguları için bileşik indeks (kolonlar mevcutsa)
create index if not exists idx_products_public_catalog_visibility
on public.products (status, approval_status, admin_approval_status, created_at desc);
