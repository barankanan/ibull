-- Sequential production-contract checks. Races are in the shell runner.

do $$
declare
  v_owner uuid := '11111111-1111-4111-8111-111111111111';
  v_first jsonb;
  v_second jsonb;
  v_old jsonb;
  v_orders integer;
  v_jobs integer;
  v_merge jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  v_first := public.create_table_order_with_print_jobs(
    v_owner, 4, '[]'::jsonb, null, null, 'ilk', 'new_order', 'table', 'local-1'
  );
  v_second := public.create_table_order_with_print_jobs(
    v_owner, 4, '[]'::jsonb, null, null, 'ilk', 'new_order', 'table', 'local-1'
  );
  if v_second ->> 'order_id' is distinct from v_first ->> 'order_id'
     or (v_second ->> 'idempotent_replay')::boolean is not true then
    raise exception 'replay did not return the original order';
  end if;
  select count(*) into v_orders from public.orders where local_order_id = 'local-1';
  select count(*) into v_jobs from public.print_jobs pj
    join public.orders o on o.id = pj.order_id
    where o.local_order_id = 'local-1';
  if v_orders <> 1 or v_jobs <> 1 then
    raise exception 'replay created another order or ticket orders=% jobs=%', v_orders, v_jobs;
  end if;
  if (select current_setting('ibul.marketplace_order_rpc', true)) is distinct from 'on' then
    raise exception 'marketplace rpc flag was not set by impl';
  end if;

  v_old := public.create_table_order_with_print_jobs(
    v_owner, 4, '[]'::jsonb, null, null, 'eski', 'new_order', 'table', null
  );
  perform public.create_table_order_with_print_jobs(
    v_owner, 4, '[]'::jsonb, null, null, 'eski-2', 'new_order', 'table', null
  );
  if (select count(*) from public.orders where local_order_id is null) <> 2 then
    raise exception 'old client without local id could not send';
  end if;

  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
  insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
  values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', v_owner::text, 4,
    '[{"name":"Corba","quantity":1,"price":40}]'::jsonb, 'sent',
    '2026-11-07 12:00:00+00', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  );
  begin
    perform public.record_table_payment(
      v_owner, 4, 's1', 10, 'cash', false, 'pay-view', null, null, null, null
    );
    raise exception 'view-only payment should have failed uid=%', auth.uid();
  exception when others then
    if sqlerrm not like '%yetkisi yok%' then
      raise;
    end if;
  end;

  perform set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555555', true);
  perform public.record_table_payment(
    v_owner, 4, 's1', 10, 'cash', false, 'pay-1', null, null, null, null
  );
  begin
    perform public.record_table_payment(
      v_owner, 4, 's1', 10, 'cash', false, 'pay-1', null, null, null, null
    );
    raise exception 'duplicate payment request should have failed';
  exception when others then
    if sqlerrm not like '%IBUL_PAYMENT_REPLAY%' and sqlerrm not like '%duplicate%' then
      raise;
    end if;
  end;
  if (select count(*) from public.table_payments where client_request_id = 'pay-1') <> 1 then
    raise exception 'payment request was stored twice';
  end if;

  perform set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
  insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
  values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8', v_owner::text, 8,
    '[]'::jsonb, 'sent', now(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8'
  );
  perform public.transfer_table_orders(v_owner::text, 8, 9);
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8') <> 9 then
    raise exception 'transfer did not move the order';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
  values
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa21', v_owner::text, 21, '[{"price":40}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '12121212-1212-4121-8121-121212121212'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa22', v_owner::text, 22, '[{"price":30}]'::jsonb, 'sent', '2026-11-07 12:05:00+00', '13131313-1313-4131-8131-131313131313');
  insert into public.table_payments (seller_id, table_number, session_key, amount, client_request_id, created_at, visit_id)
  values (v_owner, 21, 'v21', 10, 'pay-21', '2026-11-07 12:10:00+00', '12121212-1212-4121-8121-121212121212');
  v_merge := public.merge_table_bills(
    v_owner::text, 21, 22,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa21"]'::jsonb,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa22"]'::jsonb
  );
  if (v_merge ->> 'moved_payments')::int <> 1 then
    raise exception 'matching visit payment did not move';
  end if;
  if (select visit_id from public.table_orders where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa21')
     is distinct from '12121212-1212-4121-8121-121212121212'::uuid
     or (select visit_id from public.table_orders where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa22')
     is distinct from '13131313-1313-4131-8131-131313131313'::uuid then
    raise exception 'merge collapsed two visit ids';
  end if;

  insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
  values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa30', v_owner::text, 30, '[{"price":20}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '30303030-3030-4030-8030-303030303030');
  insert into public.table_payments (seller_id, table_number, session_key, amount, client_request_id, created_at, visit_id)
  values (v_owner, 30, 'old', 5, 'pay-ambiguous', '2026-11-07 12:10:00+00', '30303030-3030-4030-8030-303030303030');
  update public.table_payments set visit_id = null where client_request_id = 'pay-ambiguous';
  begin
    perform public.merge_table_bills(
      v_owner::text, 30, 60,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa30"]'::jsonb,
      '[]'::jsonb
    );
    raise exception 'ambiguous payment should have blocked merge';
  exception when others then
    if sqlerrm not like '%ziyareti belirsiz%' then raise; end if;
  end;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa30') <> 30 then
    raise exception 'aborted merge moved a row';
  end if;

  insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
  values
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa41', v_owner::text, 41, '[]'::jsonb, 'sent', now(), '41414141-4141-4141-8141-414141414141'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa42', v_owner::text, 41, '[]'::jsonb, 'sent', now(), '42424242-4242-4242-8242-424242424242');
  begin
    perform public.merge_table_bills(
      v_owner::text, 41, 61,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa41","aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa42"]'::jsonb,
      '[]'::jsonb
    );
    raise exception 'multiple visits should have blocked merge';
  exception when others then
    if sqlerrm not like '%belirsiz ziyaret%' and sqlerrm not like '%birden fazla%' then
      raise;
    end if;
  end;
end
$$;
