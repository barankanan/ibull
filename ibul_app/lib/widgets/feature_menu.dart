import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/build_profile.dart';
import '../core/constants.dart';

typedef HomeShortcutTapCallback = void Function(String shortcutKey, String label);

class FeatureMenu extends StatelessWidget {
  final List<Map<String, dynamic>> remoteCategories;
  final HomeShortcutTapCallback? onShortcutTap;

  const FeatureMenu({
    super.key,
    this.remoteCategories = const [],
    this.onShortcutTap,
  });

  static const List<HomeFeatureMenuConfig> featureConfigs = [
    HomeFeatureMenuConfig(
      key: 'yakin_lokasyon',
      label: 'Yakın Lokasyon',
      assetPath: 'assets/images/features/yakin-lokasyon.png',
    ),
    HomeFeatureMenuConfig(
      key: 'urun_listele',
      label: 'Ürün Listele',
      assetPath: 'assets/images/features/listele.png',
    ),
    HomeFeatureMenuConfig(
      key: 'gorsel_zeka',
      label: 'Görsel Zeka',
      assetPath: 'assets/images/features/gorsel-zeka.png',
    ),
    HomeFeatureMenuConfig(
      key: 'urun_parcala',
      label: 'Ürün Parçala',
      assetPath: 'assets/images/features/urun-parcala.png',
    ),
    HomeFeatureMenuConfig(
      key: 'bana_ozel',
      label: 'Bana Özel',
      assetPath: 'assets/images/features/sana-ozel.png',
    ),
    HomeFeatureMenuConfig(
      key: 'hizli_yemek',
      label: 'Hızlı Yemek',
      assetPath: 'assets/images/features/hizli-yemek.png',
    ),
    HomeFeatureMenuConfig(
      key: 'yapay_zeka',
      label: 'Yapay Zeka',
      assetPath: 'assets/images/features/yapay-zeka.png',
    ),
    HomeFeatureMenuConfig(
      key: 'yakinda',
      label: 'Yakında',
      assetPath: 'assets/images/features/ibul-premium.png',
      comingSoon: true,
      icon: Icons.hourglass_top_rounded,
    ),
  ];

  /// Yalnızca admin `app_categories` kaydını aktif ettiğinde gösterilir.
  static const List<HomeFeatureMenuConfig> optionalConfigs = [
    HomeFeatureMenuConfig(
      key: 'ibul_premium',
      label: 'İBUL Premium',
      assetPath: 'assets/images/features/ibul-premium.png',
      comingSoon: true,
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  /// [remoteCategories] sırasıyla (bkz. `HomeShortcutsFetch.sortShortcutRows`)
  /// kısayolları dizer; uzak kayıt yoksa varsayılan sıra korunur.
  static List<HomeFeatureMenuConfig> resolveConfigs(
    List<Map<String, dynamic>> remoteCategories,
  ) {
    if (remoteCategories.isEmpty) return featureConfigs;
    final remoteIndex = <String, int>{};
    for (var i = 0; i < remoteCategories.length; i++) {
      final key = remoteCategories[i]['category_key']?.toString() ?? '';
      if (key.isNotEmpty) remoteIndex.putIfAbsent(key, () => i);
    }
    final configs = <HomeFeatureMenuConfig>[
      ...featureConfigs,
      for (final optional in optionalConfigs)
        if (remoteCategories.any(
          (row) =>
              row['category_key']?.toString() == optional.key &&
              row['is_active'] == true,
        ))
          optional,
    ];
    final fallbackIndex = {
      for (var i = 0; i < configs.length; i++) configs[i].key: i,
    };
    int rank(HomeFeatureMenuConfig c) =>
        remoteIndex[c.key] ?? remoteCategories.length + fallbackIndex[c.key]!;
    configs.sort((a, b) => rank(a).compareTo(rank(b)));
    return configs;
  }

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('FeatureMenu', () {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isSmallScreen = screenWidth < 360;
      final Map<String, Map<String, dynamic>> remoteByKey = {
        for (final category in remoteCategories)
          if ((category['category_key']?.toString() ?? '').isNotEmpty)
            category['category_key'].toString(): category,
      };

      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8.0 : 12.0,
          vertical: isSmallScreen ? 6.0 : 8.0,
        ),
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: isSmallScreen ? 12 : 16,
          crossAxisSpacing: isSmallScreen ? 6 : 10,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isSmallScreen ? 0.75 : 0.7,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: resolveConfigs(remoteCategories).map((config) {
            final remote = remoteByKey[config.key];
            final remoteUrl = remote?['image_url']?.toString();
            final displayName = remote?['display_name']?.toString();
            final isActive = remote?['is_active'] != false;
            final label = (displayName != null && displayName.isNotEmpty)
                ? displayName
                : config.label;

            return _FeatureTile(
              shortcutKey: config.key,
              imageUrl: (isActive && remoteUrl != null && remoteUrl.isNotEmpty)
                  ? remoteUrl
                  : null,
              assetPath: config.assetPath,
              icon: config.icon,
              label: label,
              comingSoon: config.comingSoon || !isActive,
              onTap: onShortcutTap == null
                  ? null
                  : () => onShortcutTap!(config.key, label),
            );
          }).toList(),
        ),
      );
    });
  }
}

class _FeatureTile extends StatefulWidget {
  const _FeatureTile({
    required this.shortcutKey,
    this.imageUrl,
    required this.assetPath,
    this.icon,
    required this.label,
    required this.onTap,
    this.comingSoon = false,
  });

  final String shortcutKey;
  final String? imageUrl;
  final String assetPath;
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 10.0 : 11.0;
    final onTap = widget.onTap;

    return Semantics(
      button: true,
      label: widget.comingSoon ? '${widget.label}, Yakında' : widget.label,
      enabled: onTap != null,
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: onTap == null ? null : (_) => setState(() => _pressed = true),
            onTapUp: onTap == null ? null : (_) => setState(() => _pressed = false),
            onTapCancel: onTap == null ? null : () => setState(() => _pressed = false),
            onTap: onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(isSmallScreen ? 12 : 16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 12 : 16,
                            ),
                            child: _buildImage(),
                          ),
                        ),
                        if (widget.comingSoon)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Yakında',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 1.0 : 2.0,
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.icon != null) {
      return ColoredBox(
        color: AppColors.softPurple,
        child: Center(
          child: Icon(widget.icon, color: AppColors.primary, size: 32),
        ),
      );
    }
    final fallback = Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
      ),
    );

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return OptimizedImage(
        imageUrlOrPath: widget.imageUrl!,
        fit: BoxFit.cover,
        errorWidget: _buildAssetFallback(fallback),
      );
    }

    return _buildAssetFallback(fallback);
  }

  Widget _buildAssetFallback(Widget fallback) {
    return Image.asset(
      widget.assetPath,
      package: 'ibul_app',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class HomeFeatureMenuConfig {
  final String key;
  final String label;
  final String assetPath;
  final bool comingSoon;
  final IconData? icon;

  const HomeFeatureMenuConfig({
    required this.key,
    required this.label,
    required this.assetPath,
    this.comingSoon = false,
    this.icon,
  });
}
