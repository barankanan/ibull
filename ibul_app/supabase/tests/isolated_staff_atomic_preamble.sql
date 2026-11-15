-- Throwaway database only. Shapes the shared fixture into the live waiter
-- baseline before the atomic transition script. Does not connect to production.

alter table public.store_sub_admins add column if not exists staff_role text;

update public.store_sub_admins
set staff_role = 'waiter',
    permissions = array['viewOrders','manageOrders','manageProducts','manageSupport']
where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';

update public.store_sub_admins
set staff_role = 'sub_admin',
    permissions = array['viewOrders']
where auth_user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2';

update public.store_sub_admins
set staff_role = 'sub_admin',
    permissions = array['viewOrders','manageOrders']
where auth_user_id = 'cccccccc-cccc-cccc-cccc-ccccccccccc1';

drop trigger if exists validate_restaurant_staff on public.store_sub_admins;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();
