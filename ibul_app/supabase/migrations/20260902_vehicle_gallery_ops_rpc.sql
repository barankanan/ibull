-- iBUL Araç / Galerici — rezervasyon sonrası RPC'ler

create or replace function public.confirm_vehicle_rental_payment(
  p_reservation_id uuid,
  p_order_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_docs int;
  v_code text;
  v_hash text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status not in ('pending_docs', 'pending_payment') then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  select count(*) into v_docs
  from public.vehicle_kyc_documents d
  where d.reservation_id = p_reservation_id
    and d.doc_type in ('identity', 'driver_license')
    and d.status in ('submitted', 'verified');
  if v_docs < 2 then
    return jsonb_build_object('ok', false, 'error', 'documents_required');
  end if;
  if v_res.terms_accepted_at is null then
    return jsonb_build_object('ok', false, 'error', 'terms_required');
  end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');

  update public.vehicle_reservations
  set status = 'reserved',
      payment_status = 'paid',
      order_id = coalesce(p_order_id, order_id),
      handover_code_hash = v_hash
  where id = p_reservation_id;

  update public.vehicle_listings
  set status = 'reserved'
  where id = v_res.listing_id
    and status = 'active';

  insert into public.vehicle_analytics_events (listing_id, seller_id, event_type, actor_id)
  values (v_res.listing_id, v_res.seller_id, 'rental', v_uid);

  return jsonb_build_object(
    'ok', true,
    'status', 'reserved',
    'handover_code', v_code,
    'reservation_id', p_reservation_id
  );
end;
$$;

create or replace function public.accept_vehicle_rental_terms(p_reservation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  update public.vehicle_reservations
  set terms_accepted_at = timezone('utc', now()),
      status = case when status = 'pending_docs' then 'pending_payment' else status end
  where id = p_reservation_id and customer_id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.complete_vehicle_handover(
  p_reservation_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_hash text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.seller_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'reserved' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;
  if v_res.payment_status <> 'paid' then
    return jsonb_build_object('ok', false, 'error', 'payment_required');
  end if;
  v_hash := encode(digest(trim(coalesce(p_code, '')), 'sha256'), 'hex');
  if v_res.handover_code_hash is null or v_hash <> v_res.handover_code_hash then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  update public.vehicle_reservations
  set status = 'active_rental'
  where id = p_reservation_id;

  update public.vehicle_listings
  set status = 'rented'
  where id = v_res.listing_id;

  return jsonb_build_object('ok', true, 'status', 'active_rental');
end;
$$;

create or replace function public.complete_vehicle_return(
  p_reservation_id uuid,
  p_odometer_km int default null,
  p_fuel_level text default null,
  p_damage_note text default null,
  p_photo_urls text[] default '{}',
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.seller_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status not in ('active_rental', 'return_pending') then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  insert into public.vehicle_returns (
    reservation_id, listing_id, seller_id, customer_id,
    odometer_km, fuel_level, damage_note, photo_urls, notes
  ) values (
    p_reservation_id, v_res.listing_id, v_res.seller_id, v_res.customer_id,
    p_odometer_km, p_fuel_level, p_damage_note, coalesce(p_photo_urls, '{}'), p_notes
  )
  on conflict (reservation_id) do update set
    odometer_km = excluded.odometer_km,
    fuel_level = excluded.fuel_level,
    damage_note = excluded.damage_note,
    photo_urls = excluded.photo_urls,
    notes = excluded.notes;

  update public.vehicle_reservations
  set status = 'completed'
  where id = p_reservation_id;

  update public.vehicle_listings
  set status = 'active'
  where id = v_res.listing_id
    and status in ('rented', 'return_pending', 'reserved');

  return jsonb_build_object('ok', true, 'status', 'completed');
end;
$$;

create or replace function public.respond_vehicle_quote(
  p_quote_id uuid,
  p_action text,
  p_counter_amount numeric default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_q public.vehicle_quotes%rowtype;
  v_status text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_q from public.vehicle_quotes where id = p_quote_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_q.seller_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_q.status <> 'pending' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;
  if p_action not in ('accept', 'reject', 'counter') then
    return jsonb_build_object('ok', false, 'error', 'invalid_action');
  end if;
  if p_action = 'counter' and (p_counter_amount is null or p_counter_amount <= 0) then
    return jsonb_build_object('ok', false, 'error', 'counter_amount_required');
  end if;

  v_status := case p_action
    when 'accept' then 'accepted'
    when 'reject' then 'rejected'
    else 'countered'
  end;

  update public.vehicle_quotes
  set status = v_status,
      counter_amount = case when p_action = 'counter' then p_counter_amount else counter_amount end,
      note = coalesce(p_note, note)
  where id = p_quote_id;

  insert into public.vehicle_quote_events (quote_id, actor_id, action, amount, note)
  values (p_quote_id, v_uid, p_action, coalesce(p_counter_amount, v_q.amount), p_note);

  if p_action = 'accept' then
    insert into public.vehicle_analytics_events (listing_id, seller_id, event_type, actor_id)
    values (v_q.listing_id, v_q.seller_id, 'quote', v_uid);
  end if;

  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

create or replace function public.respond_vehicle_appointment(
  p_appointment_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_a public.vehicle_appointments%rowtype;
  v_status text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_a from public.vehicle_appointments where id = p_appointment_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_a.seller_id <> v_uid and v_a.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if p_action = 'cancel' then
    v_status := 'cancelled';
  elsif v_a.seller_id = v_uid and p_action in ('confirm', 'reject', 'complete') then
    v_status := case p_action
      when 'confirm' then 'confirmed'
      when 'reject' then 'rejected'
      else 'completed'
    end;
  else
    return jsonb_build_object('ok', false, 'error', 'invalid_action');
  end if;

  update public.vehicle_appointments set status = v_status where id = p_appointment_id;
  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

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
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_listing from public.vehicle_listings where id = p_listing_id for update;
  if not found or v_listing.seller_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select * into v_spec from public.vehicle_specs where listing_id = p_listing_id;
  if not found or v_spec.brand is null or v_spec.model is null or v_spec.year is null then
    return jsonb_build_object('ok', false, 'error', 'specs_required');
  end if;
  if v_listing.listing_type in ('sale', 'both') and coalesce(v_listing.sale_price, 0) <= 0 then
    return jsonb_build_object('ok', false, 'error', 'sale_price_required');
  end if;
  if v_listing.listing_type in ('rental', 'both')
     and not exists (select 1 from public.vehicle_rental_settings where listing_id = p_listing_id) then
    return jsonb_build_object('ok', false, 'error', 'rental_settings_required');
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

create or replace function public.vehicle_seller_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (timezone('utc', now()))::date;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  return jsonb_build_object(
    'ok', true,
    'total', (select count(*) from public.vehicle_listings where seller_id = v_uid),
    'active', (select count(*) from public.vehicle_listings where seller_id = v_uid and status = 'active'),
    'rental', (select count(*) from public.vehicle_listings where seller_id = v_uid and listing_type in ('rental', 'both')),
    'reserved', (select count(*) from public.vehicle_listings where seller_id = v_uid and status = 'reserved'),
    'sold', (select count(*) from public.vehicle_listings where seller_id = v_uid and status = 'sold'),
    'maintenance', (select count(*) from public.vehicle_listings where seller_id = v_uid and status = 'maintenance'),
    'unread_messages', (
      select count(*) from public.vehicle_conversations
      where seller_id = v_uid and last_message_at::date = v_today
    ),
    'new_quotes', (
      select count(*) from public.vehicle_quotes
      where seller_id = v_uid and status = 'pending'
    ),
    'new_reservations', (
      select count(*) from public.vehicle_reservations
      where seller_id = v_uid and created_at::date = v_today
        and status not in ('cancelled')
    ),
    'appointments_today', (
      select count(*) from public.vehicle_appointments
      where seller_id = v_uid and scheduled_at::date = v_today
        and status in ('pending', 'confirmed')
    ),
    'handovers_today', (
      select count(*) from public.vehicle_reservations
      where seller_id = v_uid and pickup_at::date = v_today
        and status in ('reserved', 'active_rental')
    ),
    'returns_today', (
      select count(*) from public.vehicle_reservations
      where seller_id = v_uid and return_at::date = v_today
        and status in ('active_rental', 'return_pending')
    ),
    'views', (
      select count(*) from public.vehicle_analytics_events
      where seller_id = v_uid and event_type = 'view'
    ),
    'favorites', (
      select count(*) from public.vehicle_favorites f
      join public.vehicle_listings l on l.id = f.listing_id
      where l.seller_id = v_uid
    ),
    'quotes', (select count(*) from public.vehicle_quotes where seller_id = v_uid),
    'sales', (select count(*) from public.vehicle_listings where seller_id = v_uid and status = 'sold'),
    'active_rentals', (
      select count(*) from public.vehicle_reservations
      where seller_id = v_uid and status = 'active_rental'
    ),
    'upcoming_reservations', (
      select count(*) from public.vehicle_reservations
      where seller_id = v_uid and status = 'reserved' and pickup_at >= timezone('utc', now())
    )
  );
end;
$$;

create or replace function public.nearby_vehicle_galleries(
  p_lat double precision,
  p_lng double precision,
  p_radius_km numeric default 25,
  p_limit int default 30
)
returns table (
  seller_id uuid,
  business_name text,
  logo_url text,
  cover_url text,
  address text,
  city text,
  district text,
  phone text,
  store_lat double precision,
  store_lng double precision,
  is_verified boolean,
  vehicle_count bigint,
  distance_km numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    s.seller_id,
    s.business_name,
    s.logo_url,
    s.cover_url,
    s.address,
    s.city,
    s.district,
    coalesce(s.phone, s.support_phone),
    s.store_lat,
    s.store_lng,
    coalesce(g.verified_gallery, s.is_verified, false),
    (
      select count(*) from public.vehicle_listings l
      where l.seller_id = s.seller_id and l.status in ('active', 'reserved', 'rented')
    ) as vehicle_count,
    round((
      6371 * acos(least(1::numeric, greatest(-1::numeric,
        cos(radians(p_lat)) * cos(radians(s.store_lat)) *
        cos(radians(s.store_lng) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(s.store_lat))
      )))
    )::numeric, 2) as distance_km
  from public.stores s
  left join public.vehicle_galleries g on g.seller_id = s.seller_id
  where s.store_lat is not null
    and s.store_lng is not null
    and (
      lower(coalesce(s.category, '')) like '%galeri%'
      or exists (select 1 from public.vehicle_listings vl where vl.seller_id = s.seller_id)
    )
  order by distance_km asc
  limit least(greatest(coalesce(p_limit, 30), 1), 80);
end;
$$;

grant execute on function public.confirm_vehicle_rental_payment(uuid, text) to authenticated;
grant execute on function public.accept_vehicle_rental_terms(uuid) to authenticated;
grant execute on function public.complete_vehicle_handover(uuid, text) to authenticated;
grant execute on function public.complete_vehicle_return(uuid, int, text, text, text[], text) to authenticated;
grant execute on function public.respond_vehicle_quote(uuid, text, numeric, text) to authenticated;
grant execute on function public.respond_vehicle_appointment(uuid, text) to authenticated;
grant execute on function public.publish_vehicle_listing(uuid) to authenticated;
grant execute on function public.vehicle_seller_dashboard() to authenticated;
grant execute on function public.nearby_vehicle_galleries(double precision, double precision, numeric, int)
  to anon, authenticated;
