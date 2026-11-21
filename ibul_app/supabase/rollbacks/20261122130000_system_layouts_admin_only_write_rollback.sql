-- Geri alma: UYARI herkese açık düzen yazmayı yeniden açar.
begin;
drop policy if exists system_layouts_admin_write on public.system_layouts;
create policy system_layouts_insert_all on public.system_layouts for insert to public with check (true);
create policy system_layouts_update_all on public.system_layouts for update to public using (true) with check (true);
create policy "Enable delete for users based on user_id" on public.system_layouts for delete to public using (true);
commit;
