import '../models/seller_panel_types.dart';

/// İnternet yokken Satıcı panelinde çalışan sayfalar. Başka hiçbir sayfa açılmaz:
/// menü, rota (derin bağlantı dahil), veri yükleme ve işlem katmanı bu tek kümeyi kullanır.
const Set<SellerModule> offlineAvailableModules = <SellerModule>{
  SellerModule.dashboard,
  SellerModule.garson,
  SellerModule.system,
};

const String offlineRequiresInternetMessage = 'İnternet bağlantısı gerektirir';
const String offlineRequiresInternetDetail =
    'Bu sayfa internet yokken kullanılamaz. Bağlantı gelince otomatik açılır.';

bool moduleAvailableOffline(SellerModule module) =>
    offlineAvailableModules.contains(module);

/// Çevrimdışıyken [module] engelli mi? Çevrimiçi hiçbir sayfa bu kuralla engellenmez.
bool moduleBlockedByOffline({
  required SellerModule module,
  required bool offline,
}) => offline && !moduleAvailableOffline(module);

/// Engelli bir sayfadan dönülecek ilk izinli ve çevrimdışı çalışan sayfa.
/// [permitted] hesabın zaten sahip olduğu sayfalardır; hiç yeni yetki eklenmez.
SellerModule? offlineFallbackModule(List<SellerModule> permitted) {
  for (final module in permitted) {
    if (moduleAvailableOffline(module)) return module;
  }
  return null;
}

/// İzinli sayfalardan çevrimdışıyken AÇILABİLENLER.
List<SellerModule> openableModules({
  required List<SellerModule> permitted,
  required bool offline,
}) {
  if (!offline) return permitted;
  return permitted.where(moduleAvailableOffline).toList(growable: false);
}

/// Bulut yeniden yanıt verdiğinde panelin yapacakları.
///
/// Çevrimdışı açılış bayrağı yalnız başarılı bir mağaza profili yüklemesiyle
/// kalkar. Tek deneme geçici bir hatada başarısız olursa panel kalıcı olarak
/// üç sayfada kalıyordu; bu karar bulut açıkken denemeyi aralıklı yineler.
class CloudRecoveryPlan {
  const CloudRecoveryPlan({
    required this.retryProfile,
    required this.refreshBoards,
    required this.rebuild,
  });

  /// Hesabı doğrula ve gerçek menüyü yükle (çevrimdışı açılıştan çıkış).
  final bool retryProfile;

  /// Genel Bakış ve Garson verisini buluttan yenile.
  final bool refreshBoards;

  /// Menü ve sayfa kilidi yeniden çizilsin.
  final bool rebuild;
}

CloudRecoveryPlan decideCloudRecovery({
  required bool cloudUp,
  required bool wasCloudUp,
  required bool offlineStartActive,
  required bool recoveryInFlight,
  required bool boardShowsCloudError,
  required DateTime? lastAttemptAt,
  required DateTime now,
  Duration retryEvery = const Duration(seconds: 10),
}) {
  final changed = cloudUp != wasCloudUp;
  if (!cloudUp) {
    return CloudRecoveryPlan(
      retryProfile: false,
      refreshBoards: false,
      rebuild: changed,
    );
  }
  final due =
      lastAttemptAt == null || now.difference(lastAttemptAt) >= retryEvery;
  if (offlineStartActive) {
    return CloudRecoveryPlan(
      retryProfile: !recoveryInFlight && due,
      refreshBoards: false,
      rebuild: changed,
    );
  }
  return CloudRecoveryPlan(
    retryProfile: false,
    refreshBoards:
        !recoveryInFlight && (changed || (boardShowsCloudError && due)),
    rebuild: changed,
  );
}
