#!/usr/bin/env bash
set -euo pipefail

# Fast quality gate: critical Flutter tests that must pass before web deploy.
# Full `flutter analyze` on 439k lines is not this job — keep the suite small
# and deterministic.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/ibul_app"

cd "$APP_DIR"
flutter pub get
# New-code dirs only. Root analyzer must stay flutter_lints — do not
# `flutter analyze` the whole lib (seller_panel / print / models).
# İHIZ courier dashboard (~10k) is Dilim 4; exclude it from this gate.
flutter analyze --no-fatal-infos \
  lib/features/checkout \
  lib/features/investor \
  lib/features/ihiz/apply \
  lib/features/ihiz/business \
  lib/features/ihiz/delivery \
  lib/features/ihiz/sections \
  lib/features/ihiz/send \
  lib/features/ihiz/shell \
  lib/features/ihiz/theme \
  lib/features/ihiz/tracking \
  lib/features/ihiz/widgets \
  lib/features/ihiz/ihiz_landing_body.dart \
  lib/screens/coming_soon \
  lib/screens/legal \
  lib/features/seller/panel/cargo \
  lib/features/seller/panel/printer_center \
  lib/app/ibul_material_app.dart \
  lib/app/ibul_go_router.dart \
  lib/app/ibul_router.dart
flutter test \
  test/app/root_seller_route_deferred_test.dart \
  test/app/ibul_architecture_slice_test.dart \
  test/home/home_product_visibility_parity_test.dart \
  test/features/saved_payment_cards/saved_payment_cards_test.dart \
  test/features/checkout/checkout_line_identity_test.dart \
  test/services/money_session_catch_log_test.dart \
  test/analysis/new_code_analyzer_contract_test.dart \
  test/features/seller/panel/seller_cargo_extract_test.dart \
  test/features/seller/panel/seller_printer_extract_test.dart \
  test/web_footer_admin_nav_test.dart \
  test/features/admin/admin_panel_content_router_test.dart \
  test/screens/legal/legal_and_footer_pages_test.dart
