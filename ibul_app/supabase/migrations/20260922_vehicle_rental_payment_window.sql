-- Seller approve starts a 3-hour unpaid window. Pending payment still does not
-- lock inventory. Expire is server-side (pg_cron + RPC). No fake paid status.

alter table public.vehicle_reservations
  add column if not exists approved_at timestamptz,
  add column if not exists payment_due_at timestamptz,
  add column if not exists paid_at timestamptz;

drop function if exists public.vehicle_rental_notify(uuid, text, text, text);

create or replace function public.vehicle_rental_notify(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb default '{}'::jsonb
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
    jsonb_strip_nulls(
      jsonb_build_object('type', p_type) || coalesce(p_data, '{}'::jsonb)
    )
  );
exception when others then
  null;
end;
$$;

create or replace function public.vehicle_rental_listing_title(p_listing_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  select nullif(btrim(coalesce(l.ai_payload->>'title', '')), '')
    into v_title
  from public.vehicle_listings l
  where l.id = p_listing_id;

  if v_title is not null then
    return v_title;
  end if;

  if to_regclass('public.vehicle_specs') is not null then
    select nullif(btrim(concat_ws(' ', s.brand, s.model)), '')
      into v_title
    from public.vehicle_specs s
    where s.listing_id = p_listing_id;
  end if;

  return coalesce(nullif(btrim(coalesce(v_title, '')), ''), 'Araç');
end;
$$;

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
  v_now timestamptz := timezone('utc', now());
  v_due timestamptz;
  v_title text;
  v_due_clock text;
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

  v_title := public.vehicle_rental_listing_title(v_res.listing_id);

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
    v_due := v_now + interval '3 hours';
    v_due_clock := to_char(v_due at time zone 'Europe/Istanbul', 'HH24:MI');
    update public.vehicle_reservations
    set status = v_next,
        confirmed_at = v_now,
        approved_at = v_now,
        payment_due_at = v_due
    where id = p_reservation_id;
    perform public.vehicle_rental_notify(
      v_res.customer_id,
      'Kiralama talebiniz onaylandı',
      v_title || ' kiralama talebiniz onaylandı. Rezervasyonu kesinleştirmek için 3 saat içinde ödeme yapın. Ödeme son zamanı: ' || v_due_clock,
      'vehicle_rental_seller_approved',
      jsonb_build_object(
        'reservation_id', p_reservation_id,
        'rental_code', v_res.rental_code,
        'listing_title', v_title,
        'payment_due_at', v_due,
        'open_tab', 'rental'
      )
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
          cancelled_at = v_now,
          refund_amount = v_res.total,
          refund_reason = p_reason
      where id = p_reservation_id;
    else
      v_next := 'rejected';
      update public.vehicle_reservations
      set status = v_next,
          reject_reason = p_reason,
          cancelled_at = v_now
      where id = p_reservation_id;
    end if;
    perform public.vehicle_rental_notify(
      v_res.customer_id,
      'Kiralama talebiniz reddedildi',
      case when v_next = 'refund_pending' then 'İade başlatıldı.'
           else 'Ödeme alınmadığı için iade gerekmedi.' end,
      'vehicle_rental_seller_rejected',
      jsonb_build_object(
        'reservation_id', p_reservation_id,
        'rental_code', v_res.rental_code
      )
    );
  else
    if nullif(btrim(coalesce(p_reason, '')), '') is null then
      return jsonb_build_object('ok', false, 'error', 'reason_required');
    end if;
    if v_res.status not in ('pending_payment', 'confirmed', 'reserved') then
      return jsonb_build_object('ok', false, 'error', 'invalid_state');
    end if;
    if v_res.payment_status in ('paid', 'authorized') then
      insert into public.vehicle_rental_refunds (booking_id, amount, reason, status)
      values (p_reservation_id, v_res.total, p_reason, 'refund_pending');
      update public.vehicle_reservations
      set status = 'seller_cancelled',
          payment_status = 'refund_pending',
          cancel_reason = p_reason,
          cancel_actor = 'seller',
          cancelled_at = v_now,
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
          cancelled_at = v_now
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
      'vehicle_rental_seller_cancelled',
      jsonb_build_object(
        'reservation_id', p_reservation_id,
        'rental_code', v_res.rental_code
      )
    );
  end if;

  perform public.vehicle_rental_log_event(p_reservation_id, v_uid, p_action, v_res.status, v_next);
  return jsonb_build_object(
    'ok', true,
    'status', v_next,
    'reservation_id', p_reservation_id,
    'payment_due_at', v_due
  );
end;
$$;

create or replace function public.expire_unpaid_vehicle_rentals()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.vehicle_reservations%rowtype;
  v_count int := 0;
  v_title text;
  v_code text;
begin
  for r in
    select *
    from public.vehicle_reservations
    where status = 'pending_payment'
      and coalesce(payment_status, 'unpaid') not in ('paid', 'authorized')
      and payment_due_at is not null
      and payment_due_at <= timezone('utc', now())
    for update skip locked
  loop
    update public.vehicle_reservations
    set status = 'cancelled',
        cancel_reason = 'payment_window_expired',
        cancel_actor = 'system',
        cancelled_at = timezone('utc', now())
    where id = r.id
      and status = 'pending_payment'
      and coalesce(payment_status, 'unpaid') not in ('paid', 'authorized');
    if not found then
      continue;
    end if;
    v_count := v_count + 1;
    v_title := public.vehicle_rental_listing_title(r.listing_id);
    v_code := coalesce(r.rental_code, 'IBR-XXXX');
    perform public.vehicle_rental_notify(
      r.customer_id,
      'Kiralama talebi iptal edildi',
      'Ödeme süresi dolduğu için kiralama talebiniz iptal edildi.',
      'vehicle_rental_payment_expired',
      jsonb_build_object(
        'reservation_id', r.id,
        'rental_code', r.rental_code,
        'listing_title', v_title
      )
    );
    perform public.vehicle_rental_notify(
      r.seller_id,
      'Kiralama otomatik iptal',
      v_code || ' numaralı kiralama talebi ödeme yapılmadığı için otomatik iptal edildi.',
      'vehicle_rental_payment_expired',
      jsonb_build_object(
        'reservation_id', r.id,
        'rental_code', r.rental_code,
        'listing_title', v_title,
        'audience', 'seller'
      )
    );
    perform public.vehicle_rental_log_event(
      r.id, null, 'payment_window_expired', 'pending_payment', 'cancelled'
    );
  end loop;
  return jsonb_build_object('ok', true, 'expired', v_count);
end;
$$;

create or replace function public.confirm_vehicle_rental_payment(
  p_reservation_id uuid,
  p_order_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_docs int;
  v_code text;
  v_hash text;
  v_rental_code text;
  v_title text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if nullif(btrim(coalesce(p_order_id, '')), '') is null then
    return jsonb_build_object('ok', false, 'error', 'payment_provider_required');
  end if;

  select * into v_res
  from public.vehicle_reservations
  where id = p_reservation_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if v_res.status <> 'pending_payment' then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;
  if coalesce(v_res.payment_status, 'unpaid') in ('paid', 'authorized') then
    return jsonb_build_object(
      'ok', true,
      'status', v_res.status,
      'reservation_id', p_reservation_id,
      'rental_code', v_res.rental_code,
      'idempotent', true
    );
  end if;
  if v_res.payment_due_at is not null
     and v_res.payment_due_at <= timezone('utc', now()) then
    return jsonb_build_object('ok', false, 'error', 'payment_window_expired');
  end if;

  perform 1
  from public.vehicle_listings
  where id = v_res.listing_id
  for update;

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
  v_rental_code := coalesce(v_res.rental_code, public.vehicle_rental_make_code());
  v_title := public.vehicle_rental_listing_title(v_res.listing_id);

  update public.vehicle_reservations
  set status = 'reserved',
      payment_status = 'paid',
      order_id = p_order_id,
      handover_code_hash = v_hash,
      rental_code = v_rental_code,
      paid_at = timezone('utc', now())
  where id = p_reservation_id
    and status = 'pending_payment'
    and coalesce(payment_status, 'unpaid') not in ('paid', 'authorized');
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_state');
  end if;

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
    v_res.customer_id,
    'Ödemeniz alındı',
    'Ödemeniz alındı. Kiralamanız kesinleşti.',
    'vehicle_rental_payment_received',
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'rental_code', v_rental_code,
      'listing_title', v_title
    )
  );
  perform public.vehicle_rental_notify(
    v_res.seller_id,
    'Kiralama ödemesi tamamlandı',
    coalesce(v_rental_code, 'IBR') || ' numaralı ' || v_title || ' kiralamasının ödemesi tamamlandı.',
    'vehicle_rental_payment_complete',
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'rental_code', v_rental_code,
      'listing_title', v_title,
      'audience', 'seller'
    )
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

delete from public.vehicle_kyc_documents a
using public.vehicle_kyc_documents b
where a.reservation_id = b.reservation_id
  and a.doc_type = b.doc_type
  and a.ctid < b.ctid;

create unique index if not exists vehicle_kyc_one_doc_per_type_uidx
  on public.vehicle_kyc_documents (reservation_id, doc_type);

grant execute on function public.vehicle_rental_notify(uuid, text, text, text, jsonb)
  to authenticated;
grant execute on function public.vehicle_rental_listing_title(uuid) to authenticated;
grant execute on function public.respond_vehicle_rental_reservation(uuid, text, text)
  to authenticated;
grant execute on function public.expire_unpaid_vehicle_rentals()
  to authenticated, service_role;
grant execute on function public.confirm_vehicle_rental_payment(uuid, text)
  to authenticated;

do $$
begin
  perform cron.schedule(
    'expire-unpaid-vehicle-rentals',
    '*/5 * * * *',
    'select public.expire_unpaid_vehicle_rentals()'
  );
exception
  when duplicate_object then
    null;
  when undefined_function then
    raise notice 'pg_cron not installed; use expire_vehicle_rentals edge function';
  when others then
    raise notice 'pg_cron skip: %', sqlerrm;
end;
$$;
