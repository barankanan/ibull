-- Continues on the throwaway database after the permission test and payment race.

\ir ../manual_patches/2026110117_staff_operation_permissions_ROLLBACK.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  waiter uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  close_def text;
begin
  close_def := pg_get_functiondef('public.close_table_with_history(uuid,integer,text,text,uuid,text,text,text,text,text)'::regprocedure);
  if position('p_seller_id <> auth.uid()' in close_def) = 0
     or position('restaurant_staff_may_operate' in close_def) > 0 then
    raise exception 'rollback did not restore the saved close body';
  end if;
  perform set_config('request.jwt.claim.sub', waiter::text, true);
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  update public.store_sub_admins
  set permissions = array['closeBill']
  where auth_user_id = waiter;
  insert into public.table_orders (seller_id, table_number, items)
  values (destina::text, 1, '[{"price":10,"quantity":1}]'::jsonb);
  begin
    perform public.close_table_with_history(destina, 1, 'cash', null, waiter, null, 'after-rollback', null, null, null);
    raise exception 'rollback still allowed staff to close';
  exception when insufficient_privilege then null;
  end;
  if not exists (select 1 from public.table_orders where seller_id = destina::text and table_number = 1) then
    raise exception 'rollback close removed the order';
  end if;
  raise notice 'STAFF_OPERATION_ROLLBACK_OK';
end $$;
