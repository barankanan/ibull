-- DO NOT APPLY. This file is the pre-apply checksum record.
-- Captured read-only on 2026-11-01 from project ihmmixxzqnpamcwmrfibx.
-- The byte-exact restore is the row written to ibul_function_patch_backup
-- in the same transaction, immediately before each function is replaced.
-- After 2026110117, these checksums must match that backup:
--   close_table_with_history(uuid,integer,text,text,uuid,text,text)
--     53162e8a165120695cd7cd0ef4ae18e1
--   transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)
--     130e06abd39b3697d9e9c3e0f776d8c4
--   validate_restaurant_staff_membership()
--     d7fb9f1b57e8d60f3fa5ab2f05a69d7c
-- After 20261101184615, the guard backup must match:
--   guard_restaurant_staff_order_write()
--     906549c4ac3ecb1d401fac32fd95f013
-- Restoring that guard body reopens direct table_orders writes for manageOrders.
-- The safe rollback does not restore it.

begin;

do $$
begin
  raise exception 'Ön hazırlık kontrol toplamı. Bu dosya canlıya uygulanmaz.';
end $$;

commit;
