-- ROLLBACK — yalnız operatör onayıyla. Audit tablosu VERİ içerir; silinmez, yalnız tetikleyici kapatılır.
begin;
drop trigger if exists table_order_history_staff_update_guard on public.table_order_history;
drop trigger if exists table_order_history_audit_trg on public.table_order_history;
drop function if exists public.guard_table_order_history_staff_update();
drop function if exists public.audit_table_order_history_change();
grant execute on function public.close_table_orders(uuid,integer,text,text,uuid,text,text) to anon;
grant execute on function public.close_table_with_history(uuid,integer,text,text,uuid,text,text) to anon;
grant truncate, trigger, references on public.table_order_history to authenticated;
grant all on public.table_order_history to anon;
-- close_table_orders gövdesi: yetki satırı (restaurant_staff_may_operate) elle çıkarılarak eski hâle döner;
-- eski gövde 20260915_live_security_audit / SUPABASE_FIX_GARSON_CLOSE_TABLE.sql içinde.
commit;
