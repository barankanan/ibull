import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/admin/panel/widgets/system_layout_section.dart';
import 'package:ibul_app/features/coupon/domain/coupon_campaign.dart';
import 'package:ibul_app/features/coupon/domain/coupon_enums.dart';
import 'package:ibul_app/features/coupon/domain/coupon_helpers.dart';
import 'package:ibul_app/services/home_shortcuts_fetch.dart';
import 'package:ibul_app/widgets/feature_menu.dart';

CouponCampaign _coupon({
  bool isPublic = true,
  bool wheel = false,
  CouponApprovalStatus approval = CouponApprovalStatus.approved,
  bool paused = false,
  DateTime? startsAt,
  DateTime? endsAt,
  int? limit,
  int used = 0,
}) {
  final now = DateTime.utc(2026, 10, 1);
  return CouponCampaign(
    id: 'c1',
    name: 'Kupon',
    code: 'IBULTEST',
    sourceType: CouponSourceType.ibul,
    discountType: CouponDiscountType.percent,
    discountValue: 10,
    minOrderAmount: 0,
    startsAt: startsAt ?? now.subtract(const Duration(days: 1)),
    endsAt: endsAt ?? now.add(const Duration(days: 30)),
    approvalStatus: approval,
    scopeType: CouponScopeType.all,
    isPublic: isPublic,
    wheelEnabled: wheel,
    paused: paused,
    totalUsageLimit: limit,
    usedCount: used,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 1);

  group('couponDiscoveryBlockReason (list_discoverable_coupons ile aynı)', () {
    test('onaylı, tarihi geçerli, herkese açık kupon keşfedilebilir', () {
      expect(couponDiscoveryBlockReason(_coupon(), now: now), isNull);
    });

    test('çark, gizli, süresi dolmuş, kotası dolmuş kuponlar engellenir', () {
      expect(
        couponDiscoveryBlockReason(_coupon(wheel: true), now: now),
        contains('çark'),
      );
      expect(
        couponDiscoveryBlockReason(_coupon(isPublic: false), now: now),
        'Herkese açık değil',
      );
      expect(
        couponDiscoveryBlockReason(
          _coupon(endsAt: now.subtract(const Duration(days: 1))),
          now: now,
        ),
        'Süresi doldu',
      );
      expect(
        couponDiscoveryBlockReason(_coupon(limit: 5, used: 5), now: now),
        'Kota doldu',
      );
      expect(
        couponDiscoveryBlockReason(
          _coupon(approval: CouponApprovalStatus.pendingReview),
          now: now,
        ),
        'Onay bekliyor',
      );
    });
  });

  group('FeatureMenu.resolveConfigs', () {
    List<String> keys(List<Map<String, dynamic>> remote) =>
        FeatureMenu.resolveConfigs(remote).map((c) => c.key).toList();

    test('uzak kayıt yoksa mevcut mobil sıra korunur', () {
      expect(keys(const []), FeatureMenu.featureConfigs.map((c) => c.key));
    });

    test('kayıtlı sort_order sırası uygulanır, eksikler sona eklenir', () {
      final remote = HomeShortcutsFetch.sortShortcutRows([
        {'id': 1, 'category_key': 'yakin_lokasyon', 'sort_order': 2},
        {'id': 2, 'category_key': 'yapay_zeka', 'sort_order': 1},
      ]);
      final result = keys(remote);
      expect(result.take(2), ['yapay_zeka', 'yakin_lokasyon']);
      expect(result.length, FeatureMenu.featureConfigs.length);
    });

    test('isteğe bağlı kısayol yalnızca aktif kayıtla görünür', () {
      expect(
        keys([
          {'category_key': 'ibul_premium', 'is_active': false},
        ]),
        isNot(contains('ibul_premium')),
      );
      expect(
        keys([
          {'category_key': 'ibul_premium', 'is_active': true},
        ]),
        contains('ibul_premium'),
      );
    });
  });

  testWidgets('bölüm başlığı dar ve geniş pencerede taşmaz', (tester) async {
    for (final width in [360.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
            body: SystemLayoutSectionHeader(
              title: 'Kategoriler ve Alt Kategoriler çok uzun bir başlık',
              subtitle: 'Uzun açıklama ' * 10,
              liveNote: 'Canlı etkisi açıklaması ' * 6,
              secondaryActions: [
                OutlinedButton(onPressed: () {}, child: const Text('Yenile')),
              ],
              primaryAction: FilledButton(
                onPressed: () {},
                child: const Text('Yeni Kategori'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final primary = tester.getRect(find.text('Yeni Kategori'));
      expect(primary.right, lessThanOrEqualTo(width));
    }
    addTearDown(tester.view.reset);
  });
}
