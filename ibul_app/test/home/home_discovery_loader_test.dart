import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/screens/home/home_discovery_loader.dart';

void main() {
  tearDown(HomeDiscoveryLoader.resetForTest);

  test('vehicle and location queries start in parallel', () async {
    final order = <String>[];
    HomeDiscoveryLoader.debugVehiclesQuery = () async {
      order.add('v_start');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      order.add('v_end');
      return const [];
    };
    HomeDiscoveryLoader.debugPositionQuery = () async {
      order.add('d_start');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      order.add('d_end');
      return null;
    };

    await Future.wait([
      HomeDiscoveryLoader.loadVehicles(),
      HomeDiscoveryLoader.resolvePosition(),
    ]);

    expect(order.contains('v_start'), isTrue);
    expect(order.contains('d_start'), isTrue);
    expect(order.indexOf('v_start'), lessThan(order.indexOf('d_end')));
    expect(order.indexOf('d_start'), lessThan(order.indexOf('v_end')));
  });

  test('cached vehicle query does not hit the network twice', () async {
    var calls = 0;
    HomeDiscoveryLoader.debugVehiclesQuery = () async {
      calls += 1;
      return [
        VehicleListing(
          id: 'live',
          sellerId: 's1',
          listingType: VehicleListingType.sale,
          status: VehicleListingStatus.active,
          specs: const VehicleSpecs(brand: 'Toyota', model: 'Corolla', year: 2021),
        ),
      ];
    };
    final first = await HomeDiscoveryLoader.loadVehicles();
    final second = await HomeDiscoveryLoader.loadVehicles();
    expect(calls, 1);
    expect(first.map((e) => e.id), ['live']);
    expect(second.map((e) => e.id), ['live']);
  });
}
