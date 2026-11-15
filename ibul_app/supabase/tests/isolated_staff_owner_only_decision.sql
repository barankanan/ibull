-- Throwaway database only. Does not connect to supabase.co.
-- Load lines 1–309 of isolated_staff_close_transfer_guard.sql first.
-- Decision: the waiter keeps order and kitchen print. Close, transfer,
-- and staff management stay with the owner. No permission is granted.

update public.store_sub_admins
set permissions = array['viewOrders','manageOrders','manageProducts','manageSupport']
where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';

\ir ../migrations/2026110117_staff_operation_permissions.sql

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();

drop trigger if exists restaurant_staff_write_guard on public.print_jobs;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.print_jobs
  for each row execute function public.guard_restaurant_staff_order_write();

\ir ../migrations/20261101184615_staff_close_transfer_direct_write_guard.sql
\ir ../manual_patches/2026110119_staff_manage_permission.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
  customer_order_id uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';
  table_id uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd1';
begin
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders','manageProducts','manageSupport'] then
    raise exception 'decision changed the active waiter permissions';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     && array['closeBill','transferTable','manageStaff'] then
    raise exception 'decision granted a forbidden permission';
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

  begin
    delete from public.table_orders where id = order_id;
    raise exception 'old client delete was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set status = 'closed' where id = order_id;
    raise exception 'old client status close was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set status = 'archived' where id = order_id;
    raise exception 'live close archive write was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.table_orders set table_number = 2 where id = order_id;
    raise exception 'old client transfer was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.table_order_history (seller_id, table_number, status, session_key)
    values (destina, 1, 'closed', 'old-client');
    raise exception 'old client history insert was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.close_table_with_history(destina, 1, 'cash');
    raise exception 'waiter close RPC was accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, 'waiter', null);
    raise exception 'waiter transfer RPC was accepted';
  exception when insufficient_privilege then null;
  end;
  if (select status from public.table_orders where id = order_id) <> 'preparing'
     or (select table_number from public.table_orders where id = order_id) <> 1 then
    raise exception 'waiter order or print path changed the table order';
  end if;
  if not exists (
    select 1 from public.print_jobs
    where print_jobs.order_id = customer_order_id and status = 'pending'
  ) then
    raise exception 'waiter kitchen print job was not stored';
  end if;

  perform set_config('request.jwt.claim.sub', owner::text, true);
  update public.table_orders set status = 'archived' where id = order_id;
  insert into public.table_order_history (seller_id, table_number, status, session_key)
  values (destina, 1, 'archived', 'owner-close');
  if (select status from public.table_orders where id = order_id) <> 'archived' then
    raise exception 'owner archive close was blocked';
  end if;
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"ana"}]'::jsonb, 'sent')
  returning id into order_id;
  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, owner, 'owner', null);
  if (select table_number from public.table_orders where id = order_id) <> 2 then
    raise exception 'owner transfer was blocked';
  end if;
  perform public.close_table_with_history(destina, 2, 'cash');
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'owner close RPC was blocked';
  end if;
  raise notice 'OWNER_ONLY_DECISION_OK';
end $$;

\ir ../manual_patches/20261101_safe_rollback_keep_close_guard.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
begin
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0 then
    raise exception 'safe rollback left manageStaff';
  end if;
  if position('restaurant_staff_may_operate' in pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure)) > 0 then
    raise exception 'safe rollback left the new close gate';
  end if;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[]'::jsonb, 'sent')
  returning id into order_id;
  begin
    update public.table_orders set status = 'archived' where id = order_id;
    raise exception 'safe rollback allowed waiter archive close';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.table_orders where id = order_id;
    raise exception 'safe rollback allowed waiter delete';
  exception when insufficient_privilege then null;
  end;
  update public.table_orders set status = 'preparing' where id = order_id;
  perform set_config('request.jwt.claim.sub', owner::text, true);
  perform public.close_table_with_history(destina, 1, 'cash');
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'safe rollback blocked the owner close';
  end if;
  raise notice 'SAFE_ROLLBACK_KEEPS_GUARD_OK';
end $$;
