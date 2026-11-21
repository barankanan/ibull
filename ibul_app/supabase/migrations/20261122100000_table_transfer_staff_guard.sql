-- Masa aktarımı: transferTable yetkili alt yönetici/personel için `orders.table_id` taşıma.
--
-- Kök neden (izole DB'de yeniden üretildi, production katalogundan doğrulandı):
--  transfer_table_orders (SECURITY DEFINER) tam aktarımda orders.table_id günceller.
--  orders üzerindeki guard_restaurant_staff_order_write, yönetilen personel için
--  table_id değişimini koşulsuz "İşletme veya masa kimliği değiştirilemez" (42501) ile
--  reddediyordu; auth.uid() DEFINER içinde de personeldir. Sahipte guard geçtiği için
--  hata yalnız personelde görünüyordu.
--
-- Düzeltme: yalnız `orders.table_id` değişimine, RPC'nin işlem-yerel işaretiyle
--  (ibul.staff_table_transfer_rpc) ve ŞU koşullarla izin verilir:
--   * transferTable izni, eski ve yeni masaya erişim,
--   * satırın table_id ve updated_at dışında hiçbir alanı değişmemiş olmalı,
--   * restaurant_id / order_id kimliği hâlâ değiştirilemez.
--  İşaret sahte kurulsa bile aynı izin ve masa kontrolleri geçerlidir.
--  manageOrders gerekmez (transferTable yeterli), closeBill/ödeme/fiyat yetkisi verilmez.

begin;

create or replace function public.guard_restaurant_staff_order_write()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare r uuid; t uuid; row_data jsonb;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  if tg_table_name='orders' then
    r:=(row_data->>'restaurant_id')::uuid; t:=(row_data->>'table_id')::uuid;
  elsif tg_table_name in ('order_items','print_jobs') then
    select restaurant_id,table_id into r,t from public.orders where id=(row_data->>'order_id')::uuid;
  else
    r:=(row_data->>'seller_id')::uuid;
    select id into t from public.store_tables where seller_id=r and table_number=(row_data->>'table_number')::integer limit 1;
  end if;

  -- Yetkili masa aktarımı: yalnız orders.table_id (+updated_at) değişimi.
  if tg_op='UPDATE' and tg_table_name='orders'
     and (to_jsonb(old)->>'table_id') is distinct from (row_data->>'table_id')
     and (to_jsonb(old)->>'restaurant_id') is not distinct from (row_data->>'restaurant_id')
     and (to_jsonb(old)->>'order_id') is not distinct from (row_data->>'order_id')
     and current_setting('ibul.staff_table_transfer_rpc', true) = 'on'
     and (to_jsonb(old) - 'table_id' - 'updated_at') = (row_data - 'table_id' - 'updated_at') then
    if r is null or not public.restaurant_has_permission(r,'transferTable')
       or not public.restaurant_table_access(r, nullif(to_jsonb(old)->>'table_id','')::uuid)
       or not public.restaurant_table_access(r, t) then
      raise exception 'Masa aktarma yetkisi yok.' using errcode='42501';
    end if;
    return new;
  end if;

  if tg_op='UPDATE' and (
    (to_jsonb(old)->>'restaurant_id') is distinct from (row_data->>'restaurant_id')
    or (to_jsonb(old)->>'seller_id') is distinct from (row_data->>'seller_id')
    or (to_jsonb(old)->>'order_id') is distinct from (row_data->>'order_id')
    or (to_jsonb(old)->>'table_id') is distinct from (row_data->>'table_id')
  ) then raise exception 'İşletme veya masa kimliği değiştirilemez.' using errcode='42501'; end if;
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
  if tg_op='DELETE' then return old; else return new; end if;
end; $function$;

-- transfer_table_orders: orders.table_id güncellemesini işaretle (gövde aynı, yalnız iki set_config satırı eklendi).
do $mig$
declare v_def text;
begin
  select pg_get_functiondef(to_regprocedure(
    'public.transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)')) into v_def;
  if v_def is null then
    raise exception 'transfer_table_orders bulunamadı; yeni gövde yazılmadı.';
  end if;
  if position('ibul.staff_table_transfer_rpc' in v_def) > 0 then
    return; -- zaten uygulanmış
  end if;
  v_def := replace(v_def,
    $a$perform set_config('ibul.marketplace_order_rpc', 'on', true);$a$,
    $a$perform set_config('ibul.marketplace_order_rpc', 'on', true);
    perform set_config('ibul.staff_table_transfer_rpc', 'on', true);$a$);
  v_def := replace(v_def,
    $b$perform set_config('ibul.marketplace_order_rpc', 'off', true);$b$,
    $b$perform set_config('ibul.marketplace_order_rpc', 'off', true);
    perform set_config('ibul.staff_table_transfer_rpc', 'off', true);$b$);
  if position('ibul.staff_table_transfer_rpc' in v_def) = 0 then
    raise exception 'transfer_table_orders gövdesi beklenen kalıpla eşleşmedi; değişiklik yapılmadı.';
  end if;
  execute v_def;
end
$mig$;

commit;
