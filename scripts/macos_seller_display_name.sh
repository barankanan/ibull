#!/bin/sh
# Shows the seller app as "İBUL Satıcı" in the Dock, Finder, the app switcher
# and the menu bar without renaming the bundle or touching its identifier.
#
# macOS shows a bundle's localized name only when the unlocalized
# CFBundleDisplayName equals the bundle's file name. The product stays
# IbulSellerDesktop.app (scripts, signing, Keychain and the embedded print
# bridge keep their paths); the visible name comes from InfoPlist.strings.
# The customer app is left exactly as it is.
set -eu

case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
  com.ibul.sellerdesktop|com.ibul.sellerdesktop.*) ;;
  *) exit 0 ;;
esac

display="${APP_DISPLAY_NAME:-}"
[ -n "$display" ] || exit 0

app="${BUILT_PRODUCTS_DIR:?}/${WRAPPER_NAME:?}"
plist="$app/Contents/Info.plist"
resources="$app/Contents/Resources"
[ -f "$plist" ] || { echo "error: Info.plist not found: $plist" >&2; exit 1; }

buddy=/usr/libexec/PlistBuddy
"$buddy" -c "Set :CFBundleDisplayName ${PRODUCT_NAME:?}" "$plist" 2>/dev/null ||
  "$buddy" -c "Add :CFBundleDisplayName string ${PRODUCT_NAME}" "$plist"
"$buddy" -c "Set :LSHasLocalizedDisplayName true" "$plist" 2>/dev/null ||
  "$buddy" -c "Add :LSHasLocalizedDisplayName bool true" "$plist"
"$buddy" -c "Set :IbulAppDisplayName $display" "$plist" 2>/dev/null ||
  "$buddy" -c "Add :IbulAppDisplayName string $display" "$plist"

for lang in tr en; do
  mkdir -p "$resources/$lang.lproj"
  printf '"CFBundleDisplayName" = "%s";\n"CFBundleName" = "%s";\n' \
    "$display" "$display" > "$resources/$lang.lproj/InfoPlist.strings"
done
echo "Seller display name set: $display ($app)"
