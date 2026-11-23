import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/restaurant_local_ops_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Yerel Operasyon Merkezi sade bölümlerle açılır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: RestaurantLocalOpsPage(restaurantId: 'r-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Yerel Operasyon Merkezi'), findsOneWidget);
    expect(find.text('Merkez durumu'), findsOneWidget);
    expect(find.text('Garson cihazları'), findsOneWidget);
    expect(find.text('Kayıtlı yazıcılar'), findsOneWidget);
    expect(find.text('Bu cihazda kayıtlı yazıcı bilgisi yok.'), findsOneWidget);
    expect(find.text('Yerel merkezi başlat'), findsOneWidget);
    expect(find.textContaining('Yerel sunucu: kapalı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekranda taşma olmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: RestaurantLocalOpsPage(restaurantId: 'r-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
