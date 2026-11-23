-- DRAFT — DO NOT APPLY without explicit operator approval naming this file.
-- Üretimde YALNIZ SALT-OKUNUR doğrulananlar (2026-11-23):
--  (a) close_table_orders(...) SECURITY DEFINER, yetki kontrolü YOK, EXECUTE anon+authenticated.
--      Bugün table_orders.seller_id = text olduğundan `seller_id = p_seller_id(uuid)` 42883 ile
--      düşüyor (sömürülemez), ama tip düzeltilirse anonim sahte geçmiş + masa arşivleme açılır.
--  (b) manageOrders'lı (closeBill'siz) personel table_order_history UPDATE ile grand_total,
--      payment_method, items, archived_orders gibi finans alanlarını değiştirebiliyor
--      (mevcut tetikleyici yalnız manageOrders+masa erişimi ister).
--  (c) anon/authenticated üzerinde TRUNCATE/TRIGGER/REFERENCES yetkisi (API'den ulaşılmaz; hijyen).
-- Yalnız viewOrders'lı personelin UPDATE/DELETE yapabilmesi: mevcut tetikleyici ENGELLİYOR (doğrulandı).
-- Geri alma: 20261123_table_order_history_write_hardening_ROLLBACK_DRAFT.sql
begin;

-- 1) Eski RPC: yetki kapısı (sahip veya closeBill'li personel, masa erişimiyle) + anon kapalı.
create or replace function public.close_table_orders(
  p_seller_id uuid, p_table_number integer,
  p_payment_method text default 'cash', p_payment_note text default null,
  p_waiter_id uuid default null, p_waiter_name text default null, p_session_key text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
DECLARE
  v_order          record;
  v_grand_total    numeric(12,2) := 0;
  v_session        text;
  v_archived_count integer := 0;
  v_deleted_count  integer := 0;
BEGIN
  IF p_seller_id IS NULL OR p_table_number <= 0 THEN
    RAISE EXCEPTION 'Geçersiz parametre: seller_id=% table_number=%',
      p_seller_id, p_table_number USING ERRCODE = '22023';
  END IF;
  -- YENİ: oturum + closeBill + masa erişimi (sahip ya da yetkili personel).
  PERFORM public.restaurant_staff_may_operate(p_seller_id, 'closeBill', p_table_number);

  v_session := COALESCE(p_session_key,
    'session_' || p_seller_id || '_' || p_table_number || '_' || EXTRACT(EPOCH FROM NOW())::bigint::text);

  FOR v_order IN
    SELECT * FROM public.table_orders
    WHERE seller_id = p_seller_id AND table_number = p_table_number
      AND status NOT IN ('closed','paid','cancelled','canceled','completed','complete','archived','payment_completed')
  LOOP
    SELECT COALESCE(SUM((item->>'price')::numeric * COALESCE((item->>'quantity')::numeric, 1)), 0)
    INTO v_grand_total
    FROM jsonb_array_elements(COALESCE(v_order.items, '[]'::jsonb)) AS item;

    INSERT INTO public.table_order_history (
      original_order_id, seller_id, table_number, items, status, revision,
      last_edit_summary, last_edit_note, payment_method, payment_note,
      waiter_id, waiter_name, grand_total, session_key, opened_at, closed_at, created_at
    ) VALUES (
      v_order.id, p_seller_id, p_table_number, COALESCE(v_order.items, '[]'::jsonb), 'closed',
      COALESCE(v_order.revision, 1), COALESCE(v_order.last_edit_summary, '{}'::jsonb), v_order.last_edit_note,
      p_payment_method, p_payment_note, p_waiter_id, p_waiter_name, v_grand_total, v_session,
      v_order.created_at, TIMEZONE('utc', NOW()), v_order.created_at);
    v_archived_count := v_archived_count + 1;
  END LOOP;

  UPDATE public.table_orders SET status = 'archived', updated_at = TIMEZONE('utc', NOW())
  WHERE seller_id = p_seller_id AND table_number = p_table_number
    AND status NOT IN ('closed','paid','cancelled','canceled','completed','complete','archived','payment_completed');
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'archived', v_archived_count, 'deleted', v_deleted_count,
    'seller_id', p_seller_id, 'table_number', p_table_number, 'session_key', v_session);
END;
$function$;

revoke execute on function public.close_table_orders(uuid,integer,text,text,uuid,text,text) from public, anon;
grant  execute on function public.close_table_orders(uuid,integer,text,text,uuid,text,text) to authenticated, service_role;
revoke execute on function public.close_table_with_history(uuid,integer,text,text,uuid,text,text) from public, anon;
grant  execute on function public.close_table_with_history(uuid,integer,text,text,uuid,text,text) to authenticated, service_role;

-- 2) Personel geçmiş kaydında yalnız kimlik/etiket alanlarını güncelleyebilir; finans alanları değişmez.
create or replace function public.guard_table_order_history_staff_update()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_allowed text[] := array['display_table_label','table_area_name','waiter_id','waiter_name','updated_at'];
        o jsonb := to_jsonb(old); n jsonb := to_jsonb(new);
        k text;
begin
  if auth.uid() is null or auth.uid() = old.seller_id then return new; end if;  -- sunucu bağlamı / sahip
  foreach k in array v_allowed loop o := o - k; n := n - k; end loop;
  if o is distinct from n then
    raise exception 'Geçmiş kaydının finans alanları personel tarafından değiştirilemez.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists table_order_history_staff_update_guard on public.table_order_history;
create trigger table_order_history_staff_update_guard before update on public.table_order_history
  for each row execute function public.guard_table_order_history_staff_update();

-- 3) Denetim izi: kim, ne zaman, hangi kaydı değiştirdi/sildi (yalnız sahip okur).
create table if not exists public.table_order_history_audit (
  id bigserial primary key, at timestamptz not null default now(), actor uuid,
  op text not null, seller_id uuid, history_id uuid, old_row jsonb, new_row jsonb);
alter table public.table_order_history_audit enable row level security;
revoke all on public.table_order_history_audit from anon, authenticated;
grant select on public.table_order_history_audit to authenticated;
drop policy if exists table_order_history_audit_owner_read on public.table_order_history_audit;
create policy table_order_history_audit_owner_read on public.table_order_history_audit
  for select to authenticated using (seller_id = auth.uid());
create or replace function public.audit_table_order_history_change()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.table_order_history_audit(actor, op, seller_id, history_id, old_row, new_row)
  values (auth.uid(), tg_op, old.seller_id, old.id, to_jsonb(old),
          case when tg_op = 'UPDATE' then to_jsonb(new) end);
  if tg_op = 'DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists table_order_history_audit_trg on public.table_order_history;
create trigger table_order_history_audit_trg after update or delete on public.table_order_history
  for each row execute function public.audit_table_order_history_change();

-- 4) Yetki hijyeni (RLS'e tabi olmayan TRUNCATE dahil).
revoke truncate, trigger, references on public.table_order_history from anon, authenticated;
revoke all on public.table_order_history from anon;

commit;
