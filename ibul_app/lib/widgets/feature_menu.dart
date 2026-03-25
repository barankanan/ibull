import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/build_profile.dart';

class FeatureMenu extends StatelessWidget {
  final List<Map<String, dynamic>> remoteCategories;

  const FeatureMenu({super.key, this.remoteCategories = const []});

  static const List<_FeatureConfig> _featureConfigs = [
    _FeatureConfig(
      key: 'yakin_lokasyon',
      label: 'Yakın Lokasyon',
      assetPath: 'assets/images/features/yakin-lokasyon.png',
    ),
    _FeatureConfig(
      key: 'urun_listele',
      label: 'Ürün Listele',
      assetPath: 'assets/images/features/listele.png',
    ),
    _FeatureConfig(
      key: 'gorsel_zeka',
      label: 'Görsel Zeka',
      assetPath: 'assets/images/features/gorsel-zeka.png',
    ),
    _FeatureConfig(
      key: 'urun_parcala',
      label: 'Ürün Parçala',
      assetPath: 'assets/images/features/urun-parcala.png',
    ),
    _FeatureConfig(
      key: 'ibul_premium',
      label: 'İBUL Premium',
      assetPath: 'assets/images/features/ibul-premium.png',
    ),
    _FeatureConfig(
      key: 'bana_ozel',
      label: 'Bana Özel',
      assetPath: 'assets/images/features/sana-ozel.png',
    ),
    _FeatureConfig(
      key: 'hizli_yemek',
      label: 'Hızlı Yemek',
      assetPath: 'assets/images/features/hizli-yemek.png',
    ),
    _FeatureConfig(
      key: 'yapay_zeka',
      label: 'Yapay Zeka',
      assetPath: 'assets/images/features/yapay-zeka.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('FeatureMenu', () {
      final screenWidth = MediaQuery.of(context).size.width;
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
          children: _featureConfigs.map((config) {
            final remote = remoteByKey[config.key];
            final remoteUrl = remote?['image_url']?.toString();
            final displayName = remote?['display_name']?.toString();
            final isActive = remote?['is_active'] != false;

            return _FeatureTile(
              imageUrl: (isActive && remoteUrl != null && remoteUrl.isNotEmpty)
                  ? remoteUrl
                  : null,
              assetPath: config.assetPath,
              label: (displayName != null && displayName.isNotEmpty)
                  ? displayName
                  : config.label,
            );
          }).toList(),
        ),
      );
    });
  }
}

class _FeatureTile extends StatelessWidget {
  final String? imageUrl;
  final String assetPath;
  final String label;

  const _FeatureTile({
    this.imageUrl,
    required this.assetPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = isSmallScreen ? 10.0 : 11.0;

    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Force square aspect ratio for the image box
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                child: _buildImage(),
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 1.0 : 2.0,
            ),
            child: Text(
              label,
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
    );
  }

  Widget _buildImage() {
    final fallback = Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
      ),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return OptimizedImage(
        imageUrlOrPath: imageUrl!,
        fit: BoxFit.cover,
        errorWidget: _buildAssetFallback(fallback),
      );
    }

    return _buildAssetFallback(fallback);
  }

  Widget _buildAssetFallback(Widget fallback) {
    return Image.asset(
      assetPath,
      package: 'ibul_app',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _FeatureConfig {
  final String key;
  final String label;
  final String assetPath;

  const _FeatureConfig({
    required this.key,
    required this.label,
    required this.assetPath,
  });
}
