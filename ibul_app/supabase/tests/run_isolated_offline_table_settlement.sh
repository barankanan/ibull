#!/bin/sh
# Throwaway PostgreSQL proof for offline table settlement. Refuses a hosted
# Supabase URL. Drops and recreates the `public` schema of the given database.
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
T="$ROOT/ibul_app/supabase/tests"
M="$ROOT/ibul_app/supabase/migrations/20261122160000_offline_table_settlement.sql"
FN="public.apply_offline_table_settlement(uuid,integer,text,text[],numeric,text,timestamptz,uuid,uuid,uuid,text,text)"

reset() {
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q \
    -c "drop schema if exists public cascade; create schema public;" 2>&1 | grep -v NOTICE || true
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$T/isolated_offline_table_settlement_schema.sql"
}

# 1. Behaviour.
reset
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$M"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$T/isolated_offline_table_settlement_assert.sql" 2>&1 \
  | grep -E "PASS|FAIL|ERROR|HATA" || true

# 2. The migration applies twice without error (re-run safety).
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$M"
echo "PASS 14 migration ikinci kez hatasız uygulanır"

# 3. Race: the same settlement from eight connections at once.
reset
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$M"
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
insert into public.store_tables (id, seller_id, table_number)
values ('aaaaaaaa-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 7);
insert into public.restaurant_offline_settlement_settings values
  ('11111111-1111-1111-1111-111111111111', true);
with o as (
  insert into public.orders (restaurant_id, table_id, order_type, status, local_order_id)
  values ('11111111-1111-1111-1111-111111111111',
          'aaaaaaaa-0000-0000-0000-000000000007', 'table', 'confirmed', 'R-1')
  returning id
)
insert into public.order_items (order_id, product_name, quantity, unit_price, total_price, line_total)
select id, 'Ürün', 2, 150, 300, 300 from o;
SQL
CALL="select public.apply_offline_table_settlement(
  '11111111-1111-1111-1111-111111111111', 7, 'RACE-1', array['R-1'], 300, 'cash',
  '2026-11-22T10:00:00Z', '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111') ->> 'replayed';"
OUT="$(mktemp)"
i=0
while [ "$i" -lt 8 ]; do
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At -c "$CALL" >> "$OUT" 2>&1 &
  i=$((i + 1))
done
wait
FIRST="$(grep -c '^false$' "$OUT" || true)"
REPEAT="$(grep -c '^true$' "$OUT" || true)"
ROWS="$("$PSQL" "$DB_URL" -At -c "select (select count(*) from public.table_order_history) || '/' || (select count(*) from public.restaurant_offline_settlements) || '/' || (select count(*) from public.restaurant_offline_settlement_orders)")"
rm -f "$OUT"
if [ "$FIRST" = "1" ] && [ "$REPEAT" = "7" ] && [ "$ROWS" = "1/1/1" ]; then
  echo "PASS 15 sekiz eşzamanlı istekte tek uygulama, yedi tekrar, tek geçmiş kaydı"
else
  echo "FAIL 15 ilk=$FIRST tekrar=$REPEAT satır=$ROWS"
  exit 1
fi

# 4. Race: two different settlement ids fighting over the same order.
"$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q <<'SQL'
with o as (
  insert into public.orders (restaurant_id, table_id, order_type, status, local_order_id)
  values ('11111111-1111-1111-1111-111111111111',
          'aaaaaaaa-0000-0000-0000-000000000007', 'table', 'confirmed', 'R-2')
  returning id
)
insert into public.order_items (order_id, product_name, quantity, unit_price, total_price, line_total)
select id, 'Ürün', 1, 80, 80, 80 from o;
SQL
OUT="$(mktemp)"
for sid in TWO-A TWO-B TWO-C TWO-D; do
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At -c "select public.apply_offline_table_settlement(
    '11111111-1111-1111-1111-111111111111', 7, '$sid', array['R-2'], 80, 'card',
    '2026-11-22T10:05:00Z', '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111') ->> 'status';" >> "$OUT" 2>&1 &
done
wait
APPLIED="$(grep -c '^applied$' "$OUT" || true)"
CONFLICT="$(grep -c '^conflict$' "$OUT" || true)"
HIST="$("$PSQL" "$DB_URL" -At -c "select count(*) from public.table_order_history h join public.orders o on o.id = h.original_order_id where o.local_order_id = 'R-2'")"
rm -f "$OUT"
if [ "$APPLIED" = "1" ] && [ "$CONFLICT" = "3" ] && [ "$HIST" = "1" ]; then
  echo "PASS 16 aynı sipariş için dört farklı işlem kimliği yarışında tek kapanış, üç çatışma"
else
  echo "FAIL 16 uygulanan=$APPLIED çatışma=$CONFLICT geçmiş=$HIST"
  exit 1
fi

# 5. Rollback block from the migration leaves nothing behind.
sed -n '/^--   begin;$/,/^--   commit;$/p' "$M" | sed 's/^--   //' \
  | "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -q
LEFT="$("$PSQL" "$DB_URL" -At -c "select (select count(*) from pg_proc where proname = 'apply_offline_table_settlement') + (select count(*) from pg_class where relname like 'restaurant_offline_settlement%')")"
KEPT="$("$PSQL" "$DB_URL" -At -c "select count(*) from public.table_order_history")"
if [ "$LEFT" = "0" ] && [ "$KEPT" = "2" ]; then
  echo "PASS 17 geri alma bloğu yeni nesneleri kaldırır, mevcut tablolar ve geçmiş yerinde kalır"
else
  echo "FAIL 17 kalan=$LEFT geçmiş=$KEPT"
  exit 1
fi
: "$FN"
