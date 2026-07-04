import 'package:flutter/foundation.dart';

/// Which IBUL application surface is running (customer web/mobile vs seller/admin).
enum IbulAppMode {
  customer,
  seller,
  admin,
  restaurant,
  /// Legacy full entry — all routes deferred, seller/desktop providers included.
  full,
}

/// Active app mode for the current isolate (set once at [main]).
abstract final class IbulAppModeRegistry {
  static IbulAppMode _current = IbulAppMode.full;

  static IbulAppMode get current => _current;

  static set current(IbulAppMode mode) {
    _current = mode;
    if (kDebugMode || kIsWeb) {
      // ignore: avoid_print
      print('[AppMode] ${mode.name}');
    }
  }

  static bool get isCustomer => _current == IbulAppMode.customer;

  static bool get isFull => _current == IbulAppMode.full;

  static bool get mountsSellerModules =>
      _current == IbulAppMode.full ||
      _current == IbulAppMode.seller ||
      _current == IbulAppMode.admin ||
      _current == IbulAppMode.restaurant;

  static bool get mountsDesktopPrint =>
      !kIsWeb &&
      (_current == IbulAppMode.full ||
          _current == IbulAppMode.seller ||
          _current == IbulAppMode.restaurant);

  static bool get mountsRestaurantConnectivity =>
      !kIsWeb &&
      (_current == IbulAppMode.full ||
          _current == IbulAppMode.seller ||
          _current == IbulAppMode.restaurant);

  @visibleForTesting
  static void resetForTests() {
    _current = IbulAppMode.full;
  }
}

String ibulEntrypointLabel(IbulAppMode mode) {
  switch (mode) {
    case IbulAppMode.customer:
      return 'main_customer';
    case IbulAppMode.seller:
      return 'main_seller';
    case IbulAppMode.admin:
      return 'main_admin';
    case IbulAppMode.restaurant:
      return 'main_restaurant';
    case IbulAppMode.full:
      return 'main';
  }
}
