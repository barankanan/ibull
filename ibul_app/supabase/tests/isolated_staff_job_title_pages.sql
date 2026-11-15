-- Throwaway database only. Does not connect to Supabase.
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  email text
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table if not exists public.store_branches (
  id uuid primary key,
  store_id uuid not null
);
create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  branch_id uuid,
  auth_user_id uuid,
  email text,
  permissions text[] not null default '{}',
  staff_role text not null default 'sub_admin',
  status text not null default 'active',
  job_title text,
  visible_modules text[],
  created_at timestamptz not null default now()
);

\ir ../migrations/20261105123000_staff_job_title_page_permissions.sql

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();

insert into auth.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'garson@example.test');
insert into public.store_branches (id, store_id)
values ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');

insert into public.store_sub_admins (
  id, store_id, branch_id, auth_user_id, email, permissions, staff_role,
  job_title, visible_modules
) values (
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333',
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'garson@example.test',
  array['viewOrders','manageOrders'],
  'waiter',
  'Salon Sorumlusu',
  array['garson','orders']
);

do $$
begin
  begin
    insert into public.store_sub_admins (
      id, store_id, email, permissions, staff_role
    ) values (
      '55555555-5555-5555-5555-555555555555',
      '33333333-3333-3333-3333-333333333333',
      'bad@example.test',
      array['finance'],
      'sub_admin'
    );
    raise exception 'page name was accepted as an operation permission';
  exception when sqlstate '22023' then
    null;
  end;
  begin
    insert into public.store_sub_admins (
      id, store_id, email, permissions, staff_role, job_title
    ) values (
      '66666666-6666-6666-6666-666666666666',
      '33333333-3333-3333-3333-333333333333',
      'title@example.test',
      array['viewOrders'],
      'manager',
      'Garson'
    );
    raise exception 'custom title was stored as a security role';
  exception when sqlstate '22023' then
    null;
  end;
end $$;

select case
  when job_title = 'Salon Sorumlusu'
   and visible_modules = array['garson','orders']
   and staff_role = 'waiter'
   and not ('closeBill' = any(permissions))
  then 'PASS'
  else 'FAIL'
end as staff_page_contract
from public.store_sub_admins
where id = '44444444-4444-4444-4444-444444444444';
