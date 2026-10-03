import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/home_mobile_shortcut.dart';
import '../../../services/home_shortcuts_fetch.dart';
import '../../../widgets/feature_menu.dart';
import '../deferred/deferred_home_hero_section.dart';

/// Mobil ana sayfa: 4'lü kısayol grid + kampanya slider.
class IbulMobileHomeChrome extends StatefulWidget {
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
  State<IbulMobileHomeChrome> createState() => _IbulMobileHomeChromeState();
}

class _IbulMobileHomeChromeState extends State<IbulMobileHomeChrome> {
  List<Map<String, dynamic>> _shortcuts = HomeShortcutsFetch.readCachedSync();

  @override
  void initState() {
    super.initState();
    unawaited(_loadShortcuts());
  }

  Future<void> _loadShortcuts() async {
    final rows = await HomeShortcutsFetch.fetch();
    if (!mounted || identical(rows, _shortcuts)) return;
    setState(() => _shortcuts = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeatureMenu(
          remoteCategories: _shortcuts,
          onShortcutTap: widget.onShortcutTap,
        ),
        DeferredHomeHeroSection(
          delay: Duration.zero,
          bannerImageUrls: widget.bannerImageUrls,
          isLoading: widget.isLoadingHero,
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
