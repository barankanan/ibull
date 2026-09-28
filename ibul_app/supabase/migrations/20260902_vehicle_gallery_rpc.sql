-- iBUL Araç / Galerici — güvenlik tanımlı RPC'ler
-- Fiyat, teslim ücreti, müsaitlik, teslim kodu client'tan güvenilmez.

create or replace function public.vehicle_listing_is_rentable(p_listing public.vehicle_listings)
returns boolean
language sql
immutable
as $$
  select p_listing.status in ('active', 'reserved')
     and p_listing.listing_type in ('rental', 'both');
$$;

create or replace function public.search_vehicle_listings(
  p_query text default null,
  p_brand text default null,
  p_model text default null,
  p_version text default null,
  p_year_min int default null,
  p_year_max int default null,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_km_min int default null,
  p_km_max int default null,
  p_fuel text default null,
  p_transmission text default null,
  p_body_type text default null,
  p_engine_cc_min int default null,
  p_engine_cc_max int default null,
  p_power_hp_min int default null,
  p_power_hp_max int default null,
  p_color text default null,
  p_city text default null,
  p_district text default null,
  p_sale_only boolean default false,
  p_rental_only boolean default false,
  p_verified_only boolean default false,
  p_trade_in boolean default false,
  p_financing boolean default false,
  p_home_delivery boolean default false,
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  id uuid,
  seller_id uuid,
  listing_type text,
  status text,
  sale_price numeric,
  negotiable boolean,
  financing boolean,
  trade_in boolean,
  home_delivery_sale boolean,
  city text,
  district text,
  cover_url text,
  description text,
  favorite_count int,
  view_count int,
  brand text,
  model text,
  version text,
  year int,
  body_type text,
  fuel text,
  transmission text,
  engine_cc int,
  power_hp int,
  color text,
  mileage_km int,
  mileage_verified boolean,
  gallery_name text,
  gallery_verified boolean,
  daily_price numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(lower(trim(coalesce(p_query, ''))), '');
begin
  return query
  select
    l.id, l.seller_id, l.listing_type, l.status, l.sale_price, l.negotiable,
    l.financing, l.trade_in, l.home_delivery_sale, l.city, l.district, l.cover_url,
    l.description, l.favorite_count, l.view_count,
    s.brand, s.model, s.version, s.year, s.body_type, s.fuel, s.transmission,
    s.engine_cc, s.power_hp, s.color, s.mileage_km, s.mileage_verified,
    st.business_name, coalesce(g.verified_gallery, st.is_verified, false),
    rs.daily_price
  from public.vehicle_listings l
  join public.vehicle_specs s on s.listing_id = l.id
  join public.stores st on st.seller_id = l.seller_id
  left join public.vehicle_galleries g on g.seller_id = l.seller_id
  left join public.vehicle_rental_settings rs on rs.listing_id = l.id
  where l.status in ('active', 'reserved', 'rented')
    and (v_q is null or l.search_text like '%' || v_q || '%')
    and (p_brand is null or lower(s.brand) = lower(p_brand))
    and (p_model is null or lower(s.model) = lower(p_model))
    and (p_version is null or lower(coalesce(s.version, '')) like '%' || lower(p_version) || '%')
    and (p_year_min is null or s.year >= p_year_min)
    and (p_year_max is null or s.year <= p_year_max)
    and (p_price_min is null or coalesce(l.sale_price, rs.daily_price, 0) >= p_price_min)
    and (p_price_max is null or coalesce(l.sale_price, rs.daily_price, 0) <= p_price_max)
    and (p_km_min is null or coalesce(s.mileage_km, 0) >= p_km_min)
    and (p_km_max is null or coalesce(s.mileage_km, 0) <= p_km_max)
    and (p_fuel is null or lower(coalesce(s.fuel, '')) = lower(p_fuel))
    and (p_transmission is null or lower(coalesce(s.transmission, '')) = lower(p_transmission))
    and (p_body_type is null or lower(coalesce(s.body_type, '')) = lower(p_body_type))
    and (p_engine_cc_min is null or coalesce(s.engine_cc, 0) >= p_engine_cc_min)
    and (p_engine_cc_max is null or coalesce(s.engine_cc, 0) <= p_engine_cc_max)
    and (p_power_hp_min is null or coalesce(s.power_hp, 0) >= p_power_hp_min)
    and (p_power_hp_max is null or coalesce(s.power_hp, 0) <= p_power_hp_max)
    and (p_color is null or lower(coalesce(s.color, '')) = lower(p_color))
    and (p_city is null or lower(coalesce(l.city, '')) = lower(p_city))
    and (p_district is null or lower(coalesce(l.district, '')) = lower(p_district))
    and (not p_sale_only or l.listing_type in ('sale', 'both'))
    and (not p_rental_only or l.listing_type in ('rental', 'both'))
    and (not p_verified_only or s.mileage_verified)
    and (not p_trade_in or l.trade_in)
    and (not p_financing or l.financing)
    and (not p_home_delivery or l.home_delivery_sale or coalesce(rs.home_delivery, false))
  order by l.created_at desc
  limit v_limit offset v_offset;
end;
$$;

grant execute on function public.search_vehicle_listings(
  text, text, text, text, int, int, numeric, numeric, int, int, text, text, text,
  int, int, int, int, text, text, text, boolean, boolean, boolean, boolean, boolean,
  boolean, int, int
) to anon, authenticated;

create or replace function public.quote_vehicle_delivery_fee(
  p_listing_id uuid,
  p_mode text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_airport boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_listing public.vehicle_listings%rowtype;
  v_store public.stores%rowtype;
  v_settings public.vehicle_rental_settings%rowtype;
  v_km numeric;
  v_fee numeric := 0;
  v_label text := 'gallery';
begin
  select * into v_listing from public.vehicle_listings where id = p_listing_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'listing_not_found');
  end if;
  select * into v_store from public.stores where seller_id = v_listing.seller_id;
  select * into v_settings from public.vehicle_rental_settings where listing_id = p_listing_id;

  if p_mode = 'gallery_pickup' then
    return jsonb_build_object('ok', true, 'fee', 0, 'km', 0, 'label', 'gallery_pickup');
  end if;

  if p_mode = 'home_delivery' and (v_settings.home_delivery is distinct from true) then
    return jsonb_build_object('ok', false, 'error', 'home_delivery_disabled');
  end if;
  if p_mode = 'map_point' and (v_settings.map_point_delivery is distinct from true) then
    return jsonb_build_object('ok', false, 'error', 'map_point_disabled');
  end if;
  if p_lat is null or p_lng is null then
    return jsonb_build_object('ok', false, 'error', 'location_required');
  end if;
  if v_store.store_lat is null or v_store.store_lng is null then
    return jsonb_build_object('ok', false, 'error', 'gallery_location_missing');
  end if;

  v_km := 6371 * acos(
    least(1::numeric, greatest(-1::numeric,
      cos(radians(v_store.store_lat)) * cos(radians(p_lat)) *
      cos(radians(p_lng) - radians(v_store.store_lng)) +
      sin(radians(v_store.store_lat)) * sin(radians(p_lat))
    ))
  );

  if p_airport then
    select fee, label into v_fee, v_label
    from public.vehicle_delivery_zones
    where seller_id = v_listing.seller_id and is_airport
    order by fee asc
    limit 1;
    if v_fee is null then
      return jsonb_build_object('ok', false, 'error', 'airport_zone_missing', 'km', v_km);
    end if;
  else
    select fee, label into v_fee, v_label
    from public.vehicle_delivery_zones
    where seller_id = v_listing.seller_id
      and not is_airport
      and v_km >= min_km and v_km <= max_km
    order by min_km asc
    limit 1;
    if v_fee is null then
      return jsonb_build_object('ok', false, 'error', 'out_of_zone', 'km', v_km);
    end if;
  end if;

  return jsonb_build_object('ok', true, 'fee', v_fee, 'km', round(v_km, 2), 'label', v_label);
end;
$$;

grant execute on function public.quote_vehicle_delivery_fee(uuid, text, double precision, double precision, boolean)
to anon, authenticated;

create or replace function public.vehicle_rental_days(p_pickup timestamptz, p_return timestamptz)
returns int
language sql
immutable
as $$
  select greatest(
    1,
    (date_trunc('day', p_return)::date - date_trunc('day', p_pickup)::date)
  );
$$;

create or replace function public.create_vehicle_rental_reservation(
  p_listing_id uuid,
  p_pickup_at timestamptz,
  p_return_at timestamptz,
  p_delivery_mode text,
  p_delivery_address text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_airport boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_listing public.vehicle_listings%rowtype;
  v_settings public.vehicle_rental_settings%rowtype;
  v_days int;
  v_subtotal numeric;
  v_quote jsonb;
  v_fee numeric := 0;
  v_total numeric;
  v_id uuid;
  v_overlap int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_return_at <= p_pickup_at then
    return jsonb_build_object('ok', false, 'error', 'invalid_window');
  end if;
  if p_delivery_mode not in ('gallery_pickup', 'map_point', 'home_delivery') then
    return jsonb_build_object('ok', false, 'error', 'invalid_delivery_mode');
  end if;

  select * into v_listing from public.vehicle_listings where id = p_listing_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'listing_not_found');
  end if;
  if v_listing.seller_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'cannot_rent_own_vehicle');
  end if;
  if v_listing.status not in ('active') or v_listing.listing_type not in ('rental', 'both') then
    return jsonb_build_object('ok', false, 'error', 'not_rentable');
  end if;

  select * into v_settings from public.vehicle_rental_settings where listing_id = p_listing_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'rental_settings_missing');
  end if;

  v_days := public.vehicle_rental_days(p_pickup_at, p_return_at);
  if v_days < v_settings.min_days or v_days > v_settings.max_days then
    return jsonb_build_object('ok', false, 'error', 'duration_not_allowed', 'days', v_days);
  end if;

  v_subtotal := v_settings.daily_price * v_days;
  if v_settings.weekly_price is not null and v_days >= 7 then
    v_subtotal := least(v_subtotal, v_settings.weekly_price * (v_days / 7.0));
  end if;
  if v_settings.monthly_price is not null and v_days >= 28 then
    v_subtotal := least(v_subtotal, v_settings.monthly_price * (v_days / 30.0));
  end if;
  v_subtotal := round(v_subtotal, 2);

  v_quote := public.quote_vehicle_delivery_fee(p_listing_id, p_delivery_mode, p_lat, p_lng, p_airport);
  if coalesce(v_quote->>'ok', 'false') <> 'true' then
    return v_quote;
  end if;
  v_fee := coalesce((v_quote->>'fee')::numeric, 0);
  v_total := round(v_subtotal + v_fee + coalesce(v_settings.deposit, 0), 2);

  select count(*) into v_overlap
  from public.vehicle_reservations r
  where r.listing_id = p_listing_id
    and r.status in (
      'pending_payment', 'pending_docs', 'confirmed', 'reserved',
      'active_rental', 'return_pending'
    )
    and tstzrange(r.pickup_at, r.return_at, '[)') && tstzrange(p_pickup_at, p_return_at, '[)');
  if v_overlap > 0 then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  insert into public.vehicle_reservations (
    listing_id, seller_id, customer_id, status, pickup_at, return_at,
    delivery_mode, delivery_address, delivery_lat, delivery_lng,
    rental_days, rental_subtotal, delivery_fee, deposit, total, payment_status
  ) values (
    p_listing_id, v_listing.seller_id, v_uid, 'pending_docs',
    p_pickup_at, p_return_at, p_delivery_mode, p_delivery_address, p_lat, p_lng,
    v_days, v_subtotal, v_fee, coalesce(v_settings.deposit, 0), v_total, 'unpaid'
  ) returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'reservation_id', v_id,
    'rental_days', v_days,
    'rental_subtotal', v_subtotal,
    'delivery_fee', v_fee,
    'deposit', coalesce(v_settings.deposit, 0),
    'total', v_total
  );
end;
$$;

grant execute on function public.create_vehicle_rental_reservation(
  uuid, timestamptz, timestamptz, text, text, double precision, double precision, boolean
) to authenticated;
