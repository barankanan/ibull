-- P0: rental overbooking — serialize draft updates on the listing row and add
-- a GiST exclusion constraint when existing rows do not already overlap.
--
-- Lock impact: ADD CONSTRAINT SHARE UPDATE EXCLUSIVE-ish table lock.
-- lock_timeout fails fast instead of blocking checkout traffic.
-- Rollback: drop constraint vehicle_reservations_no_overlap_excl;

create extension if not exists btree_gist;

create or replace function public.update_vehicle_rental_draft(
  p_reservation_id uuid,
  p_pickup_at timestamptz,
  p_return_at timestamptz,
  p_delivery_mode text,
  p_delivery_address text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_airport boolean default false,
  p_dropoff_mode text default 'gallery_pickup',
  p_dropoff_address text default null,
  p_customer_name text default null,
  p_customer_phone text default null,
  p_customer_birth_date date default null,
  p_customer_email text default null,
  p_customer_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_settings public.vehicle_rental_settings%rowtype;
  v_days int;
  v_subtotal numeric;
  v_quote jsonb;
  v_fee numeric := 0;
  v_total numeric;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_return_at <= p_pickup_at then
    return jsonb_build_object('ok', false, 'error', 'invalid_window');
  end if;
  if p_pickup_at < timezone('utc', now()) - interval '5 minutes' then
    return jsonb_build_object('ok', false, 'error', 'past_date');
  end if;
  if p_delivery_mode not in ('gallery_pickup', 'map_point', 'home_delivery') then
    return jsonb_build_object('ok', false, 'error', 'invalid_delivery_mode');
  end if;
  if p_dropoff_mode is not null
     and p_dropoff_mode not in ('gallery_pickup', 'map_point', 'home_delivery') then
    return jsonb_build_object('ok', false, 'error', 'invalid_dropoff_mode');
  end if;

  select * into v_res
  from public.vehicle_reservations
  where id = p_reservation_id
  for update;
  if not found or v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'pending_docs' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  perform 1
  from public.vehicle_listings
  where id = v_res.listing_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'listing_not_found');
  end if;

  select * into v_settings
  from public.vehicle_rental_settings
  where listing_id = v_res.listing_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'rental_settings_missing');
  end if;

  v_days := public.vehicle_rental_days(p_pickup_at, p_return_at);
  if v_days < v_settings.min_days or v_days > v_settings.max_days then
    return jsonb_build_object(
      'ok', false, 'error', 'duration_not_allowed', 'days', v_days
    );
  end if;

  v_subtotal := v_settings.daily_price * v_days;
  if v_settings.weekly_price is not null and v_days >= 7 then
    v_subtotal := least(v_subtotal, v_settings.weekly_price * (v_days / 7.0));
  end if;
  if v_settings.monthly_price is not null and v_days >= 28 then
    v_subtotal := least(v_subtotal, v_settings.monthly_price * (v_days / 30.0));
  end if;
  v_subtotal := round(v_subtotal, 2);

  v_quote := public.quote_vehicle_delivery_fee(
    v_res.listing_id, p_delivery_mode, p_lat, p_lng, p_airport
  );
  if coalesce(v_quote->>'ok', 'false') <> 'true' then
    return v_quote;
  end if;
  v_fee := coalesce((v_quote->>'fee')::numeric, 0);
  v_total := round(v_subtotal + v_fee + coalesce(v_settings.deposit, 0), 2);

  if public.vehicle_rental_window_blocked(
    v_res.listing_id, p_pickup_at, p_return_at, p_reservation_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  update public.vehicle_reservations set
    pickup_at = p_pickup_at,
    return_at = p_return_at,
    delivery_mode = p_delivery_mode,
    delivery_address = p_delivery_address,
    delivery_lat = p_lat,
    delivery_lng = p_lng,
    dropoff_mode = coalesce(p_dropoff_mode, 'gallery_pickup'),
    dropoff_address = p_dropoff_address,
    rental_days = v_days,
    rental_subtotal = v_subtotal,
    delivery_fee = v_fee,
    total = v_total,
    customer_name = p_customer_name,
    customer_phone = p_customer_phone,
    customer_birth_date = p_customer_birth_date,
    customer_email = p_customer_email,
    customer_note = p_customer_note
  where id = p_reservation_id;

  return jsonb_build_object(
    'ok', true,
    'reservation_id', p_reservation_id,
    'rental_days', v_days,
    'rental_subtotal', v_subtotal,
    'delivery_fee', v_fee,
    'deposit', coalesce(v_settings.deposit, 0),
    'total', v_total,
    'status', 'pending_docs'
  );
end;
$$;

grant execute on function public.update_vehicle_rental_draft(
  uuid, timestamptz, timestamptz, text, text, double precision, double precision,
  boolean, text, text, text, text, date, text, text
) to authenticated;

do $$
declare
  v_overlap int := 0;
begin
  if to_regclass('public.vehicle_reservations') is null then
    return;
  end if;
  if exists (
    select 1
    from pg_constraint
    where conname = 'vehicle_reservations_no_overlap_excl'
  ) then
    return;
  end if;

  select count(*) into v_overlap
  from public.vehicle_reservations a
  join public.vehicle_reservations b
    on a.listing_id = b.listing_id
   and a.id < b.id
  where a.status in (
      'pending_payment', 'pending_docs', 'pending_seller_review',
      'confirmed', 'reserved', 'active_rental', 'return_pending'
    )
    and b.status in (
      'pending_payment', 'pending_docs', 'pending_seller_review',
      'confirmed', 'reserved', 'active_rental', 'return_pending'
    )
    and tstzrange(a.pickup_at, a.return_at, '[)')
        && tstzrange(b.pickup_at, b.return_at, '[)');

  if v_overlap > 0 then
    raise notice
      'vehicle_reservations_no_overlap_excl skipped: % overlapping blocking rows',
      v_overlap;
    return;
  end if;

  perform set_config('lock_timeout', '5s', true);
  execute $sql$
    alter table public.vehicle_reservations
    add constraint vehicle_reservations_no_overlap_excl
    exclude using gist (
      listing_id with =,
      tstzrange(pickup_at, return_at, '[)') with &&
    )
    where (
      status in (
        'pending_payment', 'pending_docs', 'pending_seller_review',
        'confirmed', 'reserved', 'active_rental', 'return_pending'
      )
    )
  $sql$;
exception
  when lock_not_available then
    raise notice 'vehicle_reservations_no_overlap_excl skipped: lock timeout';
  when unique_violation then
    raise notice 'vehicle_reservations_no_overlap_excl skipped: overlap race';
  when others then
    raise notice
      'vehicle_reservations_no_overlap_excl skipped: %',
      sqlerrm;
end;
$$;
