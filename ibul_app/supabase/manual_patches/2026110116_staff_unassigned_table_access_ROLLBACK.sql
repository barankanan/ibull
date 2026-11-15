-- DO NOT APPLY unless 2026110116 was applied and must be reversed.
-- This is a forward rollback. It restores the stricter branch predicate from
-- 2026110101. It does not delete tables, orders, print jobs, or staff rows.
-- Run it only after a confirmed backup or restore point.

begin;

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
          and (sa.branch_id is null or (
            t.branch_id = sa.branch_id
            and exists(
              select 1 from public.store_branches b
              where b.id = sa.branch_id
                and b.store_id = sa.store_id
                and b.status = 'active'
            )
          ))
          and (sa.auth_user_id = au.id or (sa.auth_user_id is null and (
            (au.email_confirmed_at is not null and lower(trim(sa.email)) = lower(trim(au.email)))
            or (au.phone_confirmed_at is not null and sa.phone = au.phone)
          )))
      )
    );
$$;

drop function if exists public.restaurant_staff_branch_can_see_table(uuid, uuid);
drop index if exists public.store_sub_admins_auth_active_idx;

commit;
