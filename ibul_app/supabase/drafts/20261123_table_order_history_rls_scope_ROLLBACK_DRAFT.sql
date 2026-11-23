-- DRAFT geri alma: eski (açık) politikayı geri koyar. Yalnızca acil durumda.
begin;
drop policy if exists table_order_history_owner_select on public.table_order_history;
drop policy if exists table_order_history_owner_insert on public.table_order_history;
create policy table_order_history_authenticated
  on public.table_order_history for all to authenticated using (true) with check (true);
commit;
