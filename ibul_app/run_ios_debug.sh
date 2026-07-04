#!/bin/bash
set -e

DEVICE_ID="00008030-001610AC14BB802E"
SUPABASE_URL="https://ihmixxzqnpamcwmrfibx.supabase.co"
PLIST="ios/Runner/GoogleService-Info.plist"

SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' run_ios_release.sh | sed 's/^SUPABASE_ANON_KEY="//; s/"$//')

FIREBASE_IOS_API_KEY=$(/usr/libexec/PlistBuddy -c "Print :API_KEY" "$PLIST")
FIREBASE_IOS_APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST")
FIREBASE_PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$PLIST")
FIREBASE_MESSAGING_SENDER_ID=$(/usr/libexec/PlistBuddy -c "Print :GCM_SENDER_ID" "$PLIST")
FIREBASE_STORAGE_BUCKET=$(/usr/libexec/PlistBuddy -c "Print :STORAGE_BUCKET" "$PLIST")
FIREBASE_IOS_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$PLIST")

echo "iPhone DEBUG başlatılıyor..."
echo "Hot Reload: r"
echo "Hot Restart: R"
echo "Çıkış: q"
echo "BUNDLE_ID=$FIREBASNDLE_ID"

flutter run -d "$DEVICE_ID" --debug \
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
