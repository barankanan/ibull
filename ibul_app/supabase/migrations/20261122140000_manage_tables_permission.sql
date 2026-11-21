-- Yeni izin: manageTables (Alan, masa ve QR düzeni).
--
-- Neden: Sistem sayfasındaki alan/masa/QR yönetimi yalnız sahibe açıktı (store_tables ve
-- store_table_areas: auth.uid() = seller_id) ve bu iş için bir izin yoktu; alt yönetici sayfayı açıyor,
-- yazamıyordu. Sahip, şifre/personel ve finans izinleri bu izne DAHİL DEĞİLDİR; sipariş/ödeme yetkisi vermez.
--
-- Sözleşme (Flutter `SellerPermission.manageTables`, Edge Function allowed/restaurantOnly/triggerPermissions,
-- bu migration'ın doğrulama tetikleyicisi ve RLS aynı adı kullanır):
--  * store_tables   : personel yazma = manageTables + şube kapsamı (yalnız kendi şubesinin masaları;
--                     şubesiz/sahip dışında satırın branch_id'si personelin şubesiyle eşleşmeli).
--  * store_table_areas: şubesi olmayan paylaşılan alanlar. manageTables personeli ekleyebilir; güncelleme/silme
--                     yalnız alanı DİĞER şubelerin masaları kullanmıyorsa.
--  * Mevcut sahip politikaları ve herkese açık okuma politikaları DEĞİŞMEZ.
-- Geri alma: rollbacks/20261122140000_manage_tables_permission_rollback.sql

begin;

-- 1) Üyelik doğrulaması: 'manageTables' geçerli izin (production gövdesi + yeni izin).
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
    'manageTables','manageStaff'
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

-- 2) Şube kapsamı yardımcısı: sahip her zaman; personel şubesiz ise her şube, şubeli ise yalnız kendi (aktif) şubesi.
create or replace function public.restaurant_branch_scope_ok(p_restaurant_id uuid, p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select auth.uid() is not null
    and not public.staff_must_change_password()
    and (
      auth.uid() = p_restaurant_id
      or exists (
        select 1 from public.store_sub_admins sa
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and sa.auth_user_id = auth.uid()
          and (
            sa.branch_id is null
            or (
              p_branch_id is not null
              and sa.branch_id = p_branch_id
              and exists (
                select 1 from public.store_branches b
                where b.id = sa.branch_id and b.store_id = sa.store_id and b.status = 'active'
              )
            )
          )
      )
    );
$function$;
revoke all on function public.restaurant_branch_scope_ok(uuid, uuid) from public, anon;
grant execute on function public.restaurant_branch_scope_ok(uuid, uuid) to authenticated;

-- 3) RLS: masalar.
drop policy if exists store_tables_manage_tables_staff on public.store_tables;
create policy store_tables_manage_tables_staff
on public.store_tables
for all
to authenticated
using (
  public.restaurant_has_permission(seller_id, 'manageTables')
  and public.restaurant_branch_scope_ok(seller_id, branch_id)
)
with check (
  public.restaurant_has_permission(seller_id, 'manageTables')
  and public.restaurant_branch_scope_ok(seller_id, branch_id)
);

-- 4) RLS: alanlar (paylaşılan; güncelleme/silme yalnız başka şubenin masası kullanmıyorsa).
drop policy if exists store_table_areas_manage_tables_insert on public.store_table_areas;
create policy store_table_areas_manage_tables_insert
on public.store_table_areas
for insert
to authenticated
with check (public.restaurant_has_permission(seller_id, 'manageTables'));

drop policy if exists store_table_areas_manage_tables_update on public.store_table_areas;
create policy store_table_areas_manage_tables_update
on public.store_table_areas
for update
to authenticated
using (
  public.restaurant_has_permission(seller_id, 'manageTables')
  and not exists (
    select 1 from public.store_tables t
    where t.area_id = store_table_areas.id
      and not public.restaurant_branch_scope_ok(t.seller_id, t.branch_id)
  )
)
with check (public.restaurant_has_permission(seller_id, 'manageTables'));

drop policy if exists store_table_areas_manage_tables_delete on public.store_table_areas;
create policy store_table_areas_manage_tables_delete
on public.store_table_areas
for delete
to authenticated
using (
  public.restaurant_has_permission(seller_id, 'manageTables')
  and not exists (
    select 1 from public.store_tables t
    where t.area_id = store_table_areas.id
      and not public.restaurant_branch_scope_ok(t.seller_id, t.branch_id)
  )
);

commit;
