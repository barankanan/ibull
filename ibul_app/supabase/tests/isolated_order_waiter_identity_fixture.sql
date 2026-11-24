-- Fixture for run_isolated_order_waiter_identity.sh. THROWAWAY PostgreSQL only.
\set ON_ERROR_STOP on
insert into public.users (id) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),  -- inactive staff of this restaurant
  ('ffffffff-ffff-ffff-ffff-ffffffffffff'),  -- active staff of ANOTHER restaurant
  ('10101010-1010-1010-1010-101010101010'),  -- active staff of this restaurant, OTHER branch
  ('abababab-abab-abab-abab-abababababab')   -- a customer: in public.users, staff nowhere
on conflict do nothing;
insert into public.store_sub_admins (store_id, status, permissions, auth_user_id, branch_id) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'inactive', array['manageOrders'], 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('99999999-0000-0000-0000-999999999999', 'active', array['manageOrders'], 'ffffffff-ffff-ffff-ffff-ffffffffffff', null),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'active', array['manageOrders'], '10101010-1010-1010-1010-101010101010', '99999999-9999-9999-9999-999999999999');
create table public.t_wi(phase text, k text, v text, primary key (phase, k));
-- Owner (or the given user) sends table 1 with p_waiter_id = <waiter>; stores orders.waiter_id or ERR.
create or replace function public.t_wi_send(p_phase text, p_key text, p_waiter text, p_table int default 1,
    p_as text default 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_role text default '', p_actor text default null, p_local text default null)
returns void language plpgsql as $$
declare v jsonb; wid text;
begin
  perform set_config('ibul.test_uid', p_as, true);
  perform set_config('request.jwt.claim.role', p_role, true);
  begin
    v := public.create_table_order_with_print_jobs(
      p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => p_table,
      p_items => '[{"name":"KATI CACIK","product_id":"p1","quantity":2,"price":180,"station_id":"11111111-1111-1111-1111-111111111111"}]'::jsonb,
      p_waiter_id => nullif(p_waiter, '')::uuid, p_waiter_name => 'efe',
      p_local_order_id => coalesce(p_local, 'wi-' || p_phase || '-' || p_key), p_verified_actor => nullif(p_actor, '')::uuid);
    select coalesce(waiter_id::text, 'null') into wid from public.orders where local_order_id = coalesce(p_local, 'wi-' || p_phase || '-' || p_key);
    insert into public.t_wi values (p_phase, p_key, wid);
  exception when others then
    insert into public.t_wi values (p_phase, p_key, 'ERR:' || sqlerrm);
  end;
  perform set_config('request.jwt.claim.role', '', true);
end $$;
