-- Read-only. Beklenen: tablolar, unique kod, occupied şemada durur, store_branch_id yoktur.

select to_regclass('public.mall_floors') as mall_floors,
       to_regclass('public.mall_units') as mall_units;

select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'mall_units'
  and column_name = 'store_branch_id';

select indexname
from pg_indexes
where schemaname = 'public'
  and indexname in ('mall_floors_mall_name_unique', 'mall_units_mall_code_unique');

select pol.polname
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('mall_floors', 'mall_units')
order by c.relname, pol.polname;

select p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'update_mall_profile',
    'upsert_mall_floor',
    'delete_mall_floor',
    'upsert_mall_unit',
    'delete_mall_unit'
  )
order by p.proname;
