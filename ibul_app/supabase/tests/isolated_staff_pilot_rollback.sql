-- Throwaway database, after isolated_staff_operation_permissions.sql and 0119.
-- Restores both patches and checks that business rows stay.

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0 then
    raise exception '0119 was not applied';
  end if;
  update public.store_sub_admins
  set permissions = array['manageStaff','viewOrders']
  where auth_user_id = waiter;
  if not exists (
    select 1 from public.store_sub_admins
    where auth_user_id = waiter and 'manageStaff' = any(permissions)
  ) then
    raise exception 'owner-granted manageStaff was rejected';
  end if;
end $$;

\ir ../manual_patches/2026110119_staff_manage_permission_ROLLBACK.sql

do $$
declare
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  orders_before integer;
  payments_before integer;
  staff_before integer;
  prints_before integer;
  order_id uuid;
  print_id uuid;
begin
  select count(*) into orders_before from public.orders;
  select count(*) into payments_before from public.table_payments;
  select count(*) into staff_before from public.store_sub_admins;
  select count(*) into prints_before from public.print_jobs;
  select id into order_id from public.orders;
  select id into print_id from public.print_jobs;
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0 then
    raise exception 'manageStaff remained after its rollback';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['manageStaff']
    where auth_user_id = waiter;
    raise exception 'manageStaff was still accepted';
  exception when invalid_parameter_value then null;
  end;
  update public.store_sub_admins
  set permissions = array['transferTable','closeBill']
  where auth_user_id = waiter;

  perform set_config('rollback.orders', orders_before::text, false);
  perform set_config('rollback.payments', payments_before::text, false);
  perform set_config('rollback.staff', staff_before::text, false);
  perform set_config('rollback.prints', prints_before::text, false);
  perform set_config('rollback.order_id', order_id::text, false);
  perform set_config('rollback.print_id', print_id::text, false);
end $$;

\ir ../manual_patches/2026110117_staff_operation_permissions_ROLLBACK.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  close_def text;
  transfer_def text;
begin
  close_def := pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure);
  transfer_def := pg_get_functiondef('public.transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)'::regprocedure);
  if position('Sipariş yönetme yetkisi yok.' in close_def) = 0
     or position('Yetkisiz işlem.' in close_def) = 0
     or position('restaurant_staff_may_operate' in close_def) > 0 then
    raise exception 'close function was not restored';
  end if;
  if position('p_seller_id <> auth.uid()' in transfer_def) = 0
     or position('restaurant_staff_may_operate' in transfer_def) > 0 then
    raise exception 'transfer function was not restored';
  end if;
  if to_regprocedure('public.record_table_payment(uuid,integer,text,numeric,text,boolean,text,text,uuid,text,text)') is not null then
    raise exception 'payment RPC remained after rollback';
  end if;
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0
     or position('closeBill' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0 then
    raise exception 'permission list was not restored';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['closeBill']
    where auth_user_id = waiter;
    raise exception 'closeBill was still accepted after rollback';
  exception when invalid_parameter_value then null;
  end;
  if (select count(*) from public.orders) <> current_setting('rollback.orders')::integer
     or (select count(*) from public.table_payments) <> current_setting('rollback.payments')::integer
     or (select count(*) from public.store_sub_admins) <> current_setting('rollback.staff')::integer
     or (select count(*) from public.print_jobs) <> current_setting('rollback.prints')::integer then
    raise exception 'rollback deleted or added business rows';
  end if;
  if not exists (select 1 from public.orders where id = current_setting('rollback.order_id')::uuid)
     or not exists (select 1 from public.print_jobs where id = current_setting('rollback.print_id')::uuid) then
    raise exception 'rollback removed an order or print job';
  end if;
  if not exists (select 1 from public.store_sub_admins where auth_user_id = waiter)
     or not exists (select 1 from public.table_payments where seller_id = destina) then
    raise exception 'rollback removed staff or payments';
  end if;
  raise notice 'PILOT_ROLLBACK_OK';
end $$;
