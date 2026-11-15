import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pairing_guard.dart';

void main() {
  test('seller center restarts only the host this computer already owns', () {
    expect(
      sellerLanCenterAction(
        alreadyListening: true,
        centerEnabled: true,
        savedAddressReady: true,
        otherMachineAnswers: false,
      ),
      SellerLanCenterAction.alreadyRunning,
    );
    expect(
      sellerLanCenterAction(
        alreadyListening: false,
        centerEnabled: true,
        savedAddressReady: true,
        otherMachineAnswers: false,
      ),
      SellerLanCenterAction.start,
    );
    expect(
      sellerLanCenterAction(
        alreadyListening: false,
        centerEnabled: true,
        savedAddressReady: true,
        otherMachineAnswers: true,
      ),
      SellerLanCenterAction.blocked,
    );
    expect(
      sellerLanCenterAction(
        alreadyListening: false,
        centerEnabled: false,
        savedAddressReady: false,
        otherMachineAnswers: false,
      ),
      SellerLanCenterAction.needsChoice,
    );
  });

  test('IBUL_LAN_HOME keeps test certificates out of the seller directory', () {
    expect(
      lanMaterialDirectory(
        operatingSystem: 'macos',
        environment: const <String, String>{'HOME': '/Users/seller'},
        restaurantId: 'rest-1',
      ),
      '/Users/seller/Library/Application Support/ibul-lan/rest-1',
    );
    expect(
      lanMaterialDirectory(
        operatingSystem: 'macos',
        environment: const <String, String>{
          'HOME': '/Users/seller',
          'IBUL_LAN_HOME': '/tmp/ibul-lan-test',
        },
        restaurantId: 'rest-1',
      ),
      '/tmp/ibul-lan-test/rest-1',
    );
  });
}
