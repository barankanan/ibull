-- =============================================================================
-- Migration: order_send_staff_guard
-- Date: 2026-11-07
--
-- Sending a table order through create_table_order_with_print_jobs follows
-- the same staff rule as collection, close, and transfer: the owner, or an
-- active staff member with manageOrders or Tam Erişim (fullAccess).
-- View-only, empty permissions, invited staff, another business, and a
-- signed-out caller may not send.
--
-- The existing function body is not rewritten. It is renamed to
-- create_table_order_with_print_jobs_staff_body and called only after the
-- grant check. auth.uid() is left unchanged, so the body's own waiter
-- attribution stays as it is today. Direct execution of that body and of
-- create_table_order_with_print_jobs_impl is revoked.
--
-- If a later migration replaces the public function, run:
--   select public.install_order_send_staff_wrapper();
--
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

create or replace function public.normalize_staff_permission(p_token text)
returns text
language sql
immutable
as $$
  select case folded
    when 'fullaccess' then 'fullAccess'
    when 'tamerisim' then 'fullAccess'
    when 'tam_erisim' then 'fullAccess'
    when 'tam erisim' then 'fullAccess'
    when 'tam erişim' then 'fullAccess'
    when 'manageproducts' then 'manageProducts'
    when 'vieworders' then 'viewOrders'
    when 'manageorders' then 'manageOrders'
    when 'managecampaigns' then 'manageCampaigns'
    when 'viewfinance' then 'viewFinance'
    when 'managesupport' then 'manageSupport'
    when 'managestoreprofile' then 'manageStoreProfile'
    else null
  end
  from (
    select lower(translate(btrim(coalesce(p_token, '')), 'İIı', 'iii')) as folded
  ) token
  where folded <> '';
$$;

create or replace function public.user_can_manage_restaurant_orders(
  p_seller_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return true;
  end if;
  if auth.uid() is null or p_seller_id is null then
    return false;
  end if;
  if auth.uid() = p_seller_id then
    return true;
  end if;
  return exists (
    select 1
    from public.store_sub_admins sa
    join public.users u
      on u.id = auth.uid()
    where sa.store_id = p_seller_id
      and sa.status = 'active'
      and (
        (
          sa.email is not null
          and btrim(sa.email) <> ''
          and lower(btrim(coalesce(u.email, ''))) = lower(btrim(sa.email))
        )
        or (
          sa.phone is not null
          and btrim(sa.phone) <> ''
          and btrim(coalesce(u.phone, '')) = btrim(sa.phone)
        )
      )
      and exists (
        select 1
        from unnest(coalesce(sa.permissions, '{}'::text[])) as token(value)
        where public.normalize_staff_permission(token.value) in (
          'manageOrders',
          'fullAccess'
        )
      )
  );
end;
$$;

create or replace function public.neutralize_order_identity_impersonation(
  p_fn regprocedure
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_def text := pg_get_functiondef(p_fn);
  v_next text;
begin
  if v_def is null then
    return;
  end if;

  v_next := v_def;
  -- Remove only the impersonation statement. Whitespace and either
  -- restaurant or seller id are accepted. The pattern is the same on
  -- PostgreSQL 14 through 17; it does not use the occurrence argument
  -- added in PostgreSQL 15.
  v_next := regexp_replace(
    v_next,
    'perform\s+set_config\(\s*''request\.jwt\.claim\.sub''\s*,\s*p_(restaurant_id|seller_id)::text\s*,\s*true\s*\)\s*;\s*',
    '',
    'gi'
  );
  v_next := regexp_replace(
    v_next,
    'if\s+auth\.uid\(\)\s*(<>|is\s+distinct\s+from)\s*p_restaurant_id\s+then\s+raise\s',
    'if not public.user_can_manage_restaurant_orders(p_restaurant_id) then raise ',
    'gi'
  );
  v_next := regexp_replace(
    v_next,
    'if\s+p_restaurant_id\s*(<>|is\s+distinct\s+from)\s*auth\.uid\(\)\s+then\s+raise\s',
    'if not public.user_can_manage_restaurant_orders(p_restaurant_id) then raise ',
    'gi'
  );

  if v_next ~* 'set_config\(\s*''request\.jwt\.claim\.sub''' then
    raise exception
      'Yazdırma fonksiyonundaki kimlik taklidi tanınmadı: %', p_fn::text;
  end if;

  if v_next is distinct from v_def then
    execute v_next;
  end if;
end;
$$;

create or replace function public.install_order_send_staff_wrapper()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_signature constant text := 'uuid,integer,jsonb,uuid,text,text,text,text';
  v_public regprocedure;
  v_body regprocedure;
  v_impl regprocedure;
  v_prev regprocedure;
  v_public_def text;
  v_role text;
begin
  v_public := to_regprocedure(
    format('public.create_table_order_with_print_jobs(%s)', v_signature)
  );
  v_body := to_regprocedure(
    format('public.create_table_order_with_print_jobs_staff_body(%s)', v_signature)
  );

  if v_public is null and v_body is null then
    raise exception
      'create_table_order_with_print_jobs bulunamadı; sipariş gövdesi yeniden yazılmadı.';
  end if;

  if v_public is not null then
    v_public_def := pg_get_functiondef(v_public);
  else
    v_public_def := '';
  end if;

  if v_public is not null
     and position(
       'create_table_order_with_print_jobs_request_body(' in v_public_def
     ) > 0
     and v_body is not null
  then
    raise exception
      'Sipariş gönderme sarmalayıcısı yazdırma gövdesini silmeden kurulamadı.';
  end if;

  if v_public is null
     or position('create_table_order_with_print_jobs_staff_body' in v_public_def) = 0
  then
    if v_public is not null
       and position(
         'create_table_order_with_print_jobs_request_body(' in v_public_def
       ) > 0
       and v_body is null
    then
      execute format(
        'alter function public.create_table_order_with_print_jobs(%s) rename to create_table_order_with_print_jobs_staff_body',
        v_signature
      );
    else
      if v_body is not null then
        execute format(
          'alter function public.create_table_order_with_print_jobs_staff_body(%s) rename to create_table_order_with_print_jobs_staff_body_prev',
          v_signature
        );
      end if;

      if v_public is not null then
        execute format(
          'alter function public.create_table_order_with_print_jobs(%s) rename to create_table_order_with_print_jobs_staff_body',
          v_signature
        );
      elsif v_body is not null then
        execute format(
          'alter function public.create_table_order_with_print_jobs_staff_body_prev(%s) rename to create_table_order_with_print_jobs_staff_body',
          v_signature
        );
      end if;

      v_prev := to_regprocedure(
        format(
          'public.create_table_order_with_print_jobs_staff_body_prev(%s)',
          v_signature
        )
      );
      if v_prev is not null then
        execute format(
          'drop function public.create_table_order_with_print_jobs_staff_body_prev(%s)',
          v_signature
        );
      end if;
    end if;
  end if;

  v_body := to_regprocedure(
    format('public.create_table_order_with_print_jobs_staff_body(%s)', v_signature)
  );
  if v_body is null then
    raise exception 'Sipariş gönderme sarmalayıcısı kurulamadı.';
  end if;

  perform public.neutralize_order_identity_impersonation(v_body);
  v_impl := to_regprocedure(
    format('public.create_table_order_with_print_jobs_impl(%s)', v_signature)
  );
  if v_impl is not null then
    perform public.neutralize_order_identity_impersonation(v_impl);
  end if;
  if to_regprocedure(
    format(
      'public.create_table_order_with_print_jobs_request_body(%s)',
      v_signature
    )
  ) is not null then
    perform public.neutralize_order_identity_impersonation(
      to_regprocedure(
        format(
          'public.create_table_order_with_print_jobs_request_body(%s)',
          v_signature
        )
      )
    );
  end if;

  execute $order_send_wrapper$
    create or replace function public.create_table_order_with_print_jobs(
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
    as $body$
    begin
      if auth.uid() is null then
        raise exception 'Yetkisiz istek.' using errcode = '42501';
      end if;

      if not public.user_can_manage_restaurant_orders(p_restaurant_id) then
        raise exception 'Bu restoran için sipariş gönderme yetkiniz yok.'
          using errcode = '42501';
      end if;

      return public.create_table_order_with_print_jobs_staff_body(
        p_restaurant_id,
        p_table_number,
        p_items,
        p_waiter_id,
        p_waiter_name,
        p_notes,
        p_job_type,
        p_order_type
      );
    end;
    $body$;
  $order_send_wrapper$;

  execute format(
    'revoke all on function public.create_table_order_with_print_jobs_staff_body(%s) from public',
    v_signature
  );
  execute format(
    'revoke all on function public.create_table_order_with_print_jobs(%s) from public',
    v_signature
  );

  v_impl := to_regprocedure(
    format('public.create_table_order_with_print_jobs_impl(%s)', v_signature)
  );
  if v_impl is not null then
    execute format(
      'revoke all on function public.create_table_order_with_print_jobs_impl(%s) from public',
      v_signature
    );
  end if;

  foreach v_role in array array['anon', 'authenticated', 'service_role']
  loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format(
        'revoke all on function public.create_table_order_with_print_jobs_staff_body(%s) from %I',
        v_signature,
        v_role
      );
      if v_impl is not null then
        execute format(
          'revoke all on function public.create_table_order_with_print_jobs_impl(%s) from %I',
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

revoke all on function public.normalize_staff_permission(text) from public;
revoke all on function public.user_can_manage_restaurant_orders(uuid) from public;
revoke all on function public.neutralize_order_identity_impersonation(regprocedure) from public;
revoke all on function public.install_order_send_staff_wrapper() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.normalize_staff_permission(text) to authenticated;
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to service_role;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.normalize_staff_permission(text) from anon;
    revoke all on function public.user_can_manage_restaurant_orders(uuid) from anon;
    revoke all on function public.install_order_send_staff_wrapper() from anon;
  end if;
end
$$;

select public.install_order_send_staff_wrapper();

comment on function public.user_can_manage_restaurant_orders(uuid) is
  'Owner, or active staff with manageOrders / Tam Erişim, may send and manage restaurant orders.';

comment on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) is
  'Sends a table order only for the owner or active staff with manageOrders / Tam Erişim. The previous function body is preserved.';

notify pgrst, 'reload schema';

commit;
