-- Izole: hardening testinden sonra (ayni veritabaninda) cast duzeltmesini dener.
\set ON_ERROR_STOP off
\i isolated_table_order_history_write_hardening.sql
\echo '=== CAST DUZELTMESI: ONCE ==='
insert into public.table_orders(seller_id, table_number, status, items, revision)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 1, 'open', '[{"price":10,"quantity":2},{"price":5,"quantity":1}]', 1);
create temp table res2(step text, outcome text);
grant all on res2 to authenticated;
create or replace function pg_temp.try2(step text, sql text) returns void language plpgsql as $$
begin execute sql; insert into res2 values (step,'OK');
exception when others then insert into res2 values (step,'ENGEL '||sqlstate); end $$;
grant execute on function pg_temp.try2(text,text) to public;
-- hardening geri alma sonrasi tetikleyiciler yok; yetki kapisi fonksiyonda
set role authenticated; select set_config('request.jwt.claim.sub','eeeeeeee-0000-0000-0000-000000000005',false);
select pg_temp.try2('kasiyer close_table_orders (cast ONCE)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
reset role;
\i ../drafts/20261123_close_table_orders_seller_text_cast_DRAFT.sql
\echo '=== SONRA ==='
set role authenticated;
select set_config('request.jwt.claim.sub','eeeeeeee-0000-0000-0000-000000000005',false);
select pg_temp.try2('kasiyer close_table_orders (cast SONRA)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select set_config('request.jwt.claim.sub','cccccccc-0000-0000-0000-000000000003',false);
select pg_temp.try2('viewer close_table_orders (yetki yok)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000002',false);
select pg_temp.try2('baska isletme close_table_orders', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
reset role;
select * from res2 order by 1;
select count(*) history_rows_for_A_table1, coalesce(sum(grand_total),0) toplam from public.table_order_history where seller_id='aaaaaaaa-0000-0000-0000-000000000001' and session_key like 'session_%';
select status from public.table_orders where table_number=1;
