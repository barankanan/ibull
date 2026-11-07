-- =============================================================================
-- Migration: bill_item_edit_staff_guard
-- Date: 2026-11-07
--
-- Editing, repricing, or removing a line on an open bill follows the same
-- staff rule as collection, close, transfer, and order send: the owner, or
-- an active staff member with manageOrders or Tam Erişim (fullAccess).
-- View-only, empty permissions, invited staff, another business, and a
-- signed-out caller may not change table_orders.items.
--
-- Kitchen status updates that do not change items stay on their existing
-- path. Row delete and table-number moves stay with the close/transfer
-- guard; this trigger does not replace that one.
--
-- approve_waiter_order_request and reject_waiter_order_request are not
-- rewritten. Each current body is renamed to *_staff_body and called only
-- after the same grant check. auth.uid() is left unchanged, so the body's
-- waiter attribution stays as it is today. Direct execution of the body is
-- revoked.
--
-- If a later migration replaces either public function, run:
--   select public.install_bill_item_edit_staff_guards();
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

create or replace function public.guard_table_order_item_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if new.items is not distinct from old.items then
    return new;
  end if;

  begin
    v_seller := nullif(btrim(coalesce(new.seller_id::text, '')), '')::uuid;
  exception
    when invalid_text_representation then
      v_seller := null;
  end;

  if not public.user_can_manage_restaurant_orders(v_seller) then
    raise exception 'Bu restoran için adisyon düzenleme yetkiniz yok.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.install_bill_item_edit_staff_guards()
returns void
language plpgsql
security definer
set search_path = public
as $install$
declare
  v_spec record;
  v_public regprocedure;
  v_body regprocedure;
  v_prev regprocedure;
  v_public_def text;
  v_role text;
begin
  for v_spec in
    select *
    from (
      values
        (
          'approve_waiter_order_request',
          'uuid,jsonb',
          'approve_waiter_order_request_staff_body'
        ),
        (
          'reject_waiter_order_request',
          'uuid,text',
          'reject_waiter_order_request_staff_body'
        )
    ) as spec(fn_name, fn_types, body_name)
  loop
    v_public := to_regprocedure(
      format('public.%I(%s)', v_spec.fn_name, v_spec.fn_types)
    );
    v_body := to_regprocedure(
      format('public.%I(%s)', v_spec.body_name, v_spec.fn_types)
    );

    if v_public is null and v_body is null then
      raise exception
        '% bulunamadı; gövde yeniden yazılmadı.', v_spec.fn_name;
    end if;

    if v_public is not null then
      v_public_def := pg_get_functiondef(v_public);
    else
      v_public_def := '';
    end if;

    if v_public is null
       or position(v_spec.body_name in v_public_def) = 0
    then
      if v_body is not null then
        execute format(
          'alter function public.%I(%s) rename to %I',
          v_spec.body_name,
          v_spec.fn_types,
          v_spec.body_name || '_prev'
        );
      end if;

      if v_public is not null then
        execute format(
          'alter function public.%I(%s) rename to %I',
          v_spec.fn_name,
          v_spec.fn_types,
          v_spec.body_name
        );
      elsif v_body is not null then
        execute format(
          'alter function public.%I(%s) rename to %I',
          v_spec.body_name || '_prev',
          v_spec.fn_types,
          v_spec.body_name
        );
      end if;

      v_prev := to_regprocedure(
        format('public.%I(%s)', v_spec.body_name || '_prev', v_spec.fn_types)
      );
      if v_prev is not null then
        execute format(
          'drop function public.%I(%s)',
          v_spec.body_name || '_prev',
          v_spec.fn_types
        );
      end if;
    end if;

    v_body := to_regprocedure(
      format('public.%I(%s)', v_spec.body_name, v_spec.fn_types)
    );
    if v_body is null then
      raise exception 'Adisyon yetki sarmalayıcısı kurulamadı: %', v_spec.fn_name;
    end if;
  end loop;

  execute $approve_wrapper$
    create or replace function public.approve_waiter_order_request(
      p_request_id uuid,
      p_edited_items jsonb default null
    )
    returns jsonb
    language plpgsql
    security definer
    set search_path = public
    as $body$
    declare
      v_seller uuid;
    begin
      if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
        if auth.uid() is null then
          raise exception 'Yetkisiz istek.' using errcode = '42501';
        end if;

        select seller_id
        into v_seller
        from public.waiter_order_requests
        where id = p_request_id;

        if v_seller is null then
          raise exception 'İstek bulunamadı.' using errcode = '22023';
        end if;

        if not public.user_can_manage_restaurant_orders(v_seller) then
          raise exception 'Bu restoran için sipariş onaylama yetkiniz yok.'
            using errcode = '42501';
        end if;
      end if;

      return public.approve_waiter_order_request_staff_body(
        p_request_id,
        p_edited_items
      );
    end;
    $body$;
  $approve_wrapper$;

  execute $reject_wrapper$
    create or replace function public.reject_waiter_order_request(
      p_request_id uuid,
      p_reason text default null
    )
    returns void
    language plpgsql
    security definer
    set search_path = public
    as $body$
    declare
      v_seller uuid;
    begin
      if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
        if auth.uid() is null then
          raise exception 'Yetkisiz istek.' using errcode = '42501';
        end if;

        select seller_id
        into v_seller
        from public.waiter_order_requests
        where id = p_request_id;

        if v_seller is null then
          raise exception 'İstek bulunamadı.' using errcode = '22023';
        end if;

        if not public.user_can_manage_restaurant_orders(v_seller) then
          raise exception 'Bu restoran için sipariş onaylama yetkiniz yok.'
            using errcode = '42501';
        end if;
      end if;

      perform public.reject_waiter_order_request_staff_body(
        p_request_id,
        p_reason
      );
    end;
    $body$;
  $reject_wrapper$;

  foreach v_role in array array['anon', 'authenticated', 'service_role']
  loop
    if not exists (select 1 from pg_roles where rolname = v_role) then
      continue;
    end if;

    execute format(
      'revoke all on function public.approve_waiter_order_request_staff_body(uuid, jsonb) from %I',
      v_role
    );
    execute format(
      'revoke all on function public.reject_waiter_order_request_staff_body(uuid, text) from %I',
      v_role
    );
    execute 'revoke all on function public.approve_waiter_order_request(uuid, jsonb) from ' || quote_ident(v_role);
    execute 'revoke all on function public.reject_waiter_order_request(uuid, text) from ' || quote_ident(v_role);

    if v_role <> 'anon' then
      execute format(
        'grant execute on function public.approve_waiter_order_request(uuid, jsonb) to %I',
        v_role
      );
      execute format(
        'grant execute on function public.reject_waiter_order_request(uuid, text) to %I',
        v_role
      );
    end if;
  end loop;

  revoke all on function public.approve_waiter_order_request_staff_body(uuid, jsonb) from public;
  revoke all on function public.reject_waiter_order_request_staff_body(uuid, text) from public;
  revoke all on function public.approve_waiter_order_request(uuid, jsonb) from public;
  revoke all on function public.reject_waiter_order_request(uuid, text) from public;

  if to_regclass('public.table_orders') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'table_orders'
         and column_name = 'seller_id'
     )
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'table_orders'
         and column_name = 'items'
     )
  then
    execute 'drop trigger if exists trg_guard_table_order_item_edit on public.table_orders';
    execute 'create trigger trg_guard_table_order_item_edit before update of items on public.table_orders for each row execute function public.guard_table_order_item_edit()';
  end if;
end;
$install$;

revoke all on function public.normalize_staff_permission(text) from public;
revoke all on function public.user_can_manage_restaurant_orders(uuid) from public;
revoke all on function public.guard_table_order_item_edit() from public;
revoke all on function public.install_bill_item_edit_staff_guards() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.normalize_staff_permission(text) to authenticated;
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to service_role;
    grant execute on function public.guard_table_order_item_edit() to service_role;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.normalize_staff_permission(text) from anon;
    revoke all on function public.user_can_manage_restaurant_orders(uuid) from anon;
    revoke all on function public.install_bill_item_edit_staff_guards() from anon;
  end if;
end
$$;

select public.install_bill_item_edit_staff_guards();

comment on function public.user_can_manage_restaurant_orders(uuid) is
  'Owner, or active staff with manageOrders / Tam Erişim, may edit bill items and decide waiter requests.';

comment on function public.guard_table_order_item_edit() is
  'Blocks table_orders item edits unless the caller may manage that restaurant''s orders.';

comment on function public.approve_waiter_order_request(uuid, jsonb) is
  'Approves a waiter request only for the owner or active staff with manageOrders / Tam Erişim. The previous function body is preserved.';

comment on function public.reject_waiter_order_request(uuid, text) is
  'Rejects a waiter request only for the owner or active staff with manageOrders / Tam Erişim. The previous function body is preserved.';

notify pgrst, 'reload schema';

commit;
