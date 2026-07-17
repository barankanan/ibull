import 'package:flutter/material.dart';

import '../core/config/runtime_config.dart';
import '../utils/browser_file_download.dart';

/// Customer mobil uygulama indirme linkleri.
///
/// Değerler runtime config'ten (dart-define) gelir; testler kendi
/// değerlerini enjekte edebilir. Boş/whitespace string "link yok" sayılır.
/// Fake/demo link hardcode edilmez.
class MobileAppDownloadLinks {
  const MobileAppDownloadLinks({
    this.androidApkUrl,
    this.androidPlayStoreUrl,
    this.iosAppStoreUrl,
    this.iosTestFlightUrl,
  });

  factory MobileAppDownloadLinks.fromRuntimeConfig() {
    return MobileAppDownloadLinks(
      androidApkUrl: AppRuntimeConfig.customerAndroidApkDownloadUrl,
      androidPlayStoreUrl: AppRuntimeConfig.customerAndroidPlayStoreUrl,
      iosAppStoreUrl: AppRuntimeConfig.customerIosAppStoreUrl,
      iosTestFlightUrl: AppRuntimeConfig.customerIosTestFlightUrl,
    );
  }

  final String? androidApkUrl;
  final String? androidPlayStoreUrl;
  final String? iosAppStoreUrl;
  final String? iosTestFlightUrl;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? get apkUrl => _clean(androidApkUrl);
  String? get playStoreUrl => _clean(androidPlayStoreUrl);
  String? get appStoreUrl => _clean(iosAppStoreUrl);
  String? get testFlightUrl => _clean(iosTestFlightUrl);

  /// Play Store öncelikli; yoksa doğrudan APK release linki.
  String? get androidUrl => playStoreUrl ?? apkUrl;

  /// App Store öncelikli; yoksa TestFlight daveti.
  String? get iosUrl => appStoreUrl ?? testFlightUrl;

  bool get hasAndroid => androidUrl != null;
  bool get hasIos => iosUrl != null;
  bool get hasAnyLink => hasAndroid || hasIos;

  /// iOS linkinin kaynağı: `app_store` > `testflight` > null (link yok).
  /// Console loglarında `source=` alanı olarak kullanılır.
  String? get iosSource {
    if (appStoreUrl != null) return 'app_store';
    if (testFlightUrl != null) return 'testflight';
    return null;
  }

  String? get androidActionLabel {
    if (playStoreUrl != null) return 'Google Play’de aç';
    if (apkUrl != null) return 'Android APK indir';
    return null;
  }

  String? get iosActionLabel {
    if (appStoreUrl != null) return 'App Store’da aç';
    if (testFlightUrl != null) return 'TestFlight’tan yükle';
    return null;
  }
}

/// Mobil web'de native uygulamayı indirmeye yönlendiren bottom sheet.
///
/// Android ve iPhone kartları her zaman görünür; linki olmayan platform
/// "Yakında" olarak disabled gösterilir ve asla kırık/boş URL açmaz.
class CustomerMobileAppDownloadPrompt extends StatelessWidget {
  const CustomerMobileAppDownloadPrompt({
    super.key,
    required this.onDismiss,
    this.links,
    this.openUrl,
  });

  static const Key androidCardKey = Key('mobile_app_prompt_android_card');
  static const Key iosCardKey = Key('mobile_app_prompt_ios_card');

  final VoidCallback onDismiss;

  /// Test enjeksiyonu için; null ise runtime config kullanılır.
  final MobileAppDownloadLinks? links;

  /// Test enjeksiyonu için; null ise [BrowserFileDownload.openExternalUrl].
  final void Function(String url)? openUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedLinks = links ?? MobileAppDownloadLinks.fromRuntimeConfig();
    final open = openUrl ?? BrowserFileDownload.openExternalUrl;

    final androidUrl = resolvedLinks.androidUrl;
    final iosUrl = resolvedLinks.iosUrl;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'İBUL’u telefonuna indir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6D28D9), // iBul purple theme
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Daha hızlı alışveriş, yakın fırsatlar ve favori mağazaların cebinde.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _PlatformOptionCard(
                        key: androidCardKey,
                        icon: Icons.android,
                        title: 'Android',
                        actionLabel: resolvedLinks.androidActionLabel,
                        onTap: androidUrl == null
                            ? null
                            : () => open(androidUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlatformOptionCard(
                        key: iosCardKey,
                        icon: Icons.apple,
                        title: 'iPhone',
                        actionLabel: resolvedLinks.iosActionLabel,
                        onTap: iosUrl == null ? null : () => open(iosUrl),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Daha sonra',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek platform seçenek kartı. [actionLabel] null ise disabled "Yakında"
/// durumunda çizilir ve tıklanamaz (kırık linke gidemez).
class _PlatformOptionCard extends StatelessWidget {
  const _PlatformOptionCard({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  bool get _enabled => onTap != null && actionLabel != null;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6D28D9);
    const disabledGrey = Color(0xFF9CA3AF);
    final accent = _enabled ? purple : disabledGrey;

    return Material(
      color: _enabled ? const Color(0xFFF5F3FF) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _enabled ? const Color(0xFFDDD6FE) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: accent),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _enabled ? const Color(0xFF1F2937) : disabledGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                actionLabel ?? 'Yakında',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
