import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';

void main() {
  setUp(RestaurantCloudGate.resetForTests);

  test('bulut yanıt vermeyince sonraki çağrılar beklemeden vazgeçer', () {
    expect(RestaurantCloudGate.shouldFailFast, isFalse);
    RestaurantCloudGate.noteFailure();
    final sw = Stopwatch()..start();
    // Her sayfa geçişi aynı kapıyı sorar; hiçbiri ağ beklemez.
    for (var i = 0; i < 1000; i++) {
      expect(RestaurantCloudGate.shouldFailFast, isTrue);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(50));
  });

  test('başarı kapıyı açar, ardışık hata bekleme süresini büyütür', () {
    RestaurantCloudGate.noteFailure();
    RestaurantCloudGate.noteSuccess();
    expect(RestaurantCloudGate.shouldFailFast, isFalse);
  });
}
