#!/bin/bash
file="test/printer_setup/printer_system_setup_wizard_widget_test.dart"
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
