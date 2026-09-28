-- Tighten publish_vehicle_listing: empty brand/model must fail,
-- and at least one photo (media or cover) is required.
-- Does not change listing statuses or restaurant/e-commerce tables.

create or replace function public.publish_vehicle_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_listing public.vehicle_listings%rowtype;
  v_spec public.vehicle_specs%rowtype;
  v_media_count integer := 0;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_listing from public.vehicle_listings where id = p_listing_id for update;
  if not found or v_listing.seller_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select * into v_spec from public.vehicle_specs where listing_id = p_listing_id;
  if not found
     or nullif(trim(coalesce(v_spec.brand, '')), '') is null
     or nullif(trim(coalesce(v_spec.model, '')), '') is null
     or v_spec.year is null then
    return jsonb_build_object('ok', false, 'error', 'specs_required');
  end if;
  if v_listing.listing_type in ('sale', 'both') and coalesce(v_listing.sale_price, 0) <= 0 then
    return jsonb_build_object('ok', false, 'error', 'sale_price_required');
  end if;
  if v_listing.listing_type in ('rental', 'both')
     and not exists (select 1 from public.vehicle_rental_settings where listing_id = p_listing_id) then
    return jsonb_build_object('ok', false, 'error', 'rental_settings_required');
  end if;
  select count(*) into v_media_count
  from public.vehicle_media
  where listing_id = p_listing_id;
  if v_media_count < 1 and nullif(trim(coalesce(v_listing.cover_url, '')), '') is null then
    return jsonb_build_object('ok', false, 'error', 'photos_required');
  end if;
  if v_listing.status not in ('draft', 'pending_review', 'inactive') then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  update public.vehicle_listings
  set status = 'active', published_at = timezone('utc', now())
  where id = p_listing_id;

  insert into public.vehicle_galleries (seller_id)
  values (v_uid)
  on conflict (seller_id) do nothing;

  return jsonb_build_object('ok', true, 'status', 'active');
end;
$$;

grant execute on function public.publish_vehicle_listing(uuid) to authenticated;
