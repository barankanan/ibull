-- Seller submit must land on pending_review, never public active.
-- Idempotent if already pending. Does not touch products/restaurants/auth.

create or replace function public.submit_vehicle_listing_for_review(p_listing_id uuid)
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
  if v_listing.status = 'pending_review' then
    return jsonb_build_object('ok', true, 'status', 'pending_review');
  end if;
  if v_listing.status = 'active' then
    return jsonb_build_object('ok', false, 'error', 'already_published', 'status', v_listing.status);
  end if;
  if v_listing.status not in ('draft', 'inactive') then
    return jsonb_build_object(
      'ok', false,
      'error', 'invalid_state',
      'status', v_listing.status
    );
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

  update public.vehicle_listings
  set
    status = 'pending_review',
    ai_payload = coalesce(ai_payload, '{}'::jsonb) || jsonb_build_object(
      'moderation', jsonb_build_object(
        'status', 'pending',
        'submitted_at', timezone('utc', now())
      )
    )
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'status', 'pending_review');
end;
$$;

create or replace function public.publish_vehicle_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.submit_vehicle_listing_for_review(p_listing_id);
end;
$$;

revoke all on function public.submit_vehicle_listing_for_review(uuid) from public, anon;
grant execute on function public.submit_vehicle_listing_for_review(uuid) to authenticated;
grant execute on function public.publish_vehicle_listing(uuid) to authenticated;
