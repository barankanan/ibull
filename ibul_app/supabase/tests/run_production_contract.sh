#!/usr/bin/env bash
# Isolated production-contract tests. Does not connect to production.
set -euo pipefail
cd "$(dirname "$0")/../../.."
PSQL="${PSQL:-sudo -u postgres psql -v ON_ERROR_STOP=1}"
DB="${CONTRACT_TEST_DB:-ibull_prod_contract}"
$PSQL -d postgres -c "drop database if exists \"$DB\";"
$PSQL -d postgres -c "create database \"$DB\";"
$PSQL -d "$DB" -f ibul_app/supabase/tests/production_contract_prelude.sql
$PSQL -d "$DB" -f ibul_app/supabase/migrations/20261107223000_production_contract_compat.sql
$PSQL -d "$DB" -f ibul_app/supabase/tests/production_contract_assertions.sql

OWNER=11111111-1111-4111-8111-111111111111
SEND="select public.create_table_order_with_print_jobs('$OWNER'::uuid, 70, '[]'::jsonb, null, null, 'race', 'new_order', 'table', 'race-local');"
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.sub','$OWNER', false); $SEND" >/tmp/contract_send_a.out 2>&1 &
pid_a=$!
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.sub','$OWNER', false); $SEND" >/tmp/contract_send_b.out 2>&1 &
pid_b=$!
set +e
wait "$pid_a"; code_a=$?
wait "$pid_b"; code_b=$?
set -e
if [[ "$code_a" -ne 0 || "$code_b" -ne 0 ]]; then
  echo "concurrent send failed" >&2
  cat /tmp/contract_send_a.out /tmp/contract_send_b.out >&2
  exit 1
fi
count="$($PSQL -d "$DB" -tAc "select count(*) from public.orders where local_order_id='race-local'")"
jobs="$($PSQL -d "$DB" -tAc "select count(*) from public.print_jobs pj join public.orders o on o.id=pj.order_id where o.local_order_id='race-local'")"
if [[ "$count" != "1" || "$jobs" != "1" ]]; then
  echo "concurrent send duplicated count=$count jobs=$jobs" >&2
  exit 1
fi

$PSQL -d "$DB" -c "
insert into public.table_orders (id, seller_id, table_number, items, status, created_at, visit_id)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa51', '$OWNER', 51, '[{\"price\":40}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '51515151-5151-4151-8151-515151515151'),
       ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa52', '$OWNER', 52, '[{\"price\":10}]'::jsonb, 'sent', '2026-11-07 12:00:00+00', '52525252-5252-4252-8252-525252525252');
"
MERGE="select public.merge_table_bills('$OWNER', 51, 52, '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa51\"]'::jsonb, '[\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa52\"]'::jsonb);"
PAY="select public.record_table_payment('$OWNER'::uuid, 51, 'race-s', 5, 'cash', false, 'pay-race-51', null, null, null, null);"
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555', false); $PAY" >/tmp/contract_pay.out 2>&1 &
pid_p=$!
$PSQL -d "$DB" -c "select set_config('request.jwt.claim.sub','$OWNER', false); $MERGE" >/tmp/contract_merge.out 2>&1 &
pid_m=$!
set +e
wait "$pid_p"; code_p=$?
wait "$pid_m"; code_m=$?
set -e
if [[ "$code_m" -ne 0 ]]; then
  echo "merge failed during payment race" >&2
  cat /tmp/contract_merge.out /tmp/contract_pay.out >&2
  exit 1
fi
left="$($PSQL -d "$DB" -tAc "select (select count(*) from public.table_orders where table_number=51 and public.table_order_is_open(status))::text || ' ' || (select count(*) from public.table_payments where table_number=51 and visit_id='51515151-5151-4151-8151-515151515151')::text")"
if [[ "$left" != "0 0" ]]; then
  echo "payment/merge left source rows: $left" >&2
  cat /tmp/contract_pay.out >&2
  exit 1
fi
echo PRODUCTION_CONTRACT_OK
