import 'package:flutter/foundation.dart';

import '../ibul_boot_stage.dart';
import 'generated_runtime_config.g.dart' as gen;

const String _kIbulSupabaseUrl = String.fromEnvironment('IBUL_SUPABASE_URL');
const String _kIbulSupabaseAnonKey = String.fromEnvironment(
  'IBUL_SUPABASE_ANON_KEY',
);
// Legacy define isimleri: eski build akışları IBUL_ prefix'siz geçmiş olabilir.
const String _kLegacySupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _kLegacySupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
);
const String _kIbulGoogleClientId = String.fromEnvironment(
  'IBUL_GOOGLE_CLIENT_ID',
);
// Firebase Android config (firebase_options.dart `android` getter'ının
// zorunlu alanlarıyla birebir aynı isimler). Okuma sırası:
// dart-define → generated dosya → missing (legacy define yok).
const String _kIbulFirebaseAndroidApiKey = String.fromEnvironment(
  'IBUL_FIREBASE_ANDROID_API_KEY',
);
const String _kIbulFirebaseAndroidAppId = String.fromEnvironment(
  'IBUL_FIREBASE_ANDROID_APP_ID',
);
const String _kIbulFirebaseMessagingSenderId = String.fromEnvironment(
  'IBUL_FIREBASE_MESSAGING_SENDER_ID',
);
const String _kIbulFirebaseProjectId = String.fromEnvironment(
  'IBUL_FIREBASE_PROJECT_ID',
);
const String _kIbulFirebaseStorageBucket = String.fromEnvironment(
  'IBUL_FIREBASE_STORAGE_BUCKET',
);
const String _kIbulGoogleServerClientId = String.fromEnvironment(
  'IBUL_GOOGLE_SERVER_CLIENT_ID',
);
/// `full_installer` (web download, bundled print service) or `microsoft_store`.
const String _kIbulDistributionChannel = String.fromEnvironment(
  'IBUL_DISTRIBUTION_CHANNEL',
  defaultValue: 'full_installer',
);
// Sabit GitHub Release tag: `ibul-public-downloads`. Tüm platform asset'leri
// aynı release altında sabit dosya adlarıyla yayınlanır; `latest/download`
// eski tag karışıklığına yol açıyordu (bkz. release_artifacts/).
const String _kIbulPublicDownloadsReleaseTag = 'ibul-public-downloads';
const String _kIbulPublicDownloadsBaseUrl =
    'https://github.com/barankanan/ibull/releases/download/$_kIbulPublicDownloadsReleaseTag';

// Güvenli fallback asset URL'leri (ibul-public-downloads release tag'i).
// .env / dart-define doluysa o değer öncelikli; boşsa bu fallback kullanılır.
const String _kIbulCustomerApkFallbackUrl =
    '$_kIbulPublicDownloadsBaseUrl/IbulCustomer.apk';
const String _kIbulSellerWindowsFallbackUrl =
    '$_kIbulPublicDownloadsBaseUrl/IbulSellerSetup.exe';
const String _kIbulSellerMacosFallbackUrl =
    '$_kIbulPublicDownloadsBaseUrl/IbulSellerDesktop.dmg';

const String _kIbulSellerDesktopWindowsDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
  defaultValue: _kIbulSellerWindowsFallbackUrl,
);
const String _kIbulSellerDesktopMacosDownloadUrl = String.fromEnvironment(
  'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
  defaultValue: _kIbulSellerMacosFallbackUrl,
);
const bool _kIbulSafeBoot = bool.fromEnvironment(
  'IBUL_SAFE_BOOT',
  defaultValue: false,
);
const String _kIbulBootStage = String.fromEnvironment(
  'IBUL_BOOT_STAGE',
  defaultValue: 'normal',
);

/// Çözülmüş runtime değeri + kaynağı.
///
/// `source`: `dart_define` | `legacy_define` | `generated` | `missing`
@immutable
class ResolvedRuntimeValue {
  const ResolvedRuntimeValue(this.value, this.source);

  final String value;
  final String source;

  bool get isPresent => value.isNotEmpty;
}

class AppRuntimeConfig {
  static bool? _safeBootOverride;
  static IbulBootStage? _bootStageOverride;

  @visibleForTesting
  static void setSafeBootOverrideForTest(bool? value) {
    _safeBootOverride = value;
  }

  @visibleForTesting
  static void setBootStageOverrideForTest(IbulBootStage? value) {
    _bootStageOverride = value;
  }

  @visibleForTesting
  static bool parseSafeBootFlag(String? raw) {
    if (raw == null) return false;
    final normalized = raw.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  /// "null", "undefined", boş/whitespace değerleri boş kabul eder; trim'ler.
  @visibleForTesting
  static String sanitizeEnvValue(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'undefined') return '';
    return trimmed;
  }

  /// Okuma sırası: dart-define → legacy define → generated dosya → missing.
  /// Saf fonksiyon; testlerde doğrudan çağrılır.
  @visibleForTesting
  static ResolvedRuntimeValue resolveWithFallback({
    required String primaryDefine,
    String legacyDefine = '',
    String generated = '',
  }) {
    final primary = sanitizeEnvValue(primaryDefine);
    if (primary.isNotEmpty) {
      return ResolvedRuntimeValue(primary, 'dart_define');
    }
    final legacy = sanitizeEnvValue(legacyDefine);
    if (legacy.isNotEmpty) {
      return ResolvedRuntimeValue(legacy, 'legacy_define');
    }
    final generatedValue = sanitizeEnvValue(generated);
    if (generatedValue.isNotEmpty) {
      return ResolvedRuntimeValue(generatedValue, 'generated');
    }
    return const ResolvedRuntimeValue('', 'missing');
  }

  static ResolvedRuntimeValue get supabaseUrlResolved => resolveWithFallback(
    primaryDefine: _kIbulSupabaseUrl,
    legacyDefine: _kLegacySupabaseUrl,
    generated: gen.generatedIbulSupabaseUrl,
  );

  static ResolvedRuntimeValue get supabaseAnonKeyResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulSupabaseAnonKey,
        legacyDefine: _kLegacySupabaseAnonKey,
        generated: gen.generatedIbulSupabaseAnonKey,
      );

  static ResolvedRuntimeValue get firebaseAndroidApiKeyResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulFirebaseAndroidApiKey,
        generated: gen.generatedFirebaseAndroidApiKey,
      );

  static ResolvedRuntimeValue get firebaseAndroidAppIdResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulFirebaseAndroidAppId,
        generated: gen.generatedFirebaseAndroidAppId,
      );

  static ResolvedRuntimeValue get firebaseMessagingSenderIdResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulFirebaseMessagingSenderId,
        generated: gen.generatedFirebaseMessagingSenderId,
      );

  static ResolvedRuntimeValue get firebaseProjectIdResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulFirebaseProjectId,
        generated: gen.generatedFirebaseProjectId,
      );

  static ResolvedRuntimeValue get firebaseStorageBucketResolved =>
      resolveWithFallback(
        primaryDefine: _kIbulFirebaseStorageBucket,
        generated: gen.generatedFirebaseStorageBucket,
      );

  /// Eksik zorunlu Firebase Android define adları (virgülle). Saf fonksiyon;
  /// testlerde doğrudan çağrılır.
  @visibleForTesting
  static String missingFirebaseAndroidKeyNames({
    required ResolvedRuntimeValue apiKey,
    required ResolvedRuntimeValue appId,
    required ResolvedRuntimeValue senderId,
    required ResolvedRuntimeValue projectId,
    required ResolvedRuntimeValue storageBucket,
  }) {
    return <String>[
      if (!apiKey.isPresent) 'IBUL_FIREBASE_ANDROID_API_KEY',
      if (!appId.isPresent) 'IBUL_FIREBASE_ANDROID_APP_ID',
      if (!senderId.isPresent) 'IBUL_FIREBASE_MESSAGING_SENDER_ID',
      if (!projectId.isPresent) 'IBUL_FIREBASE_PROJECT_ID',
      if (!storageBucket.isPresent) 'IBUL_FIREBASE_STORAGE_BUCKET',
    ].join(',');
  }

  static String get rawSupabaseUrl => supabaseUrlResolved.value;

  static String get rawSupabaseAnonKey => supabaseAnonKeyResolved.value;

  static bool get hasSupabaseConfig =>
      rawSupabaseUrl.trim().isNotEmpty && rawSupabaseAnonKey.trim().isNotEmpty;

  static String get supabaseUrl =>
      _requireEnv('IBUL_SUPABASE_URL', rawSupabaseUrl);

  static String get supabaseAnonKey =>
      _requireEnv('IBUL_SUPABASE_ANON_KEY', rawSupabaseAnonKey);

  /// Güvenli boot diagnostiği: key'in kendisini ASLA loglamaz.
  /// Sadece varlık, host, uzunluk ve kaynak bilgisi yazar.
  static void logSupabaseConfigDiagnostics() {
    final url = supabaseUrlResolved;
    final key = supabaseAnonKeyResolved;
    final host = url.isPresent
        ? (Uri.tryParse(url.value)?.host ?? 'parse_error')
        : '';
    final source = url.source == key.source
        ? url.source
        : 'url=${url.source},key=${key.source}';
    debugPrint(
      '[RuntimeConfig] supabaseUrlPresent=${url.isPresent} '
      'supabaseAnonKeyPresent=${key.isPresent} '
      'supabaseUrlHost=$host '
      'anonKeyLength=${key.value.length} '
      'configSource=$source',
    );
  }

  /// Güvenli teşhis snapshot'ı — cihaz üzerinde (logcat olmadan) hata
  /// ekranında gösterilebilir. Anon key DEĞERİ asla dönmez; sadece uzunluk.
  static Map<String, String> safeDiagnostics() {
    final url = supabaseUrlResolved;
    final key = supabaseAnonKeyResolved;
    final missing = <String>[
      if (!url.isPresent) 'IBUL_SUPABASE_URL',
      if (!key.isPresent) 'IBUL_SUPABASE_ANON_KEY',
    ].join(',');
    final fbApiKey = firebaseAndroidApiKeyResolved;
    final fbAppId = firebaseAndroidAppIdResolved;
    final fbSenderId = firebaseMessagingSenderIdResolved;
    final fbProjectId = firebaseProjectIdResolved;
    final fbStorageBucket = firebaseStorageBucketResolved;
    final fbSources = <String>{
      fbApiKey.source,
      fbAppId.source,
      fbSenderId.source,
      fbProjectId.source,
      fbStorageBucket.source,
    };
    return <String, String>{
      'buildMarker': gen.generatedBuildMarker,
      'buildShaHint': gen.generatedBuildSha256Hint,
      'supabaseUrlPresent': '${url.isPresent}',
      'supabaseAnonKeyPresent': '${key.isPresent}',
      'supabaseUrlHost': url.isPresent
          ? (Uri.tryParse(url.value)?.host ?? 'parse_error')
          : '',
      'anonKeyLength': '${key.value.length}',
      'configSource': url.source == key.source
          ? url.source
          : 'url=${url.source},key=${key.source}',
      'generatedUrlPresent':
          '${sanitizeEnvValue(gen.generatedIbulSupabaseUrl).isNotEmpty}',
      'generatedAnonKeyLength':
          '${sanitizeEnvValue(gen.generatedIbulSupabaseAnonKey).length}',
      'dartDefineUrlPresent': '${sanitizeEnvValue(_kIbulSupabaseUrl).isNotEmpty}',
      'legacyUrlPresent': '${sanitizeEnvValue(_kLegacySupabaseUrl).isNotEmpty}',
      'missingKey': missing,
      // Firebase Android teşhisi — API key DEĞERİ asla dönmez; sadece
      // varlık + uzunluk. projectId secret değildir (google-services.json
      // zaten APK içinde düz metin taşır).
      'firebaseAndroidApiKeyPresent': '${fbApiKey.isPresent}',
      'firebaseAndroidApiKeyLength': '${fbApiKey.value.length}',
      'firebaseAndroidAppIdPresent': '${fbAppId.isPresent}',
      'firebaseProjectId': fbProjectId.value,
      'firebaseSource': fbSources.length == 1
          ? fbSources.first
          : 'mixed(${fbSources.join('/')})',
      'firebaseMissingKey': missingFirebaseAndroidKeyNames(
        apiKey: fbApiKey,
        appId: fbAppId,
        senderId: fbSenderId,
        projectId: fbProjectId,
        storageBucket: fbStorageBucket,
      ),
    };
  }

  /// Hata metinlerindeki secret'ları maskeler:
  /// - Bilinen anon key değeri geçiyorsa `***anonKey(len=N)***` olur.
  /// - `eyJ...` ile başlayan tüm JWT benzeri tokenlar `***jwt***` olur.
  static String maskSecrets(String input) {
    var out = input;
    final anonKey = rawSupabaseAnonKey;
    if (anonKey.isNotEmpty && out.contains(anonKey)) {
      out = out.replaceAll(anonKey, '***anonKey(len=${anonKey.length})***');
    }
    // Tam 3 parçalı JWT (header.payload.signature)
    out = out.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'),
      '***jwt***',
    );
    // Kırpılmış/parçalı JWT kalıntıları
    out = out.replaceAll(RegExp(r'eyJ[A-Za-z0-9_\-\.]{16,}'), '***jwt***');
    return out;
  }

  static String get googleClientId =>
      _requireEnv('IBUL_GOOGLE_CLIENT_ID', _kIbulGoogleClientId);

  static String? get googleServerClientId {
    final serverClientId = _normalize(_kIbulGoogleServerClientId);
    if (serverClientId != null) return serverClientId;
    return _normalize(_kIbulGoogleClientId);
  }

  static String? get optionalGoogleClientId => _normalize(_kIbulGoogleClientId);

  /// GitHub Release download for the unified Windows seller installer (web + panel).
  /// Sıra: dart-define → generated → `ibul-public-downloads` fallback.
  static String get sellerDesktopWindowsDownloadUrl {
    final resolved = resolveWithFallback(
      primaryDefine: _kIbulSellerDesktopWindowsDownloadUrl,
      generated: gen.generatedSellerWindowsDownloadUrl,
    );
    return _requireHttpUrl(
      'IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL',
      resolved.isPresent ? resolved.value : _kIbulSellerWindowsFallbackUrl,
    );
  }

  /// UI-safe variant: geçersiz/eksik config'te throw etmek yerine null döner.
  /// Widget'lar null durumunda "İndirme linki hazırlanıyor." göstermelidir.
  static String? get sellerDesktopWindowsDownloadUrlOrNull {
    try {
      return sellerDesktopWindowsDownloadUrl;
    } catch (_) {
      return null;
    }
  }

  /// Legacy name — same unified installer as [sellerDesktopWindowsDownloadUrl].
  static String get windowsInstallerDownloadUrl =>
      sellerDesktopWindowsDownloadUrl;

  static String get sellerDesktopMacosDownloadUrl {
    final resolved = resolveWithFallback(
      primaryDefine: _kIbulSellerDesktopMacosDownloadUrl,
      generated: gen.generatedSellerMacosDownloadUrl,
    );
    return _requireHttpUrl(
      'IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL',
      resolved.isPresent ? resolved.value : _kIbulSellerMacosFallbackUrl,
    );
  }

  /// UI-safe variant: geçersiz/eksik config'te throw etmek yerine null döner.
  static String? get sellerDesktopMacosDownloadUrlOrNull {
    try {
      return sellerDesktopMacosDownloadUrl;
    } catch (_) {
      return null;
    }
  }

  /// Store builds may restrict background print service; full installer is preferred.
  static bool get isMicrosoftStoreDistribution =>
      _normalize(_kIbulDistributionChannel) == 'microsoft_store';

  static bool get isFullInstallerDistribution => !isMicrosoftStoreDistribution;

  /// Minimal web boot: bypass provider tree and heavy init.
  static bool get safeBootMode => _safeBootOverride ?? _kIbulSafeBoot;

  static IbulBootStage get bootStage =>
      _bootStageOverride ?? parseIbulBootStage(_kIbulBootStage);

  static bool get skipHomeCacheLoad => bootStage == IbulBootStage.homeNoCache;

  /// Android APK indirme linki. Sıra: dart-define → generated → güvenli
  /// `ibul-public-downloads` fallback (IbulCustomer.apk).
  static String? get customerAndroidApkDownloadUrl {
    final resolved = resolveWithFallback(
      primaryDefine: const String.fromEnvironment(
        'IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL',
      ),
      generated: gen.generatedCustomerAndroidApkDownloadUrl,
    );
    return resolved.isPresent ? resolved.value : _kIbulCustomerApkFallbackUrl;
  }

  static String? get customerAndroidPlayStoreUrl {
    final resolved = resolveWithFallback(
      primaryDefine: const String.fromEnvironment(
        'IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL',
      ),
      generated: gen.generatedCustomerAndroidPlayStoreUrl,
    );
    return resolved.isPresent ? resolved.value : null;
  }

  /// iOS App Store linki. Bilinçli olarak sentetik fallback YOK: link yoksa
  /// null döner ve UI "iPhone için yakında" gösterir. Sahte IPA linki üretilmez.
  static String? get customerIosAppStoreUrl {
    final resolved = resolveWithFallback(
      primaryDefine: const String.fromEnvironment(
        'IBUL_CUSTOMER_IOS_APP_STORE_URL',
      ),
      generated: gen.generatedCustomerIosAppStoreUrl,
    );
    return resolved.isPresent ? resolved.value : null;
  }

  /// iOS TestFlight linki. Sentetik fallback YOK (bkz. [customerIosAppStoreUrl]).
  static String? get customerIosTestFlightUrl {
    final resolved = resolveWithFallback(
      primaryDefine: const String.fromEnvironment(
        'IBUL_CUSTOMER_IOS_TESTFLIGHT_URL',
      ),
      generated: gen.generatedCustomerIosTestFlightUrl,
    );
    return resolved.isPresent ? resolved.value : null;
  }

  static String _requireEnv(String name, String value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      // Kullanıcıya gösterilmez; sadece developer console'a düşer.
      debugPrint('[RuntimeConfig] missing=$name');
      throw StateError(
        '$name dart-define is required. Add --dart-define=$name=...',
      );
    }
    return normalized;
  }

  static String _requireHttpUrl(String name, String value) {
    final normalized = _requireEnv(name, value);
    final uri = Uri.tryParse(normalized);
    final isValidHttpUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!isValidHttpUrl) {
      throw StateError(
        '$name must be an absolute http/https URL. Current value: $normalized',
      );
    }
    return normalized;
  }

  static String? _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
