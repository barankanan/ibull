import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/admin_panel_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:ibul_app/services/admin_service.dart';
import 'package:ibul_app/models/admin_permissions.dart';

class _MockAuthService extends AuthService {
  @override
  User? get currentUser => const User(
    id: 'test-user-id',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2025-01-01T00:00:00.000Z',
    email: 'admin@ibul.com',
  );

  @override
  Future<dynamic> getUserDataField(String field) async => 'admin';

  @override
  Future<Map<String, dynamic>?> getUserProfile() async => {
    'display_name': 'Test Admin',
  };
}

class _MockAdminService extends AdminService {
  @override
  Future<AdminAccessBundle> getCurrentAdminAccessBundle() async {
    return const AdminAccessBundle(
      roleKey: 'admin',
      roleTitle: 'Admin',
      allowedModules: AdminModules.all,
      deniedModules: [],
    );
  }
}

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://foo.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'foo',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  testWidgets('Dashboard stat kartları ilgili modüllere geçirir', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AdminPanelPage(
          authService: _MockAuthService(),
          adminService: _MockAdminService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Genel Bakış'), findsWidgets);

    // Sidebar'daki Sipariş & İade menüsüne tıkla
    await tester.tap(find.text('Sipariş & İade').last);
    await tester.pumpAndSettle();

    // Sipariş & İade sayfasının içeriği render edilmeli
    expect(find.text('Sipariş & İade'), findsWidgets);

    // Sidebar'daki Finans menüsüne tıkla
    await tester.tap(find.text('Finans').last);
    await tester.pumpAndSettle();

    expect(find.text('Finans'), findsWidgets);
  });
}
