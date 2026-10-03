-- list_daily_deal_products artık discount_price < price satırından yüzde üretmez.
-- Flutter ürün modeli discount_price alanını eski fiyat olarak okur.
-- Fırsat yalnızca kayıtlı eski fiyat güncel fiyattan yüksekse döner.
-- Yüzde: ((discount_price - price) / discount_price) * 100

create or replace function public.list_daily_deal_products(p_limit integer default 12)
returns table (
  id text,
  name text,
  brand text,
  image_url text,
  price numeric,
  discount_price numeric,
  discount_percent numeric,
  stock integer,
  seller_id uuid,
  store_name text,
  main_category text,
  sub_category text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.brand,
    p.image_url,
    p.price::numeric,
    p.discount_price::numeric,
    case
      when p.price > 0 and p.discount_price > p.price
        then round(((p.discount_price - p.price) / p.discount_price) * 100)
      else 0
    end as discount_percent,
    p.stock,
    p.seller_id,
    s.business_name,
    p.main_category,
    p.sub_category
  from public.products p
  left join public.stores s on s.seller_id = p.seller_id
  where lower(coalesce(p.status, '')) in ('aktif', 'active')
    and (
      lower(coalesce(p.approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
      or lower(coalesce(p.admin_approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
    )
    and coalesce(p.stock, 0) > 0
    and p.discount_price is not null
    and p.price is not null
    and p.discount_price > p.price
    and coalesce(s.is_store_open, true) = true
    and coalesce(s.is_holiday_mode, false) = false
    and coalesce(s.accept_new_orders, true) = true
  order by
    ((p.discount_price - p.price) / nullif(p.discount_price, 0)) desc,
    p.created_at desc
  limit greatest(coalesce(p_limit, 12), 1);
$$;
