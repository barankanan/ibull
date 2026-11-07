-- Sequential merge checks. The two-device race is in run_merge_table_bills.sh.

do $$
declare
  v_owner uuid := '11111111-1111-4111-8111-111111111111';
  v_result jsonb;
  v_orders integer;
  v_payments integer;
  v_print integer;
  v_items jsonb;
begin
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claim.sub',
    '44444444-4444-4444-8444-444444444444',
    true
  );
  begin
    perform public.merge_table_bills(
      v_owner, 6, 7,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6"]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7"]'::jsonb
    );
    raise exception 'view-only merge should have been rejected';
  exception
    when insufficient_privilege then
      null;
  end;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6') <> 6 then
    raise exception 'view-only merge changed the source table';
  end if;

  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.merge_table_bills(
      v_owner, 6, 7,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6"]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7"]'::jsonb
    );
    raise exception 'signed-out merge should have been rejected';
  exception
    when insufficient_privilege then
      null;
  end;

  perform set_config(
    'request.jwt.claim.sub',
    '77777777-7777-4777-8777-777777777777',
    true
  );
  begin
    perform public.merge_table_bills(
      v_owner, 6, 7,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6"]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7"]'::jsonb
    );
    raise exception 'other-business merge should have been rejected';
  exception
    when insufficient_privilege then
      null;
  end;

  perform set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    true
  );
  begin
    perform public.merge_table_bills(
      v_owner, 4, 3,
      '[]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"]'::jsonb
    );
    raise exception 'closed table merge should have been rejected';
  exception
    when others then
      if sqlerrm not like '%açık adisyon%' then
        raise;
      end if;
  end;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4') <> 4 then
    raise exception 'closed order moved';
  end if;

  begin
    perform public.merge_table_bills(
      v_owner, 5, 3,
      '[]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"]'::jsonb
    );
    raise exception 'paid table merge should have been rejected';
  exception
    when others then
      if sqlerrm not like '%açık adisyon%' then
        raise;
      end if;
  end;

  begin
    perform public.merge_table_bills(
      v_owner, 2, 3,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"]'::jsonb,
      '[]'::jsonb
    );
    raise exception 'stale target ids should have been rejected';
  exception
    when others then
      if sqlerrm not like '%Masalar değişti%' then
        raise;
      end if;
  end;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1') <> 2 then
    raise exception 'rejected merge moved the source order';
  end if;
  if (select count(*) from public.table_payments
      where table_number = 3 and seller_id = v_owner) <> 1 then
    raise exception 'rejected merge changed payments';
  end if;

  update public.table_orders
  set visit_id = 'abababab-abab-4aba-8aba-abababababa1'
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  update public.table_orders
  set visit_id = 'abababab-abab-4aba-8aba-abababababa2'
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  update public.table_payments
  set visit_id = 'abababab-abab-4aba-8aba-abababababa1'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  update public.table_payments
  set visit_id = 'abababab-abab-4aba-8aba-abababababa2'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  insert into public.table_payments (
    id, seller_id, table_number, session_key, amount, idempotency_key, created_at
  ) values (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
    v_owner,
    2,
    'other-visit',
    4,
    'pay-other-visit',
    '2026-11-07 12:20:00+00'
  );
  update public.table_payments
  set visit_id = 'abababab-abab-4aba-8aba-abababababa9'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4';
  insert into public.table_orders (
    id, seller_id, table_number, items, status, created_at, visit_id
  ) values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa14',
    v_owner, 14,
    '[{"name":"Belirsiz","quantity":1,"price":20}]'::jsonb,
    'sent', '2026-11-07 12:00:00+00', null
  );
  insert into public.table_payments (
    id, seller_id, table_number, session_key, amount, idempotency_key, created_at
  ) values (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb5',
    v_owner, 14, 'ambiguous', 5, 'pay-ambiguous',
    '2026-11-07 12:10:00+00'
  );
  update public.table_payments
  set visit_id = null
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb5';
  begin
    perform public.merge_table_bills(
      v_owner, 14, 3,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa14"]'::jsonb,
      '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"]'::jsonb
    );
    raise exception 'ambiguous payment merge should have been rejected';
  exception
    when others then
      if sqlerrm not like '%ziyareti belirsiz%' then
        raise;
      end if;
  end;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa14') <> 14 then
    raise exception 'ambiguous merge moved the source order';
  end if;

  v_result := public.merge_table_bills(
    v_owner, 2, 3,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"]'::jsonb,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"]'::jsonb,
    null,
    'Ayse'
  );
  if (v_result ->> 'moved_orders')::int <> 1
     or (v_result ->> 'moved_payments')::int <> 1
     or (v_result ->> 'moved_customer_orders')::int <> 1 then
    raise exception 'merge counts unexpected: %', v_result;
  end if;

  select table_number, items
    into v_orders, v_items
  from public.table_orders
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  if v_orders <> 3
     or v_items::text not like '%az tuz%'
     or v_items::text not like '%"quantity": 2%' and v_items::text not like '%"quantity":2%' then
    raise exception 'source items were not preserved: %', v_items;
  end if;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2') <> 3 then
    raise exception 'target order left its table';
  end if;
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa9') <> 2 then
    raise exception 'print anchor was moved';
  end if;
  if (select count(*) from public.table_orders) <> 13 then
    raise exception 'merge inserted or deleted an order row';
  end if;

  if (select table_number from public.table_payments
      where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1') <> 3 then
    raise exception 'visit payment stayed on the source table';
  end if;
  if (select table_number from public.table_payments
      where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2') <> 3 then
    raise exception 'target payment was rewritten';
  end if;
  if (select table_number from public.table_payments
      where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3') <> 2 then
    raise exception 'previous visit payment was moved';
  end if;
  if (select table_number from public.table_payments
      where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4') <> 2 then
    raise exception 'a different visit payment was moved by time';
  end if;
  if (select visit_id from public.table_payments
      where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1')
     <> (select visit_id from public.table_orders
         where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2') then
    raise exception 'moved payment did not join the target visit';
  end if;
  select count(*) into v_payments from public.table_payments;
  if v_payments <> 5 then
    raise exception 'payment rows were copied: %', v_payments;
  end if;
  begin
    insert into public.table_payments (
      id, seller_id, table_number, session_key, amount, idempotency_key
    ) values (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb6',
      v_owner, 2, 'after-merge', 1, 'pay-after-merge'
    );
    raise exception 'payment insert on the emptied source should have failed';
  exception
    when others then
      if sqlerrm not like '%Masa hesabı değişti%' then
        raise;
      end if;
  end;

  if (select table_id from public.orders
      where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1')
     <> 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3' then
    raise exception 'customer order stayed on the source table';
  end if;
  if (select notes from public.orders
      where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1') <> 'musteri notu' then
    raise exception 'customer note changed';
  end if;

  select count(*) into v_print from public.print_jobs;
  if v_print <> 1
     or (select status from public.print_jobs
         where id = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1') <> 'pending'
     or (select payload::text from public.print_jobs
         where id = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1') <> '{"ticket": "corba"}'
        and (select payload::text from public.print_jobs
         where id = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1') <> '{"ticket":"corba"}' then
    raise exception 'kitchen print job was rewritten';
  end if;
  if (select transfer_type from public.table_transfers_log
      where from_table = 2 and to_table = 3) <> 'merge' then
    raise exception 'merge was not logged';
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );
  perform public.merge_table_bills(
    v_owner, 8, 7,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8"]'::jsonb,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7"]'::jsonb
  );
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8') <> 7 then
    raise exception 'manageOrders merge did not move the bill';
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    '33333333-3333-4333-8333-333333333333',
    true
  );
  perform public.merge_table_bills(
    v_owner, 10, 11,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10"]'::jsonb,
    '["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11"]'::jsonb
  );
  if (select table_number from public.table_orders
      where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10') <> 11 then
    raise exception 'Tam Erişim merge did not move the bill';
  end if;
end
$$;
