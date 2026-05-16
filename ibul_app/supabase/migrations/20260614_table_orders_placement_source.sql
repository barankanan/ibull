-- Origin of table_orders rows: distinguishes customer (QR/menu) vs waiter (garson panel)
-- for "Siparişi Onayla" (kitchen dispatch) UX.

alter table public.table_orders
  add column if not exists placement_source text;

comment on column public.table_orders.placement_source is
  'customer: placed via customer app/QR; waiter: placed via garson panel. Controls pending-kitchen-approval UI.';

-- Keep approve_waiter_order_request in sync: customer-origin rows + avoid duplicate kitchen
-- dispatch when print jobs were already created during banner approval.
create or replace function public.approve_waiter_order_request(
  p_request_id uuid,
  p_edited_items jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.waiter_order_requests%rowtype;
  v_src jsonb;
  v_recalc jsonb;
  v_print jsonb;
  v_table_order_id uuid;
  v_label text;
  v_area text;
  v_area_no int;
  v_print_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select * into v_req
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if v_req.status <> 'pending_waiter_approval' then
    raise exception 'Bu istek onay için uygun değil.' using errcode = '22023';
  end if;

  if not public.user_can_access_restaurant(v_req.seller_id) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  v_src := coalesce(
    case
      when p_edited_items is null then null
      when jsonb_typeof(p_edited_items) = 'array'
        and jsonb_array_length(p_edited_items) > 0 then p_edited_items
      else null
    end,
    v_req.items_draft
  );

  if v_src is null
     or jsonb_typeof(v_src) <> 'array'
     or jsonb_array_length(v_src) = 0 then
    raise exception 'Onaylanacak kalem bulunamadı.' using errcode = '22023';
  end if;

  v_recalc := public.recalculate_waiter_request_items(v_req.seller_id, v_src);
  v_print := public.flatten_waiter_items_for_kitchen_print(
    v_req.seller_id,
    v_recalc
  );

  v_label := nullif(
    trim(coalesce(v_req.table_payload ->> 'display_table_label', '')),
    ''
  );
  v_area := nullif(trim(coalesce(v_req.table_payload ->> 'table_area_name', '')), '');
  begin
    v_area_no := (nullif(
      trim(coalesce(v_req.table_payload ->> 'area_table_number', '')),
      ''
    ))::integer;
  exception
    when others then
      v_area_no := null;
  end;
  if v_area_no is not null and v_area_no <= 0 then
    v_area_no := null;
  end if;

  insert into public.table_orders (
    seller_id,
    table_number,
    items,
    status,
    created_at,
    display_table_label,
    table_display_name,
    table_name,
    table_area_name,
    area_name,
    area_table_number,
    placement_source
  )
  values (
    v_req.seller_id,
    v_req.table_number,
    v_recalc,
    'new',
    now(),
    v_label,
    v_label,
    v_label,
    nullif(v_area, ''),
    nullif(v_area, ''),
    v_area_no,
    'customer'
  )
  returning id into v_table_order_id;

  update public.waiter_order_requests
  set
    status = 'approved_converted',
    resolved_by = auth.uid(),
    resolved_at = now(),
    resulting_table_order_id = v_table_order_id,
    server_items_snapshot = v_recalc,
    items_draft = v_src
  where id = p_request_id;

  v_print_result := null;
  if v_print is not null
     and jsonb_typeof(v_print) = 'array'
     and jsonb_array_length(v_print) > 0 then
    v_print_result := public.create_table_order_with_print_jobs(
      v_req.seller_id,
      v_req.table_number,
      v_print,
      auth.uid(),
      coalesce(
        (select u.email from auth.users u where u.id = auth.uid() limit 1),
        'Garson'
      ),
      format(
        'waiter_request:%s %s',
        p_request_id::text,
        coalesce(nullif(trim(v_req.customer_notes), ''), '')
      ),
      'new_order',
      'table'
    );
    update public.table_orders
    set status = 'sent'
    where id = v_table_order_id;
  end if;

  return jsonb_build_object(
    'request_id', p_request_id,
    'table_order_id', v_table_order_id,
    'items', v_recalc,
    'print_result', v_print_result
  );
end;
$$;

revoke all on function public.approve_waiter_order_request from public;
grant execute on function public.approve_waiter_order_request to authenticated;
