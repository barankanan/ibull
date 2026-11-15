#!/bin/sh
# Copy the standalone bridge into the Seller app bundle.
# Does not start the bridge and does not use port 3001.
set -eu
if [ -n "${SRCROOT:-}" ]; then
  ROOT="$(cd "$SRCROOT/.." && pwd)"
else
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
SRC="$ROOT/local_print_bridge/dist/macos/IbulPrintBridge"
if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${WRAPPER_NAME:-}" ]; then
  DEST_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Contents/MacOS"
else
  DEST_DIR="${1:-}"
fi
if [ -z "${DEST_DIR}" ]; then
  echo "embed_print_bridge_macos: no destination" >&2
  exit 1
fi
mkdir -p "$DEST_DIR"
if [ ! -f "$SRC" ]; then
  echo "warning: IbulPrintBridge has not been built at $SRC" >&2
  exit 0
fi
cp "$SRC" "$DEST_DIR/IbulPrintBridge"
chmod 755 "$DEST_DIR/IbulPrintBridge"
# Sign the helper before the outer app signature. Do not apply the app sandbox.
SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -n "$SIGN_ID" ] && [ "$SIGN_ID" != "-" ]; then
  codesign --force --sign "$SIGN_ID" --identifier "com.ibul.sellerdesktop.printbridge" "$DEST_DIR/IbulPrintBridge"
else
  codesign --force --sign - --identifier "com.ibul.sellerdesktop.printbridge" "$DEST_DIR/IbulPrintBridge"
fi
echo "Embedded IbulPrintBridge into $DEST_DIR"

AGENT_SRC="$ROOT/macos/Runner/Library/LaunchAgents"
AGENT_DEST="$(dirname "$DEST_DIR")/Library/LaunchAgents"
if [ -d "$AGENT_SRC" ]; then
  mkdir -p "$AGENT_DEST"
  for plist in "$AGENT_SRC"/*.plist; do
    [ -f "$plist" ] || continue
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
    if [ "$label" = "com.ibul.localprint" ]; then
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
