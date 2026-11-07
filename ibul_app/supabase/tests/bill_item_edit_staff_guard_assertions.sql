-- Assertions for bill item edits and waiter-request decisions.
-- Apply the prelude, then 20261107_bill_item_edit_staff_guard.sql, then this file.

create or replace function pg_temp.assume(
  p_user uuid,
  p_role text
)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), false);
  perform set_config('request.jwt.claim.role', p_role, false);
end;
$$;

create or replace function pg_temp.assert_items(
  p_name text,
  p_items jsonb
)
returns void
language plpgsql
as $$
declare
  v_items jsonb;
begin
  select items
  into v_items
  from public.table_orders
  where id = 'abababab-abab-abab-abab-abababababab';

  if v_items is distinct from p_items then
    raise exception 'ASSERT FAIL % expected % got %', p_name, p_items, v_items;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

create or replace function pg_temp.expect_edit_denied(
  p_name text,
  p_user uuid,
  p_role text,
  p_items jsonb
)
returns void
language plpgsql
as $$
declare
  v_before jsonb;
  v_sqlstate text;
begin
  select items
  into v_before
  from public.table_orders
  where id = 'abababab-abab-abab-abab-abababababab';

  perform pg_temp.assume(p_user, p_role);
  begin
    update public.table_orders
    set items = p_items
    where id = 'abababab-abab-abab-abab-abababababab';
    raise exception 'ASSERT FAIL % wrote items', p_name;
  exception
    when insufficient_privilege then
      get stacked diagnostics v_sqlstate = returned_sqlstate;
      if v_sqlstate <> '42501'
         or sqlerrm not like '%adisyon düzenleme yetkiniz yok%' then
        raise exception 'ASSERT FAIL % unexpected denial: %', p_name, sqlerrm;
      end if;
  end;

  perform pg_temp.assert_items(p_name, v_before);
end;
$$;

create or replace function pg_temp.insert_request(
  p_id uuid
)
returns void
language plpgsql
as $$
begin
  insert into public.waiter_order_requests (id, seller_id, status)
  values (p_id, '11111111-1111-1111-1111-111111111111', 'pending_waiter_approval');
end;
$$;

create or replace function pg_temp.assert_probe(
  p_name text,
  p_request uuid,
  p_actor uuid,
  p_action text
)
returns void
language plpgsql
as $$
declare
  v_actor uuid;
  v_action text;
  v_status text;
  v_resolved uuid;
begin
  select actor_id, action
  into v_actor, v_action
  from public.waiter_request_probe
  where request_id = p_request
  order by id desc
  limit 1;

  select status, resolved_by
  into v_status, v_resolved
  from public.waiter_order_requests
  where id = p_request;

  if v_actor is distinct from p_actor
     or v_action is distinct from p_action
     or v_resolved is distinct from p_actor then
    raise exception
      'ASSERT FAIL % expected actor % action % got actor % action % resolved % status %',
      p_name, p_actor, p_action, v_actor, v_action, v_resolved, v_status;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

create or replace function pg_temp.expect_decision_denied(
  p_name text,
  p_user uuid,
  p_role text,
  p_request uuid,
  p_approve boolean,
  p_fragment text default 'sipariş onaylama yetkiniz yok'
)
returns void
language plpgsql
as $$
declare
  v_status text;
  v_sqlstate text;
begin
  perform pg_temp.assume(p_user, p_role);
  begin
    if p_approve then
      perform public.approve_waiter_order_request(p_request, null);
    else
      perform public.reject_waiter_order_request(p_request, 'yok');
    end if;
    raise exception 'ASSERT FAIL % decided the request', p_name;
  exception
    when insufficient_privilege then
      get stacked diagnostics v_sqlstate = returned_sqlstate;
      if v_sqlstate <> '42501'
         or position(p_fragment in sqlerrm) = 0 then
        raise exception 'ASSERT FAIL % unexpected denial: %', p_name, sqlerrm;
      end if;
  end;

  select status
  into v_status
  from public.waiter_order_requests
  where id = p_request;

  if v_status is distinct from 'pending_waiter_approval' then
    raise exception 'ASSERT FAIL % changed status to %', p_name, v_status;
  end if;
  if exists (
    select 1 from public.waiter_request_probe where request_id = p_request
  ) then
    raise exception 'ASSERT FAIL % wrote a probe row', p_name;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

-- Item edits. The permissive authenticated policy would allow these writes
-- without the trigger.

select pg_temp.assume('11111111-1111-1111-1111-111111111111', 'authenticated');
update public.table_orders
set items = '[{"name":"corba","price":55,"quantity":1}]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'owner changes the line price',
  '[{"name":"corba","price":55,"quantity":1}]'::jsonb
);

select pg_temp.assume('22222222-2222-2222-2222-222222222222', 'authenticated');
update public.table_orders
set items = '[{"name":"corba","price":55,"quantity":2}]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'manageOrders edits the line',
  '[{"name":"corba","price":55,"quantity":2}]'::jsonb
);

select pg_temp.assume('33333333-3333-3333-3333-333333333333', 'authenticated');
update public.table_orders
set items = '[{"name":"izgara","price":90,"quantity":1}]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'fullAccess replaces the product',
  '[{"name":"izgara","price":90,"quantity":1}]'::jsonb
);

select pg_temp.assume('99999999-9999-9999-9999-999999999999', 'authenticated');
update public.table_orders
set items = '[]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'Tam Erişim removes every line',
  '[]'::jsonb
);

select pg_temp.assume('88888888-8888-8888-8888-888888888888', 'authenticated');
update public.table_orders
set items = '[{"name":"cay","price":15,"quantity":1}]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'phone manageOrders adds a line',
  '[{"name":"cay","price":15,"quantity":1}]'::jsonb
);

select pg_temp.expect_edit_denied(
  'viewOrders cannot change price',
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  '[{"name":"cay","price":1,"quantity":1}]'::jsonb
);

select pg_temp.expect_edit_denied(
  'empty permissions cannot remove a line',
  '55555555-5555-5555-5555-555555555555',
  'authenticated',
  '[]'::jsonb
);

select pg_temp.expect_edit_denied(
  'invited manageOrders cannot edit',
  '66666666-6666-6666-6666-666666666666',
  'authenticated',
  '[{"name":"cay","price":15,"quantity":2}]'::jsonb
);

select pg_temp.expect_edit_denied(
  'another business cannot edit',
  '77777777-7777-7777-7777-777777777777',
  'authenticated',
  '[{"name":"baska","price":10,"quantity":1}]'::jsonb
);

select pg_temp.expect_edit_denied(
  'signed-out caller cannot edit',
  null,
  'authenticated',
  '[{"name":"yok","price":1,"quantity":1}]'::jsonb
);

select pg_temp.assume('44444444-4444-4444-4444-444444444444', 'authenticated');
update public.table_orders
set status = 'preparing'
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'viewOrders can still update kitchen status',
  '[{"name":"cay","price":15,"quantity":1}]'::jsonb
);

do $$
declare
  v_status text;
begin
  select status
  into v_status
  from public.table_orders
  where id = 'abababab-abab-abab-abab-abababababab';
  if v_status is distinct from 'preparing' then
    raise exception 'ASSERT FAIL kitchen status stayed %', v_status;
  end if;
  raise notice 'PASS viewOrders kitchen status changed';
end
$$;

select pg_temp.assume('44444444-4444-4444-4444-444444444444', 'authenticated');
update public.table_orders
set items = items,
    status = 'ready'
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'identical items rewrite does not require a grant',
  '[{"name":"cay","price":15,"quantity":1}]'::jsonb
);

select pg_temp.assume(null, 'service_role');
update public.table_orders
set items = '[{"name":"servis","price":20,"quantity":1}]'::jsonb
where id = 'abababab-abab-abab-abab-abababababab';
select pg_temp.assert_items(
  'service role can edit items',
  '[{"name":"servis","price":20,"quantity":1}]'::jsonb
);

-- Waiter request decisions. The preserved body records the real caller.

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00001');
select pg_temp.assume('11111111-1111-1111-1111-111111111111', 'authenticated');
select public.approve_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00001',
  null
);
select pg_temp.assert_probe(
  'owner approves through preserved body',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00001',
  '11111111-1111-1111-1111-111111111111',
  'approve-body'
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00002');
select pg_temp.assume('22222222-2222-2222-2222-222222222222', 'authenticated');
select public.approve_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00002',
  '[{"name":"corba","quantity":2}]'::jsonb
);
select pg_temp.assert_probe(
  'manageOrders approves without impersonating the owner',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00002',
  '22222222-2222-2222-2222-222222222222',
  'approve-body'
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00003');
select pg_temp.assume('99999999-9999-9999-9999-999999999999', 'authenticated');
select public.reject_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00003',
  'iptal'
);
select pg_temp.assert_probe(
  'Tam Erişim rejects through preserved body',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00003',
  '99999999-9999-9999-9999-999999999999',
  'reject-body'
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00004');
select pg_temp.assume('88888888-8888-8888-8888-888888888888', 'authenticated');
select public.reject_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00004',
  null
);
select pg_temp.assert_probe(
  'phone manageOrders rejects',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00004',
  '88888888-8888-8888-8888-888888888888',
  'reject-body'
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00005');
select pg_temp.expect_decision_denied(
  'viewOrders cannot approve',
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00005',
  true
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00006');
select pg_temp.expect_decision_denied(
  'empty permissions cannot reject',
  '55555555-5555-5555-5555-555555555555',
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00006',
  false
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00007');
select pg_temp.expect_decision_denied(
  'invited staff cannot approve',
  '66666666-6666-6666-6666-666666666666',
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00007',
  true
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00008');
select pg_temp.expect_decision_denied(
  'another business cannot reject',
  '77777777-7777-7777-7777-777777777777',
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00008',
  false
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00009');
select pg_temp.expect_decision_denied(
  'signed-out caller cannot approve',
  null,
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00009',
  true,
  'Yetkisiz istek'
);

do $$
begin
  perform pg_temp.assume('11111111-1111-1111-1111-111111111111', 'authenticated');
  begin
    perform public.approve_waiter_order_request(
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      null
    );
    raise exception 'ASSERT FAIL missing request was approved';
  exception
    when invalid_parameter_value or sqlstate '22023' then
      if sqlerrm not like '%İstek bulunamadı%' then
        raise exception 'ASSERT FAIL missing request text: %', sqlerrm;
      end if;
  end;
  raise notice 'PASS missing request stays not found';
end
$$;

do $$
declare
  v_def text;
begin
  v_def := pg_get_functiondef(
    'public.approve_waiter_order_request_staff_body(uuid,jsonb)'::regprocedure
  );
  if position('user_can_access_restaurant' in v_def) = 0
     or position('user_can_manage_restaurant_orders' in v_def) > 0 then
    raise exception 'ASSERT FAIL approve body was rewritten';
  end if;
  v_def := pg_get_functiondef(
    'public.reject_waiter_order_request_staff_body(uuid,text)'::regprocedure
  );
  if position('user_can_access_restaurant' in v_def) = 0
     or position('user_can_manage_restaurant_orders' in v_def) > 0 then
    raise exception 'ASSERT FAIL reject body was rewritten';
  end if;
  v_def := pg_get_functiondef(
    'public.approve_waiter_order_request(uuid,jsonb)'::regprocedure
  );
  if position('request.jwt.claim.sub' in v_def) > 0
     or position('approve_waiter_order_request_staff_body' in v_def) = 0 then
    raise exception 'ASSERT FAIL approve wrapper impersonates the owner or dropped the body';
  end if;
  raise notice 'PASS bodies preserved and caller identity unchanged';
end
$$;

do $$
begin
  perform pg_temp.assume('22222222-2222-2222-2222-222222222222', 'authenticated');
  set local role authenticated;
  begin
    perform public.approve_waiter_order_request_staff_body(
      'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00001',
      null
    );
    raise exception 'ASSERT FAIL staff body was executable';
  exception
    when insufficient_privilege then
      if sqlerrm not like '%permission denied%' then
        raise exception 'ASSERT FAIL body denial text: %', sqlerrm;
      end if;
  end;
  reset role;
  raise notice 'PASS staff body execute revoked';
end
$$;

do $$
begin
  perform pg_temp.assume('22222222-2222-2222-2222-222222222222', 'authenticated');
  set local role anon;
  begin
    perform public.reject_waiter_order_request(
      'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00001',
      null
    );
    raise exception 'ASSERT FAIL anon rejected a request';
  exception
    when insufficient_privilege then
      null;
  end;
  reset role;
  raise notice 'PASS anon cannot execute the public reject function';
end
$$;

select public.install_bill_item_edit_staff_guards();

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00010');
select pg_temp.assume('33333333-3333-3333-3333-333333333333', 'authenticated');
select public.approve_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00010',
  null
);
select pg_temp.assert_probe(
  'second install still uses the preserved body',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00010',
  '33333333-3333-3333-3333-333333333333',
  'approve-body'
);

create or replace function public.approve_waiter_order_request(
  p_request_id uuid,
  p_edited_items jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
begin
  select seller_id into v_seller
  from public.waiter_order_requests
  where id = p_request_id;

  if not public.user_can_access_restaurant(v_seller) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  update public.waiter_order_requests
  set status = 'approved_converted',
      resolved_by = auth.uid()
  where id = p_request_id;

  insert into public.waiter_request_probe (request_id, actor_id, action, seller_id)
  values (p_request_id, auth.uid(), 'approve-replaced', v_seller);

  return jsonb_build_object('ok', true, 'source', 'approve-replaced');
end;
$$;

select public.install_bill_item_edit_staff_guards();

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00011');
select pg_temp.assume('22222222-2222-2222-2222-222222222222', 'authenticated');
select public.approve_waiter_order_request(
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00011',
  null
);
select pg_temp.assert_probe(
  'reinstall wraps a later approve body',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00011',
  '22222222-2222-2222-2222-222222222222',
  'approve-replaced'
);

select pg_temp.insert_request('b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00012');
select pg_temp.expect_decision_denied(
  'reinstall still blocks viewOrders',
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b00012',
  true
);
