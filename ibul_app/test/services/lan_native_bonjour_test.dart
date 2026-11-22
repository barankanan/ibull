import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_advertiser.dart';

class _Recorder implements LanAdvertiser {
  int starts = 0;
  @override
  Future<void> start({required String instanceName, required int port, required String restaurantId, required String machineId, required String fingerprint}) async => starts++;
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeBonjourAdvertiser.channelName);
  final calls = <MethodCall>[];

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('native announce sends the same record keys the browser reads', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final advertiser = NativeBonjourAdvertiser();
    await advertiser.start(instanceName: 'IBUL Merkez!', port: 18783, restaurantId: 'r1', machineId: 'm1', fingerprint: 'ff');
    expect(advertiser.announced, isTrue);
    final args = calls.single.arguments as Map;
    expect(args['type'], '_ibul-lan._tcp.');
    expect(args['port'], 18783);
    expect(args['name'], 'IBUL Merkez');
    expect(args['txt'], {'svc': 'ibul-lan', 'rid': 'r1', 'mid': 'm1', 'fp': 'ff'});
  });

  test('a missing or refusing native side falls back to dns-sd, quietly', () async {
    if (!Platform.isMacOS) return;
    final fallback = _Recorder();
    final advertiser = PlatformLanAdvertiser(fallback: fallback);
    await advertiser.start(instanceName: 'x', port: 1, restaurantId: 'r', machineId: 'm', fingerprint: 'f');
    expect(fallback.starts, 1, reason: 'no native handler registered');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'publish_failed'));
    await advertiser.start(instanceName: 'x', port: 1, restaurantId: 'r', machineId: 'm', fingerprint: 'f');
    expect(fallback.starts, 2);
  });

  test('when native works dns-sd is not started', () async {
    if (!Platform.isMacOS) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => true);
    final fallback = _Recorder();
    await PlatformLanAdvertiser(fallback: fallback).start(instanceName: 'x', port: 1, restaurantId: 'r', machineId: 'm', fingerprint: 'f');
    expect(fallback.starts, 0);
  });
}
