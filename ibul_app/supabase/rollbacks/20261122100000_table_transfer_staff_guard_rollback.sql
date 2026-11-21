-- Geri alma: 20261122100000_table_transfer_staff_guard.sql
-- transfer_table_orders: iki set_config('ibul.staff_table_transfer_rpc', ...) satırını kaldırır.
-- guard_restaurant_staff_order_write: orders.table_id özel dalını kaldırır (önceki production gövdesi).
begin;

do $rb$
declare v_def text;
begin
  select pg_get_functiondef(to_regprocedure(
    'public.transfer_table_orders(uuid,integer,integer,text,jsonb,uuid,text,text)')) into v_def;
  v_def := replace(v_def, E'\n    perform set_config(''ibul.staff_table_transfer_rpc'', ''on'', true);', '');
  v_def := replace(v_def, E'\n    perform set_config(''ibul.staff_table_transfer_rpc'', ''off'', true);', '');
  execute v_def;
end
$rb$;

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

commit;
