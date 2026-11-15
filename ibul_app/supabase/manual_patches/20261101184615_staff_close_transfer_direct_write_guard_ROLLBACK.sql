-- DO NOT APPLY unless 20261101184615 was applied and must be reversed.
-- Restores the staff write guard saved before the close/transfer check.
-- Orders, payments, staff rows, and print jobs are not deleted.

begin;

do $$
declare
  rec record;
  restored integer := 0;
begin
  for rec in
    select signature, definition
    from public.ibul_function_patch_backup
    where patch_name = '20261101184615'
    order by signature
  loop
    execute rec.definition;
    restored := restored + 1;
  end loop;
  if restored = 0 then
    raise exception 'Yedek fonksiyon tanımı yok. Eski gövde yazılmadı.';
  end if;
  if position(
    'Hesabı kesme yetkisi yok.' in pg_get_functiondef('public.guard_restaurant_staff_order_write()'::regprocedure)
  ) > 0 then
    raise exception 'Hesap kesme koruması geri alınamadı.';
  end if;
end $$;

commit;
