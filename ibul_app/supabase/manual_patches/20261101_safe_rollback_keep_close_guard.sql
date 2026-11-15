-- Safe rollback for the owner-only close decision.
-- Removes manageStaff, then restores the pre-0117 close, transfer, and
-- validator bodies from ibul_function_patch_backup.
-- It does not restore guard_restaurant_staff_order_write.
-- Restoring that guard reopens direct DELETE and status/table updates
-- for a waiter who has manageOrders.

\ir 2026110119_staff_manage_permission_ROLLBACK.sql
\ir 2026110117_staff_operation_permissions_ROLLBACK.sql

do $$
begin
  if position(
    'Hesabı kesme yetkisi yok.' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)
  ) = 0 then
    raise exception 'Güvenli geri alma hesap kesme korumasını düşürdü. Dur.';
  end if;
  if position(
    'print_jobs' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)
  ) = 0 then
    raise exception 'Güvenli geri alma mutfak baskısı yolunu düşürdü. Dur.';
  end if;
end $$;
