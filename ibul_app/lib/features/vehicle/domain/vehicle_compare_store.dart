import 'package:flutter/foundation.dart';

import '../models/vehicle_listing.dart';

enum VehicleCompareToggleResult { added, removed, atLimit }

class VehicleCompareStore extends ChangeNotifier {
  VehicleCompareStore._();

  static final VehicleCompareStore instance = VehicleCompareStore._();

  static const int minItems = 2;
  static const int maxItems = 4;

  final List<VehicleListing> _items = [];

  List<VehicleListing> get items => List.unmodifiable(_items);

  int get length => _items.length;

  bool get canCompare => _items.length >= minItems;

  bool contains(String listingId) =>
      _items.any((listing) => listing.id == listingId);

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  bool toggle(VehicleListing listing) {
    return applyToggle(listing) == VehicleCompareToggleResult.added;
  }

  VehicleCompareToggleResult applyToggle(VehicleListing listing) {
    if (contains(listing.id)) {
      _items.removeWhere((item) => item.id == listing.id);
      notifyListeners();
      return VehicleCompareToggleResult.removed;
    }
    if (_items.length >= maxItems) {
      return VehicleCompareToggleResult.atLimit;
    }
    _items.add(listing);
    notifyListeners();
    return VehicleCompareToggleResult.added;
  }

  void setSelection(List<VehicleListing> listings) {
    _items
      ..clear()
      ..addAll(listings.take(maxItems));
    notifyListeners();
  }

  @visibleForTesting
  void replaceAll(List<VehicleListing> listings) => setSelection(listings);
}
