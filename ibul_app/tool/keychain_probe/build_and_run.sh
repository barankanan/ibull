#!/bin/bash
# Builds the isolated, signed macOS Keychain probe (no Firebase) and runs the
# phases as separate processes: write -> read -> tamper -> nokey -> cleanup.
# Needs: Flutter, Xcode, an Apple Development identity. Production data is
# never touched; the Keychain account is a throw-away name.
set -euo pipefail
APP="$(cd "$(dirname "$0")/../.." && pwd)"
P="${IBUL_PROBE_DIR:-$HOME/IBUL_isolated_build/keychain_probe}"
TEAM="${IBUL_TEAM_ID:-B4849QMKTU}"
ACC="ibul.kcprobe.$(date +%s)"
if [ ! -d "$P/macos" ]; then
  (cd "$(dirname "$P")" && flutter create --platforms=macos --org com.ibul --project-name keychain_probe "$(basename "$P")" >/dev/null)
  (cd "$P" && flutter pub add flutter_secure_storage:10.3.4 shared_preferences crypto >/dev/null)
fi
mkdir -p "$P/lib/core" "$P/lib/services/restaurant_offline"
cp "$APP/lib/core/secure_local_store.dart" "$P/lib/core/"
cp "$APP/lib/services/restaurant_offline/offline_identity_seal.dart" "$APP/lib/services/restaurant_offline/offline_panel_identity.dart" "$P/lib/services/restaurant_offline/"
cp "$APP/tool/keychain_probe/main.dart" "$P/lib/main.dart"
cp "$APP/tool/keychain_probe/DebugProfile.entitlements" "$P/macos/Runner/DebugProfile.entitlements"
cd "$P"
flutter pub get >/dev/null
flutter build macos --debug --config-only --dart-define=IBUL_KEYCHAIN_ACCOUNT="$ACC" > "$P/config.log" 2>&1 || { tail -20 "$P/config.log"; exit 2; }
DEFS="$(printf 'IBUL_KEYCHAIN_ACCOUNT=%s' "$ACC" | base64)"
# Sign with the real Apple Development identity and the Keychain entitlement.
xcodebuild build -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug \
  -derivedDataPath build/xc -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" CODE_SIGN_ENTITLEMENTS=Runner/DebugProfile.entitlements \
  DART_DEFINES="$DEFS" > "$P/xcode.log" 2>&1 || { grep -E "error:" "$P/xcode.log" | head -10; echo BUILD_FAILED; exit 2; }
BIN="$(find build/xc -name keychain_probe.app -maxdepth 6 | head -1)"
echo "== signature"; codesign -dvv "$BIN" 2>&1 | grep -E "Identifier|Authority=Apple Dev|TeamIdentifier" || true
codesign -d --entitlements - "$BIN" 2>&1 | grep -A3 keychain-access-groups || true
for ph in write read tamper nokey cleanup; do
  IBUL_KC_PHASE="$ph" "$BIN/Contents/MacOS/keychain_probe" 2>&1 | grep "^PROBE" || echo "PROBE $ph NO_OUTPUT"
done
