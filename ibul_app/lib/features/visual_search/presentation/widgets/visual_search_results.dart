import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../models/product_model.dart';
import '../../../../screens/home_lazy_routes.dart';
import '../../data/visual_search_image_memory.dart';
import '../../domain/visual_search_models.dart';
import 'visual_search_states.dart';

class VisualSearchResultSummary extends StatelessWidget {
  const VisualSearchResultSummary({super.key, required this.job});

  final VisualSearchJob job;

  @override
  Widget build(BuildContext context) {
    final analysis = job.analysis;
    final confidence = ((analysis?.confidence ?? 0) * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.jobType.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              VisualSearchStatusChip.forStatus(job.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis?.summary ?? visualSearchSummaryLine(job),
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Güven skoru %$confidence',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (analysis?.usedMock == true) ...[
            const SizedBox(height: 8),
            const Text(
              'Ön izleme analizi. Gerçek model bağlandığında aynı sonuç alanı kullanılacak.',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
        ],
      ),
    );
  }
}

class VisualSearchMarkOverlay extends StatelessWidget {
  const VisualSearchMarkOverlay({super.key, required this.job});

  final VisualSearchJob job;

  @override
  Widget build(BuildContext context) {
    final analysis = job.analysis;
    final boxes = <_Mark>[
      for (final damage in analysis?.damages ?? const <DamageDetection>[])
        _Mark(damage.bbox, AppColors.danger, damage.label),
      for (final part in analysis?.missingParts ?? const <MissingPartDetection>[])
        _Mark(part.bbox, AppColors.primary, part.partName),
    ];
    final bytes = VisualSearchImageMemory.get(job.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İşaretleme',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ImageLayer(bytes: bytes),
                    for (final mark in boxes)
                      Positioned(
                        left: mark.box.x * constraints.maxWidth,
                        top: mark.box.y * constraints.maxHeight,
                        width: mark.box.width * constraints.maxWidth,
                        height: mark.box.height * constraints.maxHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: mark.color.withValues(alpha: 0.16),
                            border: Border.all(color: mark.color, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mark in boxes)
              VisualSearchStatusChip(label: mark.label, color: mark.color),
          ],
        ),
      ],
    );
  }
}

class VisualSearchFindingList extends StatelessWidget {
  const VisualSearchFindingList({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class VisualSearchFindingTile extends StatelessWidget {
  const VisualSearchFindingTile({
    super.key,
    required this.title,
    required this.detail,
    required this.confidence,
  });

  final String title;
  final String detail;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '%${(confidence * 100).round()}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class VisualSearchMatchCard extends StatelessWidget {
  const VisualSearchMatchCard({super.key, required this.match, this.onOpen});

  final ProductMatch match;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (match.matchType) {
      ProductMatchType.exact => 'Aynı ürün',
      ProductMatchType.similar => 'Benzer',
      ProductMatchType.alternative => 'Alternatif',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.softPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.brand} · ${match.store}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                const SizedBox(height: 6),
                Text(
                  match.price,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              VisualSearchStatusChip(
                label: typeLabel,
                color: AppColors.primary,
                background: AppColors.softPurple,
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onOpen, child: const Text('Ürüne git')),
            ],
          ),
        ],
      ),
    );
  }
}

class VisualSearchFeedbackRow extends StatelessWidget {
  const VisualSearchFeedbackRow({super.key, required this.onFeedback});

  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Bu sonuç yardımcı oldu mu?',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
        IconButton(
          tooltip: 'Yararlı',
          onPressed: () => onFeedback('helpful'),
          icon: const Icon(Icons.thumb_up_alt_outlined, color: AppColors.primary),
        ),
        IconButton(
          tooltip: 'Yararsız',
          onPressed: () => onFeedback('not_helpful'),
          icon: const Icon(Icons.thumb_down_alt_outlined, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

Future<void> openVisualSearchProduct(
  BuildContext context,
  ProductMatch match,
) async {
  if (match.productId.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu ürün için detay bağlantısı yok.')),
    );
    return;
  }
  final product = Product(
    productId: match.productId,
    name: match.name,
    brand: match.brand.isEmpty ? 'İBUL' : match.brand,
    price: match.price.isEmpty ? '—' : match.price,
    rating: match.rating,
    reviewCount: match.reviewCount,
    tags: const [],
    images: match.imageUrl.isEmpty ? const [] : [match.imageUrl],
    store: match.store,
    category: match.category,
  );
  await HomeLazyRoutes.openProductDetail(context, product);
}

class _Mark {
  const _Mark(this.box, this.color, this.label);

  final BoundingBox box;
  final Color color;
  final String label;
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Icon(Icons.image_outlined, color: AppColors.primary, size: 36),
        ),
      );
    }
    return Image.memory(bytes!, fit: BoxFit.cover);
  }
}
