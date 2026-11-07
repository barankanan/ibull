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

reset_db ibul_guard_reverse
apply_waiter_before_send ibul_guard_reverse
$PSQL -d ibul_guard_reverse -f "$TEST/integration_restaurant_guards_assertions.sql"

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

echo "INTEGRATION_SQL_OK"
