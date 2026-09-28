-- Rental RPCs: overlap, seller review, cancel/refund status, honest payment.

create or replace function public.vehicle_rental_notify(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  insert into public.user_notifications (user_id, title, body, data)
  values (
    p_user_id,
    p_title,
    p_body,
    jsonb_build_object('type', p_type)
  );
exception when others then
  null;
end;
$$;

create or replace function public.vehicle_rental_log_event(
  p_booking uuid,
  p_actor uuid,
  p_action text,
  p_from text,
  p_to text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.vehicle_rental_booking_events (
    booking_id, actor_id, action, from_status, to_status
  ) values (p_booking, p_actor, p_action, p_from, p_to);
exception when others then
  null;
end;
$$;

create or replace function public.vehicle_rental_window_blocked(
  p_listing_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_ignore_id uuid default null
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.vehicle_reservations r
    where r.listing_id = p_listing_id
      and (p_ignore_id is null or r.id <> p_ignore_id)
      and r.status in (
        'pending_payment', 'pending_docs', 'pending_seller_review',
        'confirmed', 'reserved', 'active_rental', 'return_pending'
      )
      and tstzrange(r.pickup_at, r.return_at, '[)') && tstzrange(p_start, p_end, '[)')
  ) or exists (
    select 1
    from public.vehicle_rental_blocks b
    where b.listing_id = p_listing_id
      and tstzrange(b.start_at, b.end_at, '[)') && tstzrange(p_start, p_end, '[)')
  );
$$;

create or replace function public.vehicle_rental_make_code()
returns text
language plpgsql
as $$
declare
  v_code text;
  v_tries int := 0;
begin
  loop
    v_tries := v_tries + 1;
    v_code := 'IBR-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (
      select 1 from public.vehicle_reservations where rental_code = v_code
    ) or v_tries > 8;
  end loop;
  return v_code;
end;
$$;

create or replace function public.vehicle_rental_refund_percent(
  p_policy jsonb,
  p_start_at timestamptz,
  p_actor text
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_hours numeric;
  v_full int;
  v_half int;
begin
  if p_actor = 'seller' then
    return 100;
  end if;
  v_hours := extract(epoch from (p_start_at - timezone('utc', now()))) / 3600.0;
  v_full := coalesce((p_policy->>'full_refund_hours')::int, 24);
  v_half := coalesce((p_policy->>'half_refund_hours')::int, 12);
  if v_hours >= v_full then
    return coalesce((p_policy->>'full_percent')::numeric, 100);
  end if;
  if v_hours >= v_half then
    return coalesce((p_policy->>'half_percent')::numeric, 50);
  end if;
  return coalesce((p_policy->>'late_percent')::numeric, 0);
end;
$$;

drop function if exists public.create_vehicle_rental_reservation(
  uuid, timestamptz, timestamptz, text, text, double precision, double precision, boolean
);

create or replace function public.create_vehicle_rental_reservation(
  p_listing_id uuid,
  p_pickup_at timestamptz,
  p_return_at timestamptz,
  p_delivery_mode text,
  p_delivery_address text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_airport boolean default false,
  p_dropoff_mode text default null,
  p_dropoff_address text default null,
  p_dropoff_lat double precision default null,
  p_dropoff_lng double precision default null,
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
  v_listing public.vehicle_listings%rowtype;
  v_settings public.vehicle_rental_settings%rowtype;
  v_days int;
  v_subtotal numeric;
  v_quote jsonb;
  v_fee numeric := 0;
  v_total numeric;
  v_id uuid;
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

  if public.vehicle_rental_window_blocked(p_listing_id, p_pickup_at, p_return_at) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  insert into public.vehicle_reservations (
    listing_id, seller_id, customer_id, status, pickup_at, return_at,
    delivery_mode, delivery_address, delivery_lat, delivery_lng,
    dropoff_mode, dropoff_address, dropoff_lat, dropoff_lng,
    rental_days, rental_subtotal, delivery_fee, deposit, total, payment_status,
    customer_name, customer_phone, customer_birth_date, customer_email,
    customer_note, cancellation_policy, documents_retention_until
  ) values (
    p_listing_id, v_listing.seller_id, v_uid, 'pending_docs',
    p_pickup_at, p_return_at, p_delivery_mode, p_delivery_address, p_lat, p_lng,
    coalesce(p_dropoff_mode, 'gallery_pickup'), p_dropoff_address, p_dropoff_lat, p_dropoff_lng,
    v_days, v_subtotal, v_fee, coalesce(v_settings.deposit, 0), v_total, 'unpaid',
    p_customer_name, p_customer_phone, p_customer_birth_date, p_customer_email,
    p_customer_note, v_settings.cancellation_policy,
    timezone('utc', now()) + interval '365 days'
  ) returning id into v_id;

  perform public.vehicle_rental_log_event(v_id, v_uid, 'created', null, 'pending_docs');
  perform public.vehicle_rental_notify(
    v_listing.seller_id,
    'Yeni kiralama talebi',
    'Galeriniz için yeni bir kiralama talebi oluşturuldu.',
    'vehicle_rental_new_request'
  );

  return jsonb_build_object(
    'ok', true,
    'reservation_id', v_id,
    'rental_days', v_days,
    'rental_subtotal', v_subtotal,
    'delivery_fee', v_fee,
    'deposit', coalesce(v_settings.deposit, 0),
    'total', v_total,
    'status', 'pending_docs'
  );
end;
$$;

grant execute on function public.create_vehicle_rental_reservation(
  uuid, timestamptz, timestamptz, text, text, double precision, double precision,
  boolean, text, text, double precision, double precision, text, text, date, text, text
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
  select count(distinct d.doc_type) into v_docs
  from public.vehicle_kyc_documents d
  where d.reservation_id = p_reservation_id
    and d.status in ('submitted', 'verified')
    and d.doc_type in (
      'identity', 'identity_front', 'driver_license', 'driver_license_front'
    );
  if v_docs < 2 then
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

create or replace function public.respond_vehicle_rental_reservation(
  p_reservation_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_next text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_action not in ('approve', 'reject', 'seller_cancel') then
    return jsonb_build_object('ok', false, 'error', 'invalid_action');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.seller_id <> v_uid and not public.vehicle_is_admin() then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;

  if p_action = 'approve' then
    if v_res.status <> 'pending_seller_review' then
      return jsonb_build_object('ok', false, 'error', 'invalid_state');
    end if;
    if public.vehicle_rental_window_blocked(
      v_res.listing_id, v_res.pickup_at, v_res.return_at, v_res.id
    ) then
      return jsonb_build_object('ok', false, 'error', 'not_available');
    end if;
    v_next := 'pending_payment';
    update public.vehicle_reservations
    set status = v_next, confirmed_at = timezone('utc', now())
    where id = p_reservation_id;
    perform public.vehicle_rental_notify(
      v_res.customer_id,
      'Kiralama talebiniz onaylandı',
      'Satıcı talebinizi onayladı. Ödeme, bağlı tahsilat altyapısı üzerinden alınır.',
      'vehicle_rental_seller_approved'
    );
  elsif p_action = 'reject' then
    if nullif(btrim(coalesce(p_reason, '')), '') is null then
      return jsonb_build_object('ok', false, 'error', 'reason_required');
    end if;
    if v_res.status not in ('pending_seller_review', 'pending_payment', 'pending_docs') then
      return jsonb_build_object('ok', false, 'error', 'invalid_state');
    end if;
    if v_res.payment_status in ('paid', 'authorized') then
      v_next := 'refund_pending';
      insert into public.vehicle_rental_refunds (booking_id, amount, reason, status)
      values (p_reservation_id, v_res.total, p_reason, 'refund_pending');
      update public.vehicle_reservations
      set status = v_next,
          payment_status = 'refund_pending',
          reject_reason = p_reason,
          cancelled_at = timezone('utc', now()),
          refund_amount = v_res.total,
          refund_reason = p_reason
      where id = p_reservation_id;
      perform public.vehicle_rental_notify(
        v_res.customer_id,
        'Kiralama talebiniz reddedildi',
        'İade başlatıldı.',
        'vehicle_rental_seller_rejected'
      );
    else
      v_next := 'rejected';
      update public.vehicle_reservations
      set status = v_next,
          reject_reason = p_reason,
          cancelled_at = timezone('utc', now())
      where id = p_reservation_id;
      perform public.vehicle_rental_notify(
        v_res.customer_id,
        'Kiralama talebiniz reddedildi',
        'Ödeme alınmadığı için iade gerekmedi.',
        'vehicle_rental_seller_rejected'
      );
    end if;
  else
    if nullif(btrim(coalesce(p_reason, '')), '') is null then
      return jsonb_build_object('ok', false, 'error', 'reason_required');
    end if;
    if v_res.status not in ('pending_payment', 'confirmed', 'reserved') then
      return jsonb_build_object('ok', false, 'error', 'invalid_state');
    end if;
    if v_res.payment_status in ('paid', 'authorized') then
      v_next := 'refund_pending';
      insert into public.vehicle_rental_refunds (booking_id, amount, reason, status)
      values (p_reservation_id, v_res.total, p_reason, 'refund_pending');
      update public.vehicle_reservations
      set status = 'seller_cancelled',
          payment_status = 'refund_pending',
          cancel_reason = p_reason,
          cancel_actor = 'seller',
          cancelled_at = timezone('utc', now()),
          refund_amount = v_res.total,
          refund_reason = p_reason
      where id = p_reservation_id;
      v_next := 'seller_cancelled';
    else
      v_next := 'seller_cancelled';
      update public.vehicle_reservations
      set status = v_next,
          cancel_reason = p_reason,
          cancel_actor = 'seller',
          cancelled_at = timezone('utc', now())
      where id = p_reservation_id;
    end if;
    if v_res.status in ('reserved', 'confirmed') then
      update public.vehicle_listings
      set status = 'active'
      where id = v_res.listing_id and status = 'reserved';
    end if;
    perform public.vehicle_rental_notify(
      v_res.customer_id,
      'Rezervasyon satıcı tarafından iptal edildi',
      'Satıcı kaynaklı iptalde müşteri cezalandırılmaz. İade varsa başlatılır.',
      'vehicle_rental_seller_cancelled'
    );
  end if;

  perform public.vehicle_rental_log_event(p_reservation_id, v_uid, p_action, v_res.status, v_next);
  return jsonb_build_object('ok', true, 'status', v_next, 'reservation_id', p_reservation_id);
end;
$$;

grant execute on function public.respond_vehicle_rental_reservation(uuid, text, text) to authenticated;

create or replace function public.cancel_vehicle_rental_reservation(
  p_reservation_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_pct numeric;
  v_amount numeric := 0;
  v_next text := 'cancelled';
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found or v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status not in (
    'pending_docs', 'pending_seller_review', 'pending_payment', 'confirmed', 'reserved'
  ) then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

  v_pct := public.vehicle_rental_refund_percent(
    v_res.cancellation_policy, v_res.pickup_at, 'customer'
  );
  if v_res.payment_status in ('paid', 'authorized') and v_pct > 0 then
    v_amount := round(v_res.total * v_pct / 100.0, 2);
    v_next := 'refund_pending';
    insert into public.vehicle_rental_refunds (booking_id, amount, reason, status)
    values (p_reservation_id, v_amount, coalesce(p_reason, 'customer_cancel'), 'refund_pending');
    update public.vehicle_reservations
    set status = v_next,
        payment_status = 'refund_pending',
        cancel_reason = p_reason,
        cancel_actor = 'customer',
        cancelled_at = timezone('utc', now()),
        refund_amount = v_amount,
        refund_reason = coalesce(p_reason, 'customer_cancel')
    where id = p_reservation_id;
    perform public.vehicle_rental_notify(
      v_res.customer_id, 'İade başlatıldı', 'İptal politikanıza göre iade kaydı açıldı.',
      'vehicle_rental_refund_started'
    );
  else
    update public.vehicle_reservations
    set status = 'cancelled',
        cancel_reason = p_reason,
        cancel_actor = 'customer',
        cancelled_at = timezone('utc', now()),
        refund_amount = 0
    where id = p_reservation_id;
  end if;

  if v_res.status in ('reserved', 'confirmed') then
    update public.vehicle_listings
    set status = 'active'
    where id = v_res.listing_id and status = 'reserved';
  end if;

  perform public.vehicle_rental_log_event(p_reservation_id, v_uid, 'customer_cancel', v_res.status, v_next);
  perform public.vehicle_rental_notify(
    v_res.seller_id, 'Müşteri iptali', 'Bir kiralama talebi müşteri tarafından iptal edildi.',
    'vehicle_rental_customer_cancelled'
  );
  return jsonb_build_object(
    'ok', true,
    'status', v_next,
    'refund_percent', v_pct,
    'refund_amount', v_amount
  );
end;
$$;

grant execute on function public.cancel_vehicle_rental_reservation(uuid, text) to authenticated;
