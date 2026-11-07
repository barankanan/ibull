-- =============================================================================
-- Migration: table_operation_staff_guard
-- Date: 2026-11-07
--
-- Table close and table transfer follow the same staff rule as collection:
-- the owner, or an active staff member with manageOrders or Tam Erişim
-- (fullAccess), may operate. View-only, empty permissions, invited staff,
-- another business, and a signed-out caller may not.
--
-- Existing function bodies stay in place. This migration wraps them, revokes
-- direct execution of the inner body, and blocks a direct close or transfer
-- write on table_orders. Run install_table_operation_staff_wrappers() again
-- after transfer_table_orders_v2 is created so that function is wrapped too.
--
-- The wrapper does not copy the seller id into request.jwt.claim.sub and does
-- not trust a session variable. auth.uid() stays the caller. Legacy owner-only
-- predicates are rewritten to user_can_manage_restaurant_orders, which reads
-- that same uid. A caller who sets ibul.verified_order_seller still fails the
-- real grant check. Direct execution of the inner body is revoked.
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

create or replace function public.guard_table_order_close_or_transfer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
  v_seller_text text;
  v_next_status text;
  v_previous_status text;
  v_operates boolean := false;
begin
  if tg_op = 'DELETE' then
    v_operates := true;
    v_seller_text := old.seller_id::text;
  elsif tg_op = 'UPDATE' then
    v_next_status := lower(btrim(coalesce(new.status, '')));
    v_previous_status := lower(btrim(coalesce(old.status, '')));
    v_operates := new.table_number is distinct from old.table_number
      or (
        v_next_status is distinct from v_previous_status
        and v_next_status in (
          'archived',
          'closed',
          'paid',
          'cancelled',
          'canceled',
          'completed',
          'complete',
          'payment_completed'
        )
      );
    v_seller_text := new.seller_id::text;
  end if;

  if not v_operates then
    return new;
  end if;

  begin
    v_seller := nullif(btrim(coalesce(v_seller_text, '')), '')::uuid;
  exception
    when invalid_text_representation then
      v_seller := null;
  end;

  if not public.user_can_manage_restaurant_orders(v_seller) then
    raise exception 'Bu restoran için masa işlemi yetkiniz yok.'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.rewrite_legacy_owner_order_guard(
  p_impl regprocedure
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_def text := pg_get_functiondef(p_impl);
  v_next text;
  v_begin text;
  v_pos integer;
begin
  if v_def is null or position('user_can_manage_restaurant_orders(p_seller_id)' in v_def) > 0 then
    return;
  end if;

  v_next := v_def;
  v_next := regexp_replace(
    v_next,
    'if\s+p_seller_id\s+is\s+distinct\s+from\s+auth\.uid\(\)\s+then',
    'if not public.user_can_manage_restaurant_orders(p_seller_id) then',
    'gi'
  );
  v_next := regexp_replace(
    v_next,
    'if\s+p_seller_id\s*<>\s*auth\.uid\(\)\s+then',
    'if not public.user_can_manage_restaurant_orders(p_seller_id) then',
    'gi'
  );
  v_next := regexp_replace(
    v_next,
    'if\s+auth\.uid\(\)\s*<>\s*p_seller_id\s+then',
    'if not public.user_can_manage_restaurant_orders(p_seller_id) then',
    'gi'
  );
  v_next := regexp_replace(
    v_next,
    'if\s+auth\.uid\(\)\s+is\s+distinct\s+from\s+p_seller_id\s+then',
    'if not public.user_can_manage_restaurant_orders(p_seller_id) then',
    'gi'
  );

  -- Loose membership checks (view-only, empty grant) stay in the body.
  -- A real manageOrders gate is inserted once, after the first BEGIN, so a
  -- forged session variable cannot widen them. Only the first BEGIN is used;
  -- this does not depend on regexp_replace's occurrence argument.
  if position('user_can_manage_restaurant_orders(p_seller_id)' in v_next) = 0
     and position('p_seller_id' in v_next) > 0
  then
    v_begin := substring(v_next from '[Bb][Ee][Gg][Ii][Nn]');
    if v_begin is not null then
      v_pos := position(v_begin in v_next);
      v_next := overlay(
        v_next
        placing v_begin || E'\n  if not public.user_can_manage_restaurant_orders(p_seller_id) then\n    raise exception ''Bu restoran için masa işlemi yetkiniz yok.'' using errcode = ''42501'';\n  end if;'
        from v_pos
        for char_length(v_begin)
      );
    end if;
  end if;

  v_next := regexp_replace(
    v_next,
    'auth\.uid\(\)\s+is\s+distinct\s+from\s+p_seller_id',
    'not public.user_can_manage_restaurant_orders(p_seller_id)',
    'gi'
  );

  if v_next is distinct from v_def then
    execute v_next;
  end if;
end;
$$;

create or replace function public.install_table_operation_staff_wrappers()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_spec record;
  v_public regprocedure;
  v_impl regprocedure;
  v_impl_name text;
  v_result text;
  v_statement text;
  v_role text;
begin
  for v_spec in
    select *
    from (
      values
        (
          'close_table_orders',
          'uuid,integer,text,text,uuid,text,text',
          'p_seller_id uuid, p_table_number integer, p_payment_method text default ''cash'', p_payment_note text default null, p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null',
          'p_seller_id, p_table_number, p_payment_method, p_payment_note, p_waiter_id, p_waiter_name, p_session_key'
        ),
        (
          'close_table_orders_v2',
          'uuid,integer,text,text,uuid,text,text',
          'p_seller_id uuid, p_table_number integer, p_payment_method text default ''cash'', p_payment_note text default null, p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null',
          'p_seller_id, p_table_number, p_payment_method, p_payment_note, p_waiter_id, p_waiter_name, p_session_key'
        ),
        (
          'close_table_with_history',
          'uuid,integer,text,text,uuid,text,text',
          'p_seller_id uuid, p_table_number integer, p_payment_method text default ''cash'', p_payment_note text default null, p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null',
          'p_seller_id, p_table_number, p_payment_method, p_payment_note, p_waiter_id, p_waiter_name, p_session_key'
        ),
        (
          'transfer_table_orders',
          'uuid,integer,integer,text,jsonb,uuid,text,text',
          'p_seller_id uuid, p_from_table integer, p_to_table integer, p_transfer_type text default ''full'', p_item_ids jsonb default ''[]''::jsonb, p_waiter_id uuid default null, p_waiter_name text default null, p_note text default null',
          'p_seller_id, p_from_table, p_to_table, p_transfer_type, p_item_ids, p_waiter_id, p_waiter_name, p_note'
        ),
        (
          'transfer_table_orders_v2',
          'uuid,integer,integer,text,jsonb,uuid,text,text',
          'p_seller_id uuid, p_from_table integer, p_to_table integer, p_transfer_type text default ''full'', p_item_ids jsonb default ''[]''::jsonb, p_waiter_id uuid default null, p_waiter_name text default null, p_note text default null',
          'p_seller_id, p_from_table, p_to_table, p_transfer_type, p_item_ids, p_waiter_id, p_waiter_name, p_note'
        )
    ) as spec(fn_name, fn_types, fn_args, fn_call)
  loop
    v_impl_name := v_spec.fn_name || '_impl';
    v_public := to_regprocedure(format('public.%I(%s)', v_spec.fn_name, v_spec.fn_types));
    v_impl := to_regprocedure(format('public.%I(%s)', v_impl_name, v_spec.fn_types));

    if v_impl is null then
      if v_public is null then
        continue;
      end if;
      execute format(
        'alter function public.%I(%s) rename to %I',
        v_spec.fn_name,
        v_spec.fn_types,
        v_impl_name
      );
      v_impl := to_regprocedure(format('public.%I(%s)', v_impl_name, v_spec.fn_types));
    end if;

    if v_impl is null then
      raise exception 'Masa işlem sarmalayıcısı kurulamadı: %', v_spec.fn_name;
    end if;

    perform public.rewrite_legacy_owner_order_guard(v_impl);
    v_impl := to_regprocedure(
      format('public.%I(%s)', v_impl_name, v_spec.fn_types)
    );

    select pg_get_function_result(v_impl)
    into v_result;

    if lower(v_result) = 'void' then
      v_statement := format(
        'create or replace function public.%I(%s) returns void language plpgsql security definer set search_path = public as $body$ begin if coalesce(current_setting(''request.jwt.claim.role'', true), '''') <> ''service_role'' and not public.user_can_manage_restaurant_orders(p_seller_id) then raise exception ''Bu restoran için masa işlemi yetkiniz yok.'' using errcode = ''42501''; end if; perform public.%I(%s); end $body$;',
        v_spec.fn_name,
        v_spec.fn_args,
        v_impl_name,
        v_spec.fn_call
      );
    else
      v_statement := format(
        'create or replace function public.%I(%s) returns %s language plpgsql security definer set search_path = public as $body$ begin if coalesce(current_setting(''request.jwt.claim.role'', true), '''') <> ''service_role'' and not public.user_can_manage_restaurant_orders(p_seller_id) then raise exception ''Bu restoran için masa işlemi yetkiniz yok.'' using errcode = ''42501''; end if; return public.%I(%s); end $body$;',
        v_spec.fn_name,
        v_spec.fn_args,
        v_result,
        v_impl_name,
        v_spec.fn_call
      );
    end if;
    execute v_statement;

    execute format(
      'revoke all on function public.%I(%s) from public',
      v_impl_name,
      v_spec.fn_types
    );
    execute format(
      'revoke all on function public.%I(%s) from public',
      v_spec.fn_name,
      v_spec.fn_types
    );

    foreach v_role in array array['anon', 'authenticated', 'service_role']
    loop
      if exists (select 1 from pg_roles where rolname = v_role) then
        execute format(
          'revoke all on function public.%I(%s) from %I',
          v_impl_name,
          v_spec.fn_types,
          v_role
        );
        if v_role <> 'anon' then
          execute format(
            'grant execute on function public.%I(%s) to %I',
            v_spec.fn_name,
            v_spec.fn_types,
            v_role
          );
        end if;
      end if;
    end loop;
  end loop;

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
         and column_name = 'table_number'
     )
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'table_orders'
         and column_name = 'status'
     )
  then
    execute 'drop trigger if exists trg_guard_table_order_close_or_transfer on public.table_orders';
    execute 'create trigger trg_guard_table_order_close_or_transfer before update or delete on public.table_orders for each row execute function public.guard_table_order_close_or_transfer()';
  end if;
end;
$$;

revoke all on function public.normalize_staff_permission(text) from public;
revoke all on function public.user_can_manage_restaurant_orders(uuid) from public;
revoke all on function public.guard_table_order_close_or_transfer() from public;
revoke all on function public.rewrite_legacy_owner_order_guard(regprocedure) from public;
revoke all on function public.install_table_operation_staff_wrappers() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.normalize_staff_permission(text) to authenticated;
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.user_can_manage_restaurant_orders(uuid) to service_role;
  end if;
end
$$;

select public.install_table_operation_staff_wrappers();

comment on function public.user_can_manage_restaurant_orders(uuid) is
  'Owner, or active staff with manageOrders / Tam Erişim, may close or transfer a table.';

notify pgrst, 'reload schema';

commit;
