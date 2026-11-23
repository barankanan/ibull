-- Isolated PostgreSQL fixture. Synthetic ids only. Does not connect to production.
-- Reproduces the live policy set on table_order_history, then applies the
-- scoped-RLS draft and asserts the outcome.
\set ON_ERROR_STOP on
create schema auth;
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
create table public.stores (seller_id uuid primary key);
create table public.store_sub_admins (store_id uuid, auth_user_id uuid, status text, permissions text[]);
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
$$ select public.restaurant_has_permission(p_restaurant_id,'manageOrders')
   or public.restaurant_has_permission(p_restaurant_id,'viewOrders') $$;
create table public.table_order_history (
  id uuid primary key default gen_random_uuid(), original_order_id uuid not null,
  seller_id uuid not null, table_number int, session_key text, grand_total numeric,
  archived_orders jsonb, items jsonb not null default '[]');
alter table public.table_order_history enable row level security;
grant usage on schema public, auth to authenticated;
grant select, insert, update, delete on public.table_order_history to authenticated;
grant select on public.stores, public.store_sub_admins to authenticated;
grant execute on all functions in schema public to authenticated;
grant execute on function auth.uid() to authenticated;
-- live policy set
create policy table_order_history_authenticated on public.table_order_history for all to authenticated using (true) with check (true);
create policy table_order_history_seller_delete on public.table_order_history for delete to public
  using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));
create policy table_order_history_seller_update on public.table_order_history for update to public
  using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id))
  with check (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));

\set ownerA '''aaaaaaaa-0000-0000-0000-000000000001'''
\set ownerB '''bbbbbbbb-0000-0000-0000-000000000002'''
\set viewer '''cccccccc-0000-0000-0000-000000000003'''
\set noperm '''dddddddd-0000-0000-0000-000000000004'''
\set stranger '''eeeeeeee-0000-0000-0000-000000000005'''
insert into public.stores values (:ownerA), (:ownerB);
insert into public.store_sub_admins values
  (:ownerA, :viewer, 'active', '{viewOrders}'), (:ownerA, :noperm, 'active', '{managePrinters}');
insert into public.table_order_history(original_order_id, seller_id, table_number) values
  (gen_random_uuid(), :ownerA, 1), (gen_random_uuid(), :ownerB, 1);

create function pg_temp.as_user(u text) returns void language plpgsql as
$$ begin perform set_config('request.jwt.claim.sub', u, false); end $$;

\echo '--- ONCE (canli acik): yabanci kullanici ---'
set role authenticated; select pg_temp.as_user('eeeeeeee-0000-0000-0000-000000000005');
select count(*) as yabanci_okur_once from public.table_order_history;
reset role;

\i ../drafts/20261123_table_order_history_rls_scope_DRAFT.sql

\echo '--- SONRA ---'
set role authenticated;
select pg_temp.as_user('eeeeeeee-0000-0000-0000-000000000005');
select count(*) as yabanci_okur_sonra from public.table_order_history;
do $$ begin
  begin insert into public.table_order_history(original_order_id, seller_id) values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001');
    raise exception 'FAIL: yabanci insert gecti'; exception when insufficient_privilege then null; end;
end $$;
with d as (delete from public.table_order_history returning 1) select count(*) as yabanci_siler from d;
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select count(*) as sahipA_okur from public.table_order_history;           -- 1
select count(*) as sahipA_B_gorur from public.table_order_history where seller_id='bbbbbbbb-0000-0000-0000-000000000002'; -- 0
insert into public.table_order_history(original_order_id, seller_id) values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select count(*) as viewer_okur from public.table_order_history;           -- 2
select pg_temp.as_user('dddddddd-0000-0000-0000-000000000004');
select count(*) as izinsiz_personel_okur from public.table_order_history; -- 0
reset role;
select count(*) as toplam_satir_korundu from public.table_order_history;  -- 3
