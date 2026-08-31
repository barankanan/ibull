import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/screens/ihiz_home_page.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'IBUL_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'IBUL_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  testWidgets('IhizHomePage opens the live landing, not coming-soon cards',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IhizHomePage()),
    );

    expect(find.byType(IhizCourierPage), findsOneWidget);
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.textContaining('Teslimatın yeni hızı'), findsWidgets);
    expect(find.text('NEDEN İHIZ?'), findsOneWidget);
    expect(find.text('Teslimat Prototipi'), findsNothing);
    expect(
      find.text('Hızlı teslimat ve hizmet çözümleri yakında burada.'),
      findsNothing,
    );
  });
}
