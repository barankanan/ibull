-- =============================================================================
-- Migration: waiter_request_single_order
-- Date: 2026-11-07
--
-- Approving a waiter request inserts the bill into table_orders and, when the
-- request has kitchen items, calls create_table_order_with_print_jobs. That
-- RPC inserts a second orders row with status confirmed / order_status sent.
-- The garson board reads both tables. The merge hides the orders row only
-- while the table_orders bill still occupies the table. After the bill is
-- closed, the still-active orders row can open the table again.
--
-- This migration does not rewrite approve_waiter_order_request or the print
-- RPC body. It renames the current public print function to
-- create_table_order_with_print_jobs_request_body and calls it unchanged.
-- Only a new_order whose notes start with waiter_request: (the marker the
-- approval body already writes) is then marked print_anchor. That is not a
-- customer cancellation: stock return, cancellation reports, payment
-- reversal, and kitchen void triggers key off status cancelled and do not
-- run. The orders row is kept: print_jobs.order_id references it and
-- deleting the row would cascade the kitchen ticket. The print job id is
-- unchanged. Direct garson sends do not use that note prefix.
--
-- If the staff-permission wrapper is already the public function, this guard
-- is installed under create_table_order_with_print_jobs_staff_body. Reinstall
-- does not rename that wrapper onto the print body.
--
-- Existing rows are not updated. If a later migration replaces the public
-- function, run:
--   select public.install_waiter_request_single_order_guard();
--
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

create or replace function public.install_waiter_request_single_order_guard()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_signature constant text := 'uuid,integer,jsonb,uuid,text,text,text,text';
  v_public regprocedure;
  v_body regprocedure;
  v_prev regprocedure;
  v_public_def text;
  v_role text;
  v_guard_call constant text := ':= public.create_table_order_with_print_jobs_request_body(';
  v_staff_call constant text := 'create_table_order_with_print_jobs_staff_body(';
  v_guard_in_use boolean := false;
  v_staff regprocedure;
  v_staff_def text := '';
  v_target text := 'create_table_order_with_print_jobs';
  v_wrapper text;
begin
  v_public := to_regprocedure(
    format('public.create_table_order_with_print_jobs(%s)', v_signature)
  );
  v_body := to_regprocedure(
    format(
      'public.create_table_order_with_print_jobs_request_body(%s)',
      v_signature
    )
  );

  if v_public is null and v_body is null then
    raise exception
      'create_table_order_with_print_jobs bulunamadı; onay gövdesi yeniden yazılmadı.';
  end if;

  if v_public is not null then
    v_public_def := pg_get_functiondef(v_public);
  else
    v_public_def := '';
  end if;

  select exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'create_table_order_with_print_jobs%'
      and p.oid is distinct from v_public
      and position(v_guard_call in pg_get_functiondef(p.oid)) > 0
  )
  into v_guard_in_use;

  v_staff := to_regprocedure(
    format(
      'public.create_table_order_with_print_jobs_staff_body(%s)',
      v_signature
    )
  );
  if v_staff is not null then
    v_staff_def := pg_get_functiondef(v_staff);
  end if;

  -- A permission or outer wrapper calls staff_body. Put this guard on that
  -- name so the public function is not renamed onto the print leaf.
  if v_public is not null
     and position(v_staff_call in v_public_def) > 0
     and position(v_guard_call in v_public_def) = 0
  then
    v_target := 'create_table_order_with_print_jobs_staff_body';
    if v_staff is not null and position(v_guard_call in v_staff_def) = 0 then
      if v_body is not null then
        raise exception
          'Garson isteği tek kayıt sarmalayıcısı yazdırma gövdesini silmeden kurulamadı.';
      end if;
      execute format(
        'alter function public.create_table_order_with_print_jobs_staff_body(%s) rename to create_table_order_with_print_jobs_request_body',
        v_signature
      );
    end if;
  elsif v_public is not null
     and position(v_guard_call in v_public_def) = 0
     and v_guard_in_use then
    return;
  elsif v_public is null
     or position(v_guard_call in v_public_def) = 0
  then
    if v_body is not null then
      execute format(
        'alter function public.create_table_order_with_print_jobs_request_body(%s) rename to create_table_order_with_print_jobs_request_body_prev',
        v_signature
      );
    end if;

    if v_public is not null then
      execute format(
        'alter function public.create_table_order_with_print_jobs(%s) rename to create_table_order_with_print_jobs_request_body',
        v_signature
      );
    elsif v_body is not null then
      execute format(
        'alter function public.create_table_order_with_print_jobs_request_body_prev(%s) rename to create_table_order_with_print_jobs_request_body',
        v_signature
      );
    end if;

    v_prev := to_regprocedure(
      format(
        'public.create_table_order_with_print_jobs_request_body_prev(%s)',
        v_signature
      )
    );
    if v_prev is not null then
      execute format(
        'drop function public.create_table_order_with_print_jobs_request_body_prev(%s)',
        v_signature
      );
    end if;
  end if;

  v_body := to_regprocedure(
    format(
      'public.create_table_order_with_print_jobs_request_body(%s)',
      v_signature
    )
  );
  if v_body is null then
    raise exception 'Garson isteği tek kayıt sarmalayıcısı kurulamadı.';
  end if;

  v_wrapper := $waiter_request_wrapper$
    create or replace function public.waiter_request_guard_target(
      p_restaurant_id uuid,
      p_table_number integer,
      p_items jsonb,
      p_waiter_id uuid default null,
      p_waiter_name text default null,
      p_notes text default null,
      p_job_type text default 'new_order',
      p_order_type text default 'table'
    )
    returns jsonb
    language plpgsql
    security definer
    set search_path = public
    as $fn$
    declare
      v_result jsonb;
      v_order_id uuid;
      v_notes text := btrim(coalesce(p_notes, ''));
      v_job text := btrim(coalesce(p_job_type, ''));
      v_updated integer := 0;
      v_auto_key text;
      v_fingerprint text;
      v_stored_fingerprint text;
    begin
      v_auto_key := (regexp_match(
        v_notes,
        '^(waiter_request:[0-9a-fA-F-]{36})'
      ))[1];
      if v_auto_key is not null
         and to_regclass('public.order_send_idempotency') is not null
         and to_regprocedure(
           'public.order_send_request_fingerprint(integer,jsonb,text,text)'
         ) is not null
      then
        v_fingerprint := public.order_send_request_fingerprint(
          p_table_number, p_items, p_job_type, p_order_type
        );
        perform pg_advisory_xact_lock(
          hashtext(p_restaurant_id::text),
          hashtext(v_auto_key)
        );
        select result, request_fingerprint
          into v_result, v_stored_fingerprint
        from public.order_send_idempotency
        where restaurant_id = p_restaurant_id
          and idempotency_key = v_auto_key;
        if found then
          if v_stored_fingerprint is not null
             and v_stored_fingerprint is distinct from v_fingerprint
          then
            raise exception
              'Bu işlem kimliği farklı bir siparişle kullanılmış.'
              using errcode = 'P0001';
          end if;
          return v_result || jsonb_build_object('idempotent_replay', true);
        end if;
      end if;

      v_result := public.create_table_order_with_print_jobs_request_body(
        p_restaurant_id,
        p_table_number,
        p_items,
        p_waiter_id,
        p_waiter_name,
        p_notes,
        p_job_type,
        p_order_type
      );

      if v_job = 'new_order' and v_notes like 'waiter_request:%' then
        begin
          v_order_id := nullif(v_result ->> 'order_id', '')::uuid;
        exception
          when invalid_text_representation then
            v_order_id := null;
        end;

        if v_order_id is not null then
          update public.orders
          set
            status = 'print_anchor',
            order_status = 'print_anchor'
          where id = v_order_id
            and coalesce(notes, '') like 'waiter_request:%'
            and status is distinct from 'cancelled'
            and status is distinct from 'canceled';
          get diagnostics v_updated = row_count;
          if v_updated > 0 then
            v_result := v_result || jsonb_build_object(
              'waiter_request_order_suppressed', true
            );
          end if;
        end if;
      end if;

      if v_auto_key is not null
         and v_fingerprint is not null
         and to_regclass('public.order_send_idempotency') is not null
      then
        insert into public.order_send_idempotency (
          restaurant_id, idempotency_key, request_fingerprint, result
        ) values (
          p_restaurant_id, v_auto_key, v_fingerprint, v_result
        )
        on conflict (restaurant_id, idempotency_key) do nothing;
      end if;

      return v_result;
    end;
    $fn$;
  $waiter_request_wrapper$;
  execute replace(
    v_wrapper,
    'public.waiter_request_guard_target',
    format('public.%I', v_target)
  );

  execute format(
    'revoke all on function public.create_table_order_with_print_jobs_request_body(%s) from public',
    v_signature
  );
  execute format(
    'revoke all on function public.create_table_order_with_print_jobs(%s) from public',
    v_signature
  );
  if to_regprocedure(
    format(
      'public.create_table_order_with_print_jobs_staff_body(%s)',
      v_signature
    )
  ) is not null then
    execute format(
      'revoke all on function public.create_table_order_with_print_jobs_staff_body(%s) from public',
      v_signature
    );
  end if;

  foreach v_role in array array['anon', 'authenticated', 'service_role']
  loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format(
        'revoke all on function public.create_table_order_with_print_jobs_request_body(%s) from %I',
        v_signature,
        v_role
      );
      if to_regprocedure(
        format(
          'public.create_table_order_with_print_jobs_staff_body(%s)',
          v_signature
        )
      ) is not null then
        execute format(
          'revoke all on function public.create_table_order_with_print_jobs_staff_body(%s) from %I',
          v_signature,
          v_role
        );
      end if;
      execute format(
        'revoke all on function public.create_table_order_with_print_jobs(%s) from %I',
        v_signature,
        v_role
      );
      if v_role <> 'anon' then
        execute format(
          'grant execute on function public.create_table_order_with_print_jobs(%s) to %I',
          v_signature,
          v_role
        );
      end if;
    end if;
  end loop;
end;
$$;

revoke all on function public.install_waiter_request_single_order_guard() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.install_waiter_request_single_order_guard() from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function public.install_waiter_request_single_order_guard() from authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    revoke all on function public.install_waiter_request_single_order_guard() from service_role;
  end if;
end
$$;

select public.install_waiter_request_single_order_guard();

comment on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) is
  'Keeps the previous print body. A new_order noted waiter_request: stays one open table bill; the print anchor is print_anchor, not cancelled, and its kitchen ticket is kept.';

notify pgrst, 'reload schema';

commit;
