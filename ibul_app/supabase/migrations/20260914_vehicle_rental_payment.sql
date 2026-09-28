-- Honest capture: never mark paid without a real provider order id.

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
  v_rental_code text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if nullif(btrim(coalesce(p_order_id, '')), '') is null then
    return jsonb_build_object('ok', false, 'error', 'payment_provider_required');
  end if;

  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'pending_payment' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;
  if public.vehicle_rental_window_blocked(
    v_res.listing_id, v_res.pickup_at, v_res.return_at, v_res.id
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  select count(distinct d.doc_type) into v_docs
  from public.vehicle_kyc_documents d
  where d.reservation_id = p_reservation_id
    and d.doc_type in (
      'identity', 'identity_front', 'driver_license', 'driver_license_front'
    )
    and d.status in ('submitted', 'verified');
  if v_docs < 2 then
    return jsonb_build_object('ok', false, 'error', 'documents_required');
  end if;
  if v_res.terms_accepted_at is null then
    return jsonb_build_object('ok', false, 'error', 'terms_required');
  end if;

  v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  v_rental_code := public.vehicle_rental_make_code();

  update public.vehicle_reservations
  set status = 'reserved',
      payment_status = 'paid',
      order_id = p_order_id,
      handover_code_hash = v_hash,
      rental_code = v_rental_code
  where id = p_reservation_id;

  update public.vehicle_listings
  set status = 'reserved'
  where id = v_res.listing_id
    and status = 'active';

  insert into public.vehicle_analytics_events (listing_id, seller_id, event_type, actor_id)
  values (v_res.listing_id, v_res.seller_id, 'rental', v_uid);

  perform public.vehicle_rental_log_event(
    p_reservation_id, v_uid, 'payment_captured', 'pending_payment', 'reserved'
  );
  perform public.vehicle_rental_notify(
    v_res.customer_id, 'Ödeme alındı', 'Kiralama ödemeniz kaydedildi.',
    'vehicle_rental_payment_received'
  );
  perform public.vehicle_rental_notify(
    v_res.seller_id, 'Kiralama ödemesi tamam', 'Müşteri ödemesi kaydedildi.',
    'vehicle_rental_payment_complete'
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'reserved',
    'handover_code', v_code,
    'rental_code', v_rental_code,
    'reservation_id', p_reservation_id
  );
end;
$$;
