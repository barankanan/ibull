-- DO NOT APPLY to the live project from this workspace.
-- Print identity is stamped on insert. It does not change claim or status.
-- Staff who still must change the temporary password cannot pass
-- restaurant_has_permission. Owners and accounts without that flag are unchanged.

begin;

create or replace function public.staff_must_change_password()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'managed_restaurant_staff') = 'true'
    and (auth.jwt() -> 'app_metadata' ->> 'must_change_password') = 'true',
    false
  );
$$;

create or replace function public.restaurant_has_permission(
  p_restaurant_id uuid,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and not public.staff_must_change_password()
    and (
      exists(
        select 1 from public.stores
        where seller_id = p_restaurant_id and seller_id = auth.uid()
      )
      or exists(
        select 1 from public.store_sub_admins sa
        join auth.users au on au.id = auth.uid()
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and (sa.branch_id is null or exists(
            select 1 from public.store_branches b
            where b.id = sa.branch_id
              and b.store_id = sa.store_id
              and b.status = 'active'
          ))
          and (p_permission is null or p_permission = any(sa.permissions))
          and (sa.auth_user_id = au.id or (sa.auth_user_id is null and (
            (au.email_confirmed_at is not null and lower(trim(sa.email)) = lower(trim(au.email)))
            or (au.phone_confirmed_at is not null and sa.phone = au.phone)
          )))
      )
    );
$$;

create or replace function public.restaurant_table_access(
  p_restaurant_id uuid,
  p_table_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.staff_must_change_password()
    and (
      auth.uid() = p_restaurant_id
      or exists(
        select 1 from public.store_sub_admins sa
        join auth.users au on au.id = auth.uid()
        join public.store_tables t on t.id = p_table_id
          and t.seller_id = sa.store_id
          and t.is_active
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and (sa.branch_id is null or (
            t.branch_id = sa.branch_id
            and exists(
              select 1 from public.store_branches b
              where b.id = sa.branch_id
                and b.store_id = sa.store_id
                and b.status = 'active'
            )
          ))
          and (sa.auth_user_id = au.id or (sa.auth_user_id is null and (
            (au.email_confirmed_at is not null and lower(trim(sa.email)) = lower(trim(au.email)))
            or (au.phone_confirmed_at is not null and sa.phone = au.phone)
          )))
      )
    );
$$;

-- restaurant | order key | revision | station | job type
-- order key prefers orders.local_order_id, then the cloud order id.
create or replace function public.stamp_print_job_logical_key()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_local text;
  v_revision text;
  v_station text;
  v_job text;
  v_order_key text;
begin
  v_local := nullif(trim(coalesce(new.payload->>'local_order_id', '')), '');
  if v_local is null and new.order_id is not null then
    select nullif(trim(coalesce(local_order_id, '')), '')
      into v_local
    from public.orders
    where id = new.order_id;
  end if;
  v_order_key := coalesce(v_local, new.order_id::text, '');
  v_revision := coalesce(
    nullif(trim(coalesce(new.payload->>'revision_key', '')), ''),
    nullif(trim(coalesce(new.payload->>'revision', '')), ''),
    '1'
  );
  v_station := coalesce(new.station_id::text, nullif(trim(coalesce(new.payload->>'station_id', '')), ''), '');
  v_job := coalesce(nullif(trim(coalesce(new.job_type, '')), ''), nullif(trim(coalesce(new.payload->>'job_type', '')), ''), 'new_order');
  new.payload := coalesce(new.payload, '{}'::jsonb) || jsonb_build_object(
    'local_order_id', coalesce(v_local, new.payload->>'local_order_id'),
    'logical_print_key', concat_ws('|', new.restaurant_id::text, v_order_key, v_revision, v_station, v_job)
  );
  return new;
end;
$$;

drop trigger if exists print_jobs_stamp_logical_key on public.print_jobs;
create trigger print_jobs_stamp_logical_key
  before insert on public.print_jobs
  for each row
  execute function public.stamp_print_job_logical_key();

commit;
