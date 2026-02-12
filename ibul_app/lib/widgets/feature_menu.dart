import 'package:flutter/material.dart';

class FeatureMenu extends StatelessWidget {
  const FeatureMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
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
        children: const [
          _FeatureTile(
            imagePath: 'assets/images/features/yakin-lokasyon.png',
            label: 'Yakın Lokasyon',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/listele.png',
            label: 'Ürün Listele',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/gorsel-zeka.png',
            label: 'Görsel Zeka',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/urun-parcala.png',
            label: 'Ürün Parçala',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/ibul-premium.png',
            label: 'İBUL Premium',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/sana-ozel.png',
            label: 'Bana Özel',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/hizli-yemek.png',
            label: 'Hızlı Yemek',
          ),
          _FeatureTile(
            imagePath: 'assets/images/features/yapay-zeka.png',
            label: 'Yapay Zeka',
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String imagePath;
  final String label;

  const _FeatureTile({
    required this.imagePath,
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
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 1.0 : 2.0),
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
}
