-- Prepared only. Do not apply to production without the named approval.
-- Extends store_sub_admins. Job title is a label. visible_modules is page
-- visibility. Neither value is a security role and neither is written into
-- permissions. manageStaff becomes a real operation permission; page names
-- stay rejected by the membership trigger.

alter table public.store_sub_admins
  add column if not exists job_title text,
  add column if not exists visible_modules text[];

comment on column public.store_sub_admins.job_title is
  'Display label chosen by the store owner. Not a security role.';
comment on column public.store_sub_admins.visible_modules is
  'Seller panel page keys the member may open. Null keeps the legacy permission-derived menu.';

create or replace function public.validate_restaurant_staff_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.branch_id is not null and not exists (
    select 1 from public.store_branches
    where id = new.branch_id and store_id = new.store_id
  ) then
    raise exception 'Şube bu işletmeye ait değil.' using errcode = '42501';
  end if;
  if not new.permissions <@ array[
    'manageProducts','viewOrders','manageOrders','manageCampaigns',
    'viewFinance','manageSupport','manageStoreProfile','transferTable',
    'splitBill','takePartialPayment','closeBill','managePrintSettings',
    'manageStaff'
  ]::text[] then
    raise exception 'Geçersiz yetki.' using errcode = '22023';
  end if;
  if new.job_title is not null and char_length(btrim(new.job_title)) > 80 then
    raise exception 'Görev adı çok uzun.' using errcode = '22023';
  end if;
  if new.visible_modules is not null and exists (
    select 1
    from unnest(new.visible_modules) as page
    where page not in (
      'dashboard','products','collections','orders','garson','system','store',
      'mallRequests','contracts','team','campaigns','finance','achievements',
      'reviews','support','vehicles'
    )
  ) then
    raise exception 'Geçersiz sayfa.' using errcode = '22023';
  end if;
  if new.auth_user_id is not null and not exists (
    select 1 from auth.users
    where id = new.auth_user_id and lower(email) = lower(new.email)
  ) then
    raise exception 'Auth kimliği uyuşmuyor.' using errcode = '42501';
  end if;
  if new.staff_role is distinct from 'waiter'
     and new.staff_role is distinct from 'sub_admin' then
    raise exception 'Geçersiz personel rolü.' using errcode = '22023';
  end if;
  return new;
end;
$$;

create or replace function public.get_my_staff_access()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'store_id', store_id,
    'branch_id', branch_id,
    'staff_role', staff_role,
    'permissions', permissions,
    'job_title', job_title,
    'visible_modules', visible_modules
  )
  from public.store_sub_admins
  where auth_user_id = auth.uid()
    and status = 'active'
  order by created_at
  limit 1;
$$;
