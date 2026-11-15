-- Assertions for the isolated print-identity and staff-password gate.
-- Fails the session with an exception when a check does not hold.

insert into public.stores (seller_id)
values ('11111111-1111-1111-1111-111111111111');

insert into auth.users (id, email, email_confirmed_at)
values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.test', now()),
  ('22222222-2222-2222-2222-222222222222', 'waiter@example.test', now()),
  ('33333333-3333-3333-3333-333333333333', 'old@example.test', now());

insert into public.store_sub_admins (
  id, store_id, status, permissions, auth_user_id, email
) values
  (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'active',
    array['viewOrders'],
    '22222222-2222-2222-2222-222222222222',
    'waiter@example.test'
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    'active',
    array['manageOrders'],
    '33333333-3333-3333-3333-333333333333',
    'old@example.test'
  );

insert into public.store_tables (id, seller_id, is_active)
values (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  true
);

insert into public.orders (id, local_order_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'local-order-1');

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","app_metadata":{"must_change_password":true}}',
  false
);
do $$
begin
  if not public.restaurant_has_permission(
    '11111111-1111-1111-1111-111111111111',
    'manageOrders'
  ) then
    raise exception 'owner with a password flag but no managed flag was locked';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","app_metadata":{}}',
  false
);
do $$
begin
  if not public.restaurant_has_permission(
    '11111111-1111-1111-1111-111111111111',
    'manageOrders'
  ) then
    raise exception 'existing staff without the password flag was locked';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"managed_restaurant_staff":true,"must_change_password":true}}',
  false
);
do $$
begin
  if public.restaurant_has_permission(
    '11111111-1111-1111-1111-111111111111',
    'viewOrders'
  ) then
    raise exception 'managed staff passed restaurant_has_permission before changing the password';
  end if;
  if public.restaurant_table_access(
    '11111111-1111-1111-1111-111111111111',
    '44444444-4444-4444-4444-444444444444'
  ) then
    raise exception 'managed staff passed table access before changing the password';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"managed_restaurant_staff":true,"must_change_password":false}}',
  false
);
do $$
begin
  if not public.restaurant_has_permission(
    '11111111-1111-1111-1111-111111111111',
    'viewOrders'
  ) then
    raise exception 'waiter lost viewOrders after the password change';
  end if;
  if public.restaurant_has_permission(
    '11111111-1111-1111-1111-111111111111',
    'viewFinance'
  ) then
    raise exception 'waiter received a permission that was not granted';
  end if;
  if public.restaurant_has_permission(
    '99999999-9999-9999-9999-999999999999',
    'viewOrders'
  ) then
    raise exception 'waiter reached another restaurant';
  end if;
end $$;

insert into public.print_jobs (
  restaurant_id, order_id, station_id, job_type, payload, status
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'new_order',
  '{"revision_key":"2"}'::jsonb,
  'pending'
);

do $$
declare
  v_key text;
begin
  select payload->>'logical_print_key' into v_key
  from public.print_jobs
  where payload->>'revision_key' = '2';
  if v_key <> concat_ws(
    '|',
    '11111111-1111-1111-1111-111111111111',
    'local-order-1',
    '2',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'new_order'
  ) then
    raise exception 'logical print key mismatch: %', v_key;
  end if;
end $$;

insert into public.print_jobs (
  id, restaurant_id, order_id, station_id, job_type, payload, status
) values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'new_order',
  '{"local_order_id":"local-order-1","revision_key":"1"}'::jsonb,
  'pending'
);

-- Claim race is executed by the runner with two sessions.
select 'ASSERTIONS_OK' as result;
