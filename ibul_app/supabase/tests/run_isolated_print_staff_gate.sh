#!/bin/sh
# Throwaway PostgreSQL proof. Refuses a hosted Supabase URL.
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
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -f "$ROOT/ibul_app/supabase/tests/isolated_print_staff_schema.sql"

# Apply the migration inside a transaction and roll it back.
{
  echo "begin;"
  grep -v -E '^(begin;|commit;)$' \
    "$ROOT/ibul_app/supabase/migrations/2026110101_print_identity_and_staff_password_gate.sql"
  echo "rollback;"
  echo "select count(*) from pg_proc where proname = 'staff_must_change_password';"
} | "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At > /tmp/ibul_gate_rollback_count.txt
ROLLBACK_COUNT="$(tail -n 1 /tmp/ibul_gate_rollback_count.txt | tr -d '[:space:]')"
if [ "$ROLLBACK_COUNT" != "0" ]; then
  echo "FAIL migration rollback left staff_must_change_password ($ROLLBACK_COUNT)"
  exit 1
fi

"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT/ibul_app/supabase/migrations/2026110101_print_identity_and_staff_password_gate.sql"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
begin;
drop trigger if exists print_jobs_stamp_logical_key on public.print_jobs;
drop function if exists public.stamp_print_job_logical_key();
rollback;
do \$\$
begin
  if not exists (
    select 1 from pg_proc where proname = 'stamp_print_job_logical_key'
  ) then
    raise exception 'rollback removed the print identity function';
  end if;
end \$\$;
SQL
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT/ibul_app/supabase/tests/isolated_print_staff_assertions.sql"

"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 -At <<'SQL' > /tmp/ibul_claim_a.txt &
update public.print_jobs
set status = 'claimed'
where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  and status = 'pending'
returning id;
SQL
"$PSQL" "$DB_URL" -q -v ON_ERROR_STOP=1 -At <<'SQL' > /tmp/ibul_claim_b.txt &
update public.print_jobs
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
echo "PASS isolated staff gate, print identity, rollback, and single claim"
