-- Throwaway database only. Confirms a forced error undid the atomic script.

do $$
begin
  if exists (
    select 1 from public.store_sub_admins
    where 'transferTable' = any(permissions)
       or 'closeBill' = any(permissions)
       or 'manageStaff' = any(permissions)
  ) then
    raise exception 'forced abort left a new permission';
  end if;
  if (
    select permissions from public.store_sub_admins
    where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'
  ) is distinct from array[
    'viewOrders','manageOrders','manageProducts','manageSupport'
  ]::text[] then
    raise exception 'forced abort changed the waiter permissions';
  end if;
  if position(
       'transferTable' in pg_get_functiondef(
         'public.validate_restaurant_staff_membership()'::regprocedure
       )
     ) > 0
     or position(
       'Hesabı kesme yetkisi yok.' in pg_get_functiondef(
         'public.guard_restaurant_staff_order_write()'::regprocedure
       )
     ) > 0
     or to_regclass('public.restaurant_staff_operation_log') is not null
     or to_regclass('public.ibul_function_patch_backup') is not null then
    raise exception 'forced abort left a schema change';
  end if;
  raise notice 'ATOMIC_ROLLBACK_OK';
end $$;
