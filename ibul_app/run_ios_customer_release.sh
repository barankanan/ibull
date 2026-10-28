#!/usr/bin/env bash
# İbul müşteri iOS release — lib/main_customer.dart target
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
ENV_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  echo "✓ .env yüklendi: $ENV_FILE"
fi

DEVICE_ID="${IBUL_IOS_DEVICE_ID:-00008030-001610AC14BB802E}"

# shellcheck disable=SC1091
source "$PROJECT_DIR/ios_runtime_env.sh"
ios_runtime_prepare
ios_runtime_status

if ! ios_runtime_ready; then
  echo "iOS runtime config eksik. flutter run başlatılmadı."
  exit 1
fi

echo "Customer iOS release — target lib/main_customer.dart"

cd "$PROJECT_DIR"

flutter run -d "$DEVICE_ID" --release \
  --target lib/main_customer.dart \
  --dart-define=IBUL_SUPABASE_URL="$IBUL_SUPABASE_URL" \
  --dart-define=IBUL_SUPABASE_ANON_KEY="$IBUL_SUPABASE_ANON_KEY" \
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
