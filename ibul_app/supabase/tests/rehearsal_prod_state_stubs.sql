-- Isolated stand-ins for the objects the production approve_waiter_order_request
-- touches. Not production. The approve body below is the live prosrc captured
-- read-only on 2026-11-18 (md5 6af5b196b4fcee16291d505e30572e56).
create table if not exists public.waiter_order_requests (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid, table_number integer, status text,
  items_draft jsonb, table_payload jsonb, customer_notes text,
  resolved_by uuid, resolved_at timestamptz, resulting_table_order_id uuid,
  server_items_snapshot jsonb
);
create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid, table_number integer, items jsonb, status text,
  created_at timestamptz, display_table_label text, table_display_name text,
  table_name text, table_area_name text, area_name text,
  area_table_number integer, placement_source text
);
create or replace function public.user_can_access_restaurant(p uuid)
returns boolean language sql as $$ select auth.uid() = p $$;
create or replace function public.recalculate_waiter_request_items(p uuid, j jsonb)
returns jsonb language sql as $$ select j $$;
create or replace function public.flatten_waiter_items_for_kitchen_print(p uuid, j jsonb)
returns jsonb language sql as $$ select j $$;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key, email text);
insert into auth.users values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner@example.test')
on conflict do nothing;

create or replace function public.approve_waiter_order_request(p_request_id uuid, p_edited_items jsonb)
returns jsonb language plpgsql security definer set search_path = public as $approve$
declare
  v_req public.waiter_order_requests%rowtype;
  v_src jsonb;
  v_recalc jsonb;
  v_print jsonb;
  v_table_order_id uuid;
  v_print_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  select * into v_req from public.waiter_order_requests where id = p_request_id for update;
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
    case when p_edited_items is null then null
         when jsonb_typeof(p_edited_items) = 'array' and jsonb_array_length(p_edited_items) > 0 then p_edited_items
         else null end,
    v_req.items_draft
  );
  v_recalc := public.recalculate_waiter_request_items(v_req.seller_id, v_src);
  v_print := public.flatten_waiter_items_for_kitchen_print(v_req.seller_id, v_recalc);
  insert into public.table_orders (seller_id, table_number, items, status, created_at, placement_source)
  values (v_req.seller_id, v_req.table_number, v_recalc, 'new', now(), 'customer')
  returning id into v_table_order_id;
  update public.waiter_order_requests
  set status = 'approved_converted', resolved_by = auth.uid(), resolved_at = now(),
      resulting_table_order_id = v_table_order_id, server_items_snapshot = v_recalc
  where id = p_request_id;
  v_print_result := null;
  if v_print is not null and jsonb_typeof(v_print) = 'array' and jsonb_array_length(v_print) > 0 then
    -- EXACT call shape of the live function: 8 positional arguments.
    v_print_result := public.create_table_order_with_print_jobs(
      v_req.seller_id,
      v_req.table_number,
      v_print,
      auth.uid(),
      coalesce((select u.email from auth.users u where u.id = auth.uid() limit 1), 'Garson'),
      format('waiter_request:%s %s', p_request_id::text, coalesce(nullif(trim(v_req.customer_notes), ''), '')),
      'new_order',
      'table'
    );
    update public.table_orders set status = 'sent' where id = v_table_order_id;
  end if;
  return jsonb_build_object('request_id', p_request_id, 'table_order_id', v_table_order_id,
                            'items', v_recalc, 'print_result', v_print_result);
end;
$approve$;
