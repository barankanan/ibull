-- Throwaway proof. Do not run against a hosted database.
-- Shows that a raising unique index rolls back an order change, and that a
-- BEFORE INSERT skip does not.

create schema if not exists ibul_print_iso;

drop table if exists ibul_print_iso.print_jobs cascade;
drop table if exists ibul_print_iso.orders cascade;
drop function if exists ibul_print_iso.revise_order(uuid, text, text, text);

create table ibul_print_iso.orders (
  id uuid primary key,
  note text not null
);

create table ibul_print_iso.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid,
  station_id text,
  job_type text,
  status text not null,
  last_error text,
  payload jsonb not null default '{}'::jsonb
);

create function ibul_print_iso.revise_order(
  p_order uuid,
  p_note text,
  p_key text,
  p_job text default 'new_order'
) returns uuid
language plpgsql
as $$
declare
  v_job uuid;
begin
  update ibul_print_iso.orders set note = p_note where id = p_order;
  insert into ibul_print_iso.print_jobs (
    restaurant_id, order_id, job_type, status, payload
  ) values (
    '11111111-1111-1111-1111-111111111111',
    p_order,
    p_job,
    'pending',
    jsonb_build_object('logical_print_key', p_key)
  )
  returning id into v_job;
  return v_job;
end;
$$;

create unique index print_jobs_logical_key_unique
  on ibul_print_iso.print_jobs ((payload->>'logical_print_key'));

do $$
declare
  v_order uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_job uuid;
  v_note text;
  v_count int;
begin
  insert into ibul_print_iso.orders values (v_order, 'ilk');
  v_job := ibul_print_iso.revise_order(v_order, 'ilk-baski', 'rest|order|1|station|new_order');
  if v_job is null then
    raise exception 'first print job was skipped';
  end if;

  begin
    perform ibul_print_iso.revise_order(
      v_order,
      'kaybolan-not',
      'rest|order|1|station|new_order'
    );
    raise exception 'unique index did not abort the order function';
  exception
    when unique_violation then
      null;
  end;

  select note into v_note from ibul_print_iso.orders where id = v_order;
  if v_note is distinct from 'ilk-baski' then
    raise exception 'unique violation kept the order change: %', v_note;
  end if;

  drop index ibul_print_iso.print_jobs_logical_key_unique;

  create or replace function ibul_print_iso.skip_duplicate_print_job()
  returns trigger
  language plpgsql
  as $fn$
  declare
    v_key text := nullif(trim(coalesce(new.payload->>'logical_print_key', '')), '');
  begin
    if v_key is null then
      return new;
    end if;
    -- One transaction-scoped lock per key. The second insert waits, then sees
    -- the first row. The lock is not taken on orders, so it does not cycle
    -- with the order RPC's FOR UPDATE.
    perform pg_advisory_xact_lock(hashtextextended(v_key, 0));
    if exists (
      select 1
      from ibul_print_iso.print_jobs existing
      where existing.restaurant_id = new.restaurant_id
        and existing.order_id is not distinct from new.order_id
        and (
          existing.payload->>'logical_print_key' = v_key
          or (
            coalesce(existing.payload->>'logical_print_key', '') = ''
            and concat_ws(
              '|',
              existing.restaurant_id::text,
              coalesce(existing.order_id::text, ''),
              coalesce(
                nullif(trim(coalesce(existing.payload->>'revision_key', '')), ''),
                nullif(trim(coalesce(existing.payload->>'revision', '')), ''),
                '1'
              ),
              coalesce(existing.station_id, ''),
              coalesce(nullif(trim(coalesce(existing.job_type, '')), ''), 'new_order')
            ) = v_key
          )
        )
    ) then
      return null;
    end if;
    return new;
  end;
  $fn$;

  drop trigger if exists print_jobs_zz_skip_duplicate on ibul_print_iso.print_jobs;
  create trigger print_jobs_zz_skip_duplicate
    before insert on ibul_print_iso.print_jobs
    for each row
    execute function ibul_print_iso.skip_duplicate_print_job();

  v_job := ibul_print_iso.revise_order(
    v_order,
    'guncel-not',
    'rest|order|1|station|new_order'
  );
  if v_job is not null then
    raise exception 'duplicate print job was inserted';
  end if;
  select note into v_note from ibul_print_iso.orders where id = v_order;
  if v_note is distinct from 'guncel-not' then
    raise exception 'skip trigger rolled back the order note: %', v_note;
  end if;
  select count(*) into v_count
  from ibul_print_iso.print_jobs
  where payload->>'logical_print_key' = 'rest|order|1|station|new_order';
  if v_count <> 1 then
    raise exception 'skip trigger changed the existing row count: %', v_count;
  end if;

  v_job := ibul_print_iso.revise_order(
    v_order,
    'reprint-not',
    'rest|order|1|station|reprint',
    'reprint'
  );
  if v_job is null then
    raise exception 'a different ticket type was blocked';
  end if;

  alter table ibul_print_iso.print_jobs disable trigger print_jobs_zz_skip_duplicate;
  insert into ibul_print_iso.print_jobs (
    restaurant_id, order_id, station_id, job_type, status, payload
  ) values (
    '11111111-1111-1111-1111-111111111111',
    v_order,
    'legacy-station',
    'add_item',
    'failed',
    '{"revision_key":"4","print_outcome":"unknown","requires_operator_review":true}'::jsonb
  );
  alter table ibul_print_iso.print_jobs enable trigger print_jobs_zz_skip_duplicate;
  v_job := ibul_print_iso.revise_order(
    v_order,
    'legacy-kept',
    '11111111-1111-1111-1111-111111111111|' || v_order::text || '|4|legacy-station|add_item',
    'add_item'
  );
  if v_job is not null then
    raise exception 'keyless legacy row did not block the new insert';
  end if;
  if exists (
    select 1 from ibul_print_iso.print_jobs
    where station_id = 'legacy-station'
      and coalesce(payload->>'logical_print_key', '') <> ''
  ) then
    raise exception 'keyless legacy row was rewritten';
  end if;
  select count(*) into v_count
  from ibul_print_iso.print_jobs
  where station_id = 'legacy-station';
  if v_count <> 1 then
    raise exception 'legacy compatibility changed the row count: %', v_count;
  end if;

  update ibul_print_iso.print_jobs
  set status = 'failed', last_error = 'locally_uncertain'
  where payload->>'logical_print_key' = 'rest|order|1|station|new_order';
  if exists (
    select 1 from ibul_print_iso.print_jobs
    where status = 'pending'
      and payload->>'logical_print_key' = 'rest|order|1|station|new_order'
  ) then
    raise exception 'uncertain job is still pending';
  end if;

  insert into ibul_print_iso.print_jobs (
    id, restaurant_id, order_id, job_type, status, payload
  ) values (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    v_order,
    'new_order',
    'pending',
    '{"logical_print_key":"claim-row"}'::jsonb
  );
end $$;
