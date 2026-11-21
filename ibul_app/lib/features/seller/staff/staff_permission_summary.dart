import '../../../models/sub_admin.dart';
import '../panel/models/seller_panel_types.dart';
import 'staff_business_catalog.dart';

/// Bir sayfa için işletme sahibinin seçtiği erişim düzeyi.
/// [custom] yalnız GÖSTERİM içindir: kayıtlı izinler hiçbir hazır düzeye uymuyor.
enum StaffPageLevel { none, view, full, custom }

String staffPageLevelLabel(StaffPageLevel level) {
  switch (level) {
    case StaffPageLevel.none:
      return 'Erişim yok';
    case StaffPageLevel.view:
      return 'Görüntüle';
    case StaffPageLevel.full:
      return 'Tam yönetim';
    case StaffPageLevel.custom:
      return 'Özel';
  }
}

/// Yalnız okuma düzeyinde gerçekten karşılığı olan izinler.
/// Ürün, kampanya, destek gibi sayfalarda salt-okunur bir sunucu izni YOKTUR
/// (okuma bile yönetim iznine bağlıdır); bu sayfalar için "Görüntüle" sunulmaz.
Set<SellerPermission> pageViewOperations(SellerModule module) {
  switch (module) {
    case SellerModule.garson:
    case SellerModule.orders:
    case SellerModule.dashboard:
      return const <SellerPermission>{SellerPermission.viewOrders};
    default:
      return const <SellerPermission>{};
  }
}

/// Bir sayfanın seçilebilir düzeyleri ve her düzeyin verdiği izinler.
class StaffPageLevelPlan {
  const StaffPageLevelPlan({
    required this.levels,
    required this.viewOps,
    required this.fullOps,
  });

  final List<StaffPageLevel> levels;
  final Set<SellerPermission> viewOps;
  final Set<SellerPermission> fullOps;

  Set<SellerPermission> opsFor(StaffPageLevel level) {
    switch (level) {
      case StaffPageLevel.none:
      case StaffPageLevel.custom:
        return const <SellerPermission>{};
      case StaffPageLevel.view:
        return viewOps;
      case StaffPageLevel.full:
        return fullOps;
    }
  }
}

/// [fullOps]: sayfanın "tam yönetim" izinleri (tavan ve sunucu saklamasına göre süzülmüş).
StaffPageLevelPlan staffPageLevelPlan(
  SellerModule module,
  Set<SellerPermission> fullOps,
) {
  final viewOps = pageViewOperations(module).intersection(
    fullOps.isEmpty ? pageViewOperations(module) : fullOps,
  );
  // Sayfada hiç işlem izni yoksa yalnız görünürlük vardır.
  if (fullOps.isEmpty) {
    return const StaffPageLevelPlan(
      levels: <StaffPageLevel>[StaffPageLevel.none, StaffPageLevel.view],
      viewOps: <SellerPermission>{},
      fullOps: <SellerPermission>{},
    );
  }
  // Tam yönetim zaten salt-okunur izne eşitse (Genel Bakış) tek "Görüntüle".
  if (viewOps.isNotEmpty &&
      viewOps.length == fullOps.length &&
      viewOps.containsAll(fullOps)) {
    return StaffPageLevelPlan(
      levels: const <StaffPageLevel>[StaffPageLevel.none, StaffPageLevel.view],
      viewOps: fullOps,
      fullOps: fullOps,
    );
  }
  return StaffPageLevelPlan(
    levels: <StaffPageLevel>[
      StaffPageLevel.none,
      if (viewOps.isNotEmpty) StaffPageLevel.view,
      StaffPageLevel.full,
    ],
    viewOps: viewOps,
    fullOps: fullOps,
  );
}

/// Seçili sayfa ve izinlerden sayfanın görünen düzeyi.
StaffPageLevel staffCurrentPageLevel({
  required StaffPageLevelPlan plan,
  required bool pageVisible,
  required Set<SellerPermission> selected,
}) {
  if (!pageVisible) return StaffPageLevel.none;
  if (plan.fullOps.isEmpty) return StaffPageLevel.view;
  final hasFull = plan.fullOps.every(selected.contains);
  if (hasFull) {
    return plan.levels.contains(StaffPageLevel.full)
        ? StaffPageLevel.full
        : StaffPageLevel.view;
  }
  if (plan.levels.contains(StaffPageLevel.view) &&
      plan.viewOps.isNotEmpty &&
      plan.viewOps.every(selected.contains) &&
      !plan.fullOps.any((op) => !plan.viewOps.contains(op) && selected.contains(op))) {
    return StaffPageLevel.view;
  }
  return StaffPageLevel.custom;
}

class StaffSummaryLine {
  const StaffSummaryLine(this.text, this.allowed);

  final String text;
  final bool allowed;
}

/// Gerçek izin kümesinden insan okuyabilir sonuç. Her satır tek bir izinden gelir;
/// "Personel şifresi değiştiremez" sunucuda yalnız sahibe bağlıdır ve her zaman geçerlidir.
List<StaffSummaryLine> staffPermissionSummary(Set<SellerPermission> selected) {
  bool has(SellerPermission p) => selected.contains(p);
  final orders = has(SellerPermission.manageOrders)
      ? const StaffSummaryLine('Sipariş gönderebilir', true)
      : has(SellerPermission.viewOrders)
      ? const StaffSummaryLine('Siparişleri yalnız görüntüler', true)
      : const StaffSummaryLine('Sipariş göremez ve gönderemez', false);
  return <StaffSummaryLine>[
    orders,
    StaffSummaryLine(
      has(SellerPermission.manageProducts)
          ? 'Ürün yönetebilir'
          : 'Ürün yönetemez',
      has(SellerPermission.manageProducts),
    ),
    StaffSummaryLine(
      has(SellerPermission.transferTable)
          ? 'Masa aktarabilir'
          : 'Masa aktaramaz',
      has(SellerPermission.transferTable),
    ),
    StaffSummaryLine(
      has(SellerPermission.takePartialPayment)
          ? 'Ara ödeme alabilir'
          : 'Ara ödeme alamaz',
      has(SellerPermission.takePartialPayment),
    ),
    StaffSummaryLine(
      has(SellerPermission.closeBill)
          ? 'Masa kapatabilir'
          : 'Masa kapatamaz',
      has(SellerPermission.closeBill),
    ),
    StaffSummaryLine(
      has(SellerPermission.managePrintSettings)
          ? 'Yazıcı ayarlarını yönetebilir'
          : 'Yazıcı ayarlarını yönetemez',
      has(SellerPermission.managePrintSettings),
    ),
    StaffSummaryLine(
      has(SellerPermission.manageTables)
          ? 'Alan, masa ve QR düzenini yönetebilir'
          : 'Alan, masa ve QR düzenini yönetemez',
      has(SellerPermission.manageTables),
    ),
    StaffSummaryLine(
      has(SellerPermission.viewFinance)
          ? 'Finansı görebilir'
          : 'Finansı göremez',
      has(SellerPermission.viewFinance),
    ),
    StaffSummaryLine(
      has(SellerPermission.manageCampaigns)
          ? 'Kampanya yönetebilir'
          : 'Kampanya yönetemez',
      has(SellerPermission.manageCampaigns),
    ),
    StaffSummaryLine(
      has(SellerPermission.manageSupport)
          ? 'Destek kayıtlarını yönetebilir'
          : 'Destek kayıtlarını yönetemez',
      has(SellerPermission.manageSupport),
    ),
    StaffSummaryLine(
      has(SellerPermission.manageStaff)
          ? 'Personel yetkilerini düzenleyebilir'
          : 'Personel yönetemez',
      has(SellerPermission.manageStaff),
    ),
    const StaffSummaryLine('Personel şifresi değiştiremez', false),
  ];
}

/// Kayıttan sonra sunucudaki izinlerin gönderilenle eşleştiğinin kanıtı.
class StaffSaveCheck {
  const StaffSaveCheck({required this.missing, required this.unexpected});

  /// İstenip sunucuda OLMAYAN izinler.
  final Set<String> missing;

  /// Sunucuda olup istenmeyen izinler.
  final Set<String> unexpected;

  bool get matches => missing.isEmpty && unexpected.isEmpty;
}

StaffSaveCheck verifyStoredPermissions({
  required Iterable<SellerPermission> requested,
  required Iterable<SellerPermission> stored,
}) {
  final want = <String>{
    for (final p in requested)
      if (staffPermissionPersists(p)) p.name,
  };
  final have = <String>{
    for (final p in stored)
      if (staffPermissionPersists(p)) p.name,
  };
  return StaffSaveCheck(
    missing: want.difference(have),
    unexpected: have.difference(want),
  );
}
