-- After the follow trigger: same order id, same print job ids, destination table.
do $$
declare
  v_bill integer;
  v_bill_count integer;
  v_table uuid;
  v_closed uuid;
  v_delivery uuid;
  v_other uuid;
  v_orders integer;
  v_jobs integer;
  v_pending_status text;
  v_pending_label text;
  v_pending_number integer;
  v_printed_label text;
  v_printed_status text;
  v_partial_table uuid;
  v_partial_label text;
  v_manage_table uuid;
  v_view_table uuid;
  v_view_bill integer;
  v_view_label text;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.seed_wrong_table_case();

  perform public.transfer_table_orders_v2(
    '11111111-1111-4111-8111-111111111111',
    4,
    7,
    'full',
    '[]'::jsonb,
    null,
    null,
    'yanlis masa'
  );

  select table_number into v_bill
  from public.table_orders
  where id = '11111111-1111-4111-8111-111111111140';
  select count(*) into v_bill_count
  from public.table_orders
  where seller_id = '11111111-1111-4111-8111-111111111111'
    and table_number = 7
    and id = '11111111-1111-4111-8111-111111111140';
  select table_id into v_table
  from public.orders
  where id = '11111111-1111-4111-8111-111111111141';
  select table_id into v_closed
  from public.orders
  where id = '11111111-1111-4111-8111-111111111142';
  select table_id into v_delivery
  from public.orders
  where id = '11111111-1111-4111-8111-111111111143';
  select table_id into v_other
  from public.orders
  where id = '44444444-4444-4444-8444-444444444441';
  select count(*) into v_orders
  from public.orders
  where restaurant_id = '11111111-1111-4111-8111-111111111111';
  select count(*) into v_jobs
  from public.print_jobs
  where order_id = '11111111-1111-4111-8111-111111111141';
  select status, payload ->> 'display_table_label', (payload ->> 'table_number')::integer
    into v_pending_status, v_pending_label, v_pending_number
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111151';
  select status, payload ->> 'display_table_label'
    into v_printed_status, v_printed_label
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111152';

  if v_bill is distinct from 7
     or v_bill_count is distinct from 1
     or v_table is distinct from '11111111-1111-4111-8111-111111111107'
     or v_closed is distinct from '11111111-1111-4111-8111-111111111104'
     or v_delivery is distinct from '11111111-1111-4111-8111-111111111104'
     or v_other is distinct from '44444444-4444-4444-8444-444444444404'
     or v_orders is distinct from 6
     or v_jobs is distinct from 2
     or v_pending_status is distinct from 'pending'
     or v_pending_label is distinct from 'Bahçe 2'
     or v_pending_number is distinct from 7
     or v_printed_status is distinct from 'printed'
     or v_printed_label is distinct from 'Salon 4'
  then
    raise exception
      'full move failed bill=% count=% table=% closed=% delivery=% other=% orders=% jobs=% pending=% % % printed=% %',
      v_bill, v_bill_count, v_table, v_closed, v_delivery, v_other, v_orders,
      v_jobs, v_pending_status, v_pending_label, v_pending_number,
      v_printed_status, v_printed_label;
  end if;

  begin
    perform public.transfer_table_orders_v2(
      '11111111-1111-4111-8111-111111111111',
      4,
      7,
      'full',
      '[]'::jsonb,
      null,
      null,
      null
    );
    raise exception 'second transfer created another move';
  exception
    when others then
      if sqlerrm not like '%Aktarılacak açık sipariş%' then
        raise;
      end if;
  end;

  if (select count(*) from public.orders
      where restaurant_id = '11111111-1111-4111-8111-111111111111') <> 6
     or (select count(*) from public.print_jobs
         where order_id = '11111111-1111-4111-8111-111111111141') <> 2
  then
    raise exception 'second transfer duplicated a row';
  end if;

  perform public.seed_wrong_table_case();
  perform public.transfer_table_orders_v2(
    '11111111-1111-4111-8111-111111111111',
    8,
    9,
    'partial',
    '["tea"]'::jsonb,
    null,
    null,
    null
  );
  select table_id into v_partial_table
  from public.orders
  where id = '11111111-1111-4111-8111-111111111181';
  select payload ->> 'display_table_label' into v_partial_label
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111181';
  if v_partial_table is distinct from '11111111-1111-4111-8111-111111111108'
     or v_partial_label is distinct from 'Salon 8'
     or (select count(*) from public.print_jobs
         where order_id = '11111111-1111-4111-8111-111111111181') <> 1
     or (select count(*) from public.orders
         where id = '11111111-1111-4111-8111-111111111181') <> 1
  then
    raise exception 'partial move followed the kitchen row table=% label=%',
      v_partial_table, v_partial_label;
  end if;

  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform public.seed_wrong_table_case();
  perform public.transfer_table_orders_v2(
    '11111111-1111-4111-8111-111111111111',
    14,
    15,
    'full',
    '[]'::jsonb,
    null,
    null,
    null
  );
  select table_id into v_manage_table
  from public.orders
  where id = '11111111-1111-4111-8111-111111111191';
  if v_manage_table is distinct from '11111111-1111-4111-8111-111111111115'
     or (select count(*) from public.print_jobs
         where id = '11111111-1111-4111-8111-111111111191'
           and status = 'pending'
           and (payload ->> 'table_number')::integer = 15) <> 1
  then
    raise exception 'manageOrders move failed table=%', v_manage_table;
  end if;

  perform set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
  perform public.seed_wrong_table_case();
  perform public.transfer_table_orders_v2(
    '11111111-1111-4111-8111-111111111111',
    16,
    17,
    'full',
    '[]'::jsonb,
    null,
    null,
    null
  );
  select table_number into v_view_bill
  from public.table_orders
  where id = '11111111-1111-4111-8111-111111111116';
  select table_id into v_view_table
  from public.orders
  where id = '11111111-1111-4111-8111-111111111192';
  select payload ->> 'display_table_label' into v_view_label
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111193';
  if v_view_bill is distinct from 17
     or v_view_table is distinct from '11111111-1111-4111-8111-111111111116'
     or v_view_label is distinct from 'Masa 16'
     or (select count(*) from public.print_jobs
         where order_id = '11111111-1111-4111-8111-111111111192') <> 1
  then
    raise exception 'view-only kitchen row moved bill=% table=% label=%',
      v_view_bill, v_view_table, v_view_label;
  end if;
end
$$;
