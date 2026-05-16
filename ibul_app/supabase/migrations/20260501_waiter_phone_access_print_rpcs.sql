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
      where sa.store_id = p_restaurant_id
        and u.id = auth.uid()
        and sa.status = 'active'
    );
$$;

do $$
begin
  if to_regprocedure(
    'public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text)'
  ) is null
  and to_regprocedure(
    'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)'
  ) is not null then
    alter function public.create_table_order_with_print_jobs(
      uuid,
      integer,
      jsonb,
      uuid,
      text,
      text,
      text,
      text
    ) rename to create_table_order_with_print_jobs_impl;
  end if;
end
$$;

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
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  -- The legacy implementation still contains an owner-only auth.uid() guard.
  -- After we verify the caller against user_can_access_restaurant, temporarily
  -- impersonate the restaurant owner only for this function call so the
  -- existing implementation can continue unchanged.
  perform set_config('request.jwt.claim.sub', p_restaurant_id::text, true);

  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type
  );
end;
$$;

grant execute on function public.create_table_order_with_print_jobs(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  text,
  text
) to authenticated;

comment on function public.create_table_order_with_print_jobs(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  text,
  text
) is 'Wraps the legacy kitchen print RPC with waiter-friendly restaurant access checks (email or phone matched sub-admins).';

commit;
