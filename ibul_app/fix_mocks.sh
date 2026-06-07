#!/bin/bash
FILES=(
  "test/printer_setup/ethernet_role_mapping_test.dart"
  "test/printer_setup/windows_pos58_encoding_profile_test.dart"
  "test/printer_setup/desktop_print_orchestrator_bridge_runtime_test.dart"
  "test/printer_setup/windows_pos58_test_dispatch_test.dart"
  "test/printer_setup/save_printer_roles_test_gate_test.dart"
  "test/printer_setup/desktop_print_orchestrator_stale_printer_test.dart"
  "test/printer_setup/ethernet_printer_dialog_test.dart"
)

for file in "${FILES[@]}"; do
  # Add resolveExpectedKitchenPrinter if missing and implements PrinterRepositoryPort
  if grep -q "implements PrinterRepositoryPort" "$file" && ! grep -q "resolveExpectedKitchenPrinter" "$file"; then
    sed -i '' -e '/implements PrinterRepositoryPort {/a\
  @override\
  Future<ExpectedKitchenPrinterResolution?> resolveExpectedKitchenPrinter({\
    required String restaurantId,\
    String? stationId,\
    String? stationName,\
  }) async => null;\
' "$file"
  fi

  # Add invalidateRoleMappingCacheState if missing and implements PrintStationServicePort
  if grep -q "implements PrintStationServicePort" "$file" && ! grep -q "readRoleMappingCacheToken" "$file"; then
    sed -i '' -e '/implements PrintStationServicePort {/a\
  @override\
  Future<String> invalidateRoleMappingCacheState({\
    required String restaurantId,\
    Map<String, dynamic>? roleMappings,\
    String source = '\''print_station_service'\'',\
  }) async => '\''mock_token'\'';\
\
  @override\
  Future<String?> readRoleMappingCacheToken(String restaurantId) async => '\''mock_token'\'';\
' "$file"
  fi
done
