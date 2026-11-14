#!/bin/sh
# Keeps the production seller app, the customer app, and the isolated LAN
# test from being compiled into each other's bundle.
set -eu

generated="${IBUL_GENERATED_XCCONFIG:-${PROJECT_DIR:-}/Flutter/ephemeral/Flutter-Generated.xcconfig}"
target=""
if [ -n "$generated" ] && [ -f "$generated" ]; then
  target=$(grep '^FLUTTER_TARGET=' "$generated" | head -n 1 | cut -d= -f2- | tr -d '[:space:]')
fi

bundle="${PRODUCT_BUNDLE_IDENTIFIER:-}"
case "${bundle}:${target}" in
  com.ibul.sellerdesktop:lib/main.dart)
    echo "error: lib/main.dart cannot be built into the production seller app. Use: flutter run -d macos --flavor customer --target lib/main.dart" >&2
    exit 1
    ;;
  com.ibul.sellerdesktop.offlinetest:lib/main.dart)
    echo "error: the isolated LAN test cannot use the customer entry." >&2
    exit 1
    ;;
  com.ibul.customer:lib/main_seller.dart|com.ibul.customer:lib/main_waiter_lan.dart)
    echo "error: the seller entry cannot be built into the İBUL customer app." >&2
    exit 1
    ;;
esac

exit 0
