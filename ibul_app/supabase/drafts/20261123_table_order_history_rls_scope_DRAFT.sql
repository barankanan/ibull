-- DRAFT — DO NOT APPLY without explicit operator approval naming this file.
--
-- Sorun (üretimde salt-okunur doğrulandı): table_order_history üzerinde
-- "table_order_history_authenticated" politikası PERMISSIVE / ALL / TO
-- authenticated / USING true / WITH CHECK true. Giriş yapmış HERHANGİ bir
-- kullanıcı (müşteri dahil) tüm restoranların kapanış geçmişini okuyabilir,
-- ekleyebilir, değiştirebilir ve silebilir. anon için politika yok (engelli).
--
-- Düzeltme: o politikayı kaldırır; okuma ve eklemeyi, mevcut update/delete
-- politikalarıyla aynı kapsama indirir: mağaza sahibi veya
-- user_can_access_restaurant (manageOrders/viewOrders olan aktif personel).
-- Mevcut RESTRICTIVE staff_history_read_guard ve restaurant_staff_write_guard
-- tetikleyicisi aynen çalışmaya devam eder. close_table_with_history SECURITY
-- DEFINER olduğundan RLS'den etkilenmez.
--
-- Geri alma: 20261123_table_order_history_rls_scope_ROLLBACK_DRAFT.sql
begin;

drop policy if exists table_order_history_authenticated on public.table_order_history;

drop policy if exists table_order_history_owner_select on public.table_order_history;
create policy table_order_history_owner_select
  on public.table_order_history for select to authenticated
  using (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));

drop policy if exists table_order_history_owner_insert on public.table_order_history;
create policy table_order_history_owner_insert
  on public.table_order_history for insert to authenticated
  with check (seller_id = auth.uid() or public.user_can_access_restaurant(seller_id));

commit;
