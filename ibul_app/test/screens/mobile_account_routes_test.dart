import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/screens/account/account_security_page.dart';
import 'package:ibul_app/screens/account/contact_center_page.dart';
import 'package:ibul_app/screens/account/help_center_page.dart';
import 'package:ibul_app/screens/account/notification_settings_page.dart';
import 'package:ibul_app/screens/categories_page.dart';
import 'package:ibul_app/screens/change_password_page.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  testWidgets('mobile categories screen hides the marketplace header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: CategoriesPage()));
    await tester.pump();
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.byTooltip('Bildirimler'), findsNothing);
    expect(find.byTooltip('Kamera'), findsNothing);
  });

  testWidgets('help and contact pages use the existing copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
    expect(find.text('Yardım'), findsOneWidget);
    expect(find.textContaining('Siparişimi nasıl takip ederim'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: ContactCenterPage()));
    await tester.pump();
    expect(find.text('İletişim'), findsOneWidget);
    expect(find.text('Destek talebi aç'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification settings is its own page without fake switches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsPage()),
    );
    expect(find.text('Bildirim Ayarları'), findsOneWidget);
    expect(find.text('Sipariş bildirimleri'), findsOneWidget);
    expect(find.text('SMS bildirimleri'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('security page opens password change and is not profile edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: const MaterialApp(home: AccountSecurityPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(find.text('Şifre Değiştir'), findsOneWidget);
    expect(find.text('Oturumdan çıkış'), findsOneWidget);
    expect(find.text('Kullanıcı Bilgilerim'), findsNothing);
    await tester.tap(find.text('Şifre Değiştir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });
}
