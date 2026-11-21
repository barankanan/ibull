import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/features/seller/staff/staff_permission_summary.dart';
import 'package:ibul_app/models/sub_admin.dart';

StaffPageLevelPlan _plan(SellerModule m) =>
    staffPageLevelPlan(m, pageFullAccessOperations(m));

void main() {
  group('sayfa düzeyleri', () {
    test('Garson: yok / görüntüle / tam yönetim', () {
      final plan = _plan(SellerModule.garson);
      expect(plan.levels, [
        StaffPageLevel.none,
        StaffPageLevel.view,
        StaffPageLevel.full,
      ]);
      expect(plan.opsFor(StaffPageLevel.view), {SellerPermission.viewOrders});
      expect(
        plan.opsFor(StaffPageLevel.full),
        containsAll(<SellerPermission>{
          SellerPermission.manageOrders,
          SellerPermission.closeBill,
          SellerPermission.transferTable,
        }),
      );
    });

    test('Ürünler: salt-okunur sunucu izni yok, Görüntüle sunulmaz', () {
      final plan = _plan(SellerModule.products);
      expect(plan.levels, [StaffPageLevel.none, StaffPageLevel.full]);
    });

    test('Genel Bakış: tam yönetim görüntülemeye eşit, yalnız Görüntüle', () {
      final plan = _plan(SellerModule.dashboard);
      expect(plan.levels, [StaffPageLevel.none, StaffPageLevel.view]);
      expect(plan.opsFor(StaffPageLevel.view), {SellerPermission.viewOrders});
    });

    test('Sistem tam yönetimi yazıcı ve masa düzenini verir, ödeme vermez', () {
      final ops = _plan(SellerModule.system).opsFor(StaffPageLevel.full);
      expect(ops, contains(SellerPermission.managePrintSettings));
      expect(ops, contains(SellerPermission.manageTables));
      expect(ops, isNot(contains(SellerPermission.closeBill)));
      expect(ops, isNot(contains(SellerPermission.manageStaff)));
    });

    test('geçerli düzey seçili izinlerden hesaplanır', () {
      final plan = _plan(SellerModule.garson);
      StaffPageLevel level(Set<SellerPermission> s, {bool visible = true}) =>
          staffCurrentPageLevel(
            plan: plan,
            pageVisible: visible,
            selected: s,
          );
      expect(level({}, visible: false), StaffPageLevel.none);
      expect(level({SellerPermission.viewOrders}), StaffPageLevel.view);
      expect(level(plan.fullOps), StaffPageLevel.full);
      expect(
        level({SellerPermission.viewOrders, SellerPermission.manageOrders}),
        StaffPageLevel.custom,
      );
    });
  });

  group('canlı özet gerçek izinlerden', () {
    String joined(Set<SellerPermission> s) =>
        staffPermissionSummary(s).map((l) => l.text).join('|');

    test('izin yoksa her şey yapılamaz ve şifre satırı her zaman var', () {
      final lines = staffPermissionSummary(<SellerPermission>{});
      expect(lines.where((l) => l.allowed), isEmpty);
      expect(joined({}), contains('Personel şifresi değiştiremez'));
    });

    test('örnek sonuç: ürün, sipariş, aktarma, yazıcı var; kapatma yok', () {
      final lines = staffPermissionSummary({
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
        SellerPermission.manageProducts,
        SellerPermission.transferTable,
        SellerPermission.managePrintSettings,
      });
      final text = {for (final l in lines) l.text: l.allowed};
      expect(text['Ürün yönetebilir'], isTrue);
      expect(text['Sipariş gönderebilir'], isTrue);
      expect(text['Masa aktarabilir'], isTrue);
      expect(text['Yazıcı ayarlarını yönetebilir'], isTrue);
      expect(text['Masa kapatamaz'], isFalse);
      expect(text['Personel şifresi değiştiremez'], isFalse);
    });

    test('yalnız viewOrders siparişi sadece görüntüler, göndermez', () {
      final t = joined({SellerPermission.viewOrders});
      expect(t, contains('Siparişleri yalnız görüntüler'));
      expect(t, isNot(contains('Sipariş gönderebilir')));
    });

    test('manageStaff şifre değiştirme hakkı vermez', () {
      final lines = staffPermissionSummary({SellerPermission.manageStaff});
      expect(
        lines.singleWhere((l) => l.text == 'Personel şifresi değiştiremez'),
        isA<StaffSummaryLine>().having((l) => l.allowed, 'allowed', isFalse),
      );
    });
  });

  group('kayıt sonrası sunucu doğrulaması', () {
    test('aynı kümeler eşleşir, sıra önemsiz', () {
      final check = verifyStoredPermissions(
        requested: [SellerPermission.manageOrders, SellerPermission.viewOrders],
        stored: [SellerPermission.viewOrders, SellerPermission.manageOrders],
      );
      expect(check.matches, isTrue);
    });

    test('eksik ve fazla izin ayrı raporlanır', () {
      final check = verifyStoredPermissions(
        requested: [SellerPermission.manageTables, SellerPermission.viewOrders],
        stored: [SellerPermission.viewOrders, SellerPermission.closeBill],
      );
      expect(check.matches, isFalse);
      expect(check.missing, {'manageTables'});
      expect(check.unexpected, {'closeBill'});
    });
  });
}
