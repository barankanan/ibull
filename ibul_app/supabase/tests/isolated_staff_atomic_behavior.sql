-- Throwaway database only. Runs after the atomic transition has committed.
-- The waiter keeps orders and kitchen print, can transfer inside the branch,
-- and cannot close a bill, manage staff, or transfer outside the branch.

drop trigger if exists restaurant_staff_write_guard on public.print_jobs;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.print_jobs
  for each row execute function public.guard_restaurant_staff_order_write();

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  assistant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
  customer_order_id uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';
  table_id uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd1';
begin
  if (
    select permissions from public.store_sub_admins where auth_user_id = waiter
  ) is distinct from array[
    'viewOrders','manageOrders','manageProducts','manageSupport','transferTable'
  ]::text[] then
    raise exception 'waiter permissions are not the four originals plus transferTable';
  end if;
  if exists (
    select 1 from public.store_sub_admins
    where 'closeBill' = any(permissions) or 'manageStaff' = any(permissions)
  ) then
    raise exception 'closeBill or manageStaff was stored';
  end if;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"corba"}]'::jsonb, 'sent')
  returning id into order_id;
  update public.table_orders set status = 'preparing' where id = order_id;
  insert into public.orders (id, restaurant_id, table_id, status)
  values (customer_order_id, destina, table_id, 'sent');
  insert into public.print_jobs (id, restaurant_id, order_id, status)
  values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee2', destina, customer_order_id, 'pending');

  update public.table_orders set table_number = 2 where id = order_id;
  if (select table_number from public.table_orders where id = order_id) <> 2 then
    raise exception 'same-branch direct transfer did not move the order';
  end if;
  perform public.transfer_table_orders(
    destina, 2, 1, 'full', '[]'::jsonb, waiter, 'waiter', null
  );
  if (select table_number from public.table_orders where id = order_id) <> 1 then
    raise exception 'same-branch RPC transfer did not move the order';
  end if;

  begin
    perform public.transfer_table_orders(
      destina, 1, 3, 'full', '[]'::jsonb, waiter, 'waiter', null
    );
    raise exception 'cross-branch RPC transfer was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set table_number = 3 where id = order_id;
    raise exception 'cross-branch direct transfer was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.close_table_with_history(destina, 1, 'cash');
    raise exception 'close RPC was accepted without closeBill';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.table_orders where id = order_id;
    raise exception 'direct delete was accepted without closeBill';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set status = 'archived' where id = order_id;
    raise exception 'direct archive was accepted without closeBill';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.table_order_history (seller_id, table_number, status, session_key)
    values (destina, 1, 'closed', 'waiter-close');
    raise exception 'history insert was accepted without closeBill';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.store_sub_admins
    set permissions = permissions || array['manageStaff']
    where auth_user_id = waiter;
    raise exception 'manageStaff was stored before 0119';
  exception when sqlstate '22023' then null;
  end;

  if (select table_number from public.table_orders where id = order_id) <> 1
     or (select status from public.table_orders where id = order_id) <> 'preparing'
     or not exists (
       select 1 from public.print_jobs where print_jobs.order_id = customer_order_id
     ) then
    raise exception 'denied operations changed the order or the kitchen ticket';
  end if;

  perform set_config('request.jwt.claim.sub', assistant::text, true);
  begin
    insert into public.table_orders (seller_id, table_number, items, status)
    values (destina::text, 1, '[]'::jsonb, 'sent');
    raise exception 'assistant without manageOrders took an order';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.transfer_table_orders(
      destina, 1, 2, 'full', '[]'::jsonb, assistant, 'assistant', null
    );
    raise exception 'assistant without transferTable moved a table';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', owner::text, true);
  perform public.close_table_with_history(destina, 1, 'cash');
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'owner close did not remove the order';
  end if;
  if (
    select permissions from public.store_sub_admins where auth_user_id = waiter
  ) is distinct from array[
    'viewOrders','manageOrders','manageProducts','manageSupport','transferTable'
  ]::text[] then
    raise exception 'behavior test changed the waiter permissions';
  end if;
  raise notice 'ATOMIC_BEHAVIOR_OK';
end $$;
