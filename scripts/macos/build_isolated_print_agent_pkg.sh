#!/bin/sh
# Build an isolated print-agent package. Does not install it and does not
# touch the live com.ibul.localprint agent.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/ibul-isolated-pkg.XXXXXX")"
PAYLOAD="$STAGE/payload/Library/Application Support/IbulPrintBridgeIsolatedTest"
SCRIPTS="$STAGE/scripts"
mkdir -p "$PAYLOAD" "$SCRIPTS"

HELPER="$ROOT/build/macos/Build/Products/Release/IbulSellerDesktop.app/Contents/MacOS/IbulPrintBridge"
if [ ! -x "$HELPER" ]; then
  HELPER="$ROOT/build/macos/Build/Products/Debug/IbulSellerDesktop.app/Contents/MacOS/IbulPrintBridge"
fi
if [ ! -x "$HELPER" ]; then
  echo "IbulPrintBridge is not in the built Seller app." >&2
  exit 1
fi

PLIST="$PAYLOAD/com.ibul.localprint.isolated-test.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ibul.localprint.isolated-test</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HELPER}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ThrottleInterval</key>
  <integer>30</integer>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
    <key>Crashed</key>
    <true/>
  </dict>
  <key>StandardOutPath</key>
  <string>__HOME__/Library/Application Support/IbulPrintBridgeIsolatedTest/logs/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>__HOME__/Library/Application Support/IbulPrintBridgeIsolatedTest/logs/stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PRINT_BRIDGE_HOST</key>
    <string>127.0.0.1</string>
    <key>PRINT_BRIDGE_PORT</key>
    <string>18771</string>
    <key>PRINT_STATION_ENABLED</key>
    <string>false</string>
    <key>PRINT_BRIDGE_DATA_DIR</key>
    <string>__HOME__/Library/Application Support/IbulPrintBridgeIsolatedTest</string>
    <key>PRINT_BRIDGE_ENV_FILE</key>
    <string>__HOME__/Library/Application Support/IbulPrintBridgeIsolatedTest/bridge.env</string>
  </dict>
</dict>
</plist>
EOF
cp "$ROOT/scripts/macos/isolated_print_agent/uninstall" "$PAYLOAD/uninstall-isolated-print-agent.sh"
chmod 755 "$PAYLOAD/uninstall-isolated-print-agent.sh"

LABEL="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$PLIST")"
if [ "$LABEL" = "com.ibul.localprint" ]; then
  echo "Refusing to package the live label." >&2
  exit 1
fi
xattr -cr "$PAYLOAD" 2>/dev/null || true
find "$PAYLOAD" -name '._*' -delete

cp "$ROOT/scripts/macos/isolated_print_agent/postinstall" "$SCRIPTS/postinstall"
chmod 755 "$SCRIPTS/postinstall"
if grep 'bootout' "$SCRIPTS/postinstall" | grep -v 'isolated-test' >/dev/null; then
  echo "Refusing a postinstall that can boot out another agent." >&2
  exit 1
fi

OUT="$ROOT/build/macos/IbulPrintBridgeIsolatedTest.pkg"
mkdir -p "$(dirname "$OUT")"
pkgbuild \
  --root "$PAYLOAD" \
  --install-location "/Library/Application Support/IbulPrintBridgeIsolatedTest" \
  --scripts "$SCRIPTS" \
  --identifier "com.ibul.localprint.isolated-test.pkg" \
  --version "0.0.0-isolated" \
  "$OUT"
rm -rf "$STAGE"
echo "Built $OUT"
echo "Not installed."
