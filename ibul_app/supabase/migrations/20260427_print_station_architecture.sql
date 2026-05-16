begin;

create or replace function public.user_can_access_restaurant(
  p_restaurant_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() = p_restaurant_id
    or exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on lower(trim(u.email)) = lower(trim(sa.email))
      where sa.store_id = p_restaurant_id
        and u.id = auth.uid()
        and sa.status = 'active'
    );
$$;

alter table public.print_jobs
  alter column order_id drop not null;

alter table public.print_jobs
  drop constraint if exists print_jobs_job_type_check;

alter table public.print_jobs
  add constraint print_jobs_job_type_check
  check (
    job_type in (
      'new_order',
      'add_item',
      'cancel_item',
      'reprint',
      'receipt',
      'test_receipt'
    )
  );

alter table public.print_jobs
  add column if not exists document_type text not null default 'kitchen',
  add column if not exists printer_role text not null default 'mutfak',
  add column if not exists claimed_by text,
  add column if not exists printer_write_completed_at timestamptz,
  add column if not exists last_attempt_at timestamptz;

update public.print_jobs
set document_type = coalesce(nullif(document_type, ''), 'kitchen'),
    printer_role = coalesce(nullif(printer_role, ''), 'mutfak')
where document_type is null
   or btrim(document_type) = ''
   or printer_role is null
   or btrim(printer_role) = '';

alter table public.print_jobs
  drop constraint if exists print_jobs_document_type_check;

alter table public.print_jobs
  add constraint print_jobs_document_type_check
  check (document_type in ('kitchen', 'receipt', 'test'));

alter table public.print_jobs
  drop constraint if exists print_jobs_printer_role_check;

alter table public.print_jobs
  add constraint print_jobs_printer_role_check
  check (printer_role in ('mutfak', 'adisyon'));

create index if not exists idx_print_jobs_restaurant_status_role_created
  on public.print_jobs(restaurant_id, status, printer_role, created_at);

create table if not exists public.restaurant_print_station_configs (
  restaurant_id uuid primary key references public.stores(seller_id) on delete cascade,
  bridge_enabled boolean not null default false,
  bridge_status text not null default 'offline',
  device_name text,
  device_platform text,
  adisyon_printer_id text,
  adisyon_printer_name text,
  kitchen_printer_id text,
  kitchen_printer_name text,
  last_seen_at timestamptz,
  last_job_received_at timestamptz,
  last_job_completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_restaurant_print_station_configs_seen
  on public.restaurant_print_station_configs(last_seen_at);

alter table public.restaurant_print_station_configs enable row level security;

drop policy if exists "restaurant_print_station_configs_owner_all"
  on public.restaurant_print_station_configs;

create policy "restaurant_print_station_configs_owner_all"
on public.restaurant_print_station_configs
for all
to authenticated
using (public.user_can_access_restaurant(restaurant_id))
with check (public.user_can_access_restaurant(restaurant_id));

drop policy if exists "print_jobs_owner_all" on public.print_jobs;

create policy "print_jobs_owner_all"
on public.print_jobs
for all
to authenticated
using (public.user_can_access_restaurant(restaurant_id))
with check (public.user_can_access_restaurant(restaurant_id));

drop policy if exists "print_job_items_owner_all" on public.print_job_items;

create policy "print_job_items_owner_all"
on public.print_job_items
for all
to authenticated
using (
  exists (
    select 1
    from public.print_jobs pj
    where pj.id = print_job_items.print_job_id
      and public.user_can_access_restaurant(pj.restaurant_id)
  )
)
with check (
  exists (
    select 1
    from public.print_jobs pj
    where pj.id = print_job_items.print_job_id
      and public.user_can_access_restaurant(pj.restaurant_id)
  )
);

create or replace function public.create_adisyon_print_job(
  p_restaurant_id uuid,
  p_table_number integer,
  p_payload jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_source_device text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id uuid;
  v_restaurant_name text;
  v_waiter_name text;
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
    raise exception 'Adisyon payload geçersiz.' using errcode = '22023';
  end if;

  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  if v_restaurant_name is null then
    raise exception 'Restoran bulunamadı.' using errcode = '22023';
  end if;

  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson');
  v_payload := p_payload
    || jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'table_no', p_table_number::text,
      'table_number', p_table_number,
      'waiter_id', p_waiter_id,
      'waiter_name', v_waiter_name,
      'printer_role', 'adisyon',
      'document_type', 'receipt',
      'job_type', 'receipt',
      'source_device', coalesce(nullif(trim(coalesce(p_source_device, '')), ''), 'seller_panel'),
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
    null,
    null,
    null,
    'receipt',
    'receipt',
    'adisyon',
    'pending',
    v_payload
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'status', 'ok',
    'print_job_id', v_job_id,
    'print_job_count', 1,
    'print_job_ids', jsonb_build_array(v_job_id)
  );
end;
$$;

grant execute on function public.create_adisyon_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text
) to authenticated;

comment on function public.create_adisyon_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text
)
is 'Queues a centralized adisyon receipt print job for the restaurant print station.';

commit;
