import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/widgets/lan_paired_devices_section.dart';

void main() {
  final now = DateTime.utc(2026, 5, 1, 12);
  final devices = <LanDeviceInfo>[
    LanDeviceInfo(
      deviceId: 'aaaaaaaa11112222',
      staffId: 'staff-1-long-id',
      pairedAt: now.subtract(const Duration(days: 2)),
      revoked: false,
      deviceName: 'Garson iPhone uzun bir cihaz adı örneği burada',
      platform: 'ios',
      lastSeenAt: now.subtract(const Duration(seconds: 30)),
    ),
    LanDeviceInfo(
      deviceId: 'bbbbbbbb33334444',
      staffId: 'staff-2',
      pairedAt: now.subtract(const Duration(days: 3)),
      revoked: false,
      platform: 'android',
      expiresAt: now.subtract(const Duration(hours: 1)),
    ),
    LanDeviceInfo(
      deviceId: 'cccccccc55556666',
      staffId: 'staff-3',
      pairedAt: now.subtract(const Duration(days: 4)),
      revoked: true,
      platform: 'macos',
    ),
    LanDeviceInfo(
      deviceId: 'dddddddd77778888',
      staffId: 'staff-4',
      pairedAt: now.subtract(const Duration(days: 4)),
      revoked: false,
      platform: 'ios',
      lastSeenAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required bool canManage,
    List<LanDeviceInfo>? list,
    Future<bool> Function(String)? revoke,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LanPairedDevicesSection(
              loadDevices: () => list ?? devices,
              revoke: revoke,
              canManageDevices: canManage,
              staffNames: const {'staff-1-long-id': 'Ayşe Garson'},
              hubAddress: () => '192.168.10.67:18772',
              clock: () => now,
            ),
          ),
        ),
      ),
    );
  }

  test('status rules', () {
    expect(lanDeviceStatus(devices[0], now), LanDeviceStatus.active);
    expect(lanDeviceStatus(devices[1], now), LanDeviceStatus.expired);
    expect(lanDeviceStatus(devices[2], now), LanDeviceStatus.revoked);
    expect(lanDeviceStatus(devices[3], now), LanDeviceStatus.offline);
  });

  testWidgets('lists devices at 390 wide without overflow', (tester) async {
    await pump(tester, canManage: false);
    expect(find.text('Bağlı Cihazlar'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Yetki süresi dolmuş'), findsOneWidget);
    expect(find.text('İptal edildi'), findsOneWidget);
    expect(find.text('Bağlantı yok'), findsOneWidget);
    expect(find.text('Ayşe Garson'), findsOneWidget);
    expect(find.text('staff-2'), findsOneWidget);
    expect(find.text('iPhone'), findsWidgets);
    expect(find.text('aaaaaaaa'), findsOneWidget);
    expect(find.text('192.168.10.67:18772'), findsNWidgets(devices.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout has no overflow', (tester) async {
    await pump(tester, canManage: true, width: 1200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only without permission and empty state', (tester) async {
    await pump(tester, canManage: false);
    expect(find.text('Bağlantıyı iptal et'), findsNothing);
    await pump(tester, canManage: false, list: const <LanDeviceInfo>[]);
    expect(find.text('Henüz eşleştirilmiş cihaz yok'), findsOneWidget);
  });

  testWidgets('revoke asks first and calls back only after confirmation', (tester) async {
    final revoked = <String>[];
    await pump(
      tester,
      canManage: true,
      revoke: (id) async {
        revoked.add(id);
        return true;
      },
    );
    // Revoked devices have no button: three of four remain.
    expect(find.text('Bağlantıyı iptal et'), findsNWidgets(3));
    final button = find.byKey(const Key('lan_device_revoke_aaaaaaaa11112222'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı iptal edilsin mi?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lan_device_revoke_cancel')));
    await tester.pumpAndSettle();
    expect(revoked, isEmpty);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lan_device_revoke_confirm')));
    await tester.pumpAndSettle();
    expect(revoked, <String>['aaaaaaaa11112222']);
    expect(find.text('Bağlantı iptal edildi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
