-- Izole PostgreSQL. Sentetik kimlikler. Uretime baglanmaz.
-- Canli (salt-okunur okunan) politika/tetikleyici/fonksiyon kumesini taklit eder, sonra draft'i uygular.
\set ON_ERROR_STOP on
create schema auth;
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$; do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$; do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;
create table public.stores (seller_id uuid primary key);
create table public.store_sub_admins (store_id uuid, auth_user_id uuid, status text, permissions text[]);
create table public.store_tables (id uuid primary key default gen_random_uuid(), seller_id uuid, table_number int);
create table public.table_orders (id uuid primary key default gen_random_uuid(), seller_id text, table_number int,
  status text, items jsonb, revision int, last_edit_summary jsonb, last_edit_note text, created_at timestamptz default now(), updated_at timestamptz);
create table public.table_order_history (
  id uuid primary key default gen_random_uuid(), original_order_id uuid, seller_id uuid not null, table_number int,
  items jsonb default '[]', status text, revision int, last_edit_summary jsonb, last_edit_note text,
  payment_method text, payment_note text, waiter_id uuid, waiter_name text, grand_total numeric, session_key text,
  opened_at timestamptz, closed_at timestamptz, created_at timestamptz, archived_orders jsonb,
  display_table_label text, table_area_name text, updated_at timestamptz);
alter table public.table_order_history enable row level security;
-- Supabase varsayilan yetkileri (canlida gorulen)
grant usage on schema public, auth to anon, authenticated, service_role;
grant all on public.table_order_history to anon, authenticated, service_role;
grant select on public.stores, public.store_sub_admins, public.store_tables, public.table_orders to authenticated;
grant all on public.table_orders to authenticated;
create function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable security definer set search_path to public as $$
  select auth.uid() is not null and (
    exists(select 1 from public.stores where seller_id = p_restaurant_id and seller_id = auth.uid())
    or exists(select 1 from public.store_sub_admins sa where sa.store_id = p_restaurant_id
      and sa.status = 'active' and sa.auth_user_id = auth.uid()
      and (p_permission is null or p_permission = any(sa.permissions))));
$$;
create function public.user_can_access_restaurant(p_restaurant_id uuid) returns boolean
language sql stable security definer set search_path to public as
$$ select public.restaurant_has_permission(p_restaurant_id,'manageOrders') or public.restaurant_has_permission(p_restaurant_id,'viewOrders') $$;
create function public.is_managed_restaurant_staff() returns boolean language sql stable security definer set search_path to public as
$$ select exists(select 1 from public.store_sub_admins sa where sa.auth_user_id = auth.uid()) $$;
create function public.restaurant_table_access(r uuid, t uuid) returns boolean language sql stable as $$ select true $$;
create function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable security definer set search_path to public as
$$ select auth.uid()=p_restaurant_id or exists(select 1 from public.store_sub_admins sa where sa.store_id=p_restaurant_id and sa.auth_user_id=auth.uid()) $$;
-- CANLI restaurant_staff_may_operate (birebir)
create function public.restaurant_staff_may_operate(p_restaurant_id uuid, p_permission text, p_table_number integer)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'Yetkisiz istek.' using errcode = '42501'; end if;
  if not public.restaurant_has_permission(p_restaurant_id, p_permission) then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501'; end if;
  if p_table_number is not null and not public.restaurant_table_number_access(p_restaurant_id, p_table_number) then
    raise exception 'Bu masada işlem yetkiniz yok.' using errcode = '42501'; end if;
end $$;
-- CANLI guard tetikleyicisi: table_order_history dallari birebir
create function public.guard_restaurant_staff_order_write() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare r uuid; t uuid; row_data jsonb;
begin
  if not public.is_managed_restaurant_staff() then if tg_op='DELETE' then return old; else return new; end if; end if;
  if tg_op='DELETE' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  r:=(row_data->>'seller_id')::uuid;
  select id into t from public.store_tables where seller_id=r and table_number=(row_data->>'table_number')::integer limit 1;
  if tg_op='UPDATE' and ((to_jsonb(old)->>'seller_id') is distinct from (row_data->>'seller_id')) then
    raise exception 'İşletme veya masa kimliği değiştirilemez.' using errcode='42501'; end if;
  if tg_table_name = 'table_order_history' and tg_op in ('INSERT','DELETE') then
    if r is null or not public.restaurant_has_permission(r,'closeBill') or not public.restaurant_table_access(r,t) then
      raise exception 'Hesabı kesme yetkisi yok.' using errcode='42501'; end if;
  elsif r is null or not public.restaurant_has_permission(r,'manageOrders') or not public.restaurant_table_access(r,t) then
    raise exception 'Personel sipariş yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger restaurant_staff_write_guard before insert or delete or update on public.table_order_history
  for each row execute function public.guard_restaurant_staff_order_write();
-- CANLI politika kumesi
create policy staff_history_read_guard on public.table_order_history as restrictive for select to authenticated
  using ((not public.is_managed_restaurant_staff()) or ((public.restaurant_has_permission(seller_id,'viewOrders') or public.restaurant_has_permission(seller_id,'viewFinance') or public.restaurant_has_permission(seller_id,'manageOrders')) and public.restaurant_table_number_access(seller_id, table_number)));
create policy table_order_history_owner_insert on public.table_order_history for insert to authenticated with check (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));
create policy table_order_history_owner_select on public.table_order_history for select to authenticated using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));
create policy table_order_history_seller_delete on public.table_order_history for delete to public using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));
create policy table_order_history_seller_update on public.table_order_history for update to public using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id)) with check (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));
-- CANLI close_table_orders (yetkisiz govde) + close_table_with_history yer tutucu (imza icin)
create function public.close_table_orders(p_seller_id uuid, p_table_number integer, p_payment_method text default 'cash', p_payment_note text default null, p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
DECLARE v_order record;
BEGIN
  FOR v_order IN SELECT * FROM public.table_orders WHERE seller_id = p_seller_id AND table_number = p_table_number LOOP NULL; END LOOP;
  RETURN '{}'::jsonb;
END $$;
create function public.close_table_with_history(p_seller_id uuid, p_table_number integer, p_payment_method text default 'cash', p_payment_note text default null, p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null)
returns jsonb language sql security definer as $$ select '{}'::jsonb $$;
grant execute on all functions in schema public to public, anon, authenticated;

\set A '''aaaaaaaa-0000-0000-0000-000000000001'''
\set B '''bbbbbbbb-0000-0000-0000-000000000002'''
\set viewer '''cccccccc-0000-0000-0000-000000000003'''
\set manager '''dddddddd-0000-0000-0000-000000000004'''
\set cashier '''eeeeeeee-0000-0000-0000-000000000005'''
insert into public.stores values (:A), (:B);
insert into public.store_sub_admins values
  (:A, :viewer, 'active', '{viewOrders}'),
  (:A, :manager, 'active', '{viewOrders,manageOrders}'),
  (:A, :cashier, 'active', '{viewOrders,manageOrders,closeBill}');
insert into public.store_tables(seller_id, table_number) values (:A,1),(:B,1);
create temp table res(step text, outcome text);
grant all on res to anon, authenticated;
create function pg_temp.as_user(u text) returns void language plpgsql as $$ begin perform set_config('request.jwt.claim.sub', coalesce(u,''), false); end $$;
create function pg_temp.try(step text, sql text) returns void language plpgsql as $$
declare n int; begin
  execute sql; get diagnostics n = row_count;
  insert into res values (step, 'OK rows='||n);
exception when others then insert into res values (step, 'ENGEL '||sqlstate);
end $$;
grant execute on function pg_temp.try(text,text), pg_temp.as_user(text) to public;


-- Senaryo: her calistirmada taze veri, her kullanici icin ayri deneme.
create function pg_temp.reset_data() returns void language plpgsql as $$ begin
  delete from public.table_order_history; truncate public.table_orders;
  insert into public.table_order_history(id, original_order_id, seller_id, table_number, grand_total, payment_method, waiter_name) values
   ('11111111-0000-0000-0000-00000000000a', gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 1, 100, 'cash', 'w'),
   ('22222222-0000-0000-0000-00000000000b', gen_random_uuid(), 'bbbbbbbb-0000-0000-0000-000000000002', 1, 50, 'cash', 'w');
end $$;
create function pg_temp.scenario(phase text) returns void language plpgsql as $$ begin end $$;

\echo '=== FAZ: ONCE (canli durum) ==='
\set ON_ERROR_STOP off
select pg_temp.as_user('');
select pg_temp.reset_data();
truncate res;
set role anon;
select pg_temp.as_user('');
select pg_temp.try('anon close_table_orders(A)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select pg_temp.try('anon history SELECT', 'select * from public.table_order_history');
reset role;
set role authenticated;
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select pg_temp.try('B-sahibi close_table_orders(A)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select pg_temp.try('B-sahibi A gecmisi UPDATE', $q$update public.table_order_history set grand_total=1 where seller_id='aaaaaaaa-0000-0000-0000-000000000001'$q$);
select pg_temp.try('B-sahibi A gecmisi DELETE', $q$delete from public.table_order_history where seller_id='aaaaaaaa-0000-0000-0000-000000000001'$q$);
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select pg_temp.try('viewer UPDATE grand_total', $q$update public.table_order_history set grand_total=1 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('viewer DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('viewer SELECT A', 'select * from public.table_order_history');
select pg_temp.as_user('dddddddd-0000-0000-0000-000000000004');
select pg_temp.try('manager UPDATE grand_total', $q$update public.table_order_history set grand_total=1 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('manager DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.try('sahipA UPDATE grand_total', $q$update public.table_order_history set grand_total=7 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.as_user('eeeeeeee-0000-0000-0000-000000000005');
select pg_temp.try('cashier UPDATE waiter_name', $q$update public.table_order_history set waiter_name='x' where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('cashier DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('cashier close_table_orders(A) yetki', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
reset role;
select step, outcome from res order by 1;

\echo '=== TRUNCATE yetkisi (anon/authenticated) ==='
select has_table_privilege('anon','public.table_order_history','TRUNCATE') anon_trunc, has_table_privilege('authenticated','public.table_order_history','TRUNCATE') auth_trunc;

\echo '=== DRAFT UYGULANIYOR ==='
\set ON_ERROR_STOP on
\i ../drafts/20261123_table_order_history_write_hardening_DRAFT.sql
\set ON_ERROR_STOP off

\echo '=== FAZ: SONRA ==='
select pg_temp.as_user('');
select pg_temp.reset_data();
truncate res;
set role anon;
select pg_temp.as_user('');
select pg_temp.try('anon close_table_orders(A)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select pg_temp.try('anon history SELECT', 'select * from public.table_order_history');
reset role;
set role authenticated;
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select pg_temp.try('B-sahibi close_table_orders(A)', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select pg_temp.try('B-sahibi A gecmisi UPDATE', $q$update public.table_order_history set grand_total=1 where seller_id='aaaaaaaa-0000-0000-0000-000000000001'$q$);
select pg_temp.try('B-sahibi A gecmisi DELETE', $q$delete from public.table_order_history where seller_id='aaaaaaaa-0000-0000-0000-000000000001'$q$);
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select pg_temp.try('viewer UPDATE grand_total', $q$update public.table_order_history set grand_total=1 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('viewer DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('viewer SELECT A', 'select * from public.table_order_history');
select pg_temp.as_user('dddddddd-0000-0000-0000-000000000004');
select pg_temp.try('manager UPDATE grand_total', $q$update public.table_order_history set grand_total=1 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('manager UPDATE waiter_name', $q$update public.table_order_history set waiter_name='y' where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('manager DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.try('sahipA UPDATE grand_total', $q$update public.table_order_history set grand_total=7 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.as_user('eeeeeeee-0000-0000-0000-000000000005');
select pg_temp.try('cashier UPDATE grand_total', $q$update public.table_order_history set grand_total=1 where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('cashier UPDATE waiter_name', $q$update public.table_order_history set waiter_name='x' where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('cashier DELETE', $q$delete from public.table_order_history where id='11111111-0000-0000-0000-00000000000a'$q$);
select pg_temp.try('cashier close_table_orders(A) yetki gecer', $q$select public.close_table_orders('aaaaaaaa-0000-0000-0000-000000000001',1)$q$);
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.try('sahipA audit okur', 'select * from public.table_order_history_audit');
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select pg_temp.try('B-sahibi audit(A) okur', 'select * from public.table_order_history_audit');
reset role;
select step, outcome from res order by 1;
\echo '--- audit satirlari (postgres gorunumu) ---'
select actor::text, op, history_id::text from public.table_order_history_audit order by id;
select has_table_privilege('anon','public.table_order_history','TRUNCATE') anon_trunc, has_table_privilege('authenticated','public.table_order_history','TRUNCATE') auth_trunc;

\echo '=== GERI ALMA ==='
\set ON_ERROR_STOP on
\i ../rollbacks/../drafts/20261123_table_order_history_write_hardening_ROLLBACK_DRAFT.sql
select count(*) as tetikleyici_kalan from pg_trigger where tgrelid='public.table_order_history'::regclass and tgname in ('table_order_history_staff_update_guard','table_order_history_audit_trg');
