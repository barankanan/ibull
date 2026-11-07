#!/bin/sh
# Isolated PostgreSQL 17 runs for the combined restaurant guard migrations.
# Does not connect to production and does not print or take payment.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
MIG="$ROOT/ibul_app/supabase/migrations"
TEST="$ROOT/ibul_app/supabase/tests"
PSQL="sudo -u postgres psql -v ON_ERROR_STOP=1"

apply_filename_order() {
  db="$1"
  $PSQL -d "$db" -f "$MIG/20261106_transfer_table_orders_v2.sql"
  $PSQL -d "$db" -f "$MIG/20261107_bill_item_edit_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_order_send_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_record_table_payment_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_staff_permission_enforcement.sql"
  $PSQL -d "$db" -f "$MIG/20261107_table_operation_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_waiter_request_single_order.sql"
  $PSQL -d "$db" -f "$MIG/20261107_order_identity_idempotency.sql"
  $PSQL -d "$db" -f "$MIG/20261107_merge_table_bills.sql"
  $PSQL -d "$db" -f "$MIG/20261107_table_visit_identity.sql"
}

apply_waiter_before_send() {
  db="$1"
  $PSQL -d "$db" -f "$MIG/20261106_transfer_table_orders_v2.sql"
  $PSQL -d "$db" -f "$MIG/20261107_bill_item_edit_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_waiter_request_single_order.sql"
  $PSQL -d "$db" -f "$MIG/20261107_record_table_payment_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_staff_permission_enforcement.sql"
  $PSQL -d "$db" -f "$MIG/20261107_table_operation_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_order_send_staff_guard.sql"
  $PSQL -d "$db" -f "$MIG/20261107_order_identity_idempotency.sql"
  $PSQL -d "$db" -f "$MIG/20261107_merge_table_bills.sql"
  $PSQL -d "$db" -f "$MIG/20261107_table_visit_identity.sql"
}

reset_db() {
  db="$1"
  $PSQL -d postgres -c "drop database if exists $db;"
  $PSQL -d postgres -c "create database $db;"
  $PSQL -d "$db" -f "$TEST/integration_restaurant_guards_schema.sql"
}

reset_db ibul_guard_filename
apply_filename_order ibul_guard_filename
$PSQL -d ibul_guard_filename -f "$TEST/integration_restaurant_guards_assertions.sql"
$PSQL -d ibul_guard_filename -f "$TEST/integration_order_identity_assertions.sql"

reset_db ibul_guard_reverse
apply_waiter_before_send ibul_guard_reverse
$PSQL -d ibul_guard_reverse -f "$TEST/integration_restaurant_guards_assertions.sql"
$PSQL -d ibul_guard_reverse -f "$TEST/integration_order_identity_assertions.sql"

# Existing single-migration suites, still on PostgreSQL 17.
run_suite() {
  db="$1"
  shift
  $PSQL -d postgres -c "drop database if exists $db;"
  $PSQL -d postgres -c "create database $db;"
  for file in "$@"; do
    $PSQL -d "$db" -f "$file"
  done
}

run_suite ibul_pr5 \
  "$TEST/table_operation_staff_guard_prelude.sql" \
  "$MIG/20261107_table_operation_staff_guard.sql" \
  "$TEST/table_operation_staff_guard_assertions.sql"

run_suite ibul_pr6 \
  "$TEST/order_send_staff_guard_prelude.sql" \
  "$MIG/20261107_order_send_staff_guard.sql" \
  "$TEST/order_send_staff_guard_assertions.sql"

run_suite ibul_pr8 \
  "$TEST/waiter_request_single_order_prelude.sql" \
  "$TEST/waiter_request_single_order_before.sql" \
  "$MIG/20261107_waiter_request_single_order.sql" \
  "$TEST/waiter_request_single_order_assertions.sql"

run_suite ibul_pr4 \
  "$TEST/staff_permission_enforcement_test.sql" \
  "$MIG/20261107_staff_permission_enforcement.sql" \
  "$TEST/staff_permission_enforcement_assertions.sql"

race_send() {
  $PSQL -d ibul_guard_filename >/tmp/ibul-race-send-"$1".log 2>&1 <<'SQL'
do $$
declare
  v jsonb;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  v := public.send_table_order_idempotent(
    '11111111-1111-4111-8111-111111111111',
    55,
    '[{"name":"race","price":5,"quantity":1}]'::jsonb,
    null,
    null,
    'race',
    'new_order',
    'table',
    'race-key'
  );
end
$$;
SQL
}

race_pay() {
  $PSQL -d ibul_guard_filename >/tmp/ibul-race-pay-"$1".log 2>&1 <<SQL
do \$\$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.record_table_payment(
    '11111111-1111-4111-8111-111111111111',
    11,
    'race-pay',
    40,
    'cash',
    'race-pay-$1',
    false,
    null,
    null,
    null,
    null
  );
end
\$\$;
SQL
}

race_send a &
race_send b &
wait
race_pay a &
race_pay b &
wait || true

send_count="$($PSQL -d ibul_guard_filename -tAc "select count(*) from public.orders where notes = 'race'")"
job_count="$($PSQL -d ibul_guard_filename -tAc "select count(*) from public.print_jobs pj join public.orders o on o.id = pj.order_id where o.notes = 'race'")"
pay_count="$($PSQL -d ibul_guard_filename -tAc "select count(*) from public.table_payments where table_number = 11")"
if [ "$send_count" != "1" ] || [ "$job_count" != "1" ] || [ "$pay_count" != "1" ]; then
  echo "concurrent race failed send=$send_count jobs=$job_count pay=$pay_count" >&2
  exit 1
fi

echo "INTEGRATION_SQL_OK"
