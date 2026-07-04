-- Ad-linked home_feature products bypass public RLS approval gate.
-- Seller-selected SKUs on approved campaigns may display with relaxed approval.
-- Idempotent — safe to re-run.
--
-- Schema tip doğrulama (Supabase SQL Editor):
--   select column_name, data_type, udt_name
--   from information_schema.columns
--   where table_schema = 'public'
--     and table_name = 'products'
--   order by ordinal_position;
--
-- RPC deploy kontrolü:
--   select proname, proargtypes, prorettype
--   from pg_proc
--   where proname = 'get_ad_linked_products_by_ids';

-- ---------------------------------------------------------------------------
-- Visibility helper — ad-linked: active status, only explicit rejected blocked.
-- Pending/null approval is allowed for paid home_feature placements.
-- ---------------------------------------------------------------------------
create or replace function public.is_ad_linked_display_product(
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
    and lower(btrim(coalesce(p_status, ''))) not in (
      'rejected', 'reddedildi', 'draft', 'taslak',
      'passive', 'pasif', 'inactive', 'cancelled', 'deleted'
    )
    and not (
      lower(btrim(coalesce(p_approval_status, ''))) in ('rejected', 'reddedildi')
      or lower(btrim(coalesce(p_admin_approval_status, ''))) in ('rejected', 'reddedildi')
    );
$$;

comment on function public.is_ad_linked_display_product(text, text, text) is
  'Home feature ad-linked SKU visibility: active status; pending/null approval OK; rejected blocked.';

-- ---------------------------------------------------------------------------
-- Campaign metadata product membership (selected_product_ids + selected_product_order)
-- ---------------------------------------------------------------------------
create or replace function public.ad_campaign_metadata_contains_product(
  p_metadata jsonb,
  p_product_id text
)
returns boolean
language sql
stable
as $$
  select
    exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(p_metadata->'selected_product_ids', '[]'::jsonb)
      ) elem
      where elem = p_product_id
    )
    or exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(p_metadata->'selected_product_order', '[]'::jsonb)
      ) elem
      where elem = p_product_id
    );
$$;

-- ---------------------------------------------------------------------------
-- Store/seller gate for ad-linked display.
-- Block only when a store row exists AND is explicitly closed/holiday.
-- Missing stores row does NOT block (legacy sellers / partial onboarding).
-- ---------------------------------------------------------------------------
create or replace function public.is_ad_linked_store_active(p_seller_id uuid)
returns boolean
language sql
stable
as $$
  select not exists (
    select 1
    from public.stores st
    where st.seller_id = p_seller_id
      and (
        coalesce(st.is_store_open, true) = false
        or coalesce(st.is_holiday_mode, false) = true
      )
  );
$$;

comment on function public.is_ad_linked_store_active(uuid) is
  'Ad-linked store gate: false only when seller has a store row that is closed or in holiday mode.';

-- ---------------------------------------------------------------------------
-- RPC core + PostgREST overloads (1-arg legacy + 3-arg contextual)
-- ---------------------------------------------------------------------------
drop function if exists public.get_ad_linked_products_by_ids(text[]);
drop function if exists public.get_ad_linked_products_by_ids(text[], text, text);
drop function if exists public.get_ad_linked_products_by_ids_core(text[], text, text);

create or replace function public.get_ad_linked_products_by_ids_core(
  p_product_ids text[] default '{}',
  p_campaign_id text default null,
  p_seller_id text default null
)
returns table(
  id text,
  seller_id text,
  name text,
  brand text,
  image_url text,
  image_urls text[],
  main_category text,
  sub_category text,
  price numeric,
  pricing_type text,
  pricing_mode text,
  base_price numeric,
  portion_price numeric,
  price_per_kg numeric,
  size_options jsonb,
  discount_price numeric,
  status text,
  approval_status text,
  admin_approval_status text,
  stock integer,
  created_at timestamptz,
  updated_at timestamptz,
  stores jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id::text as id,
    p.seller_id::text as seller_id,
    p.name,
    p.brand,
    p.image_url,
    p.image_urls::text[] as image_urls,
    p.main_category,
    p.sub_category,
    p.price::numeric as price,
    p.pricing_type,
    p.pricing_mode,
    p.base_price,
    p.portion_price,
    p.price_per_kg,
    p.size_options,
    p.discount_price::numeric as discount_price,
    p.status,
    p.approval_status,
    p.admin_approval_status,
    p.stock::integer as stock,
    p.created_at,
    p.updated_at,
    case
      when s.business_name is not null then
        jsonb_build_object('business_name', s.business_name)
      else null
    end as stores
  from public.products p
  left join public.stores s on s.seller_id = p.seller_id
  where p.id::text = any(coalesce(p_product_ids, '{}'))
    and public.is_ad_linked_display_product(
      p.status,
      p.approval_status,
      p.admin_approval_status
    )
    and (
      p.seller_id is null
      or public.is_ad_linked_store_active(p.seller_id)
    )
    and (
      p_seller_id is null
      or btrim(p_seller_id) = ''
      or p.seller_id::text = btrim(p_seller_id)
    )
    and exists (
      select 1
      from public.campaigns c
      where c.type = 'home_feature'
        and c.status in ('approved', 'active')
        and c.starts_at <= now()
        and c.ends_at >= now()
        and c.seller_id::text = p.seller_id::text
        and (p_campaign_id is null or btrim(p_campaign_id) = '' or c.id = p_campaign_id)
        and public.ad_campaign_metadata_contains_product(c.metadata, p.id::text)
    )
  order by array_position(p_product_ids, p.id::text);
$$;

-- Legacy PostgREST entrypoint (deployed production signature)
create or replace function public.get_ad_linked_products_by_ids(
  p_product_ids text[]
)
returns table(
  id text,
  seller_id text,
  name text,
  brand text,
  image_url text,
  image_urls text[],
  main_category text,
  sub_category text,
  price numeric,
  pricing_type text,
  pricing_mode text,
  base_price numeric,
  portion_price numeric,
  price_per_kg numeric,
  size_options jsonb,
  discount_price numeric,
  status text,
  approval_status text,
  admin_approval_status text,
  stock integer,
  created_at timestamptz,
  updated_at timestamptz,
  stores jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.get_ad_linked_products_by_ids_core(
    p_product_ids,
    null,
    null
  );
$$;

-- Contextual entrypoint (campaign + seller scoped)
create or replace function public.get_ad_linked_products_by_ids(
  p_product_ids text[],
  p_campaign_id text,
  p_seller_id text
)
returns table(
  id text,
  seller_id text,
  name text,
  brand text,
  image_url text,
  image_urls text[],
  main_category text,
  sub_category text,
  price numeric,
  pricing_type text,
  pricing_mode text,
  base_price numeric,
  portion_price numeric,
  price_per_kg numeric,
  size_options jsonb,
  discount_price numeric,
  status text,
  approval_status text,
  admin_approval_status text,
  stock integer,
  created_at timestamptz,
  updated_at timestamptz,
  stores jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.get_ad_linked_products_by_ids_core(
    p_product_ids,
    p_campaign_id,
    p_seller_id
  );
$$;

grant execute on function public.get_ad_linked_products_by_ids(text[]) to anon, authenticated;
grant execute on function public.get_ad_linked_products_by_ids(text[], text, text)
  to anon, authenticated;
grant execute on function public.get_ad_linked_products_by_ids_core(text[], text, text)
  to anon, authenticated;

comment on function public.get_ad_linked_products_by_ids(text[]) is
  'Ad-linked products (1-arg PostgREST compat wrapper).';
comment on function public.get_ad_linked_products_by_ids(text[], text, text) is
  'Ad-linked products with campaign/seller scope.';

-- ---------------------------------------------------------------------------
-- Diagnostic RPC — why ad-linked products are missing (SQL Editor only)
-- ---------------------------------------------------------------------------
drop function if exists public.diagnose_ad_linked_products(text[], text);

create or replace function public.diagnose_ad_linked_products(
  p_product_ids text[] default '{}',
  p_campaign_id text default null
)
returns table(
  product_id text,
  product_found boolean,
  product_status text,
  approval_status text,
  admin_approval_status text,
  product_seller_id text,
  display_eligible boolean,
  store_active boolean,
  campaign_linked boolean,
  reject_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with ids as (
    select unnest(coalesce(p_product_ids, '{}')) as product_id
  )
  select
    i.product_id,
    (p.id is not null) as product_found,
    p.status as product_status,
    p.approval_status,
    p.admin_approval_status,
    p.seller_id::text as product_seller_id,
    case
      when p.id is null then false
      else public.is_ad_linked_display_product(
        p.status, p.approval_status, p.admin_approval_status
      )
    end as display_eligible,
    case
      when p.id is null then false
      else public.is_ad_linked_store_active(p.seller_id)
    end as store_active,
    exists (
      select 1
      from public.campaigns c
      where c.type = 'home_feature'
        and c.status in ('approved', 'active')
        and c.starts_at <= now()
        and c.ends_at >= now()
        and (p_campaign_id is null or c.id = p_campaign_id)
        and c.seller_id::text = p.seller_id::text
        and public.ad_campaign_metadata_contains_product(c.metadata, i.product_id)
    ) as campaign_linked,
    case
      when p.id is null then 'product_not_found'
      when not public.is_ad_linked_display_product(
        p.status, p.approval_status, p.admin_approval_status
      ) then 'display_ineligible'
      when not public.is_ad_linked_store_active(p.seller_id) then 'store_inactive'
      when not exists (
        select 1
        from public.campaigns c
        where c.type = 'home_feature'
          and c.status in ('approved', 'active')
          and c.starts_at <= now()
          and c.ends_at >= now()
          and (p_campaign_id is null or c.id = p_campaign_id)
          and c.seller_id::text = p.seller_id::text
          and public.ad_campaign_metadata_contains_product(c.metadata, i.product_id)
      ) then 'campaign_not_linked'
      else 'ok'
    end as reject_reason
  from ids i
  left join public.products p on p.id::text = i.product_id;
$$;

grant execute on function public.diagnose_ad_linked_products(text[], text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Kampanya listesi:
-- select c.id, c.name, c.status, c.seller_id, c.metadata->'selected_product_ids'
-- from public.campaigns c where c.type = 'home_feature' order by c.created_at desc limit 30;
--
-- Diagnose:
-- select * from public.diagnose_ad_linked_products(
--   array['1772236267033','1772507303824']::text[],
--   'hfa-1782103848842330'
-- );
--
-- Test RPC (1-arg — mevcut production imzası):
-- select id, name, status, seller_id, image_urls
-- from public.get_ad_linked_products_by_ids(
--   array['1772236267033','1772507303824']::text[]
-- );
--
-- Teknosa teşhis (deploy sonrası):
-- select * from public.diagnose_ad_linked_products(
--   array['1772236267033','1772507303824']::text[],
--   'hfa-1782103848842330'
-- );
--
-- Teknosa ürün + mağaza durumu:
-- select p.id, p.name, p.status, p.approval_status, p.seller_id,
--        st.business_name, st.is_store_open, st.is_holiday_mode
-- from public.products p
-- left join public.stores st on st.seller_id = p.seller_id
-- where p.id::text in ('1772236267033','1772507303824');
--
-- Deploy doğrulama — 2 overload beklenir (1009=text[]):
-- select p.oid::regprocedure as signature
-- from pg_proc p
-- join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname = 'get_ad_linked_products_by_ids';
--
-- ---------------------------------------------------------------------------
-- Teknosa: stale selected_product_ids onarımı (ürünler products tablosunda yok)
-- ---------------------------------------------------------------------------
-- 1) Satıcının mevcut telefon ürünlerini listele:
-- select p.id, p.name, p.status, p.approval_status, p.main_category, p.sub_category
-- from public.products p
-- where p.seller_id::text = '72f73ba9-8355-4573-923d-a2bc8b99bb75'
--   and lower(coalesce(p.sub_category, '')) like '%telefon%'
-- order by p.created_at desc
-- limit 10;
--
-- 2) Kampanya metadata güncelle (YUKARIDAKI gercek id'leri yazin):
-- update public.campaigns
-- set metadata = jsonb_set(
--       jsonb_set(
--         coalesce(metadata, '{}'::jsonb),
--         '{selected_product_ids}',
--         '["GERCEK_ID_1","GERCEK_ID_2"]'::jsonb,
--         true
--       ),
--       '{selected_product_order}',
--       '["GERCEK_ID_1","GERCEK_ID_2"]'::jsonb,
--       true
--     ),
--     updated_at = now()
-- where id = 'hfa-1782103848842330';
--
-- 3) Onarim sonrasi RPC test:
-- select id, name from public.get_ad_linked_products_by_ids(
--   array['GERCEK_ID_1','GERCEK_ID_2']::text[]
-- );

notify pgrst, 'reload schema';
