import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/app_state.dart';
import '../core/cart_state.dart';
import '../core/favorite_state.dart';
import '../core/ibul_app_mode.dart';
import '../core/providers/cart_provider.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/review_state.dart';
import '../core/runtime_diagnostic_logger.dart';
import 'desktop_print_provider_stub.dart'
    if (dart.library.io) 'desktop_print_provider_io.dart';
import 'restaurant_connectivity_provider_stub.dart'
    if (dart.library.io) 'restaurant_connectivity_provider_io.dart';

/// Customer web/mobile — cart, favorites, connectivity only. No print/restaurant.
List<SingleChildWidget> buildCustomerProviders() {
  RuntimeDiagnosticLogger.localPrint('skipped: customer app');
  RuntimeDiagnosticLogger.startup('[SellerModule] not mounted in customer app');
  return [
    ChangeNotifierProvider.value(value: CartState()),
    ChangeNotifierProvider.value(value: FavoriteState()),
    ChangeNotifierProvider.value(value: ReviewState()),
    ChangeNotifierProvider(create: (_) => AppState()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
  ];
}

/// Full / seller desktop — includes restaurant connectivity + desktop print hub.
List<SingleChildWidget> buildFullAppProviders() {
  return [
    ...buildCustomerProviders(),
    if (!kIsWeb) ...buildRestaurantConnectivityProviders(),
    if (!kIsWeb) ...buildDesktopPrintProviders(),
  ];
}

List<SingleChildWidget> buildProvidersForMode(IbulAppMode mode) {
  switch (mode) {
    case IbulAppMode.customer:
      return buildCustomerProviders();
    case IbulAppMode.full:
    case IbulAppMode.seller:
    case IbulAppMode.admin:
    case IbulAppMode.restaurant:
      return buildFullAppProviders();
  }
}

int countMountedProviders(IbulAppMode mode) {
  const customerCount = 6;
  if (mode == IbulAppMode.customer) return customerCount;
  if (kIsWeb) return customerCount;
  // IO full/seller/restaurant: +restaurant connectivity +desktop print hub
  return customerCount + 2;
}
