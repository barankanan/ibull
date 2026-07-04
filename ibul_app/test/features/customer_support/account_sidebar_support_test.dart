import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/widgets/account_sidebar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('account sidebar shows customer support above settings', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 900,
              width: 280,
              child: AccountSidebar(activePage: 'Müşteri Hizmetleri'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Müşteri Hizmetleri'), findsOneWidget);
    expect(find.text('Destek ve talepler'), findsOneWidget);

    final reviewsY = tester.getTopLeft(find.text('Değerlendirmelerim')).dy;
    final supportY = tester.getTopLeft(find.text('Müşteri Hizmetleri')).dy;
    final settingsY = tester.getTopLeft(find.text('Ayarlar')).dy;

    expect(reviewsY < supportY, isTrue);
    expect(supportY < settingsY, isTrue);
  });
}
