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
PLIST="$PROJECT_DIR/ios/Runner/GoogleService-Info.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "Firebase plist bulunamadı: $PLIST"
  exit 1
fi

FIREBASE_IOS_API_KEY=$(/usr/libexec/PlistBuddy -c "Print :API_KEY" "$PLIST")
FIREBASE_IOS_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST")
FIREBASE_PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$PLIST")
FIREBASE_MESSAGING_SENDER_ID=$(/usr/libexec/PlistBuddy -c "Print :GCM_SENDER_ID" "$PLIST")
FIREBASE_STORAGE_BUCKET=$(/usr/libexec/PlistBuddy -c "Print :STORAGE_BUCKET" "$PLIST")
FIREBASE_IOS_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$PLIST")

if [[ -z "${IBUL_SUPABASE_URL:-}" || -z "${IBUL_SUPABASE_ANON_KEY:-}" ]]; then
  echo "IBUL_SUPABASE_URL ve IBUL_SUPABASE_ANON_KEY gerekli (.env veya export)."
  exit 1
fi

echo "Customer iOS release — target lib/main_customer.dart"
echo "Firebase PROJECT_ID=$FIREBASE_PROJECT_ID"

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
