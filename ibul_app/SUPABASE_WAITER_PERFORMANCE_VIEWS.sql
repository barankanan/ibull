-- Garson performance: active-table kitchen reprint clone (no order RPC).
-- Idempotent: safe to run multiple times.

create or replace function public.enqueue_active_kitchen_reprint_clone(
  p_restaurant_id uuid,
  p_table_number integer,
  p_payload jsonb,
  p_source_job_id uuid default null,
  p_order_id uuid default null,
  p_station_id uuid default null,
  p_printer_id uuid default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id uuid;
  v_payload jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  if p_table_number <= 0 then
    raise exception 'Masa numarası geçersiz.' using errcode = '22023';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Mutfak fişi payload geçersiz.' using errcode = '22023';
  end if;

  v_payload := p_payload
    || jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'table_no', p_table_number::text,
      'table_number', p_table_number,
      'waiter_id', p_waiter_id,
      'waiter_name', coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson'),
      'printer_role', coalesce(p_payload->>'printer_role', 'mutfak'),
      'document_type', coalesce(p_payload->>'document_type', 'kitchen'),
      'job_type', 'reprint',
      'reprint_source_job_id', p_source_job_id,
      'reprint_notes', coalesce(p_notes, p_payload->>'notes'),
      'created_at', now()
    );

  insert into public.print_jobs (
    restaurant_id,
    order_id,
    station_id,
    printer_id,
    job_type,
    document_type,
    printer_role,
    status,
    payload
  )
  values (
    p_restaurant_id,
    p_order_id,
    p_station_id,
    p_printer_id,
    'reprint',
    coalesce(v_payload->>'document_type', 'kitchen'),
    coalesce(v_payload->>'printer_role', 'mutfak'),
    'pending',
    v_payload
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'status', 'ok',
    'print_job_id', v_job_id,
    'print_job_count', 1,
    'print_job_ids', jsonb_build_array(v_job_id),
    'reprint_source_job_id', p_source_job_id
  );
end;
$$;

grant execute on function public.enqueue_active_kitchen_reprint_clone(
  uuid,
  integer,
  jsonb,
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text
) to authenticated;

comment on function public.enqueue_active_kitchen_reprint_clone(
  uuid,
  integer,
  jsonb,
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text
) is
  'Clones an existing kitchen print payload into a new pending print_jobs row for active-table reprint without recreating orders.';

-- Optional indexes for garson board / reprint lookups (idempotent).
create index if not exists idx_print_jobs_restaurant_order_created
  on public.print_jobs (restaurant_id, order_id, created_at desc);

create index if not exists idx_table_orders_seller_status_table
  on public.table_orders (seller_id, status, table_number);

create index if not exists idx_order_items_order_id
  on public.order_items (order_id);
