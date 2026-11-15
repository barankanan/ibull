-- DO NOT APPLY unless 2026110117 was applied and must be reversed.
-- Restores the function text saved immediately before the authorization patch.
-- It does not install the 20260407 or 20260615 bodies from the repository.
-- Payments, orders, history, and the audit log are not deleted.

begin;

do $$
declare
  rec record;
  restored integer := 0;
begin
  for rec in
    select signature, definition
    from public.ibul_function_patch_backup
    where patch_name = '2026110117'
    order by signature
  loop
    execute rec.definition;
    restored := restored + 1;
  end loop;
  if restored = 0 then
    raise exception 'Yedek fonksiyon tanımı yok. Eski gövde yazılmadı.';
  end if;
end $$;

drop policy if exists table_payments_staff_select on public.table_payments;
drop policy if exists table_payments_staff_insert on public.table_payments;
drop trigger if exists guard_table_payment on public.table_payments;
drop function if exists public.guard_table_payment();
drop function if exists public.record_table_payment(
  uuid, integer, text, numeric, text, boolean, text, text, uuid, text, text
);
drop function if exists public.restaurant_staff_may_operate(uuid, text, integer);

commit;
