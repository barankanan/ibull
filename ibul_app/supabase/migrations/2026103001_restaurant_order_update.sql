-- In-place update for orders created by create_table_order_with_print_jobs.
-- Not applied to production. Requires 2026102901 and 2026102902 first.
begin;
create or replace function public.update_restaurant_table_order(
  p_restaurant_id uuid,
  p_order_id uuid,
  p_items jsonb,
  p_print_items jsonb default '[]'::jsonb,
  p_job_type text default 'add_item',
  p_extra_print_items jsonb default '[]'::jsonb,
  p_extra_job_type text default 'cancel_item',
  p_revision_key text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null
) returns jsonb language plpgsql security definer set search_path = public
as $function$
declare
  v_previous_rpc text := current_setting('ibul.marketplace_order_rpc', true);
  v_revision text := nullif(trim(coalesce(p_revision_key, '')), '');
  v_order_restaurant uuid;
  v_table_id uuid;
  v_order_number text;
  v_order_type text;
  v_shipping numeric;
  v_discount numeric;
  v_subtotal numeric;
  v_qty integer;
  v_price numeric;
  v_match uuid;
  v_raw_id text;
  v_product text;
  v_name text;
  v_note text;
  v_station uuid;
  v_used uuid[] := array[]::uuid[];
  v_candidates integer;
  v_removed record;
  v_cancel_count integer;
  v_cancel_index integer;
  v_cancel_found boolean;
  v_cancel_item jsonb;
  v_cancel_used boolean[] := array[]::boolean[];
  v_existing_ids jsonb;
  v_batch record;
  v_group record;
  v_item record;
  v_printer_id uuid;
  v_print_size text;
  v_job_id uuid;
  v_job_ids jsonb := '[]'::jsonb;
  v_station_items jsonb;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli.' using errcode = '42501';
  end if;
  if v_revision is null then
    raise exception 'Güncelleme anahtarı gerekli.' using errcode = '22023';
  end if;
  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint')
     or p_extra_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz fiş tipi.' using errcode = '22023';
  end if;
  if not public.restaurant_has_permission(p_restaurant_id, 'manageOrders') then
    raise exception 'Bu restoran için sipariş güncelleme yetkiniz yok.' using errcode = '42501';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemi boş olamaz.' using errcode = '22023';
  end if;

  select o.restaurant_id, o.table_id, o.order_number, o.order_type,
         coalesce(o.shipping_amount, 0), coalesce(o.discount_amount, 0)
    into v_order_restaurant, v_table_id, v_order_number, v_order_type,
         v_shipping, v_discount
  from public.orders o
  where o.id = p_order_id
  for update;
  if v_order_restaurant is null or v_order_restaurant is distinct from p_restaurant_id then
    raise exception 'Kayıtlı sipariş bulunamadı.' using errcode = 'P0002';
  end if;
  if coalesce(v_order_type, '') is distinct from 'table' or v_table_id is null then
    raise exception 'Yalnız masa siparişi güncellenebilir.' using errcode = '42501';
  end if;
  if not public.restaurant_table_access(p_restaurant_id, v_table_id) then
    raise exception 'Bu şubede işlem yetkiniz yok.' using errcode = '42501';
  end if;
  if exists (
    select 1
    from (
      select nullif(trim(coalesce(item->>'station_id', '')), '') as sid
      from jsonb_array_elements(p_items) item
      union all
      select nullif(trim(coalesce(item->>'station_id', '')), '')
      from jsonb_array_elements(coalesce(p_print_items, '[]'::jsonb)) item
      union all
      select nullif(trim(coalesce(item->>'station_id', '')), '')
      from jsonb_array_elements(coalesce(p_extra_print_items, '[]'::jsonb)) item
    ) stations
    where stations.sid is not null
      and not exists (
        select 1 from public.stations st
        where st.id = stations.sid::uuid and st.restaurant_id = p_restaurant_id
      )
  ) then
    raise exception 'İstasyon bu işletmeye ait değil.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(id), '[]'::jsonb)
    into v_existing_ids
  from public.print_jobs
  where restaurant_id = p_restaurant_id
    and order_id = p_order_id
    and payload->>'revision_key' = v_revision;
  if v_existing_ids is not null and jsonb_array_length(v_existing_ids) > 0 then
    return jsonb_build_object(
      'order_id', p_order_id,
      'order_number', v_order_number,
      'print_job_ids', v_existing_ids,
      'print_job_count', jsonb_array_length(v_existing_ids),
      'idempotent_replay', true
    );
  end if;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := greatest(coalesce((v_item.value->>'quantity')::integer, 1), 1);
    v_price := coalesce((v_item.value->>'unit_price')::numeric, (v_item.value->>'price')::numeric, 0);
    v_product := nullif(trim(coalesce(v_item.value->>'product_id', '')), '');
    v_name := coalesce(v_item.value->>'name', v_item.value->>'product_name', v_item.value->>'item_name', 'Ürün');
    v_note := nullif(trim(coalesce(
      v_item.value->>'item_note', v_item.value->>'note', v_item.value->>'notes', ''
    )), '');
    v_station := nullif(trim(coalesce(v_item.value->>'station_id', '')), '')::uuid;
    v_raw_id := nullif(trim(coalesce(v_item.value->>'order_item_id', '')), '');
    v_match := null;
    if v_raw_id is not null then
      if v_raw_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise exception 'Sipariş kalemi kimliği geçersiz. Güncelleme geri alındı.'
          using errcode = '22023';
      end if;
      select oi.id into v_match
      from public.order_items oi
      where oi.order_id = p_order_id
        and oi.id = v_raw_id::uuid
        and not (oi.id = any(v_used));
      if v_match is null then
        raise exception 'Sipariş kalemi bulunamadı. Güncelleme geri alındı.'
          using errcode = 'P0002';
      end if;
    else
      select count(*) into v_candidates
      from public.order_items oi
      where oi.order_id = p_order_id
        and not (oi.id = any(v_used))
        and oi.product_id is not distinct from v_product
        and (v_station is null or oi.station_id is not distinct from v_station);
      if v_candidates > 1 then
        raise exception 'Aynı ürünün birden fazla kalemi var. Sipariş kalemi kimliği olmadan güncellenemez. Güncelleme geri alındı.'
          using errcode = '22023';
      elsif v_candidates = 1 then
        select oi.id into v_match
        from public.order_items oi
        where oi.order_id = p_order_id
          and not (oi.id = any(v_used))
          and oi.product_id is not distinct from v_product
          and (v_station is null or oi.station_id is not distinct from v_station);
      end if;
    end if;
    if v_match is not null then
      update public.order_items
      set product_name = v_name,
          quantity = v_qty,
          item_note = v_note,
          unit_price = v_price,
          total_price = v_qty * v_price,
          line_total = v_qty * v_price,
          station_id = coalesce(v_station, station_id),
          attributes = case
            when v_item.value ? 'plates'
              or v_item.value ? 'service_children'
              or v_item.value ? 'child_items'
            then jsonb_strip_nulls(jsonb_build_object(
              'kitchen_plates', v_item.value -> 'plates',
              'kitchen_service_children', v_item.value -> 'service_children',
              'child_items', v_item.value -> 'child_items'
            ))
            else attributes
          end,
          updated_at = now()
      where id = v_match;
    else
      insert into public.order_items (
        order_id, seller_id, product_id, product_name, quantity, item_note,
        unit_price, total_price, line_total, station_id, attributes
      ) values (
        p_order_id, p_restaurant_id, v_product, v_name, v_qty, v_note,
        v_price, v_qty * v_price, v_qty * v_price, v_station,
        coalesce(
          case
            when v_item.value ? 'plates'
              or v_item.value ? 'service_children'
              or v_item.value ? 'child_items'
            then jsonb_strip_nulls(jsonb_build_object(
              'kitchen_plates', v_item.value -> 'plates',
              'kitchen_service_children', v_item.value -> 'service_children',
              'child_items', v_item.value -> 'child_items'
            ))
            else '{}'::jsonb
          end,
          '{}'::jsonb
        )
      ) returning id into v_match;
    end if;
    v_used := v_used || v_match;
  end loop;
  v_cancel_count := coalesce(jsonb_array_length(coalesce(p_extra_print_items, '[]'::jsonb)), 0);
  if v_cancel_count > 0 then
    v_cancel_used := array_fill(false, array[v_cancel_count]);
  end if;
  for v_removed in
    select oi.id, oi.product_id, oi.quantity, oi.station_id, oi.item_note,
           oi.kitchen_status, oi.sent_to_kitchen_at
    from public.order_items oi
    where oi.order_id = p_order_id
      and not (oi.id = any(v_used))
  loop
    if v_removed.kitchen_status is distinct from 'preparing'
       and v_removed.sent_to_kitchen_at is null then
      continue;
    end if;
    if v_removed.station_id is null or p_extra_job_type is distinct from 'cancel_item' then
      raise exception 'Hazırlanan ürün için mutfak iptal fişi oluşturulamadı. Sipariş güncellemesi geri alındı.'
        using errcode = 'P0001';
    end if;
    v_cancel_found := false;
    for v_cancel_index in 1..v_cancel_count loop
      if v_cancel_used[v_cancel_index] then
        continue;
      end if;
      v_cancel_item := p_extra_print_items -> (v_cancel_index - 1);
      if coalesce(v_cancel_item->>'product_id', '') is distinct from coalesce(v_removed.product_id, '')
         or coalesce((v_cancel_item->>'quantity')::integer, -1) is distinct from v_removed.quantity
         or nullif(trim(coalesce(v_cancel_item->>'station_id', '')), '')::uuid
            is distinct from v_removed.station_id then
        continue;
      end if;
      if nullif(trim(coalesce(v_cancel_item->>'order_item_id', '')), '') is not null
         and nullif(trim(v_cancel_item->>'order_item_id'), '') is distinct from v_removed.id::text then
        continue;
      end if;
      if nullif(trim(coalesce(v_cancel_item->>'order_item_id', '')), '') is null
         and nullif(trim(coalesce(v_cancel_item->>'item_note', v_cancel_item->>'note', v_cancel_item->>'notes', '')), '')
            is distinct from v_removed.item_note then
        continue;
      end if;
      v_cancel_used[v_cancel_index] := true;
      v_cancel_found := true;
      exit;
    end loop;
    if not v_cancel_found then
      if v_cancel_count = 0 then
        raise exception 'Hazırlanan ürün için mutfak iptal fişi oluşturulamadı. Sipariş güncellemesi geri alındı.'
          using errcode = 'P0001';
      end if;
      raise exception 'Hazırlanan ürün için mutfak iptal fişi silinen kalemle uyuşmuyor. Sipariş güncellemesi geri alındı.'
        using errcode = 'P0001';
    end if;
  end loop;
  delete from public.order_items
  where order_id = p_order_id and not (id = any(v_used));
  select coalesce(sum(line_total), 0) into v_subtotal
  from public.order_items where order_id = p_order_id;
  update public.orders
  set updated_at = now(),
      waiter_id = coalesce(p_waiter_id, waiter_id),
      subtotal_amount = v_subtotal,
      total_amount = greatest(v_subtotal - v_discount, 0) + v_shipping
  where id = p_order_id;

  -- Existing print_jobs stay untouched. A new revision inserts new rows only.
  for v_batch in
    select p_job_type as job_type, p_print_items as items
    union all
    select p_extra_job_type, p_extra_print_items
  loop
    if jsonb_typeof(v_batch.items) is distinct from 'array'
       or jsonb_array_length(v_batch.items) = 0 then
      continue;
    end if;
    for v_group in
      select distinct nullif(trim(coalesce(item->>'station_id', '')), '')::uuid as station_id
      from jsonb_array_elements(v_batch.items) item
    loop
      v_printer_id := null;
      v_print_size := 'normal';
      select sp.printer_id, coalesce(nullif(trim(pr.print_size), ''), 'normal')
        into v_printer_id, v_print_size
      from public.station_printers sp
      join public.printers pr on pr.id = sp.printer_id and pr.is_active = true
      where sp.station_id = v_group.station_id
        and pr.restaurant_id = p_restaurant_id
      order by sp.is_primary desc nulls last, sp.created_at asc
      limit 1;
      select coalesce(jsonb_agg(item), '[]'::jsonb)
        into v_station_items
      from jsonb_array_elements(v_batch.items) item
      where nullif(trim(coalesce(item->>'station_id', '')), '')::uuid is not distinct from v_group.station_id;
      insert into public.print_jobs (
        restaurant_id, order_id, station_id, printer_id, job_type, status,
        order_saved_at, print_job_created_at, payload
      ) values (
        p_restaurant_id, p_order_id, v_group.station_id, v_printer_id, v_batch.job_type,
        case when coalesce((
          select print_system_enabled from public.restaurant_print_station_configs
          where restaurant_id = p_restaurant_id
        ), true) then 'pending' else 'paused_by_operator' end,
        now(), clock_timestamp(),
        jsonb_build_object(
          'revision_key', v_revision,
          'job_type', v_batch.job_type,
          'items', v_station_items,
          'print_size_source', 'printer_settings',
          'print_size', v_print_size,
          'order_id', p_order_id,
          'order_number', v_order_number
        )
      ) returning id into v_job_id;
      v_job_ids := v_job_ids || to_jsonb(v_job_id);
    end loop;
  end loop;

  perform set_config('ibul.marketplace_order_rpc', coalesce(v_previous_rpc, ''), true);
  return jsonb_build_object(
    'order_id', p_order_id,
    'order_number', v_order_number,
    'print_job_ids', v_job_ids,
    'print_job_count', jsonb_array_length(v_job_ids),
    'idempotent_replay', false
  );
end;
$function$;
revoke all on function public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text) from public, anon;
grant execute on function public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text) to authenticated;
notify pgrst, 'reload schema';
commit;
