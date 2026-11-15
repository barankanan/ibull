-- DO NOT APPLY unless 2026110119 was applied and must be reversed.
-- Removes only the manageStaff name from the staff permission check.
-- Orders, payments, staff rows, and print jobs are not deleted.

begin;

do $$
declare
  original text;
  patched text;
  fn_signature text;
begin
  select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
  into fn_signature, original
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'validate_restaurant_staff_membership'
  limit 1;
  if fn_signature is null then
    raise exception 'validate_restaurant_staff_membership kurulu değil.';
  end if;
  if position('manageStaff' in original) = 0 then
    raise exception 'manageStaff izin listesinde yok; geri alma yazılmadı.';
  end if;
  patched := replace(
    original,
    '''manageStoreProfile'',''manageStaff''',
    '''manageStoreProfile'''
  );
  if patched = original or position('manageStaff' in patched) > 0 then
    raise exception 'manageStaff geri alınamadı.';
  end if;
  execute patched;
end $$;

commit;
