-- Vehicle listings: seller submits for review; only admin can publish.
-- Does not touch products, restaurants, stores, or auth tables.

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
  if v_listing.status not in ('draft', 'pending_review', 'inactive') then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
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

create or replace function public.moderate_vehicle_listing(
  p_listing_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing public.vehicle_listings%rowtype;
  v_action text := lower(trim(coalesce(p_action, '')));
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.vehicle_is_admin() then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select * into v_listing from public.vehicle_listings where id = p_listing_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_action = 'approve' then
    perform set_config('ibul.vehicle_moderation', '1', true);
    update public.vehicle_listings
    set
      status = 'active',
      published_at = timezone('utc', now()),
      ai_payload = coalesce(ai_payload, '{}'::jsonb) || jsonb_build_object(
        'moderation', jsonb_build_object(
          'status', 'approved',
          'reviewed_at', timezone('utc', now()),
          'reviewed_by', auth.uid()
        )
      )
    where id = p_listing_id;
    return jsonb_build_object('ok', true, 'status', 'active');
  end if;

  if v_action = 'reject' then
    if v_reason is null then
      return jsonb_build_object('ok', false, 'error', 'reason_required');
    end if;
    update public.vehicle_listings
    set
      status = 'draft',
      published_at = null,
      ai_payload = coalesce(ai_payload, '{}'::jsonb) || jsonb_build_object(
        'moderation', jsonb_build_object(
          'status', 'rejected',
          'reason', v_reason,
          'reviewed_at', timezone('utc', now()),
          'reviewed_by', auth.uid()
        ),
        'rejection_reason', v_reason
      )
    where id = p_listing_id;
    return jsonb_build_object('ok', true, 'status', 'draft');
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid_action');
end;
$$;

-- Legacy seller publish must not go public.
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

create or replace function public.vehicle_listings_guard_public_status()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'active'
     and old.status is distinct from 'active'
     and not public.vehicle_is_admin()
     and current_setting('ibul.vehicle_moderation', true) is distinct from '1' then
    raise exception 'seller_cannot_publish';
  end if;
  return new;
end;
$$;

drop trigger if exists vehicle_listings_guard_public_status on public.vehicle_listings;
create trigger vehicle_listings_guard_public_status
before update on public.vehicle_listings
for each row
execute function public.vehicle_listings_guard_public_status();

revoke all on function public.submit_vehicle_listing_for_review(uuid) from public, anon;
grant execute on function public.submit_vehicle_listing_for_review(uuid) to authenticated;
revoke all on function public.moderate_vehicle_listing(uuid, text, text) from public, anon;
grant execute on function public.moderate_vehicle_listing(uuid, text, text) to authenticated;
grant execute on function public.publish_vehicle_listing(uuid) to authenticated;
