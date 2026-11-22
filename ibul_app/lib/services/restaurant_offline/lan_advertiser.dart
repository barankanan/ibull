import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Announces the center on the local network so waiter devices can find it
/// without typing an address. The record carries only the keys the browser
/// side already reads (`svc`, `rid`, `mid`, `fp`). Finding a center is not
/// trust: the device still needs the server fingerprint and a pairing code.
abstract class LanAdvertiser {
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  });

  Future<void> stop();
}

/// Arguments for `dns-sd -R`. Pure, so they are tested without a process.
List<String> dnsSdRegisterArguments({
  required String instanceName,
  required int port,
  required String restaurantId,
  required String machineId,
  required String fingerprint,
}) {
  final name = instanceName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  return <String>[
    '-R',
    name.isEmpty ? 'IBUL Merkez' : name,
    '_ibul-lan._tcp',
    'local.',
    '$port',
    'svc=ibul-lan',
    'rid=$restaurantId',
    'mid=$machineId',
    'fp=$fingerprint',
  ];
}

/// macOS Bonjour through the system `dns-sd` tool. A sandboxed build may not
/// start it; that returns quietly and the QR/manual path stays available.
class DnsSdAdvertiser implements LanAdvertiser {
  Process? _process;

  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {
    if (!Platform.isMacOS) return;
    await stop();
    try {
      _process = await Process.start(
        'dns-sd',
        dnsSdRegisterArguments(
          instanceName: instanceName,
          port: port,
          restaurantId: restaurantId,
          machineId: machineId,
          fingerprint: fingerprint,
        ),
      );
    } on ProcessException {
      _process = null;
    }
  }

  @override
  Future<void> stop() async {
    _process?.kill();
    _process = null;
  }
}


/// macOS Bonjour through the system API (`NetService`) behind a method
/// channel. It runs in process, so the App Sandbox build can announce the
/// center without starting `dns-sd`.
class NativeBonjourAdvertiser implements LanAdvertiser {
  NativeBonjourAdvertiser({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.ibul.sellerdesktop/lan_bonjour';
  final MethodChannel _channel;

  /// True when the native side answered. False means "no native Bonjour here"
  /// (channel missing, publish refused) and the caller may try another way.
  bool announced = false;

  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {
    announced = false;
    final name = instanceName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    try {
      announced = await _channel.invokeMethod<bool>('start', <String, Object?>{
            'name': name.isEmpty ? 'IBUL Merkez' : name,
            'type': '_ibul-lan._tcp.',
            'port': port,
            'txt': <String, String>{
              'svc': 'ibul-lan',
              'rid': restaurantId,
              'mid': machineId,
              'fp': fingerprint,
            },
          }) ??
          false;
    } on MissingPluginException {
      announced = false;
    } on PlatformException {
      announced = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing was announced.
    } on PlatformException {
      // Already gone.
    }
    announced = false;
  }
}

/// The default on every platform: native Bonjour first (works in the App
/// Sandbox), the external `dns-sd` tool only when the native side is absent.
class PlatformLanAdvertiser implements LanAdvertiser {
  PlatformLanAdvertiser({LanAdvertiser? native, LanAdvertiser? fallback})
    : _native = native ?? NativeBonjourAdvertiser(),
      _fallback = fallback ?? DnsSdAdvertiser();

  final LanAdvertiser _native;
  final LanAdvertiser _fallback;

  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {
    if (!Platform.isMacOS) return;
    await _native.start(
      instanceName: instanceName,
      port: port,
      restaurantId: restaurantId,
      machineId: machineId,
      fingerprint: fingerprint,
    );
    final nativeWorked =
        _native is NativeBonjourAdvertiser && _native.announced;
    if (nativeWorked) return;
    await _fallback.start(
      instanceName: instanceName,
      port: port,
      restaurantId: restaurantId,
      machineId: machineId,
      fingerprint: fingerprint,
    );
  }

  @override
  Future<void> stop() async {
    await _native.stop();
    await _fallback.stop();
  }
}
