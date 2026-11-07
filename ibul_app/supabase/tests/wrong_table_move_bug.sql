-- Proves the gap before the follow trigger: the bill moves, the kitchen row
-- and both tickets stay on the original table, and no second row is inserted.
do $$
declare
  v_bill integer;
  v_table uuid;
  v_orders integer;
  v_jobs integer;
  v_pending integer;
  v_printed text;
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
  select table_id into v_table
  from public.orders
  where id = '11111111-1111-4111-8111-111111111141';
  select count(*) into v_orders
  from public.orders
  where restaurant_id = '11111111-1111-4111-8111-111111111111';
  select count(*) into v_jobs from public.print_jobs
  where order_id = '11111111-1111-4111-8111-111111111141';
  select (payload ->> 'table_number')::integer into v_pending
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111151';
  select status into v_printed
  from public.print_jobs
  where id = '11111111-1111-4111-8111-111111111152';

  if v_bill is distinct from 7
     or v_table is distinct from '11111111-1111-4111-8111-111111111104'
     or v_orders is distinct from 6
     or v_jobs is distinct from 2
     or v_pending is distinct from 4
     or v_printed is distinct from 'printed'
  then
    raise exception
      'bug shape drifted bill=% table=% orders=% jobs=% pending=% printed=%',
      v_bill, v_table, v_orders, v_jobs, v_pending, v_printed;
  end if;
end
$$;
