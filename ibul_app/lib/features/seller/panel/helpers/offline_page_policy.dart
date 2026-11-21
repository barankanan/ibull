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
