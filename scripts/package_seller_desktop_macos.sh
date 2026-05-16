#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/IbulSellerDesktop.app"
DMG_DIR="$PROJECT_DIR/build/macos/dist"
DMG_PATH="$DMG_DIR/IbulSellerDesktop.dmg"
STAGING_DIR="$DMG_DIR/dmg-staging"

"$SCRIPT_DIR/build_seller_desktop.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Beklenen app paketi bulunamadi: $APP_PATH"
  exit 1
fi

mkdir -p "$DMG_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "Ibul Seller Desktop" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo ""
echo "DMG hazir:"
echo "  $DMG_PATH"
