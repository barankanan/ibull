#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/IbulSellerDesktop.app"
DMG_DIR="$PROJECT_DIR/build/macos/dist"
DMG_PATH="$DMG_DIR/IbulSellerDesktop.dmg"
STAGING_DIR="$DMG_DIR/dmg-staging"
ARTIFACTS_DMG="$PROJECT_DIR/release_artifacts/macos/IbulSellerDesktop.dmg"
CHECKSUMS_DIR="$PROJECT_DIR/release_artifacts/checksums"

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

mkdir -p "$(dirname "$ARTIFACTS_DMG")" "$CHECKSUMS_DIR"
cp -f "$DMG_PATH" "$ARTIFACTS_DMG"
shasum -a 256 "$ARTIFACTS_DMG" | tee "$CHECKSUMS_DIR/IbulSellerDesktop.dmg.sha256"

echo ""
echo "DMG hazir:"
echo "  Build:  $DMG_PATH"
echo "  Staged: $ARTIFACTS_DMG"
echo ""
echo "DMG mount test:"
echo "  hdiutil attach \"$ARTIFACTS_DMG\""
echo "  hdiutil detach /Volumes/Ibul\\ Seller\\ Desktop"
echo ""
echo "Not: Developer ID notarization yapilmadiysa bazi Mac'lerde"
echo "     sag tik > Ac gerekebilir (Apple Development imzasi)."
