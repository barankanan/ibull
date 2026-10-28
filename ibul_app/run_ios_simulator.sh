#!/usr/bin/env bash
# Customer iOS simulator. Firebase values come from the same plist reader
# as the physical iPhone runner. Supabase values come from the environment
# or the repo .env. This script prints only SET / NOT_SET.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/.env"
DEVICE_ID="${1:-}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Kullanım: bash ./run_ios_simulator.sh <simulator-device-id>"
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/ios_runtime_env.sh"
ios_runtime_prepare
ios_runtime_status

if ! ios_runtime_ready; then
  echo "iOS runtime config eksik. flutter run başlatılmadı."
  exit 1
fi

SUPABASE_URL="${IBUL_SUPABASE_URL:-$SUPABASE_URL}"
SUPABASE_ANON_KEY="${IBUL_SUPABASE_ANON_KEY:-$SUPABASE_ANON_KEY}"

cd "$SCRIPT_DIR"

exec flutter run -d "$DEVICE_ID" --debug \
  --target lib/main_customer.dart \
  --dart-define=ENABLE_TEST_CHECKOUT=true \
  --dart-define=IBUL_SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=IBUL_SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=IBUL_FIREBASE_IOS_API_KEY="$FIREBASE_IOS_API_KEY" \
  --dart-define=IBUL_FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID" \
  --dart-define=IBUL_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=IBUL_FIREBASE_IOS_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=IBUL_FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=IBUL_FIREBASE_IOS_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=IBUL_FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=IBUL_FIREBASE_IOS_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=IBUL_FIREBASE_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID" \
  --dart-define=IBUL_FIREBASE_IOS_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID"
