-- Proves the double write before the guard is installed.
\set ON_ERROR_STOP on

select public.test_set_actor('11111111-1111-1111-1111-111111111111'::uuid);

select public.approve_waiter_order_request(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'::uuid,
  null
);

do $$
declare
  v_bills integer;
  v_open_orders integer;
  v_jobs integer;
  v_bill_status text;
begin
  select count(*) into v_bills
  from public.table_orders
  where table_number = 4;

  select status into v_bill_status
  from public.table_orders
  where table_number = 4;

  select count(*) into v_open_orders
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1%'
    and status = 'confirmed'
    and order_status = 'sent';

  select count(*) into v_jobs
  from public.print_jobs pj
  join public.orders o on o.id = pj.order_id
  where o.notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1%'
    and pj.status = 'pending';

  if v_bills <> 1 or v_bill_status <> 'sent' or v_open_orders <> 1 or v_jobs <> 1 then
    raise exception
      'kök neden doğrulanamadı bills=% status=% open_orders=% jobs=%',
      v_bills, v_bill_status, v_open_orders, v_jobs;
  end if;
end
$$;
