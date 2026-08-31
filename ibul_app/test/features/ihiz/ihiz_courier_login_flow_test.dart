import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/courier/ihiz_courier_login_page.dart';
import 'package:ibul_app/features/ihiz/apply/ihiz_courier_apply_page.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/services/ihiz_courier_auth_service.dart';
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

  Widget wrap(Size viewport, Widget child) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewport),
          child: child!,
        );
      },
      home: child,
    );
  }

  test('auth service maps application row fields', () {
    final service = IhizCourierAuthService();
    final data = service.applicationDataFromRow({
      'full_name': 'Ali Veli',
      'phone': '05551112233',
      'tc_number': '12345678901',
      'birth_date': '01 / 01 / 1990',
      'license_type': 'A1',
      'motor_type': '50 CC',
      'criminal_record': 'Yok',
      'company_type': 'Şirketim yok',
      'city': 'İstanbul',
      'district': 'Kadıköy',
      'availability': 'Akşam',
      'email': 'ali@example.com',
      'note': 'Not',
      'status': 'approved',
    });
    expect(data.fullName, 'Ali Veli');
    expect(data.email, 'ali@example.com');
    expect(data.locationLabel, 'Kadıköy / İstanbul');
  });

  test('auth cleanErrorMessage maps invalid credentials', () {
    final service = IhizCourierAuthService();
    expect(
      service.cleanErrorMessage(
        AuthException('bad', code: 'invalid_credentials'),
      ),
      'E-posta veya şifre hatalı.',
    );
  });

  testWidgets('Giriş Yap opens İHIZ courier login not consumer LoginPage', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final loginCta = find.text('Giriş Yap').at(0);
    await tester.ensureVisible(loginCta);
    await tester.tap(loginCta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IhizCourierLoginPage), findsOneWidget);
    expect(find.text('İhız kurye paneline giriş'), findsOneWidget);
    expect(find.text('Kurye Paneline Gir'), findsOneWidget);
    expect(find.text('Kayıt Ol / Başvur'), findsOneWidget);
    expect(find.textContaining('Hoş Geldiniz'), findsNothing);
  });

  testWidgets('login validation requires email and password', (tester) async {
    const viewport = Size(800, 900);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierLoginPage()));
    await tester.pump();

    await tester.tap(find.text('Kurye Paneline Gir'));
    await tester.pump();
    expect(find.text('E-posta ve şifre zorunlu.'), findsOneWidget);
  });

  testWidgets('Kayıt Ol / Başvur opens apply page', (tester) async {
    const viewport = Size(800, 900);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierLoginPage()));
    await tester.pump();

    await tester.tap(find.text('Kayıt Ol / Başvur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(IhizCourierApplyPage), findsOneWidget);
  });

  testWidgets('Kurye Ol still opens apply page', (tester) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final kuryeOl = find.text('Kurye Ol').at(0);
    await tester.ensureVisible(kuryeOl);
    await tester.tap(kuryeOl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(IhizCourierApplyPage), findsOneWidget);
  });

  testWidgets('login page mobile layout has no overflow', (tester) async {
    const viewport = Size(360, 720);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierLoginPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('Kurye Paneline Gir'), findsOneWidget);
  });
}
