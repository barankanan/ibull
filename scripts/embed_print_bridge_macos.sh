#!/bin/sh
# Copy the standalone bridge into the Seller app bundle.
# Does not start the bridge and does not use port 3001.
set -eu
if [ -n "${SRCROOT:-}" ]; then
  ROOT="$(cd "$SRCROOT/.." && pwd)"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
# One-folder bridge build (executable + _internal). It goes under Resources so
# the app's MacOS folder keeps only the app executable.
SRC="$ROOT/local_print_bridge/dist/macos/IbulPrintBridge"
if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${WRAPPER_NAME:-}" ]; then
  CONTENTS="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Contents"
else
  CONTENTS="${1:-}"
fi
if [ -z "${CONTENTS}" ]; then
  echo "embed_print_bridge_macos: no destination" >&2
  exit 1
fi
DEST_DIR="$CONTENTS/Resources/PrintBridge"
# A one-file bridge from an older build cannot be started on demand.
rm -f "$CONTENTS/MacOS/IbulPrintBridge"
if [ ! -x "$SRC/IbulPrintBridge" ]; then
  echo "warning: IbulPrintBridge has not been built at $SRC (run local_print_bridge/macos/build_bridge_executable.sh)" >&2
  exit 0
fi
# An incremental build must not touch an unchanged bridge: re-copying and
# re-signing it after the app was sealed breaks the app signature
# ("a sealed resource is missing or invalid"). The stamp covers the bridge
# files, the helper entitlements and the signing identity.
STAMP="$( (find "$SRC" -type f -exec stat -f '%m %z %N' {} + 2>/dev/null; \
  shasum "$ROOT/macos/Runner/PrintBridgeHelper.entitlements"; \
  echo "${EXPANDED_CODE_SIGN_IDENTITY:-}") | shasum | cut -d' ' -f1)"
if [ -f "$DEST_DIR/.embed-stamp" ] && [ "$(cat "$DEST_DIR/.embed-stamp")" = "$STAMP" ] \
  && [ -x "$DEST_DIR/IbulPrintBridge" ]; then
  echo "Embedded IbulPrintBridge is up to date; not touched."
  SKIP_EMBED=1
fi
if [ "${SKIP_EMBED:-0}" != "1" ]; then
rm -rf "$DEST_DIR"
mkdir -p "$CONTENTS/Resources"
cp -R "$SRC" "$DEST_DIR"
chmod 755 "$DEST_DIR/IbulPrintBridge"
# Sign every library, then the helper, before the outer app signature.
# Do not apply the app sandbox to the helper.
SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "$SIGN_ID" ]; then SIGN_ID="-"; fi
find "$DEST_DIR/_internal" -type f \( -name "*.dylib" -o -name "*.so" -o -name "Python" \) -print0 |
  xargs -0 -n 20 codesign --force --sign "$SIGN_ID" >/dev/null 2>&1 || true
# The seller app is sandboxed and macOS refuses it a LaunchAgent. The bridge
# is started directly as a child that inherits the app's sandbox (app-sandbox +
# inherit, no other entitlement). Network client/server come from the app.
HELPER_ENT="$ROOT/macos/Runner/PrintBridgeHelper.entitlements"
codesign --force --sign "$SIGN_ID" --identifier "com.ibul.sellerdesktop.printbridge" \
  --entitlements "$HELPER_ENT" "$DEST_DIR/IbulPrintBridge"
echo "$STAMP" > "$DEST_DIR/.embed-stamp"
echo "Embedded IbulPrintBridge into $DEST_DIR"
fi

AGENT_SRC="$ROOT/macos/Runner/Library/LaunchAgents"
AGENT_DEST="$CONTENTS/Library/LaunchAgents"
if [ -d "$AGENT_SRC" ]; then
  mkdir -p "$AGENT_DEST"
  for plist in "$AGENT_SRC"/*.plist; do
    [ -f "$plist" ] || continue
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
    # The live agent ships only in a build that opts in on purpose
    # (IBUL_ALLOW_LIVE_PRINT_AGENT = YES, see Configs/AppInfo.xcconfig).
    if [ "$label" = "com.ibul.localprint" ] &&
      [ "${IBUL_ALLOW_LIVE_PRINT_AGENT:-NO}" != "YES" ]; then
      echo "Skipped live LaunchAgent plist $plist"
      continue
    fi
    if [ "$label" = "com.ibul.localprint.isolated-test" ] &&
      [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "com.ibul.sellerdesktop.offlinetest" ]; then
      echo "Skipped isolated LaunchAgent outside the offlinetest bundle"
      continue
    fi
    cp "$plist" "$AGENT_DEST/$(basename "$plist")"
    echo "Embedded LaunchAgent $(basename "$plist")"
  done
fi
