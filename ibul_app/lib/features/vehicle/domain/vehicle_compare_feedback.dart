import 'package:flutter/material.dart';

import '../models/vehicle_listing.dart';
import '../navigation/vehicle_routes.dart';
import '../widgets/vehicle_compare_picker.dart';

abstract final class VehicleCompareFeedback {
  static Future<void> open(
    BuildContext context,
    VehicleListing listing, {
    List<VehicleListing> similar = const [],
  }) async {
    final confirmed = await VehicleComparisonModal.open(
      context,
      current: listing,
      similarVehicles: similar,
    );
    if (!confirmed || !context.mounted) return;
    await VehicleRoutes.openCompare(context);
  }
}
