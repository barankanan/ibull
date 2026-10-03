-- Live hotfix: function gen_random_bytes(integer) does not exist (42883)
-- during vehicle rental submit / rental_code generation.
-- SQL Editor'da bunun TAMAMINI Run edin.

create extension if not exists pgcrypto;

create or replace function public.vehicle_rental_make_code()
returns text
language plpgsql
set search_path = public, extensions, pg_catalog
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

create or replace function public.vehicle_rental_fill_code()
returns trigger
language plpgsql
set search_path = public, extensions, pg_catalog
as $$
begin
  if NEW.status in (
       'pending_seller_review', 'pending_payment', 'confirmed', 'reserved'
     )
     and NEW.rental_code is null then
    NEW.rental_code := public.vehicle_rental_make_code();
  end if;
  return NEW;
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
  set terms_accepted_at = timezone('utc', now())
  where id = p_reservation_id
    and customer_id = v_uid
    and status in ('pending_docs', 'pending_seller_review');
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
