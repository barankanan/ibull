#!/usr/bin/env bash
# Isolated merge_table_bills checks. Does not connect to production.
set -euo pipefail
cd "$(dirname "$0")/../../.."
PSQL="${PSQL:-sudo -u postgres psql -v ON_ERROR_STOP=1}"
DB="${MERGE_TEST_DB:-ibull_merge_bills}"

$PSQL -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname = '$DB' and pid <> pg_backend_pid();" >/dev/null || true
$PSQL -d postgres -c "drop database if exists \"$DB\";"
$PSQL -d postgres -c "create database \"$DB\";"

$PSQL -d "$DB" -f ibul_app/supabase/tests/merge_table_bills_prelude.sql
$PSQL -d "$DB" -f ibul_app/supabase/migrations/20261107_merge_table_bills.sql
$PSQL -d "$DB" -f ibul_app/supabase/migrations/20261107_table_visit_identity.sql
$PSQL -d "$DB" -f ibul_app/supabase/tests/merge_table_bills_assertions.sql

OWNER="11111111-1111-4111-8111-111111111111"
SQL="select public.merge_table_bills(
  '$OWNER'::uuid, 12, 13,
  '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa12\"]'::jsonb,
  '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa13\"]'::jsonb
);"

$PSQL -d "$DB" -c "select set_config('request.jwt.claim.role', 'authenticated', false); select set_config('request.jwt.claim.sub', '$OWNER', false); $SQL" > /tmp/merge_race_a.out 2>&1 &
pid_a=$!
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.role', 'authenticated', false); select set_config('request.jwt.claim.sub', '$OWNER', false); $SQL" > /tmp/merge_race_b.out 2>&1 &
pid_b=$!
set +e
wait "$pid_a"
code_a=$?
wait "$pid_b"
code_b=$?
set -e

if [[ "$code_a" -eq 0 && "$code_b" -eq 0 ]]; then
  echo "both merge sessions succeeded" >&2
  cat /tmp/merge_race_a.out /tmp/merge_race_b.out >&2
  exit 1
fi
if [[ "$code_a" -ne 0 && "$code_b" -ne 0 ]]; then
  echo "both merge sessions failed" >&2
  cat /tmp/merge_race_a.out /tmp/merge_race_b.out >&2
  exit 1
fi

$PSQL -d "$DB" -c "
select
  (select count(*) from public.table_orders where table_number = 12 and status = 'sent') as source_open,
  (select count(*) from public.table_orders where table_number = 13 and status = 'sent') as target_open,
  (select count(*) from public.table_orders) as order_rows,
  (select count(*) from public.table_payments) as payment_rows,
  (select count(*) from public.print_jobs) as print_rows;
" | tee /tmp/merge_race_state.out

grep -q 'source_open | 0' /tmp/merge_race_state.out || {
  # psql aligned output uses spaces; match the values on the data row.
  grep -E '^[[:space:]]*0[[:space:]]+\|[[:space:]]*2[[:space:]]+\|[[:space:]]*13[[:space:]]+\|[[:space:]]*5[[:space:]]+\|[[:space:]]*1[[:space:]]*$' /tmp/merge_race_state.out
}

OWNER="11111111-1111-4111-8111-111111111111"
$PSQL -d "$DB" -c "
insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa16', '$OWNER', 16, '[{\"name\":\"Yaris\",\"quantity\":1,\"price\":18}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '16161616-1616-4161-8161-161616161616'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa17', '$OWNER', 17, '[{\"name\":\"Yaris hedef\",\"quantity\":1,\"price\":22}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '17171717-1717-4171-8171-171717171717');
"
PAY_SQL="insert into public.table_payments (id, seller_id, table_number, session_key, amount, idempotency_key)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb16', '$OWNER', 16, 'race-pay', 3, 'pay-race-16');"
MERGE16="select public.merge_table_bills('$OWNER'::uuid, 16, 17, '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa16\"]'::jsonb, '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa17\"]'::jsonb);"
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.role','authenticated', false); select set_config('request.jwt.claim.sub','$OWNER', false); $MERGE16" > /tmp/merge_pay_race_a.out 2>&1 &
pid_m=$!
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.role','authenticated', false); select set_config('request.jwt.claim.sub','$OWNER', false); $PAY_SQL" > /tmp/merge_pay_race_b.out 2>&1 &
pid_p=$!
set +e
wait "$pid_m"
code_m=$?
wait "$pid_p"
code_p=$?
set -e
if [[ "$code_m" -ne 0 ]]; then
  echo "merge lost the payment race" >&2
  cat /tmp/merge_pay_race_a.out /tmp/merge_pay_race_b.out >&2
  exit 1
fi
$PSQL -d "$DB" -tAc "
select
  (select count(*) from public.table_orders where table_number = 16 and public.table_order_is_open(status))
  || ' ' ||
  (select count(*) from public.table_payments where table_number = 16)
" | tee /tmp/merge_pay_race_state.out
grep -qx '0 0' /tmp/merge_pay_race_state.out

echo MERGE_TABLE_BILLS_OK
