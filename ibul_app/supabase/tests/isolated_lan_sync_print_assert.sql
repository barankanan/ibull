-- Assertions for isolated_lan_sync_print.sql. Functions are already loaded.
do $$
declare
  seller uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  waiter uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  ocak text := '11111111-1111-1111-1111-111111111111';
  firin text := '22222222-2222-2222-2222-222222222222';
  kasap text := '33333333-3333-3333-3333-333333333333';
  soup jsonb;
  grill jsonb;
  three jsonb;
  first jsonb;
  second jsonb;
  claimed int;
  job_count int;
  order_count int;
begin
  perform set_config('ibul.test_uid', '', false);
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, jsonb_build_array(jsonb_build_object('name','Çorba','quantity',1,'price',40)),
      null, 'Garson', null, 'new_order', 'table', 'unauth'
    );
    raise exception 'unauthenticated call was accepted';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('ibul.test_uid', seller::text, false);
  soup := jsonb_build_array(jsonb_build_object(
    'product_id','corba','name','Çorba','quantity',1,'price',40,'station_id', ocak
  ));
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'online-1'
  );
  if coalesce((first->>'print_job_count')::int, 0) <> 1 then
    raise exception 'online print count %', first;
  end if;
  if (select status from public.print_jobs where order_id = (first->>'order_id')::uuid) <> 'pending' then
    raise exception 'online job was not pending';
  end if;

  second := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'online-1'
  );
  if second->>'order_id' <> first->>'order_id' or second->>'idempotent_replay' <> 'true' then
    raise exception 'same content was not replayed: %', second;
  end if;
  if (select count(*) from public.print_jobs where order_id = (first->>'order_id')::uuid) <> 1 then
    raise exception 'replay created another print job';
  end if;

  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1,
      jsonb_build_array(jsonb_build_object(
        'product_id','corba','name','Çorba','quantity',2,'price',40,'station_id', ocak
      )),
      null, 'Garson', null, 'new_order', 'table', 'online-1'
    );
    raise exception 'different content was accepted';
  exception when raise_exception then
    null;
  end;
  if (select quantity from public.order_items where order_id = (first->>'order_id')::uuid) <> 1 then
    raise exception 'conflict rewrote the stored quantity';
  end if;

  insert into public.orders (
    restaurant_id, local_order_id, order_number, status, user_id, table_id
  )
  select seller, 'legacy-1', 'LEGACY', 'confirmed', seller, id
  from public.store_tables
  where seller_id = seller and table_number = 1;
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'legacy-1'
    );
    raise exception 'legacy order without lines was accepted';
  exception when raise_exception then
    null;
  end;

  three := jsonb_build_array(
    jsonb_build_object('product_id','a','name','Çorba','quantity',1,'price',40,'station_id', ocak),
    jsonb_build_object('product_id','b','name','Pide','quantity',1,'price',70,'station_id', firin),
    jsonb_build_object('product_id','c','name','Köfte','quantity',1,'price',90,'station_id', kasap)
  );
  first := public.create_table_order_with_print_jobs(
    seller, 1, three, null, 'Garson', null, 'new_order', 'table', 'stations-1',
    'v1.forwarded.not-a-server-signature'
  );
  select count(*) into job_count from public.print_jobs where order_id = (first->>'order_id')::uuid;
  if job_count <> 3 then
    raise exception 'station job count %', job_count;
  end if;
  if exists (
    select 1 from public.print_jobs
    where order_id = (first->>'order_id')::uuid
      and (status <> 'paused_by_operator' or last_error <> 'print_evidence_unverified')
  ) then
    raise exception 'unsigned evidence was treated as forwarded';
  end if;
  update public.print_jobs
  set status = 'claimed'
  where order_id = (first->>'order_id')::uuid and status = 'pending';
  get diagnostics claimed = row_count;
  if claimed <> 0 then
    raise exception 'worker claimed a forwarded job';
  end if;

  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'uncertain-1',
    'v2.uncertain.1.event.abcd'
  );
  if (select status || ':' || coalesce(last_error,'') from public.print_jobs
      where order_id = (first->>'order_id')::uuid) <> 'paused_by_operator:print_evidence_unverified' then
    raise exception 'unsigned uncertain evidence was accepted';
  end if;

  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'failed-1',
    'forwarded'
  );
  if (select last_error from public.print_jobs where order_id = (first->>'order_id')::uuid)
     <> 'print_evidence_unverified' then
    raise exception 'plain forwarded text was accepted';
  end if;

  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'plain-owner', 'forwarded'
  );
  if (select last_error from public.print_jobs where order_id = (first->>'order_id')::uuid)
     <> 'print_evidence_unverified' then
    raise exception 'owner session was accepted as print proof';
  end if;

  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'bad-evidence', 'not-a-status'
  );
  if (select last_error from public.print_jobs where order_id = (first->>'order_id')::uuid)
     <> 'print_evidence_unverified' then
    raise exception 'bad evidence was trusted';
  end if;

  perform set_config('ibul.test_uid', waiter::text, false);
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, waiter, 'Garson', null, 'new_order', 'table', 'waiter-evidence', 'forwarded'
  );
  if (select last_error from public.print_jobs where order_id = (first->>'order_id')::uuid)
     <> 'print_evidence_unverified' then
    raise exception 'waiter evidence suppressed a print';
  end if;

  perform set_config('ibul.test_uid', seller::text, false);
  update public.test_flags set ok = false where name = 'permission';
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'revoked-staff'
    );
    raise exception 'revoked permission was accepted';
  exception when insufficient_privilege then
    null;
  end;
  update public.test_flags set ok = true where name = 'permission';

  update public.test_flags set ok = false where name = 'table';
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'other-branch'
    );
    raise exception 'other branch was accepted';
  exception when insufficient_privilege then
    null;
  end;
  update public.test_flags set ok = true where name = 'table';

  begin
    perform public.create_table_order_with_print_jobs(
      'dddddddd-dddd-dddd-dddd-dddddddddddd', 1,
      jsonb_build_array(jsonb_build_object('name','Çorba','quantity',1,'price',40)),
      null, 'Garson', null, 'new_order', 'table', 'other-store'
    );
    raise exception 'other store was accepted';
  exception when insufficient_privilege then
    null;
  end;

  select count(*) into order_count from public.orders where local_order_id = 'online-1';
  if order_count <> 1 then
    raise exception 'order identity changed';
  end if;
  if (
    select count(*) from pg_proc
    where proname = 'create_table_order_with_print_jobs'
      and pronamespace = 'public'::regnamespace
  ) <> 1 then
    raise exception 'function overload';
  end if;
  if (
    select prosecdef and 'search_path=public' = any(proconfig)
    from pg_proc
    where proname = 'create_table_order_with_print_jobs_impl'
      and pronamespace = 'public'::regnamespace
  ) is not true then
    raise exception 'definer contract changed';
  end if;
  if (
    select prosecdef and (
      'search_path=pg_catalog, public' = any(proconfig)
      or 'search_path="pg_catalog, public"' = any(proconfig)
    )
    from pg_proc
    where proname = 'restaurant_print_evidence_outcome'
  ) is not true then
    raise exception 'evidence definer path changed: %', (
      select proconfig from pg_proc where proname = 'restaurant_print_evidence_outcome'
    );
  end if;
  if exists (
    select 1 from pg_proc
    where proname in (
      'restaurant_rsa_sha256_verify',
      'restaurant_modexp',
      'restaurant_bytea_to_numeric'
    )
  ) then
    raise exception 'custom rsa verifier still exists';
  end if;
  if has_function_privilege(
    'authenticated',
    'public.restaurant_lan_print_evidence_public_key(uuid,text)',
    'execute'
  ) or has_function_privilege(
    'anon',
    'public.restaurant_lan_print_evidence_public_key(uuid,text)',
    'execute'
  ) then
    raise exception 'client can read the print public key';
  end if;
  if has_function_privilege(
    'anon',
    'public.restaurant_print_evidence_outcome(uuid,text,text,jsonb,text)',
    'execute'
  ) or has_function_privilege(
    'authenticated',
    'public.restaurant_print_evidence_outcome(uuid,text,text,jsonb,text)',
    'execute'
  ) then
    raise exception 'client can execute evidence verification';
  end if;
  begin
    insert into public.restaurant_lan_print_evidence_keys (
      restaurant_id, branch_id, key_id, server_fingerprint, modulus, exponent
    ) values (
      '00000000-0000-0000-0000-000000000099',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '0123456789abcdef',
      'abc',
      decode(repeat('00', 64), 'hex'),
      65537
    );
    raise exception 'short print key was accepted';
  exception when check_violation then
    null;
  end;
  begin
    insert into public.restaurant_lan_print_evidence_keys (
      restaurant_id, branch_id, key_id, server_fingerprint, modulus, exponent
    ) values (
      '00000000-0000-0000-0000-000000000099',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '0123456789abcdef',
      'abc',
      decode(repeat('ab', 256), 'hex'),
      3
    );
    raise exception 'wrong print exponent was accepted';
  exception when check_violation then
    null;
  end;
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'authenticated', 'sub', seller)::text,
    true
  );
  perform set_config('request.jwt.claim.sub', seller::text, true);
  insert into public.restaurant_lan_print_evidence_keys (
    restaurant_id, branch_id, key_id, server_fingerprint, modulus, exponent
  ) values (
    seller,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '0123456789abcdef',
    'isolated-fingerprint',
    decode(repeat('ab', 256), 'hex'),
    65537
  );
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'direct-owner',
    'v2.forwarded.1.direct-owner-event.0123456789abcdef.' || repeat('aa', 128),
    null
  );
  if first->>'print_disposition' <> 'unverified' then
    raise exception 'owner rpc applied print evidence: %', first;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'service_role', 'sub', seller)::text,
    true
  );
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'svc-forward',
    'v2.forwarded.1.svc-event.0123456789abcdef.' || repeat('aa', 128),
    seller,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  );
  if first->>'print_disposition' <> 'forwarded' then
    raise exception 'service handoff was not forwarded: %', first;
  end if;
  if (select user_id from public.orders where local_order_id = 'svc-forward') <> seller then
    raise exception 'service handoff did not act as the owner';
  end if;
  if (select status || ':' || coalesce(last_error, '') from public.print_jobs
      where order_id = (first->>'order_id')::uuid) <> 'paused_by_operator:local_forwarded' then
    raise exception 'forwarded job was printable';
  end if;
  update public.print_jobs
  set status = 'claimed'
  where order_id = (first->>'order_id')::uuid and status = 'pending';
  get diagnostics claimed = row_count;
  if claimed <> 0 then
    raise exception 'worker claimed a service-forwarded job';
  end if;

  second := public.create_table_order_with_print_jobs(
    seller, 1,
    jsonb_build_array(jsonb_build_object(
      'product_id','corba','name','Çorba','quantity',2,'price',40,'station_id', ocak
    )),
    null, 'Garson', null, 'new_order', 'table', 'svc-changed',
    'v2.forwarded.1.svc-event.0123456789abcdef.' || repeat('aa', 128),
    seller
  );
  if second->>'print_disposition' <> 'unverified' then
    raise exception 'same event with different content was accepted: %', second;
  end if;

  update public.restaurant_lan_print_evidence_keys
  set revoked = true
  where restaurant_id = seller and key_id = '0123456789abcdef';
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'svc-revoked',
    'v2.forwarded.1.svc-revoked-event.0123456789abcdef.' || repeat('aa', 128),
    seller
  );
  if first->>'print_disposition' <> 'unverified' then
    raise exception 'revoked key was accepted by the database: %', first;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'authenticated', 'sub', waiter)::text,
    true
  );
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  first := public.create_table_order_with_print_jobs(
    seller, 1, soup, waiter, 'Garson', null, 'new_order', 'table', 'forged-actor',
    'v2.forwarded.1.forged-actor-event.0123456789abcdef.' || repeat('aa', 128),
    seller,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  );
  if first->>'print_disposition' <> 'unverified'
     or (select user_id from public.orders where local_order_id = 'forged-actor') <> waiter
     or (select waiter_id from public.orders where local_order_id = 'forged-actor') <> waiter then
    raise exception 'authenticated caller forged the actor: %', first;
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'service_role', 'sub', seller)::text,
    true
  );
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, soup, null, 'Garson', null, 'new_order', 'table', 'foreign-actor',
      null, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    );
    raise exception 'unrelated actor created an order';
  exception when insufficient_privilege then
    null;
  end;
  if exists (select 1 from public.orders where local_order_id = 'foreign-actor') then
    raise exception 'foreign actor left an order behind';
  end if;

  update public.store_sub_admins
  set status = 'inactive'
  where auth_user_id = waiter;
  begin
    perform public.create_table_order_with_print_jobs(
      seller, 1, soup, waiter, 'Garson', null, 'new_order', 'table', 'revoked-staff',
      null, waiter
    );
    raise exception 'revoked staff created an order';
  exception when insufficient_privilege then
    null;
  end;
  update public.store_sub_admins
  set status = 'active'
  where auth_user_id = waiter;

  begin
    perform public.create_table_order_with_print_jobs(
      seller, 2, soup, waiter, 'Garson', null, 'new_order', 'table', 'other-branch-staff',
      null, waiter
    );
    raise exception 'staff crossed into another branch';
  exception when insufficient_privilege then
    null;
  end;

  raise notice 'LAN_SYNC_PRINT_OK';
end $$;
