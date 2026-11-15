#!/bin/sh
# Throwaway PostgreSQL proof for print identity. Refuses a hosted Supabase URL.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
DB_URL="${IBUL_ISOLATED_PG_URL:-}"
if [ -z "$DB_URL" ]; then
  echo "IBUL_ISOLATED_PG_URL is required and must point at a throwaway database."
  exit 2
fi
case "$DB_URL" in
  *supabase.co*|*pooler.supabase.com*)
    echo "Refusing a live Supabase URL."
    exit 2
    ;;
esac
PSQL="${PSQL:-psql}"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT/ibul_app/supabase/tests/isolated_print_uniqueness.sql"

# The real migration rolls back cleanly and does not raise on a repeated key.
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
create schema if not exists auth;
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
$$;
create table if not exists public.orders (
  id uuid primary key,
  local_order_id text
);
create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid,
  station_id uuid,
  job_type text,
  payload jsonb,
  status text not null
);
insert into public.orders (id, local_order_id)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'local-order-skip')
on conflict (id) do nothing;
SQL

{
  echo "begin;"
  grep -v -E '^(begin;|commit;)$' \
    "$ROOT/ibul_app/supabase/migrations/2026110102_print_job_skip_duplicate.sql"
  echo "rollback;"
  echo "select count(*) from pg_proc where proname = 'skip_duplicate_print_job' and pronamespace = 'public'::regnamespace;"
} | "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At > /tmp/ibul_skip_rollback_count.txt
ROLLBACK_COUNT="$(tail -n 1 /tmp/ibul_skip_rollback_count.txt | tr -d '[:space:]')"
if [ "$ROLLBACK_COUNT" != "0" ]; then
  echo "FAIL migration rollback left skip_duplicate_print_job ($ROLLBACK_COUNT)"
  exit 1
fi

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT/ibul_app/supabase/migrations/2026110102_print_job_skip_duplicate.sql"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT/ibul_app/supabase/migrations/2026110103_print_job_skip_race.sql"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
insert into public.print_jobs (
  restaurant_id, order_id, station_id, job_type, payload, status
) values (
  '11111111-1111-1111-1111-111111111111',
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  null,
  'new_order',
  '{"revision_key":"1"}'::jsonb,
  'pending'
);
insert into public.print_jobs (
  restaurant_id, order_id, station_id, job_type, payload, status
) values (
  '11111111-1111-1111-1111-111111111111',
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  null,
  'new_order',
  '{"revision_key":"1"}'::jsonb,
  'pending'
);
do $$
declare
  v_count int;
  v_key text;
begin
  select count(*), max(payload->>'logical_print_key')
    into v_count, v_key
  from public.print_jobs
  where order_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
    and coalesce(payload->>'revision_key', '') = '1';
  if v_count <> 1 then
    raise exception 'public skip trigger inserted % rows', v_count;
  end if;
  if v_key is distinct from '11111111-1111-1111-1111-111111111111|local-order-skip|1||new_order' then
    raise exception 'public logical key mismatch: %', v_key;
  end if;
end $$;
SQL

"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 -At <<'SQL' > /tmp/ibul_claim_a.txt &
update ibul_print_iso.print_jobs
set status = 'claimed'
where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  and status = 'pending'
returning id;
SQL
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 -At <<'SQL' > /tmp/ibul_claim_b.txt &
update ibul_print_iso.print_jobs
set status = 'claimed'
where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  and status = 'pending'
returning id;
SQL
wait
WINS="$(grep -h -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' /tmp/ibul_claim_a.txt /tmp/ibul_claim_b.txt | wc -l | tr -d '[:space:]')"
if [ "$WINS" != "1" ]; then
  echo "FAIL parallel claim wins=$WINS"
  echo "A=$(cat /tmp/ibul_claim_a.txt)"
  echo "B=$(cat /tmp/ibul_claim_b.txt)"
  exit 1
fi
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -c \
  "delete from public.print_jobs where order_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
   delete from public.orders where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';"
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 <<'SQL' > /tmp/ibul_race_a.txt &
insert into ibul_print_iso.print_jobs (
  restaurant_id, order_id, job_type, status, payload
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'new_order',
  'pending',
  '{"logical_print_key":"race-key"}'::jsonb
);
SQL
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 <<'SQL' > /tmp/ibul_race_b.txt &
insert into ibul_print_iso.print_jobs (
  restaurant_id, order_id, job_type, status, payload
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'new_order',
  'pending',
  '{"logical_print_key":"race-key"}'::jsonb
);
SQL
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 <<'SQL' > /tmp/ibul_lock_a.txt &
begin;
select id from ibul_print_iso.orders
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
for update;
select pg_sleep(0.6);
insert into ibul_print_iso.print_jobs (
  restaurant_id, order_id, job_type, status, payload
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'add_item',
  'pending',
  '{"logical_print_key":"lock-key","revision_key":"9"}'::jsonb
);
commit;
SQL
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 <<'SQL' > /tmp/ibul_lock_b.txt &
insert into ibul_print_iso.print_jobs (
  restaurant_id, order_id, job_type, status, payload
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'add_item',
  'pending',
  '{"logical_print_key":"lock-key","revision_key":"9"}'::jsonb
);
SQL
wait
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At <<'SQL'
select count(*) from ibul_print_iso.print_jobs
where payload->>'logical_print_key' = 'race-key';
select count(*) from ibul_print_iso.print_jobs
where payload->>'logical_print_key' = 'lock-key';
select count(*) from ibul_print_iso.orders
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
SQL
RACE_COUNT="$("$PSQL" "$DB_URL" -At -c "select count(*) from ibul_print_iso.print_jobs where payload->>'logical_print_key' = 'race-key'")"
LOCK_COUNT="$("$PSQL" "$DB_URL" -At -c "select count(*) from ibul_print_iso.print_jobs where payload->>'logical_print_key' = 'lock-key'")"
if [ "$RACE_COUNT" != "1" ] || [ "$LOCK_COUNT" != "1" ]; then
  echo "FAIL concurrent insert race=$RACE_COUNT lock=$LOCK_COUNT"
  echo "A=$(cat /tmp/ibul_race_a.txt)"
  echo "B=$(cat /tmp/ibul_race_b.txt)"
  echo "LA=$(cat /tmp/ibul_lock_a.txt)"
  echo "LB=$(cat /tmp/ibul_lock_b.txt)"
  exit 1
fi
echo "PASS unique index aborts order change; skip trigger does not; one claim wins; concurrent insert stays one row"
