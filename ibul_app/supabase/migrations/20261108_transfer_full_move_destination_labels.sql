-- Full table move stores the destination area name, area index, and
-- display label in the same update as table_number.
-- A later label update can fail after table_number has already changed
-- and leave the source label on the destination table. This migration
-- does not add that second write. If the destination label cannot be
-- resolved, the full move raises before any row changes.
-- Partial and customer moves keep the previous behavior.
-- Do not apply this file to production from automation.

alter table public.table_orders
  add column if not exists display_table_label text;

alter table public.table_orders
  add column if not exists table_display_name text;

alter table public.table_orders
  add column if not exists table_name text;

alter table public.table_orders
  add column if not exists table_area_name text;

alter table public.table_orders
  add column if not exists area_name text;

alter table public.table_orders
  add column if not exists area_table_number integer;

do $cols$
begin
  if to_regclass('public.store_tables') is not null then
    execute 'alter table public.store_tables add column if not exists area_name text';
    execute 'alter table public.store_tables add column if not exists area_table_number integer';
    execute 'alter table public.store_tables add column if not exists display_label text';
    execute 'alter table public.store_tables add column if not exists table_name text';
  end if;
end
$cols$;

do $migrate$
declare
  v_name text;
  v_sql text;
begin
  if to_regprocedure(
    'public.transfer_table_orders_v2_impl(uuid,integer,integer,text,jsonb,uuid,text,text)'
  ) is not null then
    v_name := 'transfer_table_orders_v2_impl';
  else
    v_name := 'transfer_table_orders_v2';
  end if;

  v_sql := replace($fn$
create or replace function public.__TRANSFER_FN__(
  p_seller_id uuid,
  p_from_table integer,
  p_to_table integer,
  p_transfer_type text default 'full',
  p_item_ids jsonb default '[]'::jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $body$
declare
  v_type text;
  v_order record;
  v_item jsonb;
  v_ord integer;
  v_line_id text;
  v_kept jsonb;
  v_moved jsonb;
  v_moved_all jsonb := '[]'::jsonb;
  v_order_ids jsonb := '[]'::jsonb;
  v_selected text[];
  v_moved_count integer := 0;
  v_status text;
  v_dest_area text;
  v_dest_area_no integer;
  v_dest_label text;
  v_dest_count integer;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if auth.uid() is distinct from p_seller_id then
    if not exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on (
          (
            sa.email is not null
            and trim(sa.email) <> ''
            and lower(trim(u.email)) = lower(trim(sa.email))
          )
          or (
            sa.phone is not null
            and trim(sa.phone) <> ''
            and trim(coalesce(u.phone, '')) = trim(sa.phone)
          )
        )
      where sa.store_id = p_seller_id
        and u.id = auth.uid()
        and sa.status = 'active'
    ) then
      raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
    end if;
  end if;

  if p_from_table is null
    or p_to_table is null
    or p_from_table <= 0
    or p_to_table <= 0
    or p_from_table = p_to_table then
    raise exception 'Kaynak ve hedef masa geçersiz.';
  end if;

  v_type := lower(trim(coalesce(p_transfer_type, 'full')));
  if v_type in ('customerbased', 'customer_based') then
    v_type := 'customer';
  end if;
  if v_type not in ('full', 'partial', 'customer') then
    raise exception 'Geçersiz aktarım türü.';
  end if;

  if v_type <> 'full' then
    select coalesce(array_agg(value), '{}'::text[])
      into v_selected
    from jsonb_array_elements_text(coalesce(p_item_ids, '[]'::jsonb));
    if v_selected is null or cardinality(v_selected) = 0 then
      raise exception 'Seçili ürün aktarımı için en az bir ürün seçilmeli.';
    end if;
  end if;

  if v_type = 'full' then
    if to_regclass('public.store_tables') is null
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'store_tables'
           and column_name = 'area_name'
       )
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'store_tables'
           and column_name = 'area_table_number'
       )
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'store_tables'
           and column_name = 'display_label'
       )
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'table_orders'
           and column_name = 'area_name'
       )
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'table_orders'
           and column_name = 'area_table_number'
       )
       or not exists (
         select 1
         from information_schema.columns
         where table_schema = 'public'
           and table_name = 'table_orders'
           and column_name = 'display_table_label'
       )
    then
      raise exception 'Hedef masanın alan etiketi yazılamadı. Aktarım yapılmadı.';
    end if;

    select count(*)
      into v_dest_count
    from public.store_tables
    where seller_id = p_seller_id
      and table_number = p_to_table;

    if v_dest_count is distinct from 1 then
      raise exception 'Hedef masanın alan etiketi yazılamadı. Aktarım yapılmadı.';
    end if;

    select
      nullif(btrim(area_name), ''),
      area_table_number,
      nullif(
        btrim(
          coalesce(
            nullif(btrim(display_label), ''),
            nullif(btrim(table_name), '')
          )
        ),
        ''
      )
      into v_dest_area, v_dest_area_no, v_dest_label
    from public.store_tables
    where seller_id = p_seller_id
      and table_number = p_to_table;

    if v_dest_area is null
       or v_dest_area_no is null
       or v_dest_area_no <= 0
       or v_dest_label is null
    then
      raise exception 'Hedef masanın alan etiketi yazılamadı. Aktarım yapılmadı.';
    end if;
  end if;

  for v_order in
    select *
    from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_from_table
      and coalesce(lower(status), '') not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived', 'delivered'
      )
    order by created_at
  loop
    v_kept := '[]'::jsonb;
    v_moved := '[]'::jsonb;

    for v_item, v_ord in
      select item, ord
      from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb))
        with ordinality as t(item, ord)
    loop
      v_line_id := nullif(trim(coalesce(v_item->>'transfer_line_id', '')), '');
      if v_line_id is null then
        v_line_id := nullif(trim(coalesce(v_item->>'id', '')), '');
      end if;
      if v_line_id is null then
        v_line_id := v_order.id::text || '#' || (v_ord - 1)::text;
      end if;
      v_item := jsonb_set(v_item, '{transfer_line_id}', to_jsonb(v_line_id), true);

      if v_type = 'full' or v_line_id = any(v_selected) then
        v_moved := v_moved || jsonb_build_array(v_item);
      else
        v_kept := v_kept || jsonb_build_array(v_item);
      end if;
    end loop;

    if jsonb_array_length(v_moved) = 0 then
      continue;
    end if;

    v_order_ids := v_order_ids || to_jsonb(v_order.id::text);
    v_moved_all := v_moved_all || v_moved;
    v_moved_count := v_moved_count + jsonb_array_length(v_moved);

    if jsonb_array_length(v_kept) = 0 then
      if v_type = 'full' then
        update public.table_orders
        set table_number = p_to_table,
            items = v_moved,
            area_name = v_dest_area,
            table_area_name = v_dest_area,
            area_table_number = v_dest_area_no,
            display_table_label = v_dest_label,
            table_display_name = v_dest_label,
            table_name = v_dest_label
        where id = v_order.id
          and seller_id = p_seller_id;
      else
        update public.table_orders
        set table_number = p_to_table,
            items = v_moved
        where id = v_order.id
          and seller_id = p_seller_id;
      end if;
    else
      update public.table_orders
      set items = v_kept
      where id = v_order.id
        and seller_id = p_seller_id;

      v_status := coalesce(nullif(trim(v_order.status), ''), 'sent');
      insert into public.table_orders (
        seller_id, table_number, items, status, created_at
      ) values (
        p_seller_id,
        p_to_table,
        v_moved,
        v_status,
        timezone('utc', now())
      );
    end if;
  end loop;

  if v_moved_count = 0 then
    raise exception 'Aktarılacak açık sipariş veya seçili ürün bulunamadı.';
  end if;

  insert into public.table_transfers_log (
    seller_id, from_table, to_table, transfer_type,
    transferred_items, order_ids, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_from_table, p_to_table, v_type,
    v_moved_all, v_order_ids, p_waiter_id, p_waiter_name, p_note
  );

  return jsonb_build_object(
    'success', true,
    'transfer_type', v_type,
    'moved_count', v_moved_count
  );
end;
$body$;
$fn$, '__TRANSFER_FN__', v_name);

  execute v_sql;

  if to_regprocedure('public.install_table_operation_staff_wrappers()')
    is not null then
    perform public.install_table_operation_staff_wrappers();
  else
    execute 'revoke all on function public.transfer_table_orders_v2(uuid, integer, integer, text, jsonb, uuid, text, text) from public';
    execute 'grant execute on function public.transfer_table_orders_v2(uuid, integer, integer, text, jsonb, uuid, text, text) to authenticated';
  end if;
end
$migrate$;

comment on function public.transfer_table_orders_v2(
  uuid, integer, integer, text, jsonb, uuid, text, text
) is
  'Full move writes the destination area name, area index, and display label in the same update as table_number. If that label cannot be resolved, the row stays unchanged.';

notify pgrst, 'reload schema';
