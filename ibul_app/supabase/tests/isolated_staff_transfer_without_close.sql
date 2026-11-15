-- Throwaway database only. Does not connect to supabase.co.
-- Load lines 1–309 of isolated_staff_close_transfer_guard.sql first.
-- Applies only 2026110117. Does not grant a production permission.

update public.store_sub_admins
set permissions = array['viewOrders','manageOrders','manageProducts','manageSupport']
where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';

\ir ../migrations/2026110117_staff_operation_permissions.sql

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();

update public.store_sub_admins
set permissions = array['viewOrders','manageOrders','manageProducts','manageSupport','transferTable']
where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
  moved_id uuid;
begin
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders','manageProducts','manageSupport','transferTable'] then
    raise exception 'test waiter permissions are not the prepared grant';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     && array['closeBill','manageStaff'] then
    raise exception 'close or staff permission was included';
  end if;
  if position('closeBill' in pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure)) = 0
     or position('transferTable' in pg_get_functiondef('public.transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)'::regprocedure)) = 0 then
    raise exception '0117 did not install both operation gates';
  end if;

  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"corba"}]'::jsonb, 'sent')
  returning id into order_id;
  update public.table_orders set status = 'preparing' where id = order_id;
  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, 'waiter', null);
  if (select table_number from public.table_orders where id = order_id) <> 2 then
    raise exception 'same-branch transfer failed';
  end if;
  begin
    perform public.transfer_table_orders(destina, 2, 3, 'full', '[]'::jsonb, waiter, 'waiter', null);
    raise exception 'cross-branch transfer was accepted';
  exception when insufficient_privilege then null;
  end;
  if (select table_number from public.table_orders where id = order_id) <> 2 then
    raise exception 'cross-branch transfer moved the order';
  end if;
  begin
    perform public.close_table_with_history(destina, 2, 'cash');
    raise exception 'close RPC succeeded without closeBill';
  exception when insufficient_privilege then null;
  end;
  if not exists (select 1 from public.table_orders where id = order_id and table_number = 2) then
    raise exception 'denied close removed the order';
  end if;

  perform set_config('request.jwt.claim.sub', owner::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"ana"}]'::jsonb, 'sent')
  returning id into moved_id;
  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, owner, 'owner', null);
  perform public.close_table_with_history(destina, 2, 'cash');
  if exists (select 1 from public.table_orders where id = moved_id) then
    raise exception 'owner close was blocked';
  end if;
  raise notice 'TRANSFER_WITHOUT_CLOSE_OK';
end $$;
