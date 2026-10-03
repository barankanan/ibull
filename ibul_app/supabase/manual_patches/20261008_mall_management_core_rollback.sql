-- Rollback. Satır varsa DROP TABLE çalışmaz ve transaction durur.
-- Gerçek kat veya birim verisi silinmez.

begin;

do $$
begin
  if to_regclass('public.mall_units') is not null
     and exists (select 1 from public.mall_units) then
    raise exception 'Rollback reddedildi: mall_units satır içeriyor. DROP TABLE yapılmadı.';
  end if;
  if to_regclass('public.mall_floors') is not null
     and exists (select 1 from public.mall_floors) then
    raise exception 'Rollback reddedildi: mall_floors satır içeriyor. DROP TABLE yapılmadı.';
  end if;
end $$;

drop function if exists public.delete_mall_unit(uuid, uuid);
drop function if exists public.upsert_mall_unit(uuid, uuid, uuid, text, text, text, text, numeric, integer);
drop function if exists public.delete_mall_floor(uuid, uuid);
drop function if exists public.upsert_mall_floor(uuid, uuid, text, integer, integer);
drop function if exists public.update_mall_profile(uuid, text, text, text, text, text, text, text, text);
drop function if exists public.mall_management_assert_role(uuid, text[]);

drop table if exists public.mall_units;
drop table if exists public.mall_floors;
drop function if exists public.mall_units_require_same_mall();

alter table public.malls drop constraint if exists malls_opening_hours_len;
alter table public.malls drop column if exists opening_hours;

commit;
