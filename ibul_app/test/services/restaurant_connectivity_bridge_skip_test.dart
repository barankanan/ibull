import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/platform_capabilities.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PlatformCapabilities.resetOverridesForTests();
    RestaurantConnectivityService.resetInstanceForTests();
  });

  test('mobile customer app never probes the local print bridge', () async {
    PlatformCapabilities.debugIsWebOverride = false;
    PlatformCapabilities.debugPlatformOverride = TargetPlatform.iOS;

    var probeCount = 0;
    final service = RestaurantConnectivityService(
      bridgeReachabilityProbe: () async {
        probeCount++;
        return true;
      },
    );

    await service.refresh(
      networkResults: const <ConnectivityResult>[ConnectivityResult.wifi],
    );

    expect(probeCount, 0);
    expect(service.bridgeReachable, isFalse);

    service.dispose();
  });

  test('desktop still probes the local print bridge', () async {
    PlatformCapabilities.debugIsWebOverride = false;
    PlatformCapabilities.debugPlatformOverride = TargetPlatform.macOS;

    var probeCount = 0;
    final service = RestaurantConnectivityService(
      bridgeReachabilityProbe: () async {
        probeCount++;
        return true;
      },
    );

    await service.refresh(
      networkResults: const <ConnectivityResult>[ConnectivityResult.wifi],
    );

    expect(probeCount, 1);
    expect(service.bridgeReachable, isTrue);

    service.dispose();
  });
}
