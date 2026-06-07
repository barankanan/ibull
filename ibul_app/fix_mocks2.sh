#!/bin/bash
file="test/printer_setup/printer_system_setup_wizard_widget_test.dart"
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
