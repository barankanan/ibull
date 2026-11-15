-- Hazırlandı, uygulanmadı.
-- manageStaff adını mevcut personel izin doğrulayıcısına ekler.
-- İşletme sahibi, şube, sipariş, ödeme ve baskı satırlarına dokunmaz.
-- Production onayı ve uygulama bu dosyada yoktur.

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
    raise exception 'validate_restaurant_staff_membership kurulu değil; doğrulayıcı yazılmadı.';
  end if;
  if position('manageStaff' in original) > 0 then
    raise exception 'manageStaff zaten izin listesinde; dosya tekrar uygulanmadı.';
  end if;
  if position('manageStoreProfile' in original) = 0 then
    raise exception 'Personel izin listesi tanınmadı; doğrulayıcı yazılmadı.';
  end if;
  patched := replace(
    original,
    '''manageStoreProfile''',
    '''manageStoreProfile'',''manageStaff'''
  );
  if patched = original then
    raise exception 'Personel izin listesine manageStaff eklenemedi.';
  end if;
  execute patched;
end $$;

commit;
