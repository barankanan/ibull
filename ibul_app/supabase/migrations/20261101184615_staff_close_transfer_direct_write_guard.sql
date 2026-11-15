-- DO NOT APPLY to the live project from this workspace.
-- 2026110117 changes the close and transfer RPCs only. A direct
-- table_orders delete, closed-status update, or table_number update still
-- passes the staff write guard with manageOrders. This file patches that
-- existing guard. It does not create a staff table, grant permissions, or
-- change print_jobs, order inserts, or ordinary order updates.
-- Existing membership rows are not updated.

begin;

create table if not exists public.ibul_function_patch_backup (
  patch_name text not null,
  signature text not null,
  definition text not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (patch_name, signature)
);

revoke all on public.ibul_function_patch_backup from public, anon, authenticated;

do $$
declare
  original text;
  patched text;
  fn_signature text;
  tail constant text := $tail$
  if r is null or not public.restaurant_has_permission(r,'manageOrders')
    or not public.restaurant_table_access(r,t) then
    raise exception 'Personel sipariş yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;$tail$;
  replacement constant text := $replacement$
  if tg_table_name = 'table_orders' and tg_op = 'DELETE' then
    if r is null or not public.restaurant_has_permission(r,'closeBill')
       or not public.restaurant_table_access(r,t) then
      raise exception 'Hesabı kesme yetkisi yok.' using errcode='42501';
    end if;
  elsif tg_table_name = 'table_orders' and tg_op = 'UPDATE'
        and (to_jsonb(old)->>'table_number') is distinct from (row_data->>'table_number')
        and lower(btrim(coalesce(row_data->>'status',''))) in (
          'closed','paid','cancelled','canceled','completed','complete',
          'archived','payment_completed','completed_payment'
        )
        and lower(btrim(coalesce(to_jsonb(old)->>'status','')))
            is distinct from lower(btrim(coalesce(row_data->>'status',''))) then
    if r is null or not public.restaurant_has_permission(r,'transferTable')
       or not public.restaurant_has_permission(r,'closeBill')
       or not public.restaurant_table_number_access(r, nullif(to_jsonb(old)->>'table_number','')::integer)
       or not public.restaurant_table_number_access(r, nullif(row_data->>'table_number','')::integer) then
      raise exception 'Masa aktarma veya hesabı kesme yetkisi yok.' using errcode='42501';
    end if;
  elsif tg_table_name = 'table_orders' and tg_op = 'UPDATE'
        and (to_jsonb(old)->>'table_number') is distinct from (row_data->>'table_number') then
    if r is null or not public.restaurant_has_permission(r,'transferTable')
       or not public.restaurant_table_number_access(r, nullif(to_jsonb(old)->>'table_number','')::integer)
       or not public.restaurant_table_number_access(r, nullif(row_data->>'table_number','')::integer) then
      raise exception 'Masa aktarma yetkisi yok.' using errcode='42501';
    end if;
  elsif tg_table_name = 'table_orders' and tg_op = 'UPDATE'
        and lower(btrim(coalesce(row_data->>'status',''))) in (
          'closed','paid','cancelled','canceled','completed','complete',
          'archived','payment_completed','completed_payment'
        )
        and lower(btrim(coalesce(to_jsonb(old)->>'status','')))
            is distinct from lower(btrim(coalesce(row_data->>'status',''))) then
    if r is null or not public.restaurant_has_permission(r,'closeBill')
       or not public.restaurant_table_access(r,t) then
      raise exception 'Hesabı kesme yetkisi yok.' using errcode='42501';
    end if;
  elsif tg_table_name = 'table_order_history' and tg_op in ('INSERT','DELETE') then
    if r is null or not public.restaurant_has_permission(r,'closeBill')
       or not public.restaurant_table_access(r,t) then
      raise exception 'Hesabı kesme yetkisi yok.' using errcode='42501';
    end if;
  elsif r is null or not public.restaurant_has_permission(r,'manageOrders')
     or not public.restaurant_table_access(r,t) then
    raise exception 'Personel sipariş yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;$replacement$;
begin
  select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
  into fn_signature, original
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'guard_restaurant_staff_order_write'
  limit 1;
  if fn_signature is null then
    raise exception 'guard_restaurant_staff_order_write kurulu değil; yeni gövde yazılmadı.';
  end if;
  if position('Hesabı kesme yetkisi yok.' in original) > 0
     and position('Masa aktarma yetkisi yok.' in original) > 0 then
    return;
  end if;
  if position('print_jobs' in original) = 0
     or position(tail in original) = 0 then
    raise exception 'Personel sipariş yazma kapısı tanınmadı; fonksiyon gövdesi yazılmadı.';
  end if;
  patched := replace(original, tail, replacement);
  if patched = original
     or position('Hesabı kesme yetkisi yok.' in patched) = 0
     or position('Masa aktarma yetkisi yok.' in patched) = 0
     or position('print_jobs' in patched) = 0
     or position('Personel sipariş yetkisi yok.' in patched) = 0 then
    raise exception 'Personel sipariş yazma kapısı genişletilemedi.';
  end if;
  insert into public.ibul_function_patch_backup (patch_name, signature, definition)
  values ('20261101184615', fn_signature, original)
  on conflict (patch_name, signature) do nothing;
  execute patched;
end $$;

commit;
