-- Read-only. Beklenen: malls var, mall_floors ve mall_units yok.

select to_regclass('public.malls') as malls,
       to_regclass('public.mall_floors') as mall_floors,
       to_regclass('public.mall_units') as mall_units,
       to_regclass('public.mall_members') as mall_members;

select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'malls'
  and column_name in ('status', 'is_verified', 'opening_hours', 'logo_url', 'cover_url')
order by column_name;
