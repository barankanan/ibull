import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/bridge_manager.dart';

void main() {
  test('windowsInstalledBridgeExeCandidates includes Program Files paths', () {
    final candidates = BridgeManager.windowsInstalledBridgeExeCandidates();
    expect(candidates, isNotEmpty);
    expect(
      candidates.any((path) => path.contains(r'IbulPrintBridge\IbulPrintBridge.exe')),
      isTrue,
    );
    expect(
      candidates.any((path) => path.contains('Program Files')),
      isTrue,
    );
  });
}
