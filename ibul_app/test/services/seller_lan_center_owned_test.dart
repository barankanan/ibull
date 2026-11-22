import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/seller_lan_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SellerLanCenter.accessReader = null;
  });

  test('a computer that was never made the center is not reopened', () async {
    expect(await SellerLanCenter.isOwned('rest-1'), isFalse);
    final result = await SellerLanCenter.resumeOwned(
      restaurantId: 'rest-1',
      readMembership: (_) async => null,
      interfaces: const [],
    );
    expect(result, isNull);
  });

  test('ownership is per restaurant and can be forgotten', () async {
    await SellerLanCenter.markOwned('rest-1', true);
    expect(await SellerLanCenter.isOwned('rest-1'), isTrue);
    expect(await SellerLanCenter.isOwned('rest-2'), isFalse);
    await SellerLanCenter.markOwned('rest-1', false);
    expect(await SellerLanCenter.isOwned('rest-1'), isFalse);
  });
}
