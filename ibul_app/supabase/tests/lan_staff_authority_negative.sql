-- Negative and positive checks for public.lan_staff_authority. Run against an
-- isolated database only. Everything is rolled back.
begin;
create temp table _r(name text, ok boolean, detail text) on commit drop;
grant all on _r to public;
do $t$
declare
  owner uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
  ok_staff uuid := gen_random_uuid(); temp_staff uuid := gen_random_uuid();
  nouser_staff uuid := gen_random_uuid(); inactive_staff uuid := gen_random_uuid();
  other_owner uuid := gen_random_uuid(); other_staff uuid := gen_random_uuid();
  r jsonb;
begin
  insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,created_at,updated_at) values
   (owner,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',owner||'@t.test','{}',now(),now()),
   (stranger,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',stranger||'@t.test','{}',now(),now()),
   (ok_staff,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',ok_staff||'@t.test','{"managed_restaurant_staff":true,"must_change_password":false}',now(),now()),
   (temp_staff,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',temp_staff||'@t.test','{"managed_restaurant_staff":true,"must_change_password":true}',now(),now()),
   (inactive_staff,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',inactive_staff||'@t.test','{"managed_restaurant_staff":true,"must_change_password":false}',now(),now()),
   (other_staff,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',other_staff||'@t.test','{}',now(),now());
  insert into public.store_sub_admins(store_id,auth_user_id,status,permissions,staff_role) values
   (owner,ok_staff,'active',array['manageOrders'],'waiter'),
   (owner,temp_staff,'active',array['manageOrders'],'waiter'),
   (owner,inactive_staff,'inactive',array['manageOrders'],'waiter'),
   (owner,nouser_staff,'active',array['manageOrders'],'waiter');
  -- impersonate the owner
  perform set_config('request.jwt.claims', json_build_object('sub',owner,'role','authenticated')::text, true);
  perform set_config('role','authenticated', true);
  r := public.lan_staff_authority(owner, ok_staff);
  insert into _r values('active staff: must_change false', (r->>'must_change_password')='false' and r->>'status'='active', r::text);
  r := public.lan_staff_authority(owner, temp_staff);
  insert into _r values('temporary password: must_change true', (r->>'must_change_password')='true', r::text);
  r := public.lan_staff_authority(owner, nouser_staff);
  insert into _r values('membership without an auth account fails closed', (r->>'must_change_password')='true', r::text);
  r := public.lan_staff_authority(owner, inactive_staff);
  insert into _r values('inactive is reported inactive', r->>'status'='inactive', r::text);
  r := public.lan_staff_authority(owner, other_staff);
  insert into _r values('non member is not found', (r->>'found')='false', r::text);
  r := public.lan_staff_authority(owner, null);
  insert into _r values('null staff is not found', (r->>'found')='false', r::text);
  -- another restaurant's staff is invisible to this owner
  insert into public.store_sub_admins(store_id,auth_user_id,status,permissions,staff_role) values (other_owner,other_staff,'active',array['manageOrders'],'waiter');
  r := public.lan_staff_authority(owner, other_staff);
  insert into _r values('other restaurant staff is not found', (r->>'found')='false', r::text);
  -- a stranger cannot ask about this restaurant
  perform set_config('request.jwt.claims', json_build_object('sub',stranger,'role','authenticated')::text, true);
  begin
    perform public.lan_staff_authority(owner, ok_staff);
    insert into _r values('stranger refused', false, 'no error');
  exception when sqlstate '42501' then
    insert into _r values('stranger refused', true, 'SQLSTATE 42501');
  end;
  -- the staff member themself cannot ask either
  perform set_config('request.jwt.claims', json_build_object('sub',ok_staff,'role','authenticated')::text, true);
  begin
    perform public.lan_staff_authority(owner, ok_staff);
    insert into _r values('staff cannot query own restaurant authority', false, 'no error');
  exception when sqlstate '42501' then
    insert into _r values('staff cannot query own restaurant authority', true, 'SQLSTATE 42501');
  end;
  -- anonymous
  perform set_config('request.jwt.claims', '{}', true);
  begin
    perform public.lan_staff_authority(owner, ok_staff);
    insert into _r values('anonymous refused', false, 'no error');
  exception when sqlstate '42501' then
    insert into _r values('anonymous refused', true, 'SQLSTATE 42501');
  end;
end $t$;
reset role;
select case when ok then 'PASS' else 'FAIL' end as result, name, detail from _r;
rollback;
