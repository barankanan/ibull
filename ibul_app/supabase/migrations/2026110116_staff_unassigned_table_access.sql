-- DO NOT APPLY to the live project from this workspace.
-- Staff are created with a branch. Tables created before branch assignment
-- have a null branch_id. restaurant_table_access treated that as no access,
-- so staff saw the public table catalog and zero orders.
-- A null table branch stays inside the same store. A different branch stays closed.
-- Email or phone remains only the legacy path for a membership with no auth_user_id.
-- This does not disable RLS, drop triggers, or treat staff as the store owner.

begin;

create or replace function public.staff_must_change_password()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'managed_restaurant_staff') = 'true'
    and (auth.jwt() -> 'app_metadata' ->> 'must_change_password') = 'true',
    false
  );
$$;

create or replace function public.restaurant_staff_branch_can_see_table(
  p_staff_branch uuid,
  p_table_branch uuid
)
returns boolean
language sql
immutable
as $$
  select p_staff_branch is null
    or p_table_branch is null
    or p_staff_branch = p_table_branch;
$$;

create or replace function public.restaurant_table_access(
  p_restaurant_id uuid,
  p_table_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.staff_must_change_password()
    and (
      auth.uid() = p_restaurant_id
      or exists(
        select 1 from public.store_sub_admins sa
        join auth.users au on au.id = auth.uid()
        join public.store_tables t on t.id = p_table_id
          and t.seller_id = sa.store_id
          and t.is_active
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and (
            sa.branch_id is null
            or exists(
              select 1 from public.store_branches b
              where b.id = sa.branch_id
                and b.store_id = sa.store_id
                and b.status = 'active'
            )
          )
          and public.restaurant_staff_branch_can_see_table(sa.branch_id, t.branch_id)
          and (sa.auth_user_id = au.id or (sa.auth_user_id is null and (
            (au.email_confirmed_at is not null and lower(trim(sa.email)) = lower(trim(au.email)))
            or (au.phone_confirmed_at is not null and sa.phone = au.phone)
          )))
      )
    );
$$;

create index if not exists store_sub_admins_auth_active_idx
  on public.store_sub_admins (auth_user_id, store_id)
  where status = 'active' and auth_user_id is not null;

commit;
