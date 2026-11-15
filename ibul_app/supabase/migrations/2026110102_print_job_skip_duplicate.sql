-- DO NOT APPLY to the live project from this workspace.
--
-- Phased print identity. Existing rows are not updated, deleted, or rewritten.
--
-- Phase 1, file 2026110101: stamp payload.logical_print_key on insert.
--   No rejection. The order RPC cannot fail because of this stamp.
-- Phase 2, read only, after phase 1 has been observed:
--   select payload->>'logical_print_key' as logical_key, count(*)
--   from public.print_jobs
--   where coalesce(payload->>'logical_print_key', '') <> ''
--   group by 1
--   having count(*) > 1;
--   Historical duplicates stay. Do not delete them; one of them may already
--   have reached a printer.
-- Phase 3, this file: BEFORE INSERT returns NULL for a repeated key.
--   It does not RAISE. A unique violation inside create/update order RPC
--   aborts the order transaction, so this phase has no unique index.
--   RETURNING id of a skipped insert is NULL. The order change still commits.
--   A null id in print_job_ids is a skipped ticket, not a printed ticket.
-- Phase 4 is intentionally absent. A unique index can still raise when two
--   transactions pass the existence check together, and that raise rolls the
--   order change back. Add it only after the order functions themselves use
--   ON CONFLICT and a staging run proves the order row remains.

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
    from public.print_jobs
    where payload->>'logical_print_key' = v_key
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
