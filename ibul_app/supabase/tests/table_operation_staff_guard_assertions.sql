-- Assertions for table close and transfer staff guards.
-- Apply the prelude, then 20261107_table_operation_staff_guard.sql, then this file.

create or replace function pg_temp.assert_status(
  p_name text,
  p_table integer,
  p_expected text
)
returns void
language plpgsql
as $$
declare
  v_status text;
begin
  select status
  into v_status
  from public.table_orders
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = p_table;
  if v_status is distinct from p_expected then
    raise exception 'ASSERT FAIL % expected % got %', p_name, p_expected, v_status;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

create or replace function pg_temp.assert_table(
  p_name text,
  p_from integer,
  p_expected integer
)
returns void
language plpgsql
as $$
declare
  v_table integer;
begin
  select table_number
  into v_table
  from public.table_orders
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = p_expected
    and items::text like '%corba%';
  if v_table is null then
    raise exception 'ASSERT FAIL % row did not land on table %', p_name, p_expected;
  end if;
  if exists (
    select 1
    from public.table_orders
    where seller_id = '11111111-1111-1111-1111-111111111111'
      and table_number = p_from
  ) then
    raise exception 'ASSERT FAIL % source table % still occupied', p_name, p_from;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_with_history('11111111-1111-1111-1111-111111111111', 1);
end
$$;
select pg_temp.assert_status('owner closes with history', 1, 'archived');

do $$
declare
  v_actor text;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_with_history('11111111-1111-1111-1111-111111111111', 2);
  v_actor := current_setting('request.jwt.claim.sub', true);
  if v_actor is distinct from '22222222-2222-2222-2222-222222222222' then
    raise exception 'ASSERT FAIL staff identity became %', v_actor;
  end if;
end
$$;
select pg_temp.assert_status('manageOrders closes owner-only history rpc', 2, 'archived');

do $$
declare
  v_wrapper text;
begin
  v_wrapper := pg_get_functiondef(
    'public.close_table_with_history(uuid,integer,text,text,uuid,text,text)'::regprocedure
  );
  if position('request.jwt.claim.sub' in v_wrapper) > 0
     or position('ibul.verified_order_seller' in v_wrapper) > 0
  then
    raise exception 'ASSERT FAIL close wrapper still borrows owner authority';
  end if;
  raise notice 'PASS staff identity stays the caller';
end
$$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 3);
end
$$;
select pg_temp.assert_status('fullAccess closes loose rpc', 3, 'archived');

do $$
begin
  perform set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999999', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_orders_v2('11111111-1111-1111-1111-111111111111', 4);
end
$$;
select pg_temp.assert_status('Tam Erişim closes through v2', 4, 'archived');

do $$
begin
  perform set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888888', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.transfer_table_orders(
    '11111111-1111-1111-1111-111111111111',
    5,
    50
  );
end
$$;
select pg_temp.assert_table('phone manageOrders transfers', 5, 50);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 6);
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL viewOrders was allowed to close';
  end if;
end
$$;
select pg_temp.assert_status('viewOrders close stays open', 6, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.close_table_with_history('11111111-1111-1111-1111-111111111111', 7);
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL empty permissions were allowed to close';
  end if;
end
$$;
select pg_temp.assert_status('empty permissions stay open', 7, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.transfer_table_orders(
      '11111111-1111-1111-1111-111111111111',
      8,
      80
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL invited staff was allowed to transfer';
  end if;
end
$$;
select pg_temp.assert_status('invited staff transfer stays', 8, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '77777777-7777-7777-7777-777777777777', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 9);
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL another business was allowed to close';
  end if;
end
$$;
select pg_temp.assert_status('other business stays open', 9, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  begin
    perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 10);
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL signed-out caller was allowed to close';
  end if;
end
$$;
select pg_temp.assert_status('signed-out close stays open', 10, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    update public.table_orders
    set status = 'archived'
    where seller_id = '11111111-1111-1111-1111-111111111111'
      and table_number = 11;
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL viewOrders direct archive was allowed';
  end if;
end
$$;
select pg_temp.assert_status('direct archive blocked for viewOrders', 11, 'sent');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    update public.table_orders
    set table_number = 110
    where seller_id = '11111111-1111-1111-1111-111111111111'
      and table_number = 12;
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL viewOrders direct transfer was allowed';
  end if;
end
$$;
select pg_temp.assert_status('direct transfer blocked for viewOrders', 12, 'sent');

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  update public.table_orders
  set items = '[{"name":"cay","price":10,"quantity":1}]'::jsonb
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = 13;
end
$$;
do $$
declare
  v_name text;
begin
  select items->0->>'name'
  into v_name
  from public.table_orders
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = 13;
  if v_name is distinct from 'cay' then
    raise exception 'ASSERT FAIL item edit was blocked: %', v_name;
  end if;
  raise notice 'PASS item edit is outside the close/transfer guard';
end
$$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  update public.table_orders
  set table_number = 140
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = 14;
end
$$;
select pg_temp.assert_table('manageOrders direct transfer', 14, 140);

do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 15);
end
$$;
select pg_temp.assert_status('service role close remains available', 15, 'archived');

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  begin
    perform public.close_table_orders_impl(
      '11111111-1111-1111-1111-111111111111',
      16
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL inner close function was still executable';
  end if;
end
$$;
select pg_temp.assert_status('inner close function stays revoked', 16, 'sent');

select public.install_table_operation_staff_wrappers();

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_orders('11111111-1111-1111-1111-111111111111', 17);
end
$$;
select pg_temp.assert_status('installer can run twice', 17, 'archived');

create or replace function public.transfer_table_orders_v2(
  p_seller_id uuid,
  p_from_table integer,
  p_to_table integer,
  p_transfer_type text default 'full',
  p_item_ids jsonb default '[]'::jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if auth.uid() is distinct from p_seller_id
     and not exists (
       select 1
       from public.store_sub_admins sa
       join public.users u on u.id = auth.uid()
       where sa.store_id = p_seller_id
         and sa.status = 'active'
         and (
           lower(btrim(coalesce(u.email, ''))) = lower(btrim(coalesce(sa.email, '')))
           or btrim(coalesce(u.phone, '')) = btrim(coalesce(sa.phone, ''))
         )
     )
  then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;
  update public.table_orders
  set table_number = p_to_table
  where seller_id = p_seller_id
    and table_number = p_from_table;
  return jsonb_build_object('success', true);
end;
$$;

select public.install_table_operation_staff_wrappers();

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.transfer_table_orders_v2(
      '11111111-1111-1111-1111-111111111111',
      18,
      180
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL viewOrders used transfer v2';
  end if;
end
$$;
select pg_temp.assert_status('v2 viewOrders transfer stays', 18, 'sent');

do $$
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.transfer_table_orders_v2(
    '11111111-1111-1111-1111-111111111111',
    19,
    190
  );
end
$$;
select pg_temp.assert_table('v2 fullAccess transfer', 19, 190);

do $$
declare
  v_denied boolean := false;
  v_status text;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'ibul.verified_order_seller',
    '11111111-1111-1111-1111-111111111111',
    true
  );
  begin
    perform public.close_table_with_history(
      '11111111-1111-1111-1111-111111111111',
      20
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL forged verified_order_seller closed a table';
  end if;
  select status into v_status
  from public.table_orders
  where seller_id = '11111111-1111-1111-1111-111111111111'
    and table_number = 20;
  if v_status is distinct from 'sent' then
    raise exception 'ASSERT FAIL forged grant changed table 20: %', v_status;
  end if;

  execute 'grant execute on function public.close_table_with_history_impl(uuid,integer,text,text,uuid,text,text) to authenticated';
  v_denied := false;
  begin
    execute 'set local role authenticated';
    perform public.close_table_with_history_impl(
      '11111111-1111-1111-1111-111111111111',
      20
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  execute 'revoke all on function public.close_table_with_history_impl(uuid,integer,text,text,uuid,text,text) from authenticated';
  if not v_denied then
    raise exception 'ASSERT FAIL inner close accepted a forged seller grant';
  end if;
  raise notice 'PASS forged verified_order_seller does not grant owner authority';
end
$$;
