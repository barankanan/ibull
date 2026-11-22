import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/platform_capabilities.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';

const _wifi = <ConnectivityResult>[ConnectivityResult.wifi];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PlatformCapabilities.debugIsWebOverride = false;
    PlatformCapabilities.debugPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    PlatformCapabilities.resetOverridesForTests();
    RestaurantConnectivityService.resetInstanceForTests();
  });

  RestaurantConnectivityService build({
    required bool Function() cloud,
    required bool Function() lanHost,
    bool bridge = true,
  }) {
    return RestaurantConnectivityService(
      supabaseReachabilityProbe: () async => cloud(),
      bridgeReachabilityProbe: () async => bridge,
      lanHostProbe: lanHost,
    );
  }

  test('Wi-Fi stays up, the cloud stops answering: local mode starts by itself', () async {
    var cloudUp = true;
    final service = build(cloud: () => cloudUp, lanHost: () => true);
    await service.refresh(networkResults: _wifi);
    expect(service.mode, RestaurantConnectivityMode.online);

    cloudUp = false;
    await service.refresh(networkResults: _wifi);
    // One slow or failed answer is not proof of an outage.
    expect(service.supabaseReachable, isTrue);
    expect(service.mode, RestaurantConnectivityMode.online);

    await service.refresh(networkResults: _wifi);
    expect(service.supabaseReachable, isFalse);
    expect(service.mode, RestaurantConnectivityMode.offlineLocalMode);
    service.dispose();
  });

  test('the first good answer returns to normal', () async {
    var cloudUp = false;
    final service = build(cloud: () => cloudUp, lanHost: () => true);
    await service.refresh(networkResults: _wifi);
    await service.refresh(networkResults: _wifi);
    expect(service.mode, RestaurantConnectivityMode.offlineLocalMode);

    cloudUp = true;
    await service.refresh(networkResults: _wifi);
    expect(service.supabaseReachable, isTrue);
    expect(service.mode, RestaurantConnectivityMode.online);
    service.dispose();
  });

  test('a save that just timed out counts as one failure', () async {
    final service = build(cloud: () => false, lanHost: () => true);
    await service.refresh(networkResults: _wifi, priorCloudFailure: true);
    expect(service.supabaseReachable, isFalse);
    expect(service.mode, RestaurantConnectivityMode.offlineLocalMode);
    service.dispose();
  });

  test('cloud down without a local center is not reported as local mode', () async {
    final service = build(cloud: () => false, lanHost: () => false);
    await service.refresh(networkResults: _wifi);
    await service.refresh(networkResults: _wifi);
    expect(service.lanHostReachable, isFalse);
    expect(service.mode, RestaurantConnectivityMode.supabaseUnreachable);
    service.dispose();
  });

  test('cloud, bridge and local center are separate facts', () async {
    final service = build(
      cloud: () => true,
      lanHost: () => false,
      bridge: false,
    );
    await service.refresh(networkResults: _wifi);
    expect(service.supabaseReachable, isTrue);
    expect(service.bridgeReachable, isFalse);
    expect(service.lanHostReachable, isFalse);
    expect(service.mode, RestaurantConnectivityMode.bridgeUnreachable);
    service.dispose();
  });
}
