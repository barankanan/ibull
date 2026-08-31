import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Production-flow wiring doğrulaması — canlı Supabase gerektirmez.
void main() {
  final root = Directory.current.path.endsWith('ibul_app')
      ? Directory.current.path
      : '${Directory.current.path}/ibul_app';

  String read(String relative) =>
      File('$root/$relative').readAsStringSync();

  test('1) landing Giriş Yap → IhizCourierLoginPage, not consumer LoginPage', () {
    final landing = read('lib/screens/ihiz_courier_page.dart');
    expect(landing, contains('IhizCourierLoginPage'));
    expect(landing, contains('onLogin: _openLogin'));
    expect(landing, isNot(contains('HomeLazyRoutes.openLogin')));
    expect(landing.contains('builder: (_) => const LoginPage('), isFalse);
  });

  test('2) login auth + approval gate uses real table/status', () {
    final auth = read('lib/services/ihiz_courier_auth_service.dart');
    expect(auth, contains('signInWithPassword'));
    expect(auth, contains("from('ihiz_courier_applications')"));
    expect(auth, contains("approvedStatus = 'approved'"));
  });

  test('3) pool only ready_to_ship / return_approved; preparing excluded', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(
      dash,
      contains(".inFilter('status', const ['ready_to_ship', 'return_approved'])"),
    );
    expect(dash, contains("itemStatus != 'ready_to_ship'"));
    expect(dash, contains("itemStatus != 'return_approved'"));
    expect(dash, contains('preparing/pending/created'));
    expect(dash, isNot(contains(".inFilter('status', const ['preparing'")));
  });

  test('4) Home/Map share _courierPoolOrders source of truth', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains('List<_CourierPoolOrder> _courierPoolOrders'));
    expect(dash, contains('List<_RegisteredStoreData> get _registeredStores'));
    expect(dash, contains('List<_OrderCardData> get _orders'));
    expect(dash, contains('_buildOrderPool'));
    expect(dash, contains('_buildMapOnlyScreen'));
  });

  test('5) claim awaits mutation + status precondition', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains('Future<bool> _markOrderAsPickedUp'));
    expect(dash, contains("final claimed = await _markOrderAsPickedUp"));
    expect(dash, contains(".eq('status', 'ready_to_ship')"));
    expect(
      dash,
      contains('Bu görev artık başka bir kurye tarafından alındı.'),
    );
  });

  test('6) delivery complete resets pool; no SharedPreferences earnings SoT', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains('_resetDeliveryFlow()'));
    expect(dash, contains('_completeDeliveryInFlight'));
    expect(dash, contains('.eq(\'status\', \'out_for_delivery\')'));
    expect(dash, isNot(contains('_recordCompletedDelivery')));
    expect(dash, isNot(contains('_loadCompletedDeliveryStats')));
    expect(dash, isNot(contains('_dailyEarnings')));
    expect(dash, contains('_clearLegacyLocalEarningsCache'));
    expect(dash, contains('Sunucu kazanç kaydı henüz yok'));
  });

  test('7) no fake KPI / name / rating', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, isNot(contains("'₺842'")));
    expect(dash, isNot(contains('Puan 4.9')));
    expect(dash, isNot(contains('Baran Yılmaz')));
    expect(dash, isNot(contains('Tepebaşı / Eskişehir')));
    expect(dash, contains("'—'"));
  });

  test('8) realtime + pull-to-refresh + lifecycle', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains("from('order_items')"));
    expect(dash, contains('.stream(primaryKey:'));
    expect(dash, contains('_schedulePoolFetch'));
    expect(dash, contains('RefreshIndicator'));
    expect(dash, contains('didChangeAppLifecycleState'));
    expect(dash, contains('WidgetsBindingObserver'));
  });

  test('9) empty/error/loading states', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains('_poolLoadError'));
    expect(dash, contains('Tekrar dene'));
    expect(dash, contains('Şu anda uygun teslimat görevi yok.'));
    expect(dash, contains('_friendlyDataError'));
  });

  test('10) mobile bottom nav intact', () {
    final dash =
        read('lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart');
    expect(dash, contains("label: 'Ana Sayfa'"));
    expect(dash, contains("label: 'Harita'"));
    expect(dash, contains("label: 'Hesabım'"));
  });
}
