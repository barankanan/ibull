-- Identity, print_anchor, idempotency, and combined operation checks.
-- Runs after 20261107_order_identity_idempotency.sql. Not for production.

\set ON_ERROR_STOP on

do $$
declare
  v_fn regprocedure;
  v_def text;
begin
  for v_fn in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'create_table_order_with_print_jobs%'
  loop
    v_def := pg_get_functiondef(v_fn);
    if v_def ~* 'set_config\(\s*''request\.jwt\.claim\.sub''' then
      raise exception 'print function still impersonates: %', v_fn::text;
    end if;
  end loop;
  raise notice 'PASS print functions do not impersonate the owner';
end
$$;

do $$
declare
  v_actor text;
  v_user uuid;
  v_result jsonb;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'ibul.verified_order_seller',
    '11111111-1111-4111-8111-111111111111',
    true
  );
  v_result := public.send_table_order_idempotent(
    '11111111-1111-4111-8111-111111111111',
    40,
    '[{"name":"pilav","price":20,"quantity":1}]'::jsonb,
    '22222222-2222-4222-8222-222222222222',
    'Garson',
    'identity-check',
    'new_order',
    'table',
    'identity-key-1'
  );
  v_actor := current_setting('request.jwt.claim.sub', true);
  select user_id into v_user
  from public.orders
  where id = (v_result ->> 'order_id')::uuid;
  if v_actor is distinct from '22222222-2222-4222-8222-222222222222'
     or v_user is distinct from '22222222-2222-4222-8222-222222222222'
  then
    raise exception 'print send changed identity actor=% user=%', v_actor, v_user;
  end if;
  raise notice 'PASS print send keeps the staff uid';
end
$$;

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'ibul.verified_order_seller',
    '11111111-1111-4111-8111-111111111111',
    true
  );
  begin
    perform public.send_table_order_idempotent(
      '11111111-1111-4111-8111-111111111111',
      41,
      '[{"name":"pilav","price":20,"quantity":1}]'::jsonb,
      null,
      null,
      'forged',
      'new_order',
      'table',
      'forged-key'
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'forged seller grant sent an order';
  end if;
  if exists (
    select 1 from public.order_send_idempotency where idempotency_key = 'forged-key'
  ) then
    raise exception 'forged grant stored an idempotency row';
  end if;
  raise notice 'PASS forged verified_order_seller cannot send';
end
$$;

do $$
declare
  v_first jsonb;
  v_second jsonb;
  v_orders integer;
  v_jobs integer;
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_first := public.send_table_order_idempotent(
    '11111111-1111-4111-8111-111111111111',
    42,
    '[{"name":"salata","price":15,"quantity":1}]'::jsonb,
    '33333333-3333-4333-8333-333333333333',
    'Garson',
    'ilk',
    'new_order',
    'table',
    'same-send'
  );
  v_second := public.send_table_order_idempotent(
    '11111111-1111-4111-8111-111111111111',
    42,
    '[{"name":"salata","price":15,"quantity":1}]'::jsonb,
    '33333333-3333-4333-8333-333333333333',
    'Garson',
    'ilk',
    'new_order',
    'table',
    'same-send'
  );
  select count(*) into v_orders
  from public.orders
  where id = (v_first ->> 'order_id')::uuid;
  select count(*) into v_jobs
  from public.print_jobs
  where order_id = (v_first ->> 'order_id')::uuid;
  if (v_second ->> 'order_id') is distinct from (v_first ->> 'order_id')
     or coalesce((v_second ->> 'idempotent_replay')::boolean, false) is not true
     or v_orders <> 1
     or v_jobs <> 1
  then
    raise exception 'idempotency created another row first=% second=% jobs=%',
      v_first, v_second, v_jobs;
  end if;
  raise notice 'PASS same idempotency key does not create a second order or ticket';

  begin
    perform public.send_table_order_idempotent(
      '11111111-1111-4111-8111-111111111111',
      42,
      '[{"name":"baska","price":15,"quantity":2}]'::jsonb,
      '33333333-3333-4333-8333-333333333333',
      'Garson',
      'ilk',
      'new_order',
      'table',
      'same-send'
    );
    raise exception 'different payload reused the same key';
  exception
    when sqlstate 'P0001' then
      if sqlerrm not like '%farklı bir sipariş%' then
        raise;
      end if;
  end;
  raise notice 'PASS same key with a different payload is rejected';

  begin
    perform public.send_table_order_idempotent(
      '11111111-1111-4111-8111-111111111111',
      42,
      '[{"name":"salata","price":15,"quantity":1}]'::jsonb,
      '33333333-3333-4333-8333-333333333333',
      'Garson',
      'ilk',
      'new_order',
      'table',
      '   '
    );
    raise exception 'blank idempotency key was accepted';
  exception
    when invalid_parameter_value then
      null;
  end;
  raise notice 'PASS blank idempotency key is rejected';
end
$$;

-- Repository orders.status has no CHECK or ENUM. print_anchor is valid there.
-- The repository table_orders check does not list print_anchor, so that status
-- must never be written onto the bill table.
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  ) then
    raise exception 'orders status check appeared; print_anchor was not validated against it';
  end if;

  create temp table bill_status_check (
    status text
  );
  alter table bill_status_check
    add constraint bill_status_check_status
    check (status in (
      'draft', 'new', 'waiting', 'sent', 'done', 'preparing',
      'kitchen', 'ready', 'served', 'closed'
    ));
  begin
    insert into bill_status_check (status) values ('print_anchor');
    raise exception 'table_orders-style check accepted print_anchor';
  exception
    when check_violation then
      null;
  end;
  raise notice 'PASS print_anchor stays off the bill status check';
end
$$;

insert into public.waiter_order_requests (
  id, seller_id, table_number, items_draft, status, created_by
) values (
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
  '11111111-1111-4111-8111-111111111111',
  44,
  '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
  'pending_waiter_approval',
  '11111111-1111-4111-8111-111111111111'
);

do $$
declare
  v_paid numeric;
  v_moved integer;
  v_full integer;
  v_anchor text;
  v_job text;
  v_approved jsonb;
  v_line text;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform public.record_table_payment(
    '11111111-1111-4111-8111-111111111111',
    12, 'visit-combined', 10, 'cash', 'combined-partial',
    false, null, null, null, null
  );
  select coalesce(sum(amount), 0) into v_paid
  from public.table_payments
  where table_number = 12;
  if v_paid < 10 then
    raise exception 'partial payment missing';
  end if;

  select o.id::text || '#0' into v_line
  from public.table_orders o
  where o.table_number = 9
  limit 1;
  perform public.transfer_table_orders_v2(
    '11111111-1111-4111-8111-111111111111',
    9, 90, 'partial',
    jsonb_build_array(v_line)
  );
  select count(*) into v_moved
  from public.table_orders
  where table_number = 90;
  if v_moved < 1 then
    raise exception 'partial transfer did not move a line';
  end if;

  perform public.transfer_table_orders(
    '11111111-1111-4111-8111-111111111111',
    10, 100, 'full'
  );
  select count(*) into v_full
  from public.table_orders
  where table_number = 100;
  if v_full < 1 then
    raise exception 'full transfer did not move the table';
  end if;

  v_approved := public.approve_waiter_order_request(
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', null
  );
  select status into v_anchor
  from public.orders
  where id = ((v_approved -> 'print_result' ->> 'order_id')::uuid);
  select pj.status into v_job
  from public.print_jobs pj
  where pj.id = ((v_approved -> 'print_result' -> 'print_job_ids' ->> 0)::uuid);
  if v_anchor is distinct from 'print_anchor' or v_job is distinct from 'pending' then
    raise exception 'approval anchor/ticket changed anchor=% job=%', v_anchor, v_job;
  end if;

  perform public.send_table_order_idempotent(
    '11111111-1111-4111-8111-111111111111',
    43,
    '[{"name":"cay","price":10,"quantity":1}]'::jsonb,
    '11111111-1111-4111-8111-111111111111',
    'Garson',
    'yeniden',
    'reprint',
    'table',
    'reprint-key'
  );
  perform public.close_table_with_history(
    '11111111-1111-4111-8111-111111111111', 7
  );
  raise notice 'PASS close, partial transfer, partial payment, approval, and reprint together';
end
$$;

-- Formatting variants the rewriter must accept without PostgreSQL 15's
-- regexp_replace occurrence argument.
create or replace function public.identity_format_compact(
  p_restaurant_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid()<>p_restaurant_id then raise exception 'no' using errcode = '42501'; end if;
  perform set_config('request.jwt.claim.sub', p_restaurant_id::text, true);
  return auth.uid();
end;
$$;

create or replace function public.identity_format_multiline(
  p_restaurant_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is distinct from p_restaurant_id then
    raise exception 'no' using errcode = '42501';
  end if;
  perform
    set_config(
      'request.jwt.claim.sub',
      p_restaurant_id::text,
      true
    );
  return auth.uid();
end;
$$;

select public.neutralize_order_identity_impersonation(
  'public.identity_format_compact(uuid)'::regprocedure
);
select public.neutralize_order_identity_impersonation(
  'public.identity_format_multiline(uuid)'::regprocedure
);

do $$
declare
  v_compact text := pg_get_functiondef('public.identity_format_compact(uuid)'::regprocedure);
  v_multi text := pg_get_functiondef('public.identity_format_multiline(uuid)'::regprocedure);
  v_actor uuid;
begin
  if v_compact ~* 'set_config\(\s*''request\.jwt\.claim\.sub'''
     or v_multi ~* 'set_config\(\s*''request\.jwt\.claim\.sub'''
  then
    raise exception 'formatter left an impersonation statement';
  end if;
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v_actor := public.identity_format_compact('11111111-1111-4111-8111-111111111111');
  if v_actor is distinct from '22222222-2222-4222-8222-222222222222' then
    raise exception 'compact rewrite still returned %', v_actor;
  end if;
  raise notice 'PASS identity rewrite accepts compact and multiline forms';
end
$$;

drop function public.identity_format_compact(uuid);
drop function public.identity_format_multiline(uuid);
