import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/admin/panel/models/admin_menu_registry.dart';
import 'package:ibul_app/features/ihiz/business/ihiz_business_admin_page.dart';
import 'package:ibul_app/features/ihiz/business/ihiz_business_link_page.dart';
import 'package:ibul_app/features/ihiz/business/ihiz_business_ops_panel.dart';
import 'package:ibul_app/features/ihiz/delivery/ihiz_business_serial.dart';
import 'package:ibul_app/features/ihiz/ihiz_landing_body.dart';
import 'package:ibul_app/features/ihiz/shell/ihiz_footer.dart';
import 'package:ibul_app/features/ihiz/theme/ihiz_brand.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:ibul_app/services/ihiz_business_account_service.dart';

class _FakeBusinessService extends IhizBusinessAccountService {
  _FakeBusinessService({
    this.lookup,
    this.linked,
    this.ops,
  });

  Map<String, dynamic>? lookup;
  Map<String, dynamic>? linked;
  Map<String, dynamic>? ops;
  int lookups = 0;
  int signIns = 0;

  @override
  Future<Map<String, dynamic>> lookupBySerial(String serial) async {
    lookups += 1;
    return lookup ?? const {'found': false, 'error': 'not_found'};
  }

  @override
  Future<Map<String, dynamic>> signInAndLink({
    required String serial,
    required String email,
    required String password,
    AuthService? auth,
  }) async {
    signIns += 1;
    if (email != 'owner@example.com' || password != 'secret') {
      throw Exception('invalid login credentials');
    }
    if (!IhizBusinessSerial.canLink(
      storeSellerId: 'store-1',
      authUserId: 'store-1',
    )) {
      throw Exception('store_forbidden');
    }
    return linked ??
        {
          'ok': true,
          'store_id': 'store-1',
          'status': 'active',
        };
  }

  @override
  Future<Map<String, dynamic>> listOps({String? storeId}) async {
    return ops ??
        {
          'ok': true,
          'stores': [
            {
              'store_id': storeId ?? 'store-1',
              'business_name': 'Demo Cafe',
              'serial': 'ISL-AB34CD',
              'status': 'active',
              'incoming_count': 1,
              'outgoing_count': 1,
              'sent_count': 1,
              'active_count': 2,
              'courier_count': 1,
              'incoming': [
                {
                  'tracking_code': 'IHZ-AAAA11',
                  'status': 'created',
                  'pickup_name': 'Müşteri',
                  'dropoff_name': 'Demo Cafe',
                },
              ],
              'outgoing': [
                {
                  'tracking_code': 'IHZ-BBBB22',
                  'status': 'ready_for_pickup',
                  'pickup_name': 'Demo Cafe',
                  'dropoff_name': 'Alıcı',
                },
              ],
              'sent': [
                {
                  'tracking_code': 'IHZ-CCCC33',
                  'status': 'in_transit',
                  'pickup_name': 'Demo Cafe',
                  'dropoff_name': 'Paket alıcı',
                },
              ],
              'active': [
                {
                  'tracking_code': 'IHZ-BBBB22',
                  'status': 'ready_for_pickup',
                  'pickup_name': 'Demo Cafe',
                  'dropoff_name': 'Alıcı',
                },
              ],
              'couriers': [
                {'full_name': 'Ayşe Kurye', 'city': 'Eskişehir', 'is_active': true},
              ],
            },
          ],
        };
  }
}

void main() {
  String repoFile(String relative) {
    final root = Directory.current.path.endsWith('ibul_app')
        ? Directory.current.path
        : '${Directory.current.path}/ibul_app';
    return File('$root/$relative').readAsStringSync();
  }

  test('business serial format', () {
    expect(IhizBusinessSerial.isValid('ISL-AB34CD'), isTrue);
    expect(IhizBusinessSerial.normalize('isl-ab34cd'), 'ISL-AB34CD');
    expect(IhizBusinessSerial.isValid('IHZ-AB34CD'), isFalse);
    expect(IhizBusinessSerial.isValid('ISL-IO01AB'), isFalse);
    expect(IhizBusinessSerial.canLink(storeSellerId: 'a', authUserId: 'a'), isTrue);
    expect(IhizBusinessSerial.canLink(storeSellerId: 'a', authUserId: 'b'), isFalse);
  });

  test('link errors stay owner-proven', () {
    expect(
      IhizBusinessAccountService.describeError(Exception('store_forbidden')),
      'Bu işletme bu hesaba ait değil.',
    );
    expect(
      IhizBusinessAccountService.describeError(Exception('invalid login')),
      'E-posta veya şifre hatalı.',
    );
    expect(
      IhizBusinessAccountService.describeError(
        Exception(
          'PostgresException(message: Could not find the function public.ensure_store_business_serial_no without parameters in the schema cache, code: PGRST202)',
        ),
      ),
      'İHIZ işletme kaydı henüz hazır değil. Lütfen daha sonra tekrar deneyin.',
    );
  });

  test('SQL serial is not a public stores column', () {
    final sql = repoFile(
      'supabase/migrations/20260826_ihiz_business_serial_link.sql',
    );
    expect(sql, contains('create table if not exists public.store_business_serials'));
    expect(sql, contains('lookup_store_by_business_serial'));
    expect(sql, contains('link_ihiz_business_by_serial'));
    expect(sql, contains('ensure_store_business_serial_no'));
    expect(sql, contains('p_store_id uuid'));
    expect(sql, contains('list_ihiz_business_ops'));
    expect(sql, contains('store_forbidden'));
    expect(sql, contains("'found', true"));
    expect(sql, isNot(contains("'seller_id', v_store_id")));
    expect(sql, isNot(contains('alter table public.stores')));
    expect(sql.contains('local_print_bridge'), isFalse);
    final dart = repoFile('lib/services/ihiz_business_account_service.dart');
    expect(dart, contains("'p_store_id': storeId.trim()"));
    expect(dart.contains("rpc('ensure_store_business_serial_no')"), isFalse);
  });

  test('admin menus expose business ops', () {
    expect(
      ihizAdminMenuDefinitions.map((item) => item.title),
      contains('İşletme Teslimatları'),
    );
    expect(
      ibulAdminMenuDefinitions.map((item) => item.title),
      contains('İHIZ Teslimatları'),
    );
  });

  testWidgets('landing has işletme bağla field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: IhizLandingBody(
                onLogin: () {},
                onCourierApply: () {},
                onBusinessJoin: () {},
                onBindBusiness: (_) {},
                onPackageSend: () {},
                onSubmitTracking: (_) {},
                howItWorksKey: GlobalKey(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İşletme bağla'), findsWidgets);
    expect(find.text('İşletmeyi Bul'), findsOneWidget);
    expect(find.text('İşletme Olarak Kullan'), findsWidgets);
  });

  testWidgets('short IHIZ page pins footer to the viewport bottom', (
    tester,
  ) async {
    const size = Size(1280, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: size),
        child: MaterialApp(
          home: IhizBusinessLinkPage(service: _FakeBusinessService()),
        ),
      ),
    );
    await tester.pump();

    final footer = tester.getRect(find.byType(IhizFooter));
    expect(footer.bottom, greaterThanOrEqualTo(size.height - 1));
    expect(footer.width, closeTo(size.width, 0.5));
    expect(footer.top, lessThan(size.height));
    expect(footer.top, greaterThan(size.height * 0.35));
  });

  testWidgets('link page finds then requires business login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeBusinessService(
      lookup: {
        'found': true,
        'business_name': 'Demo Cafe',
        'city': 'Eskişehir',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IhizBusinessLinkPage(
          initialSerial: 'ISL-AB34CD',
          service: service,
        ),
        routes: {
          '/ihiz': (_) => const Scaffold(body: Text('LANDING')),
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.lookups, 1);
    expect(find.textContaining('Demo Cafe'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'owner@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret');
    await tester.ensureVisible(find.text('İşletmeyi Bağla'));
    await tester.tap(find.text('İşletmeyi Bağla'));
    await tester.pump();
    await tester.pump();
    expect(service.signIns, 1);
    expect(find.byType(IhizBusinessAdminPage), findsOneWidget);
  });

  testWidgets('ops panel shows incoming outgoing sent and couriers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IhizBusinessOpsPanel(
              store: {
                'store_id': 'store-1',
                'business_name': 'Demo Cafe',
                'serial': 'ISL-AB34CD',
                'status': 'active',
                'incoming_count': 1,
                'outgoing_count': 1,
                'sent_count': 1,
                'active_count': 1,
                'courier_count': 1,
                'incoming': [
                  {
                    'tracking_code': 'IHZ-AAAA11',
                    'status': 'created',
                    'pickup_name': 'Müşteri',
                    'dropoff_name': 'Demo Cafe',
                  },
                ],
                'outgoing': [
                  {
                    'tracking_code': 'IHZ-BBBB22',
                    'status': 'ready_for_pickup',
                    'pickup_name': 'Demo Cafe',
                    'dropoff_name': 'Alıcı',
                  },
                ],
                'sent': [
                  {
                    'tracking_code': 'IHZ-CCCC33',
                    'status': 'in_transit',
                    'pickup_name': 'Demo Cafe',
                    'dropoff_name': 'Paket alıcı',
                  },
                ],
                'active': [],
                'couriers': [
                  {
                    'full_name': 'Ayşe Kurye',
                    'city': 'Eskişehir',
                    'is_active': true,
                  },
                ],
              },
              stores: [
                {
                  'store_id': 'store-1',
                  'business_name': 'Demo Cafe',
                },
              ],
              selectedStoreId: 'store-1',
              onOpenCouriers: _noop,
              onRefresh: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gelen paketler'), findsOneWidget);
    expect(find.text('Çıkan paketler'), findsOneWidget);
    expect(find.text('Gönderilen paketler'), findsOneWidget);
    expect(find.text('Kurye işlemleri'), findsOneWidget);
    expect(find.text('IHZ-AAAA11'), findsOneWidget);
    expect(find.text('IHZ-BBBB22'), findsOneWidget);
    expect(find.text('IHZ-CCCC33'), findsOneWidget);
    expect(find.textContaining('Ayşe Kurye'), findsOneWidget);
  });

  testWidgets('embedded admin loads ops from service', (tester) async {
    final service = _FakeBusinessService();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: IhizBrand.contentMaxWidth,
          child: IhizBusinessAdminPage(
            storeId: 'store-1',
            embedded: true,
            service: service,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('İşletme teslimatları'), findsOneWidget);
    expect(find.text('Çıkan paketler'), findsOneWidget);
    expect(find.textContaining('Demo Cafe'), findsWidgets);
  });
}

void _noop() {}
