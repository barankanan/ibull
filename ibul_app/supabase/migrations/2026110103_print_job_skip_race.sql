-- DO NOT APPLY to the live project from this workspace.
-- Replaces skip_duplicate_print_job. Does not update or delete existing rows.
--
-- The existence check is not a plain SELECT. It first takes a transaction
-- advisory lock on the logical key, so a second insert waits until the first
-- commits and then sees that row. The trigger does not lock orders. An order
-- RPC that locks its order row and then inserts cannot deadlock with an
-- insert that only needs this advisory lock: there is no lock cycle.
--
-- A unique index is still omitted. unique_violation inside the order RPC
-- rolls the order change back. RETURN NULL does not. RETURNING id is NULL
-- for the skipped row; the client already drops empty print job ids.

begin;

create or replace function public.skip_duplicate_print_job()
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
  v_key text;
begin
  v_key := nullif(trim(coalesce(new.payload->>'logical_print_key', '')), '');
  if v_key is null then
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
    v_station := coalesce(
      new.station_id::text,
      nullif(trim(coalesce(new.payload->>'station_id', '')), ''),
      ''
    );
    v_job := coalesce(
      nullif(trim(coalesce(new.job_type, '')), ''),
      nullif(trim(coalesce(new.payload->>'job_type', '')), ''),
      'new_order'
    );
    v_key := concat_ws(
      '|',
      new.restaurant_id::text,
      v_order_key,
      v_revision,
      v_station,
      v_job
    );
    new.payload := coalesce(new.payload, '{}'::jsonb) || jsonb_build_object(
      'local_order_id', coalesce(v_local, new.payload->>'local_order_id'),
      'logical_print_key', v_key
    );
  end if;

  if v_key = '' then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_key, 0));
  if exists (
    select 1
    from public.print_jobs existing
    where existing.restaurant_id = new.restaurant_id
      and existing.order_id is not distinct from new.order_id
      and (
        existing.payload->>'logical_print_key' = v_key
        or (
          coalesce(existing.payload->>'logical_print_key', '') = ''
          and concat_ws(
            '|',
            existing.restaurant_id::text,
            coalesce(
              nullif(trim(coalesce(existing.payload->>'local_order_id', '')), ''),
              (
                select nullif(trim(coalesce(o.local_order_id, '')), '')
                from public.orders o
                where o.id = existing.order_id
              ),
              existing.order_id::text,
              ''
            ),
            coalesce(
              nullif(trim(coalesce(existing.payload->>'revision_key', '')), ''),
              nullif(trim(coalesce(existing.payload->>'revision', '')), ''),
              '1'
            ),
            coalesce(
              existing.station_id::text,
              nullif(trim(coalesce(existing.payload->>'station_id', '')), ''),
              ''
            ),
            coalesce(
              nullif(trim(coalesce(existing.job_type, '')), ''),
              nullif(trim(coalesce(existing.payload->>'job_type', '')), ''),
              'new_order'
            )
          ) = v_key
        )
      )
  ) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists print_jobs_zz_skip_duplicate on public.print_jobs;
create trigger print_jobs_zz_skip_duplicate
  before insert on public.print_jobs
  for each row
  execute function public.skip_duplicate_print_job();

commit;
