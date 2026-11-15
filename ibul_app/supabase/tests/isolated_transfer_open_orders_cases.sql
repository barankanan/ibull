-- Scenarios for the disposable transfer database. Fails the session on mismatch.

do $$
declare
  v_seller uuid := '11111111-1111-1111-1111-111111111111';
  v_user uuid := '22222222-2222-2222-2222-222222222222';
  v_branch uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  v_other uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  v_t8 uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa8';
  v_t9 uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa9';
  v_t3 uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3';
  v_o1 uuid := 'c1000000-0000-0000-0000-000000000001';
  v_o2 uuid := 'c1000000-0000-0000-0000-000000000002';
  v_o3 uuid := 'c1000000-0000-0000-0000-000000000003';
  v_pay_src uuid := 'd1000000-0000-0000-0000-000000000001';
  v_pay_dst uuid := 'd1000000-0000-0000-0000-000000000002';
  v_result jsonb;
  v_count integer;
  v_total numeric;
  v_table integer;
begin
  insert into public.store_tables (id, seller_id, table_number, branch_id)
  values
    (v_t8, v_seller, 8, v_branch),
    (v_t9, v_seller, 9, v_branch),
    (v_t3, v_seller, 3, v_other);

  insert into public.orders (
    id, user_id, status, order_type, delivery_type, total_amount,
    payment_status, restaurant_id, table_id
  ) values
    (v_o1, v_user, 'confirmed', 'table', 'table', 120, 'unpaid', v_seller, v_t8),
    (v_o2, v_user, 'confirmed', 'table', 'table', 80, 'unpaid', v_seller, v_t8),
    (v_o3, v_user, 'confirmed', 'table', 'table', 40, 'unpaid', v_seller, v_t9);

  insert into public.table_orders (seller_id, table_number, items, status)
  values (
    v_seller::text,
    8,
    '[{"id":"item-a","name":"cay"},{"id":"item-b","name":"su"}]'::jsonb,
    'new'
  );

  insert into public.table_payments (id, seller_id, table_number, session_key, amount)
  values
    (v_pay_src, v_seller, 8, 'pay-src', 25),
    (v_pay_dst, v_seller, 9, 'pay-dst', 10);

  -- Partial transfer moves one table_orders item and leaves orders and payments.
  v_result := public.transfer_table_orders(
    v_seller, 8, 9, 'items', '["item-a"]'::jsonb, null, null, 'partial'
  );
  if (v_result->>'moved_count')::int <> 1 then
    raise exception 'partial moved_count %', v_result;
  end if;
  if (select table_id from public.orders where id = v_o1) <> v_t8
     or (select table_id from public.orders where id = v_o2) <> v_t8
     or (select table_id from public.orders where id = v_o3) <> v_t9 then
    raise exception 'partial transfer moved orders';
  end if;
  if (select table_number from public.table_payments where id = v_pay_src) <> 8
     or (select table_number from public.table_payments where id = v_pay_dst) <> 9 then
    raise exception 'partial transfer moved payments';
  end if;
  if exists (
    select 1 from public.table_orders
    where table_number = 8
      and items @> '[{"id":"item-a"}]'::jsonb
  ) or not exists (
    select 1 from public.table_orders
    where table_number = 9
      and items @> '[{"id":"item-a"}]'::jsonb
  ) then
    raise exception 'partial items were not split';
  end if;

  -- Full transfer of two orders onto an occupied table. Destination order stays.
  v_result := public.transfer_table_orders(
    v_seller, 8, 9, 'full', '[]'::jsonb, null, null, 'full-merge'
  );
  if (v_result->>'moved_count')::int < 2 then
    raise exception 'full merge moved_count %', v_result;
  end if;
  select count(*) into v_count
  from public.orders
  where table_id = v_t9 and id in (v_o1, v_o2, v_o3);
  if v_count <> 3 then
    raise exception 'occupied merge lost or skipped an order: %', v_count;
  end if;
  select total_amount into v_total from public.orders where id = v_o3;
  if v_total <> 40 then
    raise exception 'destination order was overwritten';
  end if;
  select table_number into v_table from public.table_payments where id = v_pay_src;
  if v_table <> 9 then
    raise exception 'source payment did not follow the full transfer';
  end if;
  select table_number into v_table from public.table_payments where id = v_pay_dst;
  if v_table <> 9 then
    raise exception 'destination payment was removed';
  end if;

  -- Different branch fails before any write.
  begin
    perform public.transfer_table_orders(
      v_seller, 9, 3, 'full', '[]'::jsonb, null, null, 'branch'
    );
    raise exception 'different branch was accepted';
  exception
    when others then
      if sqlerrm not like '%farklı şubede%' then
        raise;
      end if;
  end;
  select count(*) into v_count from public.orders where table_id = v_t9;
  if v_count <> 3 then
    raise exception 'failed branch transfer changed orders';
  end if;

  -- A failure after the writes rolls the whole transfer back.
  begin
    perform public.transfer_table_orders(
      v_seller, 9, 8, 'full', '[]'::jsonb, null, null, 'fail-after-write'
    );
    raise exception 'blocked log insert was accepted';
  exception
    when others then
      if sqlerrm not like '%log blocked%' then
        raise;
      end if;
  end;
  select count(*) into v_count from public.orders where table_id = v_t9;
  if v_count <> 3 then
    raise exception 'rolled back transfer left orders on the source: %', v_count;
  end if;
  select table_number into v_table from public.table_payments where id = v_pay_src;
  if v_table <> 9 then
    raise exception 'rolled back transfer moved a payment';
  end if;
end;
$$;
