#!/bin/bash
set -e

DEVICE_ID="00008030-001610AC14BB802E"

SUPABASE_URL="https://ihmixxzqnpamcwmrfibx.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlobWl4eHpxbnBhbWN3bXJmaWJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDE0NTEsImV4cCI6MjA4NzI3NzQ1MX0.EZkjZAq2mwg-gfBhwotAGp4stb1D-rmWHuzVsz2yzX0"

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ios_runtime_env.sh"
ios_runtime_prepare
ios_runtime_status
if ! ios_runtime_ready; then
  echo "iOS runtime config eksik. flutter run başlatılmadı."
  exit 1
fi

flutter run -d "$DEVICE_ID" --release \
  --target lib/main.dart \
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
