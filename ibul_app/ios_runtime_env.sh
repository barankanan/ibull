#!/usr/bin/env bash
# Single iOS Firebase config reader. Values come from
# ios/Runner/GoogleService-Info.plist. This file does not store secrets.

IOS_RUNTIME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_ios_runtime_flag() {
  local label="$1"
  local value="$2"
  if [[ -n "${value:-}" ]]; then
    echo "${label}: SET"
  else
    echo "${label}: NOT_SET"
  fi
}

ios_runtime_prepare() {
  local plist="$IOS_RUNTIME_ROOT/ios/Runner/GoogleService-Info.plist"
  if [[ ! -f "$plist" ]]; then
    echo "Firebase plist bulunamadı"
    return 1
  fi
  FIREBASE_IOS_API_KEY="$(/usr/libexec/PlistBuddy -c "Print :API_KEY" "$plist")"
  FIREBASE_IOS_APP_ID="$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$plist")"
  FIREBASE_PROJECT_ID="$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$plist")"
  FIREBASE_MESSAGING_SENDER_ID="$(/usr/libexec/PlistBuddy -c "Print :GCM_SENDER_ID" "$plist")"
  FIREBASE_STORAGE_BUCKET="$(/usr/libexec/PlistBuddy -c "Print :STORAGE_BUCKET" "$plist")"
  FIREBASE_IOS_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$plist")"
}

ios_runtime_status() {
  _ios_runtime_flag "SUPABASE_URL" "${IBUL_SUPABASE_URL:-${SUPABASE_URL:-}}"
  _ios_runtime_flag "SUPABASE_ANON" "${IBUL_SUPABASE_ANON_KEY:-${SUPABASE_ANON_KEY:-}}"
  _ios_runtime_flag "IOS_FIREBASE_API_KEY" "${FIREBASE_IOS_API_KEY:-}"
  _ios_runtime_flag "IOS_FIREBASE_APP_ID" "${FIREBASE_IOS_APP_ID:-}"
  _ios_runtime_flag "IOS_FIREBASE_PROJECT_ID" "${FIREBASE_PROJECT_ID:-}"
  _ios_runtime_flag "IOS_FIREBASE_SENDER_ID" "${FIREBASE_MESSAGING_SENDER_ID:-}"
  _ios_runtime_flag "IOS_FIREBASE_STORAGE" "${FIREBASE_STORAGE_BUCKET:-}"
  _ios_runtime_flag "IOS_FIREBASE_BUNDLE_ID" "${FIREBASE_IOS_BUNDLE_ID:-}"
}

ios_runtime_ready() {
  [[ -n "${IBUL_SUPABASE_URL:-${SUPABASE_URL:-}}" ]] \
    && [[ -n "${IBUL_SUPABASE_ANON_KEY:-${SUPABASE_ANON_KEY:-}}" ]] \
    && [[ -n "${FIREBASE_IOS_API_KEY:-}" ]] \
    && [[ -n "${FIREBASE_IOS_APP_ID:-}" ]] \
    && [[ -n "${FIREBASE_PROJECT_ID:-}" ]] \
    && [[ -n "${FIREBASE_MESSAGING_SENDER_ID:-}" ]] \
    && [[ -n "${FIREBASE_STORAGE_BUCKET:-}" ]] \
    && [[ -n "${FIREBASE_IOS_BUNDLE_ID:-}" ]]
}
