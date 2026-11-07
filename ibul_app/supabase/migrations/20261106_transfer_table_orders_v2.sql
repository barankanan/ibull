-- Line-level table transfer.
-- The legacy transfer_table_orders function inserts an empty destination
-- order when selected ids do not match item->>'id', and its client fallback
-- moved every row. This function moves only the selected lines and refuses
-- to create an empty order.
-- Do not apply to production from automation. Run it in a reviewed migration.

create or replace function public.transfer_table_orders_v2(
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
as $$
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
      update public.table_orders
      set table_number = p_to_table,
          items = v_moved
      where id = v_order.id
        and seller_id = p_seller_id;
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
$$;

grant execute on function public.transfer_table_orders_v2(
  uuid, integer, integer, text, jsonb, uuid, text, text
) to authenticated;

comment on function public.transfer_table_orders_v2(
  uuid, integer, integer, text, jsonb, uuid, text, text
) is
  'Moves a full table or selected lines. Does not insert an empty order.';

do $$
begin
  if to_regprocedure('public.install_table_operation_staff_wrappers()') is not null then
    perform public.install_table_operation_staff_wrappers();
  end if;
end
$$;
