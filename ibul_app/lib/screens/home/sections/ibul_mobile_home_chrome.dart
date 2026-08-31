import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_mobile_shortcut.dart';
import '../../../widgets/feature_menu.dart';
import '../deferred/deferred_home_hero_section.dart';

/// Mobil ana sayfa: 4'lü kısayol grid + kampanya slider.
class IbulMobileHomeChrome extends StatelessWidget {
  const IbulMobileHomeChrome({
    super.key,
    required this.bannerImageUrls,
    required this.isLoadingHero,
    this.onShortcutTap,
  });

  final List<String> bannerImageUrls;
  final bool isLoadingHero;
  final HomeShortcutTapCallback? onShortcutTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeatureMenu(onShortcutTap: onShortcutTap),
        DeferredHomeHeroSection(
          delay: Duration.zero,
          bannerImageUrls: bannerImageUrls,
          isLoading: isLoadingHero,
          preferMobile: true,
        ),
      ],
    );
  }
}

void openMobileHomeShortcut(
  BuildContext context, {
  required String shortcutKey,
  required String label,
  HomeMobileShortcutCallbacks callbacks = const HomeMobileShortcutCallbacks(),
}) {
  final action = HomeMobileShortcutRegistry.fromKey(shortcutKey) ??
      HomeMobileShortcutRegistry.fromLabel(label);
  if (action == null) return;
  unawaited(
    HomeMobileShortcutNavigator.open(context, action, callbacks: callbacks),
  );
}
