-- =============================================================================
-- Migration: order_identity_idempotency
-- Date: 2026-11-07
--
-- Removes the legacy create_table_order_with_print_jobs impersonation of the
-- restaurant owner. auth.uid() stays the caller. Owner-only raises become
-- user_can_manage_restaurant_orders, which reads that uid. A session variable
-- cannot grant the owner's authority.
--
-- Adds a persistent idempotency key. The same key returns the first orders
-- and print_jobs result and does not insert another row. Waiter-request notes
-- use their request id as that key.
--
-- The rewrite uses POSIX regular expressions (\s, case-insensitive flags)
-- available since PostgreSQL 9. They do not use regexp_replace's occurrence
-- argument, which exists only from PostgreSQL 15. This file is for PostgreSQL
-- 14 through 17.
--
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

create table if not exists public.order_send_idempotency (
  restaurant_id uuid not null,
  idempotency_key text not null,
  result jsonb not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (restaurant_id, idempotency_key),
  constraint order_send_idempotency_key_len check (
    char_length(btrim(idempotency_key)) between 1 and 120
  )
);

revoke all on table public.order_send_idempotency from public;

do $$
declare
  v_fn regprocedure;
begin
  if to_regprocedure(
    'public.neutralize_order_identity_impersonation(regprocedure)'
  ) is null then
    return;
  end if;

  for v_fn in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (
        p.proname like 'create_table_order_with_print_jobs%'
        or p.proname like 'close_table%'
        or p.proname like 'transfer_table_orders%'
      )
  loop
    perform public.neutralize_order_identity_impersonation(v_fn);
  end loop;
end
$$;

create or replace function public.send_table_order_idempotent(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table',
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_result jsonb;
  v_stored jsonb;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and auth.uid() is null
  then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and not public.user_can_manage_restaurant_orders(p_restaurant_id)
  then
    raise exception 'Bu restoran için sipariş gönderme yetkiniz yok.'
      using errcode = '42501';
  end if;

  if v_key is not null and char_length(v_key) > 120 then
    raise exception 'Sipariş işlem kimliği geçersiz.';
  end if;

  if v_key is not null then
    perform pg_advisory_xact_lock(
      hashtext(p_restaurant_id::text),
      hashtext(v_key)
    );
    select result
      into v_stored
    from public.order_send_idempotency
    where restaurant_id = p_restaurant_id
      and idempotency_key = v_key;
    if found then
      return v_stored || jsonb_build_object('idempotent_replay', true);
    end if;
  end if;

  v_result := public.create_table_order_with_print_jobs(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type
  );

  if v_key is not null then
    insert into public.order_send_idempotency (
      restaurant_id, idempotency_key, result
    ) values (
      p_restaurant_id, v_key, v_result
    )
    on conflict (restaurant_id, idempotency_key) do nothing;

    if not found then
      select result
        into v_stored
      from public.order_send_idempotency
      where restaurant_id = p_restaurant_id
        and idempotency_key = v_key;
      return v_stored || jsonb_build_object('idempotent_replay', true);
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function public.send_table_order_idempotent(
  uuid, integer, jsonb, uuid, text, text, text, text, text
) from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.send_table_order_idempotent(
      uuid, integer, jsonb, uuid, text, text, text, text, text
    ) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.send_table_order_idempotent(
      uuid, integer, jsonb, uuid, text, text, text, text, text
    ) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.send_table_order_idempotent(
      uuid, integer, jsonb, uuid, text, text, text, text, text
    ) to service_role;
  end if;
end
$$;

comment on function public.send_table_order_idempotent(
  uuid, integer, jsonb, uuid, text, text, text, text, text
) is
  'Sends a table order for the real caller. The same idempotency key returns the first orders and print_jobs result.';

notify pgrst, 'reload schema';

commit;
