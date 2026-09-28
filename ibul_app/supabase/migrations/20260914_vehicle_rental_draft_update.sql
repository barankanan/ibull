-- Draft booking updates + rental code on seller approve + 4 KYC faces.

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

  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found or v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'pending_docs' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  select * into v_settings from public.vehicle_rental_settings where listing_id = v_res.listing_id;
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

  v_quote := public.quote_vehicle_delivery_fee(v_res.listing_id, p_delivery_mode, p_lat, p_lng, p_airport);
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

create or replace function public.submit_vehicle_rental_for_review(p_reservation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_settings public.vehicle_rental_settings%rowtype;
  v_docs int;
  v_next text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found or v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'pending_docs' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;
  if v_res.terms_accepted_at is null then
    return jsonb_build_object('ok', false, 'error', 'terms_required');
  end if;
  select count(*) into v_docs
  from (
    select d.doc_type
    from public.vehicle_kyc_documents d
    where d.reservation_id = p_reservation_id
      and d.status in ('submitted', 'verified')
      and d.doc_type in (
        'identity_front', 'identity_back',
        'driver_license_front', 'driver_license_back'
      )
    group by d.doc_type
  ) x;
  if v_docs < 4 then
    return jsonb_build_object('ok', false, 'error', 'documents_required');
  end if;
  select * into v_settings from public.vehicle_rental_settings where listing_id = v_res.listing_id;
  if coalesce(v_settings.instant_booking, false) and not coalesce(v_settings.requires_approval, true) then
    v_next := 'pending_payment';
  else
    v_next := 'pending_seller_review';
  end if;
  update public.vehicle_reservations set status = v_next where id = p_reservation_id;
  perform public.vehicle_rental_log_event(p_reservation_id, v_uid, 'submitted', 'pending_docs', v_next);
  perform public.vehicle_rental_notify(
    v_res.seller_id,
    'Kiralama talebi incelenebilir',
    'Belgeler yüklendi. Talebi onaylayabilir veya reddedebilirsiniz.',
    'vehicle_rental_ready_for_review'
  );
  perform public.vehicle_rental_notify(
    v_res.customer_id,
    'Kiralama talebiniz alındı',
    'Talebiniz satıcı incelemesine gönderildi.',
    'vehicle_rental_request_received'
  );
  return jsonb_build_object('ok', true, 'status', v_next, 'reservation_id', p_reservation_id);
end;
$$;

grant execute on function public.submit_vehicle_rental_for_review(uuid) to authenticated;

create or replace function public.vehicle_rental_fill_code()
returns trigger
language plpgsql
as $$
begin
  if NEW.status in ('pending_payment', 'confirmed', 'reserved')
     and NEW.rental_code is null then
    NEW.rental_code := public.vehicle_rental_make_code();
  end if;
  return NEW;
end;
$$;

drop trigger if exists vehicle_rental_fill_code_trg on public.vehicle_reservations;
create trigger vehicle_rental_fill_code_trg
before update on public.vehicle_reservations
for each row execute function public.vehicle_rental_fill_code();
