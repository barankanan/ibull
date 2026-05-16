-- Add print_system_enabled to restaurant_print_station_configs
-- Add paused_by_operator status to print_jobs

alter table public.restaurant_print_station_configs
  add column if not exists print_system_enabled boolean not null default true;

alter table public.print_jobs
  drop constraint if exists print_jobs_status_check;

alter table public.print_jobs
  add constraint print_jobs_status_check
  check (status in ('pending', 'claimed', 'printing', 'completed', 'failed', 'paused_by_operator'));

-- Update existing paused jobs if any
update public.print_jobs
  set status = 'paused_by_operator'
  where status = 'pending' and created_at < now() - interval '1 hour';

comment on column public.restaurant_print_station_configs.print_system_enabled
  is 'Whether the print system is enabled for this restaurant. When false, new print jobs are created with paused_by_operator status.';

comment on column public.print_jobs.status
  is 'Print job status: pending (ready for dispatch), claimed (being processed), printing (sent to printer), completed (successfully printed), failed (max retries exceeded), paused_by_operator (system disabled by operator).';

-- Function to create print jobs with print_system_enabled check
create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_order_number text;
  v_print_system_enabled boolean := true;
  v_job_status text := 'pending';
  v_print_jobs jsonb := '[]'::jsonb;
  v_item record;
  v_job_id uuid;
  v_station_id uuid;
  v_printer_id uuid;
begin
  -- Check print system enabled
  select print_system_enabled into v_print_system_enabled
  from restaurant_print_station_configs
  where restaurant_id = p_restaurant_id
  order by updated_at desc
  limit 1;

  if v_print_system_enabled is false then
    v_job_status := 'paused_by_operator';
  end if;

  -- Create order
  insert into orders (
    restaurant_id,
    table_number,
    order_type,
    status,
    waiter_id,
    waiter_name,
    notes
  ) values (
    p_restaurant_id,
    p_table_number,
    p_order_type,
    'active',
    p_waiter_id,
    p_waiter_name,
    p_notes
  ) returning id, order_number into v_order_id, v_order_number;

  -- Create print jobs for each station
  for v_item in select * from jsonb_array_elements(p_items) loop
    -- Determine station and printer
    select s.id, p.id into v_station_id, v_printer_id
    from stations s
    left join printers p on p.station_id = s.id and p.is_default = true
    where s.restaurant_id = p_restaurant_id
      and s.name = v_item.value->>'station_name'
    limit 1;

    if v_station_id is not null then
      -- Create print job
      insert into print_jobs (
        restaurant_id,
        order_id,
        station_id,
        printer_id,
        job_type,
        status,
        payload
      ) values (
        p_restaurant_id,
        v_order_id,
        v_station_id,
        v_printer_id,
        p_job_type,
        v_job_status,
        v_item.value
      ) returning id into v_job_id;

      -- Create print job items
      if v_item.value->'order_item_ids' is not null then
        insert into print_job_items (print_job_id, order_item_id)
        select v_job_id, (item->>'id')::uuid
        from jsonb_array_elements(v_item.value->'order_item_ids') as item;
      end if;

      -- Add to result
      v_print_jobs := v_print_jobs || jsonb_build_object(
        'print_job_id', v_job_id,
        'station_name', v_item.value->>'station_name',
        'status', v_job_status
      );
    end if;
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'print_jobs', v_print_jobs,
    'print_system_enabled', v_print_system_enabled
  );
end;
$$;

grant execute on function public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text) to authenticated;
comment on function public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)
  is 'Create a table order with print jobs. If print system is disabled, jobs are created with paused_by_operator status.';