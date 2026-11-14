#!/bin/sh
# This checkout lives on a file-provider Desktop. That volume stamps
# FinderInfo onto build products and codesign then fails. Mark the macOS
# build directory so the provider leaves it alone, then clear any stamp
# already on the bundle.
set -eu
if [ -n "${SRCROOT:-}" ]; then
  build_root="$(cd "$SRCROOT/.." && pwd)/build/macos"
  if [ -d "$build_root" ]; then
    xattr -w com.apple.fileprovider.ignore#P 1 "$build_root" || true
  fi
fi
app="${TARGET_BUILD_DIR:-}/${FULL_PRODUCT_NAME:-}"
if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FULL_PRODUCT_NAME:-}" ] || [ ! -d "$app" ]; then
  exit 0
fi
xattr -cr "$app"
