// Real macOS check that the marketplace customer session and the AVM session
// live side by side. Two runs (the second is the app restart):
//   flutter test integration_test/mall_dual_session_test.dart -d macos \
//     --dart-define-from-file=.env \
//     --dart-define=CUSTOMER_RT_EMAIL=... --dart-define=CUSTOMER_RT_PASSWORD=... \
//     --dart-define=MALL_RT_EMAIL=... --dart-define=MALL_RT_PASSWORD=... \
//     --dart-define=MALL_DUAL_PHASE=login        # then: =restart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/app/ibul_app_boot.dart';
import 'package:ibul_app/app/ibul_material_app.dart';
import 'package:ibul_app/app/ibul_router.dart';
import 'package:ibul_app/app/shared_app_widgets.dart';
import 'package:ibul_app/core/route_observer.dart';
import 'package:ibul_app/features/mall/application/mall_hub_page.dart';
import 'package:ibul_app/features/mall/auth/mall_auth_session.dart';
import 'package:ibul_app/features/mall/management/services/mall_management_repository.dart';
import 'package:ibul_app/services/auth_service.dart';

const _customerEmail = String.fromEnvironment('CUSTOMER_RT_EMAIL');
const _customerPassword = String.fromEnvironment('CUSTOMER_RT_PASSWORD');
const _mallEmail = String.fromEnvironment('MALL_RT_EMAIL');
const _mallPassword = String.fromEnvironment('MALL_RT_PASSWORD');
const _phase = String.fromEnvironment('MALL_DUAL_PHASE', defaultValue: 'login');

final _report = <String, String>{};

void _log(String line) => debugPrint('[MALL_DUAL] $line');

bool get _hasAccounts =>
    _customerEmail.isNotEmpty &&
    _customerPassword.isNotEmpty &&
    _mallEmail.isNotEmpty &&
    _mallPassword.isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer and AVM sessions stay separate', (tester) async {
    await runIbulAppBootstrap(
      bootWatch: Stopwatch()..start(),
      initServicesBackground: initIbulServicesBackground,
      runAppWidget: () => runApp(
        MultiProvider(
          providers: buildAppProviders(),
          child: IbulMaterialApp(
            navigatorKey: GlobalKey<NavigatorState>(),
            includeAuthRoutes: true,
            navigatorObservers: [routeObserver, SeoRouteObserver()],
          ),
        ),
      ),
    );
    await _waitFor(tester, () => IbulGoRouterBinding.instance != null, 'router', 60);
    tester.view.physicalSize = const Size(1440, 1000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpFor(tester, const Duration(seconds: 2));

    final customer = Supabase.instance.client;
    final mall = MallAuthSession.instance;
    await mall.restore();
    _report['separate_client'] = '${!identical(mall.client, customer)}';

    if (_phase == 'restart') {
      await _restartChecks(tester, customer, mall);
      _dump();
      return;
    }

    if (!_hasAccounts) {
      await _landingWithoutMallSession(tester, mall);
      _report['dual_session'] = 'SKIPPED (no CUSTOMER_RT_* / MALL_RT_* defines)';
      _dump();
      return;
    }

    // A — customer login on the marketplace client.
    if (mall.isSignedIn) await mall.signOut();
    if (customer.auth.currentUser?.email != _customerEmail) {
      await AuthService().signInWithEmailPassword(_customerEmail, _customerPassword);
    }
    final customerId = customer.auth.currentUser?.id;
    _report['A_customer'] = '${customer.auth.currentUser?.email} uid=$customerId';
    await _landingWithoutMallSession(tester, mall);

    // B — AVM login through /avm/giris without a customer logout.
    await _go(tester, '/avm/giris');
    await _waitFor(tester, () => find.text('AVM Yönetici Girişi').evaluate().isNotEmpty, 'login');
    await tester.enterText(find.byKey(const Key('mall-login-email')), _mallEmail);
    await tester.enterText(find.byKey(const Key('mall-login-password')), _mallPassword);
    await tester.tap(find.byKey(const Key('mall-login-submit')));
    await _waitFor(tester, () => mall.isSignedIn, 'mall_sign_in', 30);
    await _waitFor(tester, () => _path() != '/avm/giris' || _visibleError() != null, 'destination', 30);
    final mallId = mall.currentUser?.id;
    _report['B_mall'] = '${mall.currentUser?.email} uid=$mallId';
    _report['B_customer_kept'] = '${customer.auth.currentUser?.email == _customerEmail}';
    _report['B_route'] = _path();
    if (_visibleError() != null) _report['B_login_message'] = _visibleError()!;

    // C — mall_members lookup runs as the AVM user.
    final memberships = await MallManagementRepository().myMemberships();
    _report['C_lookup_uid_is_mall'] = '${mallId != null && mallId != customerId}';
    _report['C_memberships'] = '${memberships.length}';

    // D — AVM logout keeps the customer.
    await mall.signOut();
    await _pumpFor(tester, const Duration(seconds: 1));
    _report['D_mall_null'] = '${mall.currentUser == null}';
    _report['D_customer_kept'] = '${customer.auth.currentUser?.email == _customerEmail}';

    // E — AVM login again; the restart run checks both restore.
    await mall.signIn(email: _mallEmail, password: _mallPassword);
    _report['E_relogin'] = '${mall.currentUser?.email == _mallEmail}';
    _report['E_customer_kept'] = '${customer.auth.currentUser?.email == _customerEmail}';
    _dump();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _restartChecks(WidgetTester tester, SupabaseClient customer, MallAuthSession mall) async {
  _report['E_restart_customer'] = '${customer.auth.currentUser?.email}';
  _report['E_restart_mall'] = '${mall.currentUser?.email}';
  _report['E_restart_distinct'] =
      '${customer.auth.currentUser?.id != null && customer.auth.currentUser?.id != mall.currentUser?.id}';
  await _go(tester, '/avm');
  await _waitFor(tester, () => find.byKey(const Key('mall-hub-account')).evaluate().isNotEmpty, 'hub_account');
  _report['E_restart_hub_account'] =
      tester.widget<Text>(find.byKey(const Key('mall-hub-account'))).data ?? '';
}

Future<void> _landingWithoutMallSession(WidgetTester tester, MallAuthSession mall) async {
  if (mall.isSignedIn) await mall.signOut();
  await _go(tester, '/avm');
  await _waitFor(tester, () => find.text('AVM Girişi').evaluate().isNotEmpty, 'hub');
  _report['landing_apply_button'] = '${find.text('AVM Başvurusu Yap').evaluate().isNotEmpty}';
  _report['landing_login_button'] = '${find.text('AVM Girişi').evaluate().isNotEmpty}';
  _report['landing_no_customer_notice'] =
      '${find.textContaining('Bu hesapla kayıtlı').evaluate().isEmpty && find.text(mallNoLinkedMallNotice).evaluate().isEmpty}';
  await tester.tap(find.text('AVM Girişi'));
  await _pumpFor(tester, const Duration(seconds: 1));
  _report['landing_login_route'] = _path();
  _report['login_page_fields'] =
      '${find.byKey(const Key('mall-login-email')).evaluate().isNotEmpty && find.byKey(const Key('mall-login-password')).evaluate().isNotEmpty}';
  _report['login_footer'] =
      '${find.text('Bu giriş yalnızca AVM yönetim hesabınız içindir.').evaluate().isNotEmpty}';
  await _go(tester, '/avm/yonetim');
  await _pumpFor(tester, const Duration(seconds: 2));
  _report['gate_without_mall_session'] = _path();
}

String? _visibleError() {
  for (final text in [mallNoLinkedMallNotice, 'E-posta veya şifre hatalı.']) {
    if (find.text(text).evaluate().isNotEmpty) return text;
  }
  return null;
}

String _path() => IbulGoRouterBinding.instance?.state.uri.path ?? '?';

Future<void> _go(WidgetTester tester, String path) async {
  IbulGoRouterBinding.instance!.go(path);
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _waitFor(WidgetTester tester, bool Function() done, String label, [int seconds = 15]) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  _dump();
  fail('timeout waiting for $label route=${_path()}');
}

void _dump() {
  _log('==== REPORT phase=$_phase ====');
  for (final entry in _report.entries) {
    _log('${entry.key}: ${entry.value}');
  }
}
