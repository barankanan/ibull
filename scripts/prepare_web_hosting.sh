#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PROJECT_DIR/.env"
  set +a
fi

normalize_firebase_aliases() {
  if [[ -z "${IBUL_FIREBASE_WEB_API_KEY:-}" && -n "${IBUL_FIREBASE_API_KEY:-}" ]]; then
    export IBUL_FIREBASE_WEB_API_KEY="$IBUL_FIREBASE_API_KEY"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_APP_ID:-}" && -n "${IBUL_FIREBASE_APP_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_APP_ID="$IBUL_FIREBASE_APP_ID"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_MEASUREMENT_ID:-}" && -n "${IBUL_FIREBASE_MEASUREMENT_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_MEASUREMENT_ID="$IBUL_FIREBASE_MEASUREMENT_ID"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_MEASUREMENT_ID:-}" && -n "${IBUL_FIREBASE_EB_MEASUREMENT_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_MEASUREMENT_ID="$IBUL_FIREBASE_EB_MEASUREMENT_ID"
  fi
}

normalize_firebase_aliases

"$SCRIPT_DIR/build_web_hosting.sh"

WEB_DIR="$PROJECT_DIR/ibul_app/build/web"
SW_FILE="$WEB_DIR/flutter_service_worker.js"

# Empty SW from --pwa-strategy=none poisons hosting caches; remove before deploy.
if [[ -f "$SW_FILE" ]] && [[ ! -s "$SW_FILE" ]]; then
  rm -f "$SW_FILE"
  echo "✓ Removed empty flutter_service_worker.js (pwa-strategy=none)"
fi

if ! grep -q "supabase.co" "$WEB_DIR/main.dart.js" 2>/dev/null; then
  echo "UYARI: main.dart.js içinde supabase.co bulunamadı."
  echo "Build muhtemelen IBUL_SUPABASE_URL olmadan yapıldı — .env kontrol edin."
  exit 1
fi

echo ""
echo "Deploy: firebase deploy --only hosting"
echo "  cd \"$PROJECT_DIR\" && firebase deploy --only hosting"
