-- Throwaway database only. Does not connect to supabase.co.
-- Load the live-shaped fixture first (lines 1–309 of
-- isolated_staff_close_transfer_guard.sql), then this file.
-- Required order: 2026110117 → 20261101184615 → 2026110119.

do $$
declare
  close_gate text := $c$IF NOT public.restaurant_has_permission(p_seller_id, 'manageOrders') OR NOT public.restaurant_table_number_access(p_seller_id,p_table_number) THEN
    RAISE EXCEPTION 'Sipariş yönetme yetkisi yok.' USING ERRCODE='42501';
  END IF;$c$;
  actor_gate text := $a$IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;$a$;
  transfer_gate text := $t$if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;$t$;
  close_body text;
  close_patched text;
  transfer_patched text;
begin
  close_body := close_gate || E'\n' || actor_gate;
  close_patched := regexp_replace(
    close_body,
    'IF NOT public\.restaurant_has_permission\(p_seller_id, ''manageOrders''\) OR NOT public\.restaurant_table_number_access\(p_seller_id,p_table_number\) THEN[[:space:]]*RAISE EXCEPTION ''Sipariş yönetme yetkisi yok\.'' USING ERRCODE=''42501'';[[:space:]]*END IF;',
    '',
    'in'
  );
  close_patched := regexp_replace(
    close_patched,
    'IF[[:space:]]+auth\.uid\(\)[[:space:]]+IS[[:space:]]+NULL[[:space:]]+OR[[:space:]]+NOT[[:space:]]+v_actor_authorized[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+''Yetkisiz işlem\.''[[:space:]]+USING[[:space:]]+ERRCODE[[:space:]]*=[[:space:]]*''42501'';[[:space:]]*END[[:space:]]+IF;',
    'perform public.restaurant_staff_may_operate(p_seller_id, ''closeBill'', p_table_number);',
    'in'
  );
  if position('Sipariş yönetme yetkisi yok.' in close_patched) > 0
     or position('restaurant_staff_may_operate' in close_patched) = 0 then
    raise exception 'live close gate does not match 2026110117';
  end if;
  transfer_patched := regexp_replace(
    transfer_gate,
    'if[[:space:]]+p_seller_id[[:space:]]*<>[[:space:]]*auth\.uid\(\)[[:space:]]+then[[:space:]]+raise[[:space:]]+exception[[:space:]]+[^;]*;[[:space:]]*end[[:space:]]+if;',
    'perform public.restaurant_staff_may_operate(p_seller_id, ''transferTable'', p_from_table);',
    'in'
  );
  if transfer_patched = transfer_gate
     or position('restaurant_staff_may_operate' in transfer_patched) = 0 then
    raise exception 'live transfer gate does not match 2026110117';
  end if;
  if position(actor_gate in actor_gate) = 0 then
    raise exception 'actor gate fixture missing';
  end if;
  raise notice 'LIVE_ANCHOR_OK';
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  order_id uuid;
begin
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception 'checkpoint 0117: waiter permissions changed';
  end if;
  if position('closeBill' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0
     or position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0 then
    raise exception 'checkpoint 0117: permission list is not the expected intermediate list';
  end if;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"corba"}]'::jsonb, 'sent')
  returning id into order_id;
  update public.table_orders set status = 'preparing' where id = order_id;
  begin
    perform public.close_table_with_history(destina, 1, 'cash');
    raise exception 'checkpoint 0117: close RPC allowed without closeBill';
  exception when insufficient_privilege then null;
  end;
  if not exists (select 1 from public.table_orders where id = order_id and status = 'preparing') then
    raise exception 'checkpoint 0117: denied close changed the order';
  end if;
  delete from public.table_orders where id = order_id;
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'checkpoint 0117: direct delete was already closed; sequence is wrong';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['viewOrders','manageOrders','manageStaff']
    where auth_user_id = waiter;
    raise exception 'checkpoint 0117: manageStaff was stored before 0119';
  exception when sqlstate '22023' then null;
  end;
  update public.store_sub_admins
  set permissions = array['viewOrders','manageOrders']
  where auth_user_id = waiter;
  raise notice 'AFTER_0117_OK';
end $$;

drop trigger if exists restaurant_staff_write_guard on public.print_jobs;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.print_jobs
  for each row execute function public.guard_restaurant_staff_order_write();
drop trigger if exists restaurant_staff_write_guard on public.orders;
create trigger restaurant_staff_write_guard
  before insert or update or delete on public.orders
  for each row execute function public.guard_restaurant_staff_order_write();

\ir ../migrations/20261101184615_staff_close_transfer_direct_write_guard.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  assistant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  owner uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  order_id uuid;
  survivor_id uuid;
  history_id uuid;
  customer_order_id uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';
  table_id uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd1';
  guard_def text;
begin
  guard_def := pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure);
  if position('print_jobs' in guard_def) = 0
     or position('Hesabı kesme yetkisi yok.' in guard_def) = 0
     or position('Masa aktarma yetkisi yok.' in guard_def) = 0
     or position('Personel sipariş yetkisi yok.' in guard_def) = 0 then
    raise exception 'checkpoint guard: print path or new gates missing';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders'] then
    raise exception 'checkpoint guard: waiter permissions changed';
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
  if not exists (select 1 from public.print_jobs where print_jobs.order_id = customer_order_id) then
    raise exception 'checkpoint guard: manageOrders could not write a print job';
  end if;

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
    update public.table_orders set table_number = 2 where id = order_id;
    raise exception 'old client transfer was accepted';
  exception when insufficient_privilege then null;
  end;
  if (select status from public.table_orders where id = order_id) <> 'preparing'
     or (select table_number from public.table_orders where id = order_id) <> 1 then
    raise exception 'old client write changed the order';
  end if;

  update public.store_sub_admins
  set permissions = array['viewOrders','manageOrders','closeBill','transferTable']
  where auth_user_id = waiter;
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"tatli"}]'::jsonb, 'sent')
  returning id into survivor_id;
  delete from public.table_orders where id = survivor_id;
  if exists (select 1 from public.table_orders where id = survivor_id) then
    raise exception 'closeBill cleanup delete was blocked';
  end if;
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 1, '[{"name":"tatli"}]'::jsonb, 'sent')
  returning id into survivor_id;
  update public.table_orders set status = 'closed' where id = survivor_id;
  if (select status from public.table_orders where id = survivor_id) <> 'closed' then
    raise exception 'closeBill cleanup status update was blocked';
  end if;
  insert into public.table_order_history (seller_id, table_number, status, session_key)
  values (destina, 1, 'closed', 'cleanup-a')
  returning id into history_id;
  insert into public.table_order_history (seller_id, table_number, status, session_key)
  values (destina, 1, 'closed', 'cleanup-a');
  delete from public.table_order_history where id = history_id;
  if exists (select 1 from public.table_order_history where id = history_id) then
    raise exception 'closeBill history cleanup was blocked';
  end if;
  update public.orders set status = 'closed' where id = customer_order_id;
  if (select status from public.orders where id = customer_order_id) <> 'closed' then
    raise exception 'customer order close was blocked for manageOrders';
  end if;
  perform public.transfer_table_orders(destina, 1, 2, 'full', '[]'::jsonb, waiter, 'waiter', null);
  if (select table_number from public.table_orders where id = order_id) <> 2 then
    raise exception 'transferTable RPC did not move the order';
  end if;
  perform public.close_table_with_history(destina, 2, 'cash');
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'closeBill RPC did not remove the transferred order';
  end if;
  update public.store_sub_admins
  set permissions = array['viewOrders','closeBill']
  where auth_user_id = assistant;
  perform set_config('request.jwt.claim.sub', assistant::text, true);
  begin
    insert into public.table_orders (seller_id, table_number, items, status)
    values (destina::text, 1, '[]'::jsonb, 'sent');
    raise exception 'assistant without manageOrders took an order';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.print_jobs (id, restaurant_id, order_id, status)
    values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3', destina, customer_order_id, 'pending');
    raise exception 'assistant without manageOrders wrote a print job';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', owner::text, true);
  if exists (select 1 from public.print_jobs where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee3') then
    raise exception 'rejected print job was stored';
  end if;
  raise notice 'AFTER_184615_OK';
end $$;

\ir ../manual_patches/2026110119_staff_manage_permission.sql

do $$
declare
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  assistant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
begin
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0
     or position('closeBill' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0 then
    raise exception 'checkpoint 0119: permission list incomplete';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['viewOrders','manageStaff','notAPermission']
    where auth_user_id = assistant;
    raise exception 'checkpoint 0119: unknown permission stored';
  exception when sqlstate '22023' then null;
  end;
  update public.store_sub_admins
  set permissions = array['viewOrders','manageStaff']
  where auth_user_id = assistant;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders','closeBill','transferTable'] then
    raise exception 'checkpoint 0119: explicit waiter grant was overwritten';
  end if;
  raise notice 'AFTER_0119_OK';
end $$;

\ir ../manual_patches/2026110119_staff_manage_permission_ROLLBACK.sql
\ir ../manual_patches/20261101184615_staff_close_transfer_direct_write_guard_ROLLBACK.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  order_id uuid;
begin
  if position('manageStaff' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) > 0 then
    raise exception '0119 rollback left manageStaff';
  end if;
  if position('closeBill' in pg_get_functiondef('public.validate_restaurant_staff_membership()'::regprocedure)) = 0 then
    raise exception '0119 rollback removed closeBill';
  end if;
  if position('Hesabı kesme yetkisi yok.' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)) > 0 then
    raise exception 'guard rollback left the close gate';
  end if;
  if position('print_jobs' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)) = 0 then
    raise exception 'guard rollback removed the print path';
  end if;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  insert into public.table_orders (seller_id, table_number, items, status)
  values (destina::text, 2, '[]'::jsonb, 'sent')
  returning id into order_id;
  delete from public.table_orders where id = order_id;
  if exists (select 1 from public.table_orders where id = order_id) then
    raise exception 'guard rollback did not reopen direct delete';
  end if;
  raise notice 'ROLLBACK_REOPENS_DIRECT_WRITE';
end $$;

\ir ../manual_patches/2026110117_staff_operation_permissions_ROLLBACK.sql

do $$
declare
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
begin
  if position('restaurant_staff_may_operate' in pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure)) > 0 then
    raise exception '0117 rollback left the new close gate';
  end if;
  if position('Sipariş yönetme yetkisi yok.' in pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure)) = 0 then
    raise exception '0117 rollback did not restore the live close gate';
  end if;
  if (select permissions from public.store_sub_admins where auth_user_id = waiter)
     <> array['viewOrders','manageOrders','closeBill','transferTable'] then
    raise exception '0117 rollback changed stored permissions';
  end if;
  begin
    update public.store_sub_admins
    set permissions = array['viewOrders','manageOrders','closeBill']
    where auth_user_id = waiter;
    raise exception '0117 rollback still accepted closeBill';
  exception when sqlstate '22023' then null;
  end;
  update public.store_sub_admins
  set permissions = array['viewOrders','manageOrders']
  where auth_user_id = waiter;
  raise notice 'TRANSITION_ORDER_OK';
end $$;
