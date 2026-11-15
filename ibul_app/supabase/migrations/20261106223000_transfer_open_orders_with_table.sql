-- DO NOT APPLY to production unless the operator names this file and says
-- Bu migration'ı production'a uygula.
--
-- Live transfer_table_orders (20261102194242) already casts
-- table_orders.seller_id to text. Postgres logs still raise
-- "Aktarılacak sipariş yok. Kayıtlar yerinde kaldı." because open checks
-- also live in public.orders.table_id. This replacement keeps that
-- table_orders path and, for a full transfer only, moves those orders onto
-- the destination store_tables.id. A occupied destination is a merge: its
-- rows are not deleted or overwritten. Payments move with the table number
-- on a full transfer. A partial transfer does not retarget orders. The
-- money guard is opened only for this table_id update and then turned off.
-- Money columns and payment_status are not written.

create or replace function public.transfer_table_orders(
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
  v_order record;
  v_moved_order record;
  v_moved_items jsonb := '[]'::jsonb;
  v_piece jsonb;
  v_kept_items jsonb;
  v_order_ids jsonb := '[]'::jsonb;
  v_moved_count integer := 0;
  v_from_branch uuid;
  v_to_branch uuid;
  v_from_table_id uuid;
  v_to_table_id uuid;
  v_seller_text text := p_seller_id::text;
begin
  perform public.restaurant_staff_may_operate(p_seller_id, 'transferTable', p_from_table);
  perform public.restaurant_staff_may_operate(p_seller_id, 'transferTable', p_to_table);

  if p_from_table is null or p_to_table is null
     or p_from_table <= 0 or p_to_table <= 0 then
    raise exception 'Geçersiz masa.' using errcode = '22023';
  end if;
  if p_from_table = p_to_table then
    raise exception 'Kaynak ve hedef masa aynı olamaz.' using errcode = '22023';
  end if;

  select t.id, t.branch_id into v_from_table_id, v_from_branch
  from public.store_tables t
  where t.seller_id = p_seller_id
    and t.table_number = p_from_table
    and coalesce(t.is_active, true)
  limit 1;
  select t.id, t.branch_id into v_to_table_id, v_to_branch
  from public.store_tables t
  where t.seller_id = p_seller_id
    and t.table_number = p_to_table
    and coalesce(t.is_active, true)
  limit 1;
  if not found then
    raise exception 'Hedef masa bu işletmede yok.' using errcode = '22023';
  end if;
  if v_from_table_id is null then
    raise exception 'Kaynak masa bu işletmede yok.' using errcode = '22023';
  end if;
  if v_from_branch is distinct from v_to_branch then
    raise exception 'Masalar farklı şubede. Aktarma yapılmadı.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    v_seller_text || ':transfer:' || least(p_from_table, p_to_table)::text
      || ':' || greatest(p_from_table, p_to_table)::text,
    0
  ));

  for v_order in
    select *
    from public.table_orders
    where seller_id = v_seller_text
      and table_number = p_from_table
      and lower(btrim(coalesce(status, ''))) not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'archived', 'payment_completed', 'completed_payment'
      )
    for update
  loop
    if coalesce(p_transfer_type, 'full') = 'full' then
      update public.table_orders
      set table_number = p_to_table,
          updated_at = timezone('utc', now())
      where id = v_order.id
        and seller_id = v_seller_text;
      v_order_ids := v_order_ids || to_jsonb(v_order.id::text);
      v_moved_items := v_moved_items || coalesce(v_order.items, '[]'::jsonb);
      v_moved_count := v_moved_count + 1;
    else
      select
        coalesce(jsonb_agg(item) filter (
          where (item->>'id') = any (select jsonb_array_elements_text(p_item_ids))
        ), '[]'::jsonb),
        coalesce(jsonb_agg(item) filter (
          where (item->>'id') <> all (select jsonb_array_elements_text(p_item_ids))
             or (item->>'id') is null
        ), '[]'::jsonb)
      into v_piece, v_kept_items
      from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) item;
      v_moved_items := v_moved_items || v_piece;

      if jsonb_array_length(v_piece) = 0 then
        continue;
      end if;
      v_order_ids := v_order_ids || to_jsonb(v_order.id::text);

      if jsonb_array_length(v_kept_items) = 0 then
        update public.table_orders
        set table_number = p_to_table,
            updated_at = timezone('utc', now())
        where id = v_order.id
          and seller_id = v_seller_text;
      else
        update public.table_orders
        set items = v_kept_items,
            updated_at = timezone('utc', now())
        where id = v_order.id
          and seller_id = v_seller_text;
        insert into public.table_orders (
          seller_id, table_number, items, status, created_at, placement_source
        ) values (
          v_seller_text,
          p_to_table,
          v_piece,
          'new',
          timezone('utc', now()),
          'transfer'
        );
      end if;
      v_moved_count := v_moved_count + 1;
    end if;
  end loop;

  if coalesce(p_transfer_type, 'full') = 'full' then
    perform set_config('ibul.marketplace_order_rpc', 'on', true);
    for v_moved_order in
      update public.orders o
      set table_id = v_to_table_id,
          updated_at = timezone('utc', now())
      where o.restaurant_id = p_seller_id
        and o.table_id = v_from_table_id
        and (o.order_type = 'table' or o.delivery_type = 'table')
        and coalesce(o.status, '') not in (
          'closed', 'paid', 'cancelled', 'canceled',
          'completed', 'complete', 'archived', 'payment_completed'
        )
      returning o.id
    loop
      v_order_ids := v_order_ids || to_jsonb(v_moved_order.id::text);
      v_moved_count := v_moved_count + 1;
    end loop;
    perform set_config('ibul.marketplace_order_rpc', 'off', true);

    update public.table_payments
    set table_number = p_to_table
    where seller_id = p_seller_id
      and table_number = p_from_table;
  elsif v_moved_count = 0 and exists (
    select 1
    from public.orders o
    where o.restaurant_id = p_seller_id
      and o.table_id = v_from_table_id
      and (o.order_type = 'table' or o.delivery_type = 'table')
      and coalesce(o.status, '') not in (
        'closed', 'paid', 'cancelled', 'canceled',
        'completed', 'complete', 'archived', 'payment_completed'
      )
  ) then
    raise exception
      'Parça aktarma bu sipariş kaydında yok. Tam aktarma kullanın. Kayıtlar yerinde kaldı.'
      using errcode = 'P0002';
  end if;

  if v_moved_count = 0 then
    raise exception 'Aktarılacak sipariş yok. Kayıtlar yerinde kaldı.'
      using errcode = 'P0002';
  end if;

  insert into public.table_transfers_log (
    seller_id, from_table, to_table, transfer_type,
    transferred_items, order_ids, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_from_table, p_to_table, coalesce(p_transfer_type, 'full'),
    v_moved_items, v_order_ids, p_waiter_id, p_waiter_name, p_note
  );

  return jsonb_build_object(
    'success', true,
    'moved_count', v_moved_count,
    'moved_items', v_moved_items,
    'transfer_type', coalesce(p_transfer_type, 'full')
  );
end;
$$;
