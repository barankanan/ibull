-- Throwaway check for restaurant_staff_branch_can_see_table.
-- Does not connect to supabase.co and does not read production data.
begin;

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

do $$
declare
  destina_branch uuid := '11111111-1111-1111-1111-111111111111';
  other_branch uuid := '22222222-2222-2222-2222-222222222222';
begin
  if not public.restaurant_staff_branch_can_see_table(destina_branch, null) then
    raise exception 'unassigned table hidden from branch staff';
  end if;
  if not public.restaurant_staff_branch_can_see_table(null, destina_branch) then
    raise exception 'store-wide staff hidden from an assigned table';
  end if;
  if not public.restaurant_staff_branch_can_see_table(destina_branch, destina_branch) then
    raise exception 'same branch hidden';
  end if;
  if public.restaurant_staff_branch_can_see_table(destina_branch, other_branch) then
    raise exception 'other branch exposed';
  end if;
  raise notice 'STAFF_BRANCH_VISIBILITY_OK';
end $$;

rollback;
