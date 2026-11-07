-- Role and side-effect checks after the restaurant guard migrations.
-- Runs on the isolated schema. Not for production.

\set ON_ERROR_STOP on

do $$
declare
  v_now text;
  v_before text;
begin
  select definition into v_before
  from public.production_guard_baseline
  where name = 'guard_table_payment';
  v_now := pg_get_functiondef('public.guard_table_payment()'::regprocedure);
  if v_now is distinct from v_before then
    raise exception 'guard_table_payment body changed';
  end if;
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'trg_guard_table_payment'
      and tgrelid = 'public.table_payments'::regclass
      and not tgisinternal
      and tgenabled = 'O'
  ) then
    raise exception 'trg_guard_table_payment is no longer enabled';
  end if;
  raise notice 'PASS existing overpayment trigger preserved';
end
$$;

do $$
declare
  v_actor text;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_with_history(
    '11111111-1111-4111-8111-111111111111', 1
  );
  v_actor := current_setting('request.jwt.claim.sub', true);
  if v_actor is distinct from '11111111-1111-4111-8111-111111111111' then
    raise exception 'owner identity changed to %', v_actor;
  end if;
end
$$;

do $$
declare
  v_status text;
begin
  select status into v_status
  from public.table_orders
  where seller_id = '11111111-1111-4111-8111-111111111111'
    and table_number = 1;
  if v_status is distinct from 'archived' then
    raise exception 'owner close failed: %', v_status;
  end if;
  raise notice 'PASS owner close';
end
$$;

do $$
declare
  v_actor text;
  v_wrapper text;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.close_table_with_history(
    '11111111-1111-4111-8111-111111111111', 2
  );
  v_actor := current_setting('request.jwt.claim.sub', true);
  if v_actor is distinct from '22222222-2222-4222-8222-222222222222' then
    raise exception 'staff identity was replaced by %', v_actor;
  end if;
  v_wrapper := pg_get_functiondef(
    'public.close_table_with_history(uuid,integer,text,text,uuid,text,text)'::regprocedure
  );
  if position('request.jwt.claim.sub' in v_wrapper) > 0 then
    raise exception 'close wrapper impersonates the owner';
  end if;
  raise notice 'PASS manageOrders close keeps staff identity';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.close_table_orders(
      '11111111-1111-4111-8111-111111111111', 3
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'view-only staff closed a table';
  end if;
  raise notice 'PASS view-only cannot close';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.transfer_table_orders(
      '11111111-1111-4111-8111-111111111111', 4, 40
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'another business transferred a table';
  end if;
  raise notice 'PASS unauthorized business cannot transfer';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  begin
    perform public.close_table_orders(
      '11111111-1111-4111-8111-111111111111', 5
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'signed-out caller closed a table';
  end if;
  raise notice 'PASS signed-out caller cannot close';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  begin
    perform public.close_table_orders_impl(
      '11111111-1111-4111-8111-111111111111', 6
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'inner close function is still executable';
  end if;
  raise notice 'PASS inner close function stays revoked';
end
$$;

do $$
declare
  v_result jsonb;
  v_order_id uuid;
  v_job_id uuid;
  v_status text;
  v_order_status text;
  v_job_status text;
  v_user uuid;
  v_stock integer;
  v_cancelled integer;
  v_actor text;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-4111-8111-111111111111',
    30,
    '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
    '22222222-2222-4222-8222-222222222222',
    'Garson',
    'waiter_request:integration-anchor',
    'new_order',
    'table'
  );
  v_actor := current_setting('request.jwt.claim.sub', true);
  if v_actor is distinct from '22222222-2222-4222-8222-222222222222' then
    raise exception 'order send replaced staff identity with %', v_actor;
  end if;
  v_order_id := (v_result ->> 'order_id')::uuid;
  v_job_id := (v_result -> 'print_job_ids' ->> 0)::uuid;
  select status, order_status, user_id
    into v_status, v_order_status, v_user
  from public.orders
  where id = v_order_id;
  select status into v_job_status from public.print_jobs where id = v_job_id;
  select count(*) into v_stock from public.stock_events where order_id = v_order_id;
  select count(*) into v_cancelled
  from public.orders
  where id = v_order_id and status = 'cancelled';
  if v_status is distinct from 'print_anchor'
     or v_order_status is distinct from 'print_anchor'
     or v_job_status is distinct from 'pending'
     or v_user is distinct from '22222222-2222-4222-8222-222222222222'
     or v_stock <> 0
     or v_cancelled <> 0
     or coalesce((v_result ->> 'waiter_request_order_suppressed')::boolean, false) is not true
  then
    raise exception
      'print anchor unsafe status=% order_status=% job=% user=% stock=% cancelled=% result=%',
      v_status, v_order_status, v_job_status, v_user, v_stock, v_cancelled, v_result;
  end if;
  raise notice 'PASS waiter anchor is print_anchor and keeps the ticket';
end
$$;

do $$
declare
  v_result jsonb;
  v_status text;
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-4111-8111-111111111111',
    31,
    '[{"name":"cay","price":10,"quantity":1}]'::jsonb,
    '33333333-3333-4333-8333-333333333333',
    'Garson',
    'masa notu',
    'new_order',
    'table'
  );
  select status into v_status
  from public.orders
  where id = (v_result ->> 'order_id')::uuid;
  if v_status is distinct from 'confirmed' then
    raise exception 'direct send was suppressed: %', v_status;
  end if;
  raise notice 'PASS direct send stays confirmed';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-4111-8111-111111111111',
      32,
      '[{"name":"cay"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'view-only staff sent an order';
  end if;
  raise notice 'PASS view-only cannot send';
end
$$;

do $$
declare
  v_approved jsonb;
  v_bills integer;
  v_open integer;
  v_anchors integer;
  v_jobs integer;
  v_stock integer;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_approved := public.approve_waiter_order_request(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    null
  );
  select count(*) into v_bills
  from public.table_orders
  where table_number = 30 and status = 'sent';
  select count(*) into v_open
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1%'
    and status is distinct from 'print_anchor';
  select count(*) into v_anchors
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1%'
    and status = 'print_anchor';
  select count(*) into v_jobs
  from public.print_jobs pj
  join public.orders o on o.id = pj.order_id
  where o.notes like 'waiter_request:bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1%'
    and pj.status = 'pending';
  select count(*) into v_stock from public.stock_events;
  if v_bills <> 1 or v_open <> 0 or v_anchors <> 1 or v_jobs <> 1 or v_stock <> 0 then
    raise exception
      'approval single-order failed bills=% open=% anchors=% jobs=% stock=% result=%',
      v_bills, v_open, v_anchors, v_jobs, v_stock, v_approved;
  end if;
  raise notice 'PASS approval keeps one bill and one live ticket';
end
$$;

do $$
begin
  begin
    insert into public.table_payments (
      seller_id, table_number, session_key, amount, method
    ) values (
      '11111111-1111-4111-8111-111111111111',
      20,
      'direct-over',
      40.01,
      'cash'
    );
    raise exception 'direct overpay insert was stored';
  exception
    when others then
      if sqlerrm not like '%fazla ödeme%' then
        raise;
      end if;
  end;
  raise notice 'PASS direct insert still hits guard_table_payment';
end
$$;

do $$
declare
  v_message text := '';
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.record_table_payment(
      '11111111-1111-4111-8111-111111111111',
      20,
      'visit-20',
      40.01,
      'cash',
      'over-1',
      false,
      null,
      null,
      null,
      null
    );
  exception
    when others then
      get stacked diagnostics v_message = message_text;
  end;
  if v_message not like '%fazla ödeme%' then
    raise exception 'overpay was not rejected: %', v_message;
  end if;
  if exists (
    select 1 from public.table_payments
    where idempotency_key = 'over-1'
  ) then
    raise exception 'overpay row was stored';
  end if;
  raise notice 'PASS one-kurus overpay rejected';
end
$$;

do $$
declare
  v_row jsonb;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_row := public.record_table_payment(
    '11111111-1111-4111-8111-111111111111',
    20,
    'visit-20',
    40,
    'cash',
    'exact-1',
    false,
    null,
    '22222222-2222-4222-8222-222222222222',
    'Garson',
    null
  );
  if coalesce((v_row ->> 'replayed')::boolean, false) then
    raise exception 'first payment was treated as a replay';
  end if;
  begin
    perform public.record_table_payment(
      '11111111-1111-4111-8111-111111111111',
      20,
      'visit-20',
      0.01,
      'card',
      'over-2',
      false,
      null,
      null,
      null,
      null
    );
    raise exception 'second payment above the bill was stored';
  exception
    when others then
      if sqlerrm not like '%fazla ödeme%' then
        raise;
      end if;
  end;
  raise notice 'PASS manageOrders collects the open bill and not more';
end
$$;

insert into public.table_orders (seller_id, table_number, items, status)
values (
  '11111111-1111-4111-8111-111111111111',
  21,
  '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
  'sent'
);

do $$
declare
  v_message text := '';
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.record_table_payment(
      '11111111-1111-4111-8111-111111111111',
      21,
      'visit-20',
      1,
      'cash',
      'view-pay',
      false,
      null,
      null,
      null,
      null
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_message = message_text;
  end;
  if v_message not like '%ödeme yetkiniz yok%' then
    raise exception 'view-only payment was not denied: %', v_message;
  end if;
  raise notice 'PASS view-only cannot collect';
end
$$;

do $$
declare
  v_message text := '';
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  begin
    perform public.record_table_payment(
      '11111111-1111-4111-8111-111111111111',
      20,
      'visit-20',
      1,
      'cash',
      'anon-pay',
      false,
      null,
      null,
      null,
      null
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_message = message_text;
  end;
  if v_message not like '%Yetkisiz%' and v_message not like '%ödeme yetkiniz yok%' then
    raise exception 'anonymous payment was not denied: %', v_message;
  end if;
  raise notice 'PASS anonymous cannot collect';
end
$$;

select public.install_order_send_staff_wrapper();
select public.install_waiter_request_single_order_guard();
select public.install_table_operation_staff_wrappers();

do $$
declare
  v_result jsonb;
  v_job uuid;
  v_status text;
  v_leaf text;
  v_public text;
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-4111-8111-111111111111',
    33,
    '[{"name":"tatli","price":20,"quantity":1}]'::jsonb,
    '33333333-3333-4333-8333-333333333333',
    'Garson',
    'waiter_request:reinstall-anchor',
    'new_order',
    'table'
  );
  v_job := (v_result -> 'print_job_ids' ->> 0)::uuid;
  select o.status into v_status
  from public.orders o
  join public.print_jobs pj on pj.order_id = o.id
  where pj.id = v_job;
  v_leaf := pg_get_functiondef(
    'public.create_table_order_with_print_jobs_request_body(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
  );
  v_public := pg_get_functiondef(
    'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
  );
  if v_status is distinct from 'print_anchor' then
    raise exception 'reinstall changed the anchor status: %', v_status;
  end if;
  if position('TBL-LIVE' in v_leaf) = 0 then
    raise exception 'reinstall dropped the print body';
  end if;
  if position('request.jwt.claim.sub' in v_public) > 0 then
    raise exception 'public order wrapper impersonates after reinstall';
  end if;
  if not has_function_privilege(
       'authenticated',
       'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'authenticated lost the public print function';
  end if;
  if has_function_privilege(
       'authenticated',
       'public.create_table_order_with_print_jobs_request_body(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'authenticated can call the print body directly';
  end if;
  if has_function_privilege(
       'anon',
       'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'anon can call the public print function';
  end if;
  raise notice 'PASS reinstall keeps print id, body, and grants';
end
$$;
