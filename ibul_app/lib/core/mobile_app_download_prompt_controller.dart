import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/customer_mobile_app_download_prompt.dart';

/// Prompt görünürlük kararı (log reason'ları ile birebir eşleşir).
enum MobileAppPromptVisibility {
  show,
  hiddenDesktop,
  hiddenDismissed,
  hiddenNoLinks,
}

/// Manages the state and display logic for the mobile app download prompt.
class MobileAppDownloadPromptController {
  /// v2: link mimarisi `ibul-public-downloads` release'ine taşınırken key
  /// bilinçli olarak yükseltildi; eski v1 dismiss kaydı yeni link setinin
  /// gösterimini engellemesin diye. Yeni link seti yayınlanırsa version'ı
  /// artırın (v3, v4, ...).
  static const String _dismissedKey = 'customer_mobile_app_prompt_dismissed_v2';
  static const String _legacyDismissedKeyV1 =
      'customer_mobile_app_prompt_dismissed_v1';
  static const double _mobileWebMaxWidth = 1100;
  static bool _sessionDismissed = false; // Prevents showing multiple times in one session if not persisted properly

  @visibleForTesting
  static void resetSessionForTest() {
    _sessionDismissed = false;
  }

  /// Saf görünürlük kararı; widget/prefs bağımlılığı yok, test edilebilir.
  @visibleForTesting
  static MobileAppPromptVisibility evaluate({
    required double width,
    required TargetPlatform platform,
    required MobileAppDownloadLinks links,
    bool dismissed = false,
  }) {
    final isNativeMobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    final isMobileWeb = width < _mobileWebMaxWidth;

    if (!isMobileWeb && !isNativeMobile) {
      return MobileAppPromptVisibility.hiddenDesktop;
    }
    if (dismissed) {
      return MobileAppPromptVisibility.hiddenDismissed;
    }
    if (!links.hasAnyLink) {
      return MobileAppPromptVisibility.hiddenNoLinks;
    }
    return MobileAppPromptVisibility.show;
  }

  /// Checks if the prompt should be shown, and if so, shows it as a bottom sheet.
  /// Should be called after a short delay on the home screen.
  static Future<void> checkAndShowPrompt(BuildContext context) async {
    if (!kIsWeb) return; // Only show on web

    if (_sessionDismissed) return;

    final width = MediaQuery.sizeOf(context).width;
    debugPrint(
      '[MobileAppPrompt] check isWeb=true width=$width platform=$defaultTargetPlatform',
    );

    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool(_dismissedKey) ?? false;
    final legacyDismissed = prefs.getBool(_legacyDismissedKeyV1) ?? false;
    debugPrint(
      '[MobileAppPrompt] dismissKey=$_dismissedKey dismissed=$isDismissed '
      'legacyV1Dismissed=$legacyDismissed (v1 kaydı artık yok sayılır)',
    );

    if (!context.mounted) return;

    final links = MobileAppDownloadLinks.fromRuntimeConfig();
    debugPrint(
      '[MobileAppPrompt] links android=${links.hasAndroid} '
      'iosAppStore=${links.appStoreUrl != null} '
      'iosTestFlight=${links.testFlightUrl != null}',
    );
    final iosSource = links.iosSource;
    if (iosSource != null) {
      debugPrint('[MobileAppPrompt] ios enabled=true source=$iosSource');
    } else {
      debugPrint('[MobileAppPrompt] ios disabled reason=no_ios_link');
    }

    final visibility = evaluate(
      width: width,
      platform: defaultTargetPlatform,
      links: links,
      dismissed: isDismissed,
    );

    switch (visibility) {
      case MobileAppPromptVisibility.hiddenDesktop:
        debugPrint('[MobileAppPrompt] hidden reason=desktop');
        return;
      case MobileAppPromptVisibility.hiddenDismissed:
        debugPrint('[MobileAppPrompt] hidden reason=dismissed');
        return;
      case MobileAppPromptVisibility.hiddenNoLinks:
        debugPrint('[MobileAppPrompt] hidden reason=no_links');
        return;
      case MobileAppPromptVisibility.show:
        break;
    }

    _sessionDismissed = true; // Mark as shown for this session

    debugPrint('[MobileAppPrompt] show reason=mobile_web');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomerMobileAppDownloadPrompt(
          links: links,
          onDismiss: () async {
            await prefs.setBool(_dismissedKey, true);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }
}
