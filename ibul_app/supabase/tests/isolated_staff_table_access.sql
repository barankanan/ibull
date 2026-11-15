-- Throwaway database only. Does not connect to supabase.co.
-- Proves restaurant_table_access after 2026110116, then applies that file again.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

create table if not exists public.store_branches (
  id uuid primary key,
  store_id uuid not null,
  status text not null
);

create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  branch_id uuid,
  table_number integer not null,
  is_active boolean not null
);

create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  auth_user_id uuid,
  branch_id uuid,
  status text not null,
  email text,
  phone text,
  permissions text[] not null default '{}'::text[]
);

insert into auth.users (id, email, email_confirmed_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'owner@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'branch-a@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'branch-b@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'inactive@destina.test', now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4', 'closed-branch@destina.test', now()),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'other@store.test', now())
on conflict (id) do nothing;

insert into public.store_branches (id, store_id, status) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'active'),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'inactive'),
  ('44444444-4444-4444-4444-444444444444', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'active')
on conflict (id) do nothing;

insert into public.store_tables (id, seller_id, branch_id, table_number, is_active) values
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', null, 1, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 2, true),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '22222222-2222-2222-2222-222222222222', 3, true),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', null, 1, true)
on conflict (id) do nothing;

insert into public.store_sub_admins (
  id, store_id, auth_user_id, branch_id, status, email, permissions
) values
  ('f1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '11111111-1111-1111-1111-111111111111', 'active', 'branch-a@destina.test', array['viewOrders','manageOrders']),
  ('f2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', '22222222-2222-2222-2222-222222222222', 'active', 'branch-b@destina.test', array['viewOrders']),
  ('f3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3', '11111111-1111-1111-1111-111111111111', 'inactive', 'inactive@destina.test', array['viewOrders','manageOrders']),
  ('f4444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4', '33333333-3333-3333-3333-333333333333', 'active', 'closed-branch@destina.test', array['manageOrders']),
  ('f5555555-5555-5555-5555-555555555555', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', '44444444-4444-4444-4444-444444444444', 'active', 'other@store.test', array['viewOrders','manageOrders'])
on conflict (id) do nothing;

\ir ../migrations/2026110116_staff_unassigned_table_access.sql
\ir ../migrations/2026110116_staff_unassigned_table_access.sql

do $$
declare
  destina uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  other uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
  unassigned uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd1';
  branch_a_table uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd2';
  branch_b_table uuid := 'dddddddd-dddd-dddd-dddd-ddddddddddd3';
  other_table uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';
  staff_a uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  staff_b uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';
  staff_inactive uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3';
  staff_closed_branch uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4';
  staff_other uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
begin
  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);

  perform set_config('request.jwt.claim.sub', staff_a::text, true);
  if not public.restaurant_table_access(destina, unassigned) then
    raise exception 'branch staff cannot see an unassigned table of the same store';
  end if;
  if not public.restaurant_table_access(destina, branch_a_table) then
    raise exception 'branch staff cannot see their own branch table';
  end if;
  if public.restaurant_table_access(destina, branch_b_table) then
    raise exception 'branch staff can see another branch table';
  end if;
  if public.restaurant_table_access(other, other_table) then
    raise exception 'destina staff can see another store table';
  end if;
  if public.restaurant_table_access(destina, other_table) then
    raise exception 'foreign table id accepted for the destina restaurant id';
  end if;

  perform set_config('request.jwt.claim.sub', staff_b::text, true);
  if not public.restaurant_table_access(destina, unassigned) then
    raise exception 'other branch staff cannot see an unassigned table';
  end if;
  if public.restaurant_table_access(destina, branch_a_table) then
    raise exception 'viewOrders staff can see another branch table';
  end if;

  perform set_config('request.jwt.claim.sub', staff_inactive::text, true);
  if public.restaurant_table_access(destina, unassigned) then
    raise exception 'inactive membership can see a table';
  end if;

  perform set_config('request.jwt.claim.sub', staff_closed_branch::text, true);
  if public.restaurant_table_access(destina, unassigned) then
    raise exception 'staff on an inactive branch can see an unassigned table';
  end if;

  perform set_config('request.jwt.claim.sub', staff_other::text, true);
  if public.restaurant_table_access(destina, unassigned) then
    raise exception 'another store staff can see destina';
  end if;

  perform set_config('request.jwt.claim.sub', staff_a::text, true);
  perform set_config(
    'request.jwt.claims',
    '{"app_metadata":{"managed_restaurant_staff":"true","must_change_password":"true"}}',
    true
  );
  if public.restaurant_table_access(destina, unassigned) then
    raise exception 'staff who must change password can see a table';
  end if;

  perform set_config('request.jwt.claims', '{"app_metadata":{}}', true);
  perform set_config('request.jwt.claim.sub', destina::text, true);
  if not public.restaurant_table_access(destina, unassigned) then
    raise exception 'owner cannot see own unassigned table';
  end if;

  raise notice 'STAFF_TABLE_ACCESS_OK';
end $$;
