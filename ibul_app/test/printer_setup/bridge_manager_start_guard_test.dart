import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/bridge_manager.dart';

void main() {
  test('shouldStartBridgeProcess is false on web', () async {
    final shouldStart = await BridgeManager.shouldStartBridgeProcess();
    expect(shouldStart, isFalse);
  });

  test('isBridgePortListening is false on web', () async {
    if (!kIsWeb) return;
    final listening = await BridgeManager.isBridgePortListening();
    expect(listening, isFalse);
  });
}
