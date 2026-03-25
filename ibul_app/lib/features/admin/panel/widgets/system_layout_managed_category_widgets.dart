import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../../../../core/mobile_category_catalog.dart';

class ManagedCategoryCard extends StatelessWidget {
  const ManagedCategoryCard({
    super.key,
    required this.category,
    required this.isSaving,
    required this.onToggleActive,
    required this.onEditTap,
    required this.onAddSubCategoryTap,
    required this.onDeleteTap,
    required this.subCategoryCards,
  });

  final MobileCategoryNode category;
  final bool isSaving;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onEditTap;
  final VoidCallback? onAddSubCategoryTap;
  final VoidCallback? onDeleteTap;
  final List<Widget> subCategoryCards;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ManagedCategoryImage(
              imageUrl: category.imageUrl,
              fallbackAssetPath: category.fallbackAssetPath,
            ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${category.subCategories.length} alt kategori • Sıra ${category.orderIndex}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aktif', style: TextStyle(fontSize: 12)),
            Switch(
              value: category.isActive,
              activeThumbColor: const Color(0xFF8B5CF6),
              onChanged: onToggleActive,
            ),
          ],
        ),
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onEditTap,
                icon: const Icon(Icons.edit_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Düzenle'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAddSubCategoryTap,
                icon: const Icon(Icons.add),
                label: const Text('Alt Kategori Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onDeleteTap,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Sil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (category.subCategories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Bu kategori icin henuz alt kategori tanimlanmadi.',
              ),
            )
          else
            Wrap(spacing: 12, runSpacing: 12, children: subCategoryCards),
        ],
      ),
    );
  }
}

class ManagedSubCategoryCard extends StatelessWidget {
  const ManagedSubCategoryCard({
    super.key,
    required this.subCategory,
    required this.isSaving,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final MobileCategoryNode subCategory;
  final bool isSaving;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCCEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: ManagedCategoryImage(
                    imageUrl: subCategory.imageUrl,
                    fallbackAssetPath: subCategory.fallbackAssetPath,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subCategory.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sıra ${subCategory.orderIndex}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditTap,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(
                    isSaving ? '...' : 'Düzenle',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDeleteTap,
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Sil', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ManagedCategoryImage extends StatelessWidget {
  const ManagedCategoryImage({
    super.key,
    this.imageUrl,
    this.fallbackAssetPath,
  });

  final String? imageUrl;
  final String? fallbackAssetPath;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return OptimizedImage(imageUrlOrPath: 
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildManagedCategoryAsset(fallbackAssetPath, fallback),
      );
    }

    return _buildManagedCategoryAsset(fallbackAssetPath, fallback);
  }
}

Widget _buildManagedCategoryAsset(String? fallbackAssetPath, Widget fallback) {
  if (fallbackAssetPath == null || fallbackAssetPath.isEmpty) {
    return fallback;
  }

  return Image.asset(
    fallbackAssetPath,
    package: 'ibul_app',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Image.asset(
      fallbackAssetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    ),
  );
}
