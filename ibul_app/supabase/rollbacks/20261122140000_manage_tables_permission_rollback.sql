-- Geri alma: 20261122140000_manage_tables_permission.sql
-- ÖNCE: manageTables izni olan üyeliklerden izni kaldırın (aksi halde eski doğrulama 'Geçersiz yetki' verir):
--   update public.store_sub_admins set permissions = array_remove(permissions, 'manageTables')
--   where 'manageTables' = any(permissions);
-- (Bu UPDATE üyelik iptal tetikleyicisini çalıştırabilir; personel oturumları kapanabilir.)
begin;
drop policy if exists store_tables_manage_tables_staff on public.store_tables;
drop policy if exists store_table_areas_manage_tables_insert on public.store_table_areas;
drop policy if exists store_table_areas_manage_tables_update on public.store_table_areas;
drop policy if exists store_table_areas_manage_tables_delete on public.store_table_areas;
drop function if exists public.restaurant_branch_scope_ok(uuid, uuid);

create or replace function public.validate_restaurant_staff_membership()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
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
$function$;
commit;
