-- Distinguish missing customer coords / missing zones from a true out-of-zone hit.
-- Backfill a default road zone for sellers who enabled home/map delivery without radius.

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
  v_has_zone boolean := false;
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
      return jsonb_build_object('ok', false, 'error', 'airport_zone_missing', 'km', round(v_km, 2));
    end if;
  else
    select exists (
      select 1
      from public.vehicle_delivery_zones
      where seller_id = v_listing.seller_id and not is_airport
    ) into v_has_zone;
    if not v_has_zone then
      return jsonb_build_object('ok', false, 'error', 'delivery_zone_missing', 'km', round(v_km, 2));
    end if;
    select fee, label into v_fee, v_label
    from public.vehicle_delivery_zones
    where seller_id = v_listing.seller_id
      and not is_airport
      and v_km >= min_km and v_km <= max_km
    order by min_km asc
    limit 1;
    if v_fee is null then
      return jsonb_build_object(
        'ok', false,
        'error', 'out_of_zone',
        'km', round(v_km, 2)
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'fee', v_fee,
    'km', round(v_km, 2),
    'label', v_label
  );
end;
$$;

grant execute on function public.quote_vehicle_delivery_fee(
  uuid, text, double precision, double precision, boolean
) to anon, authenticated;

insert into public.vehicle_delivery_zones (
  seller_id, label, min_km, max_km, fee, is_airport
)
select distinct s.seller_id, 'Adrese teslim', 0, 50, 0, false
from public.vehicle_rental_settings s
where (s.home_delivery = true or s.map_point_delivery = true)
  and s.seller_id is not null
  and not exists (
    select 1
    from public.vehicle_delivery_zones z
    where z.seller_id = s.seller_id
      and z.is_airport = false
  );
