-- Assertions for 20261107_staff_permission_enforcement.sql.
-- Runs after the prelude and the migration, on a scratch database.

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  false
);

insert into public.users (id, email, phone) values
  ('11111111-1111-4111-8111-111111111111', 'owner@ibul.test', null),
  ('22222222-2222-4222-8222-222222222222', 'waiter@ibul.test', null),
  ('55555555-5555-4555-8555-555555555555', 'viewer@ibul.test', null),
  ('66666666-6666-4666-8666-666666666666', 'full@ibul.test', null),
  ('77777777-7777-4777-8777-777777777777', 'tam@ibul.test', null),
  ('33333333-3333-4333-8333-333333333333', 'other@ibul.test', '5550001111');

insert into public.store_sub_admins (id, store_id, email, permissions, status) values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '11111111-1111-4111-8111-111111111111',
    'waiter@ibul.test',
    array['manageOrders'],
    'invited'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    '11111111-1111-4111-8111-111111111111',
    'viewer@ibul.test',
    array['viewOrders', 'manageProducts'],
    'active'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    '11111111-1111-4111-8111-111111111111',
    'full@ibul.test',
    array['fullAccess'],
    'active'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    '11111111-1111-4111-8111-111111111111',
    'tam@ibul.test',
    array['Tam Erişim'],
    'active'
  );

select set_config(
  'request.jwt.claim.sub',
  '99999999-9999-4999-8999-999999999999',
  false
);

insert into public.store_sub_admins (id, store_id, email, permissions, status) values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5',
    '99999999-9999-4999-8999-999999999999',
    'other@ibul.test',
    array['manageOrders'],
    'active'
  );

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  false
);

-- Activation does not change permissions.
select set_config(
  'request.jwt.claim.sub',
  '22222222-2222-4222-8222-222222222222',
  false
);
select public.activate_own_store_sub_admin_invites();
select set_config('request.jwt.claim.sub', '', false);

do $$
declare
  v_status text;
  v_permissions text[];
begin
  select status, permissions
    into v_status, v_permissions
  from public.store_sub_admins
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  if v_status is distinct from 'active' then
    raise exception 'activation did not mark the invite active';
  end if;
  if v_permissions is distinct from array['manageOrders'] then
    raise exception 'activation changed permissions: %', v_permissions;
  end if;
end
$$;

-- Staff cannot add Tam Erişim to their own active row.
do $$
declare
  v_permissions text[];
begin
  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );
  execute 'set local role authenticated';
  update public.store_sub_admins
  set permissions = array['fullAccess']
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  select permissions
    into v_permissions
  from public.store_sub_admins
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  if v_permissions is distinct from array['manageOrders'] then
    raise exception 'staff elevated permissions: %', v_permissions;
  end if;
end
$$;

-- Invited staff cannot activate and rewrite permissions together.
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  false
);
insert into public.store_sub_admins (id, store_id, email, permissions, status)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6',
  '11111111-1111-4111-8111-111111111111',
  'waiter@ibul.test',
  array['viewOrders'],
  'invited'
);

do $$
declare
  v_raised boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );
  begin
    execute 'set local role authenticated';
    update public.store_sub_admins
    set status = 'active',
        permissions = array['fullAccess']
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6';
  exception
    when insufficient_privilege then
      v_raised := true;
  end;
  if not v_raised then
    raise exception 'permission rewrite during activation was allowed';
  end if;
end
$$;

-- Status-only activation through the policy is allowed.
do $$
declare
  v_status text;
  v_permissions text[];
begin
  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );
  execute 'set local role authenticated';
  update public.store_sub_admins
  set status = 'active'
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6';
  select status, permissions
    into v_status, v_permissions
  from public.store_sub_admins
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6';
  if v_status is distinct from 'active'
     or v_permissions is distinct from array['viewOrders'] then
    raise exception 'status-only activation failed: % %', v_status, v_permissions;
  end if;
end
$$;

-- Owner can grant Tam Erişim.
do $$
declare
  v_permissions text[];
begin
  perform set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    true
  );
  execute 'set local role authenticated';
  update public.store_sub_admins
  set permissions = array['fullAccess']
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  select permissions
    into v_permissions
  from public.store_sub_admins
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  if v_permissions is distinct from array['fullAccess'] then
    raise exception 'owner could not grant Tam Erişim: %', v_permissions;
  end if;
end
$$;

-- Restore the view-only grant for the payment cases below.
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  false
);
update public.store_sub_admins
set permissions = array['viewOrders', 'manageProducts']
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';

-- Owner direct insert still passes RLS and the trigger.
do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    true
  );
  execute 'set local role authenticated';
  insert into public.table_payments (
    seller_id, table_number, session_key, amount, method
  ) values (
    '11111111-1111-4111-8111-111111111111',
    4,
    'owner-session',
    10,
    'cash'
  );
end
$$;

-- Authorized waiter direct insert stays blocked by the owner-only policy.
do $$
declare
  v_message text := '';
begin
  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );
  begin
    execute 'set local role authenticated';
    insert into public.table_payments (
      seller_id, table_number, session_key, amount, method
    ) values (
      '11111111-1111-4111-8111-111111111111',
      4,
      'waiter-direct',
      10,
      'cash'
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_message = message_text;
  end;
  if v_message not like '%row-level security%' then
    raise exception 'direct waiter insert was not kept owner-only: %', v_message;
  end if;
end
$$;

-- Security-definer style inserts bypass RLS. The trigger still applies.
create or replace function pg_temp.try_payment(
  p_actor uuid,
  p_seller uuid,
  p_session text
)
returns text
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  insert into public.table_payments (
    seller_id, table_number, session_key, amount, method
  ) values (
    p_seller, 4, p_session, 12, 'card'
  );
  return 'allowed';
exception
  when others then
    return sqlerrm;
end;
$$;

do $$
declare
  v_result text;
begin
  v_result := pg_temp.try_payment(
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'waiter-manage'
  );
  if v_result is distinct from 'allowed' then
    raise exception 'manageOrders waiter was blocked: %', v_result;
  end if;

  v_result := pg_temp.try_payment(
    '66666666-6666-4666-8666-666666666666',
    '11111111-1111-4111-8111-111111111111',
    'full-access'
  );
  if v_result is distinct from 'allowed' then
    raise exception 'Tam Erişim waiter was blocked: %', v_result;
  end if;

  v_result := pg_temp.try_payment(
    '77777777-7777-4777-8777-777777777777',
    '11111111-1111-4111-8111-111111111111',
    'tam-erisim'
  );
  if v_result is distinct from 'allowed' then
    raise exception 'Tam Erişim alias waiter was blocked: %', v_result;
  end if;

  v_result := pg_temp.try_payment(
    '11111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    'owner-definer'
  );
  if v_result is distinct from 'allowed' then
    raise exception 'owner definer insert was blocked: %', v_result;
  end if;

  v_result := pg_temp.try_payment(
    '55555555-5555-4555-8555-555555555555',
    '11111111-1111-4111-8111-111111111111',
    'viewer'
  );
  if v_result not like '%ödeme yetkiniz yok%' then
    raise exception 'view-only staff was allowed to collect: %', v_result;
  end if;

  -- The second invited row was activated with viewOrders only.
  v_result := pg_temp.try_payment(
    '22222222-2222-4222-8222-222222222222',
    '99999999-9999-4999-8999-999999999999',
    'wrong-store'
  );
  if v_result not like '%ödeme yetkiniz yok%' then
    raise exception 'staff collected for another business: %', v_result;
  end if;

  v_result := pg_temp.try_payment(
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'other-store-staff'
  );
  if v_result not like '%ödeme yetkiniz yok%' then
    raise exception 'another business staff collected here: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', '', true);
  begin
    insert into public.table_payments (
      seller_id, table_number, session_key, amount, method
    ) values (
      '11111111-1111-4111-8111-111111111111',
      4,
      'anonymous',
      5,
      'cash'
    );
    raise exception 'anonymous insert was allowed';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

-- Invited manageOrders cannot collect. Use a fresh invited row.
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  false
);
insert into public.store_sub_admins (id, store_id, email, permissions, status)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
  '11111111-1111-4111-8111-111111111111',
  'waiter@ibul.test',
  array['manageOrders'],
  'invited'
);
update public.store_sub_admins
set status = 'invited'
where email = 'waiter@ibul.test'
  and store_id = '11111111-1111-4111-8111-111111111111';

do $$
declare
  v_result text;
begin
  v_result := pg_temp.try_payment(
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'invited-manage'
  );
  if v_result not like '%ödeme yetkiniz yok%' then
    raise exception 'invited staff collected: %', v_result;
  end if;
end
$$;
