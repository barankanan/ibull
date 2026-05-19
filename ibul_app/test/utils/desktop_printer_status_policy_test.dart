import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/desktop_print_hub.dart';
import 'package:ibul_app/utils/desktop_printer_status_policy.dart';

void main() {
  test('bridge online hides boot banner even if bootError was set', () {
    expect(
      shouldShowDesktopPrinterBootBanner(
        bridgeStatus: BridgeStatus.online,
        bootstrapped: true,
        bootError: 'Yazıcı bağlantısı kurulamadı',
      ),
      isFalse,
    );
  });

  test('bridge offline with boot error shows banner', () {
    expect(
      shouldShowDesktopPrinterBootBanner(
        bridgeStatus: BridgeStatus.offline,
        bootstrapped: true,
        bootError: 'fail',
      ),
      isTrue,
    );
  });

  test('ready bottom chip and top banner cannot both mean ready', () {
    final topVisible = shouldShowDesktopPrinterBootBanner(
      bridgeStatus: BridgeStatus.online,
      bootstrapped: true,
      bootError: null,
    );
    final bottomReady = isDesktopPrinterBridgeReady(BridgeStatus.online);
    expect(topVisible && bottomReady, isFalse);
    expect(bottomReady, isTrue);
  });
}
