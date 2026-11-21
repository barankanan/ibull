-- Geri alma: UYARI herkese açık mağaza silme açığını yeniden açar.
begin;
drop policy if exists stores_owner_delete on public.stores;
drop policy if exists stores_admin_delete_all on public.stores;
drop policy if exists "Enable delete for users based on user_id" on public.stores;
create policy "Enable delete for users based on user_id" on public.stores for delete to public using (true);
commit;
