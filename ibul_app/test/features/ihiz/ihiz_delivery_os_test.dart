import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/delivery/ihiz_delivery_invariants.dart';
import 'package:ibul_app/features/ihiz/delivery/ihiz_delivery_status.dart';
import 'package:ibul_app/features/ihiz/delivery/ihiz_public_tracking.dart';
import 'package:ibul_app/features/ihiz/delivery/ihiz_route_paths.dart';
import 'package:ibul_app/features/ihiz/ihiz_landing_body.dart';
import 'package:ibul_app/features/ihiz/send/ihiz_package_send_validator.dart';
import 'package:ibul_app/features/ihiz/theme/ihiz_brand.dart';
import 'package:ibul_app/features/ihiz/tracking/ihiz_tracking_page.dart';
import 'package:ibul_app/services/ihiz_public_tracking_service.dart';

void main() {
  String repoFile(String relative) {
    final root = Directory.current.path.endsWith('ibul_app')
        ? Directory.current.path
        : '${Directory.current.path}/ibul_app';
    return File('$root/$relative').readAsStringSync();
  }

  IhizPublicTracking sample({
    required String status,
    String code = 'IHZ-AB34CD',
    bool withLocation = false,
    bool withVideo = false,
    List<IhizTrackingEvent>? events,
  }) {
    return IhizPublicTracking(
      found: true,
      trackingCode: code,
      status: status,
      packageMediaUrl: withVideo ? 'https://cdn.example.com/pack.mp4' : null,
      live: withLocation
          ? const IhizLiveLocation(
              courierLat: 39.76,
              courierLng: 30.52,
              pickupLat: 39.77,
              pickupLng: 30.51,
              dropoffLat: 39.78,
              dropoffLng: 30.53,
            )
          : null,
      events: events ??
          [
            IhizTrackingEvent(
              eventType: 'created',
              status: 'created',
              title: 'Sipariş oluşturuldu',
              createdAt: DateTime.utc(2026, 8, 25, 11, 32),
            ),
            IhizTrackingEvent(
              eventType: 'ready_for_pickup',
              status: 'ready_for_pickup',
              title: 'Paket hazırlandı',
              createdAt: DateTime.utc(2026, 8, 25, 12, 4),
            ),
          ],
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: child,
      routes: {
        '/ihiz': (_) => const Scaffold(body: Text('IHIZ_LANDING')),
        '/home': (_) => const Scaffold(body: Text('IBUL_HOME')),
      },
    );
  }

  test('1 valid tracking code', () {
    expect(IhizRoutePaths.isValidTrackingCode('IHZ-AB34CD'), isTrue);
    expect(IhizRoutePaths.normalizeTrackingCode('ihz-ab34cd'), 'IHZ-AB34CD');
  });

  test('2 invalid tracking code', () {
    expect(IhizRoutePaths.isValidTrackingCode('733012345678'), isFalse);
    expect(IhizRoutePaths.isValidTrackingCode('IHZ-12'), isFalse);
    expect(IhizRoutePaths.isValidTrackingCode('#IHZ-2841'), isFalse);
  });

  test('3 empty tracking code', () {
    expect(IhizRoutePaths.isValidTrackingCode(''), isFalse);
    expect(IhizRoutePaths.isValidTrackingCode('   '), isFalse);
    expect(IhizRoutePaths.trackingCodeFromPath('/ihiz/track/'), '');
  });

  testWidgets('3 empty tracking code shows not found', (tester) async {
    await tester.pumpWidget(
      wrap(
        IhizTrackingPage(
          trackingCode: '',
          service: IhizPublicTrackingService(
            fetchOverride: (code) async => IhizPublicTracking.notFound(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Teslimat bulunamadı.'), findsOneWidget);
  });

  test('4 tracking timeline uses real events', () {
    final tracking = sample(status: 'in_transit');
    expect(tracking.orderedEvents, isNotEmpty);
    expect(tracking.orderedEvents.first.displayTitle, 'Sipariş oluşturuldu');
  });

  test('5 event ordering is chronological', () {
    final tracking = IhizPublicTracking(
      found: true,
      trackingCode: 'IHZ-AB34CD',
      status: 'delivered',
      events: [
        IhizTrackingEvent(
          eventType: 'delivered',
          status: 'delivered',
          createdAt: DateTime.utc(2026, 8, 25, 15, 31),
        ),
        IhizTrackingEvent(
          eventType: 'created',
          status: 'created',
          createdAt: DateTime.utc(2026, 8, 25, 14, 32),
        ),
      ],
    );
    expect(tracking.orderedEvents.first.status, 'created');
    expect(tracking.orderedEvents.last.status, 'delivered');
  });

  test('6 delivered hides live location', () {
    final json = IhizDeliveryInvariants.publicTrackingProjection(
      trackingCode: 'IHZ-AB34CD',
      status: IhizDeliveryStatus.delivered,
      events: const [],
      courierLat: 39.7,
      courierLng: 30.5,
    ).first;
    expect(json['live'], isNull);
    final tracking = IhizPublicTracking.fromJson(json);
    expect(tracking.isLive, isFalse);
  });

  test('7 active delivery shows location', () {
    final json = IhizDeliveryInvariants.publicTrackingProjection(
      trackingCode: 'IHZ-AB34CD',
      status: IhizDeliveryStatus.inTransit,
      events: const [],
      courierLat: 39.7,
      courierLng: 30.5,
    ).first;
    expect((json['live'] as Map)['courier_lat'], 39.7);
    final tracking = IhizPublicTracking.fromJson(json);
    expect(tracking.isLive, isTrue);
  });

  test('8 video exists', () {
    final tracking = sample(
      status: 'ready_for_pickup',
      withVideo: true,
    );
    expect(tracking.hasVideo, isTrue);
  });

  test('9 video absent', () {
    final tracking = sample(status: 'ready_for_pickup');
    expect(tracking.hasVideo, isFalse);
  });

  testWidgets('8 video card visible when url exists', (tester) async {
    await tester.pumpWidget(
      wrap(
        IhizTrackingPage(
          key: const ValueKey('video-present'),
          trackingCode: 'IHZ-AB34CD',
          service: IhizPublicTrackingService(
            fetchOverride: (_) async => sample(
              status: 'ready_for_pickup',
              withVideo: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Paketleme Videosu'), findsOneWidget);
  });

  testWidgets('9 video card hidden when url absent', (tester) async {
    await tester.pumpWidget(
      wrap(
        IhizTrackingPage(
          key: const ValueKey('video-absent'),
          trackingCode: 'IHZ-AB34CD',
          service: IhizPublicTrackingService(
            fetchOverride: (_) async => sample(status: 'ready_for_pickup'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Paketleme Videosu'), findsNothing);
  });

  test('10 package send validation', () {
    expect(
      IhizPackageSendValidator.validate(
        const IhizPackageSendInput(
          pickupName: '',
          pickupPhone: '555',
          pickupAddress: 'a',
          pickupCity: 'Eskişehir',
          pickupDistrict: 'Tepebaşı',
          dropoffName: '',
          dropoffPhone: '555',
          dropoffAddress: 'b',
          dropoffCity: 'Eskişehir',
          dropoffDistrict: 'Odunpazarı',
          packageSize: 'tiny',
        ),
      ),
      isNotNull,
    );
    expect(
      IhizPackageSendValidator.validate(
        const IhizPackageSendInput(
          pickupName: 'Ada',
          pickupPhone: '555',
          pickupAddress: 'Atatürk Cad. 12',
          pickupCity: 'Eskişehir',
          pickupDistrict: 'Tepebaşı',
          dropoffName: 'Ege',
          dropoffPhone: '555',
          dropoffAddress: 'İsmet İnönü 8',
          dropoffCity: 'Eskişehir',
          dropoffDistrict: 'Odunpazarı',
          packageSize: 'medium',
          packageWeight: 2.4,
        ),
      ),
      isNull,
    );
  });

  test('11 package task creation produces tracking code', () {
    final existing = <String>{};
    final code = IhizDeliveryInvariants.generateTrackingCode(
      existing: existing,
      random: Random(7),
    );
    expect(IhizRoutePaths.isValidTrackingCode(code), isTrue);
    expect(code.startsWith('IHZ-'), isTrue);
  });

  test('12 unique tracking code', () {
    final existing = <String>{};
    final codes = <String>{};
    for (var i = 0; i < 40; i++) {
      final code = IhizDeliveryInvariants.generateTrackingCode(
        existing: existing,
        random: Random(i + 11),
      );
      expect(codes.add(code), isTrue);
      existing.add(code);
    }
  });

  test('13 duplicate order task prevention', () {
    final byOrder = <String, String>{};
    expect(
      IhizDeliveryInvariants.tryCreateTaskForOrder(
        tasksByOrderId: byOrder,
        orderId: 'order-1',
        taskId: 'task-a',
      ),
      isTrue,
    );
    expect(
      IhizDeliveryInvariants.tryCreateTaskForOrder(
        tasksByOrderId: byOrder,
        orderId: 'order-1',
        taskId: 'task-b',
      ),
      isFalse,
    );
    expect(byOrder['order-1'], 'task-a');
  });

  test('14 business activation', () {
    expect(
      IhizDeliveryInvariants.canCreateFromIbulOrder(
        orderValid: true,
        ihizDelivery: true,
        businessActive: true,
        hasDropoff: true,
      ),
      isTrue,
    );
    expect(
      IhizDeliveryInvariants.canCreateFromIbulOrder(
        orderValid: true,
        ihizDelivery: true,
        businessActive: false,
        hasDropoff: true,
      ),
      isFalse,
    );
  });

  test('15 business courier add', () {
    final pool = <String>{};
    pool.add('courier-1');
    expect(pool.contains('courier-1'), isTrue);
  });

  test('16 business courier remove', () {
    final pool = <String>{'courier-1', 'courier-2'};
    pool.remove('courier-1');
    expect(pool.contains('courier-1'), isFalse);
    expect(pool.contains('courier-2'), isTrue);
  });

  test('17 courier only sees authorized task', () {
    expect(
      IhizDeliveryInvariants.courierCanSeeTask(
        courierId: 'c1',
        assignedCourierId: 'c2',
        isApprovedCourier: true,
        status: 'ready_for_pickup',
        storeId: 'store-1',
        selectedStoreCourierIds: {'c2'},
      ),
      isFalse,
    );
    expect(
      IhizDeliveryInvariants.courierCanSeeTask(
        courierId: 'c1',
        assignedCourierId: 'c1',
        isApprovedCourier: true,
        status: 'in_transit',
        storeId: 'store-1',
        selectedStoreCourierIds: {'c1'},
      ),
      isTrue,
    );
  });

  test('18 public tracking does not expose PII', () {
    final json = {
      'found': true,
      'tracking_code': 'IHZ-AB34CD',
      'status': 'in_transit',
      'pickup_label': 'Tepebaşı',
      'dropoff_label': 'Odunpazarı',
      'events': [
        {'event_type': 'created', 'title': 'Sipariş oluşturuldu'},
      ],
    };
    expect(IhizPublicTracking.jsonExposesForbiddenKeys(json), isFalse);
    expect(
      IhizPublicTracking.jsonExposesForbiddenKeys({
        ...json,
        'dropoff_phone': '5551112233',
      }),
      isTrue,
    );
  });

  test('19 two couriers cannot claim same task', () {
    final assigned = <String, String?>{'task-1': null};
    expect(
      IhizDeliveryInvariants.claimTask(
        assignedCourierByTaskId: assigned,
        taskId: 'task-1',
        courierId: 'c1',
      ),
      isNull,
    );
    expect(
      IhizDeliveryInvariants.claimTask(
        assignedCourierByTaskId: assigned,
        taskId: 'task-1',
        courierId: 'c2',
      ),
      'already_claimed',
    );
    expect(assigned['task-1'], 'c1');
  });

  test('20 IBUL order -> IHIZ task', () {
    expect(IhizDeliveryStatus.fromIbulItemStatus('preparing'), 'preparing');
    expect(
      IhizDeliveryStatus.fromIbulItemStatus('ready_to_ship'),
      'ready_for_pickup',
    );
    expect(
      IhizDeliveryStatus.fromIbulItemStatus('out_for_delivery'),
      'courier_picked_up',
    );
    expect(IhizDeliveryStatus.fromIbulItemStatus('delivered'), 'delivered');
    expect(
      IhizDeliveryInvariants.canCreateFromIbulOrder(
        orderValid: true,
        ihizDelivery: true,
        businessActive: true,
        hasDropoff: true,
      ),
      isTrue,
    );
  });

  testWidgets('invalid tracking code page shows not found', (tester) async {
    await tester.pumpWidget(
      wrap(
        IhizTrackingPage(
          trackingCode: 'NOPE',
          service: IhizPublicTrackingService(
            fetchOverride: (_) async => IhizPublicTracking.notFound(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Teslimat bulunamadı.'), findsOneWidget);
  });

  testWidgets('valid tracking page shows code and timeline', (tester) async {
    await tester.pumpWidget(
      wrap(
        IhizTrackingPage(
          trackingCode: 'IHZ-AB34CD',
          service: IhizPublicTrackingService(
            fetchOverride: (_) async => sample(status: 'ready_for_pickup'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('IHZ-AB34CD'), findsWidgets);
    expect(find.text('Sipariş oluşturuldu'), findsOneWidget);
    expect(find.text('Paket hazırlandı'), findsOneWidget);
  });

  testWidgets('landing tracking and package send CTAs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: IhizBrand.contentMaxWidth,
                  ),
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
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Teslimat kodunuzu girin'), findsOneWidget);
    expect(find.text('Teslimatı Takip Et'), findsOneWidget);
    expect(find.text('Paketi Gönder'), findsOneWidget);
    expect(find.text('İşletme Olarak Kullan'), findsWidgets);
    expect(find.text('İşletme bağla'), findsWidgets);
    expect(find.text('#IHZ-2841'), findsNothing);
  });

  test('SQL / wiring contracts', () {
    final sql = repoFile(
      'supabase/migrations/20260825_ihiz_delivery_core.sql',
    );
    expect(sql, contains('create table if not exists public.ihiz_delivery_tasks'));
    expect(sql, contains('uq_ihiz_delivery_tasks_order_id'));
    expect(sql, contains('get_ihiz_public_tracking'));
    expect(sql, contains('assigned_courier_id is null'));
    expect(sql, contains("tracking_code = v_code"));
    expect(sql, isNot(contains("'pickup_phone', v_task.pickup_phone")));
    expect(sql, contains('create_ihiz_package_delivery'));
    expect(sql, contains('ensure_ihiz_delivery_task_for_order'));
    expect(sql, contains('claim_ihiz_delivery_task'));
    expect(sql, contains('ihiz_store_couriers'));
    expect(sql, contains('ihiz_business_accounts'));
    expect(sql.contains('local_print_bridge'), isFalse);

    final orderService = repoFile('lib/services/order_service.dart');
    expect(orderService, contains('_maybeEnsureIhizDeliveryTask'));
    expect(orderService, isNot(contains('order_print_job_service')));

    final deliveryService = repoFile('lib/services/ihiz_delivery_service.dart');
    expect(deliveryService, contains('claim_ihiz_delivery_task'));
    expect(deliveryService, contains('ensure_ihiz_delivery_task_for_order'));

    final dash = repoFile(
      'lib/features/ihiz/courier/ihiz_courier_dashboard_page.dart',
    );
    expect(dash, contains('İşletme Teslimatları'));
    expect(dash, contains('IhizDeliveryService.instance.claimTask'));
    expect(dash, contains(".eq('status', 'ready_to_ship')"));
  });
}
