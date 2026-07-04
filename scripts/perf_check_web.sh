#!/usr/bin/env bash
# Report Flutter web bundle sizes and enforce perf budgets.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$PROJECT_DIR/ibul_app/build/web"

MAIN_BUDGET_KB=4500
HOME_CORE_BUDGET_KB=1200
SINGLE_PART_WARN_KB=3000

if [[ ! -f "$WEB_DIR/main.dart.js" ]]; then
  echo "main.dart.js not found — run scripts/build_web_prod.sh first"
  exit 1
fi

main_bytes=$(wc -c < "$WEB_DIR/main.dart.js" | tr -d ' ')
main_kb=$((main_bytes / 1024))
part_total=0
part_count=0
largest_part_kb=0
largest_part_name=""
home_core_kb=0

echo "=== IBUL Web bundle report ==="
echo "main.dart.js: ${main_kb} KB (${main_bytes} bytes)"

while IFS= read -r part; do
  bytes=$(wc -c < "$part" | tr -d ' ')
  kb=$((bytes / 1024))
  part_total=$((part_total + bytes))
  part_count=$((part_count + 1))
  base=$(basename "$part")
  echo "  $base: ${kb} KB"
  if [[ $kb -gt $largest_part_kb ]]; then
    largest_part_kb=$kb
    largest_part_name=$base
  fi
  if [[ "$base" == *home_screen_core* ]] || [[ "$base" == *home_screen_deferred_entry* ]] || [[ "$base" == "main.dart.js_18.part.js" ]]; then
    home_core_kb=$kb
  fi
done < <(find "$WEB_DIR" -name 'main.dart.js_*.part.js' | sort)

total_kb=$(((main_bytes + part_total) / 1024))
total_mb=$(awk "BEGIN {printf \"%.2f\", $total_kb / 1024}")
part_total_kb=$((part_total / 1024))

echo "deferred parts: $part_count files, ${part_total_kb} KB"
echo "largest part: ${largest_part_name} (${largest_part_kb} KB)"
echo "total JS: ${total_kb} KB (${total_mb} MB)"

# Heuristic: smallest non-trivial part after build often maps to core — also scan by name
core_part=$(find "$WEB_DIR" \( -name '*home_screen_deferred_entry*.part.js' -o -name '*home_screen_core*.part.js' \) -print -quit || true)
if [[ -n "$core_part" ]]; then
  home_core_kb=$(($(wc -c < "$core_part" | tr -d ' ') / 1024))
  echo "home_screen_core part: ${home_core_kb} KB ($(basename "$core_part"))"
elif [[ $home_core_kb -gt 0 ]]; then
  echo "home core heuristic part: ${home_core_kb} KB"
else
  echo "home core part: (identify via deferred library name in build output)"
fi

exit_code=0
if [[ $main_kb -gt $MAIN_BUDGET_KB ]]; then
  echo "FAIL: main.dart.js ${main_kb} KB > budget ${MAIN_BUDGET_KB} KB"
  exit_code=2
fi
if [[ $home_core_kb -gt 0 && $home_core_kb -gt $HOME_CORE_BUDGET_KB ]]; then
  echo "WARN: home core ${home_core_kb} KB > target ${HOME_CORE_BUDGET_KB} KB"
  exit_code=2
fi
if [[ $largest_part_kb -gt $SINGLE_PART_WARN_KB ]]; then
  echo "WARN: largest part ${largest_part_kb} KB > ${SINGLE_PART_WARN_KB} KB"
fi

if [[ $exit_code -eq 0 ]]; then
  echo "OK: within budgets"
fi
exit $exit_code
