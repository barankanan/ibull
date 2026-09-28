-- Inventory lock only after a rental is actually confirmed.
-- Draft / pending seller / pending payment must not block the calendar.
-- Availability ranges are PII-free and readable by listing visitors.

create or replace function public.vehicle_rental_window_blocked(
  p_listing_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_ignore_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.vehicle_reservations r
    where r.listing_id = p_listing_id
      and (p_ignore_id is null or r.id <> p_ignore_id)
      and r.status in (
        'confirmed', 'reserved', 'active_rental', 'return_pending'
      )
      and tstzrange(r.pickup_at, r.return_at, '[)')
          && tstzrange(p_start, p_end, '[)')
  ) or exists (
    select 1
    from public.vehicle_rental_blocks b
    where b.listing_id = p_listing_id
      and tstzrange(b.start_at, b.end_at, '[)')
          && tstzrange(p_start, p_end, '[)')
  );
$$;

create or replace function public.get_vehicle_unavailable_ranges(
  p_listing_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'start_at', x.start_at,
          'end_at', x.end_at,
          'kind', x.kind
        )
        order by x.start_at
      )
      from (
        select r.pickup_at as start_at, r.return_at as end_at, 'reserved'::text as kind
        from public.vehicle_reservations r
        where r.listing_id = p_listing_id
          and r.status in (
            'confirmed', 'reserved', 'active_rental', 'return_pending'
          )
        union all
        select
          b.start_at,
          b.end_at,
          case
            when lower(coalesce(b.kind, '')) in ('maintenance', 'bakim', 'bakım')
              then 'maintenance'
            when lower(coalesce(b.kind, '')) in ('reserved')
              then 'reserved'
            else 'closed'
          end
        from public.vehicle_rental_blocks b
        where b.listing_id = p_listing_id
      ) x
    ),
    '[]'::jsonb
  );
end;
$$;

grant execute on function public.vehicle_rental_window_blocked(uuid, timestamptz, timestamptz, uuid)
  to authenticated;
grant execute on function public.get_vehicle_unavailable_ranges(uuid)
  to anon, authenticated;

alter table public.vehicle_reservations
  drop constraint if exists vehicle_reservations_no_overlap_excl;

do $$
declare
  v_overlap int := 0;
begin
  if to_regclass('public.vehicle_reservations') is null then
    return;
  end if;

  select count(*) into v_overlap
  from public.vehicle_reservations a
  join public.vehicle_reservations b
    on a.listing_id = b.listing_id
   and a.id < b.id
  where a.status in ('confirmed', 'reserved', 'active_rental', 'return_pending')
    and b.status in ('confirmed', 'reserved', 'active_rental', 'return_pending')
    and tstzrange(a.pickup_at, a.return_at, '[)')
        && tstzrange(b.pickup_at, b.return_at, '[)');

  if v_overlap > 0 then
    raise notice
      'vehicle_reservations_no_overlap_excl skipped: % confirmed overlaps',
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
      status in ('confirmed', 'reserved', 'active_rental', 'return_pending')
    )
  $sql$;
exception
  when lock_not_available then
    raise notice 'vehicle_reservations_no_overlap_excl skipped: lock timeout';
  when unique_violation then
    raise notice 'vehicle_reservations_no_overlap_excl skipped: overlap race';
  when others then
    raise notice 'vehicle_reservations_no_overlap_excl skipped: %', sqlerrm;
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

create or replace function public.rental_accepted_contract(p_reservation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select
    a.accepted_at,
    v.id as version_id,
    v.version,
    v.body_text,
    v.pdf_bucket,
    v.pdf_path,
    c.title,
    r.customer_id,
    r.seller_id
  into v_row
  from public.store_contract_acceptances a
  join public.store_contract_versions v on v.id = a.contract_version_id
  join public.store_contracts c on c.id = v.contract_id
  join public.vehicle_reservations r on r.id = a.reservation_id
  where a.reservation_id = p_reservation_id;
  if not found then
    return jsonb_build_object('ok', true, 'missing', true);
  end if;
  if v_row.customer_id <> v_uid
     and v_row.seller_id <> v_uid
     and not public.vehicle_is_admin() then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  return jsonb_build_object(
    'ok', true,
    'missing', false,
    'title', v_row.title,
    'version_id', v_row.version_id,
    'version', v_row.version,
    'body_text', v_row.body_text,
    'pdf_bucket', v_row.pdf_bucket,
    'pdf_path', v_row.pdf_path,
    'accepted_at', v_row.accepted_at
  );
end;
$$;

grant execute on function public.rental_accepted_contract(uuid) to authenticated;
grant execute on function public.confirm_vehicle_rental_payment(uuid, text) to authenticated;
