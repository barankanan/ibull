import 'package:flutter/material.dart';

import '../../../widgets/optimized_image.dart';
import '../../helpers/home_feature_ad_helper.dart';
import '../../models/home_card_template.dart';
import 'home_feature_form_card.dart';

class HomeFeatureSummaryItem {
  const HomeFeatureSummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}

class HomeFeatureAdPreviewPanel extends StatefulWidget {
  const HomeFeatureAdPreviewPanel({
    required this.storeName,
    required this.storeLogoUrl,
    required this.selectedTemplate,
    required this.bannerUrls,
    required this.selectedProducts,
    required this.startsAt,
    required this.endsAt,
    required this.durationDays,
    required this.dailyBudget,
    required this.totalBudget,
    required this.estimatedFee,
    required this.estimatedImpressions,
    super.key,
  });

  final String storeName;
  final String? storeLogoUrl;
  final HomeCardTemplate? selectedTemplate;
  final List<String> bannerUrls;
  final List<Map<String, dynamic>> selectedProducts;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationDays;
  final double dailyBudget;
  final double totalBudget;
  final double estimatedFee;
  final int estimatedImpressions;

  @override
  State<HomeFeatureAdPreviewPanel> createState() =>
      _HomeFeatureAdPreviewPanelState();
}

class _HomeFeatureAdPreviewPanelState extends State<HomeFeatureAdPreviewPanel> {
  int _bannerPreviewIndex = 0;

  @override
  void didUpdateWidget(covariant HomeFeatureAdPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_bannerPreviewIndex >= widget.bannerUrls.length) {
      _bannerPreviewIndex = 0;
    }
  }

  String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  String _formatMoney(double value) {
    if (value <= 0) return '-';
    return '${value.toStringAsFixed(0)} TRY';
  }

  List<HomeFeatureSummaryItem> get _summaryItems => [
        HomeFeatureSummaryItem(label: 'Mağaza', value: widget.storeName),
        HomeFeatureSummaryItem(
          label: 'Kart / Kategori',
          value: widget.selectedTemplate?.displayLabel ?? '-',
        ),
        HomeFeatureSummaryItem(
          label: 'Banner',
          value: '${widget.bannerUrls.length}/${HomeFeatureAdHelper.maxBannerImages}',
        ),
        HomeFeatureSummaryItem(
          label: 'Ürün',
          value:
              '${widget.selectedProducts.length}/${HomeFeatureAdHelper.maxProducts}',
        ),
        HomeFeatureSummaryItem(
          label: 'Başlangıç',
          value: _formatDate(widget.startsAt),
        ),
        HomeFeatureSummaryItem(
          label: 'Bitiş',
          value: _formatDate(widget.endsAt),
        ),
        HomeFeatureSummaryItem(
          label: 'Süre',
          value: widget.durationDays > 0
              ? '${widget.durationDays} gün'
              : '-',
        ),
        HomeFeatureSummaryItem(
          label: 'Günlük bütçe',
          value: _formatMoney(widget.dailyBudget),
        ),
        HomeFeatureSummaryItem(
          label: 'Toplam bütçe',
          value: _formatMoney(widget.totalBudget),
        ),
        HomeFeatureSummaryItem(
          label: 'Tahmini ücret',
          value: widget.estimatedFee > 0
              ? '${widget.estimatedFee.toStringAsFixed(0)} TRY (Tahmini)'
              : '-',
        ),
        const HomeFeatureSummaryItem(
          label: 'Durum',
          value: 'Onaya gönderilecek',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final categoryName = widget.selectedTemplate?.categoryName?.trim().isNotEmpty ==
            true
        ? widget.selectedTemplate!.categoryName!.trim()
        : widget.selectedTemplate?.title ?? 'Kategori';

    return Column(
      children: [
        HomeFeatureFormCard(
          title: 'Kampanya Özeti',
          child: Column(
            children: [
              for (final item in _summaryItems) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value.isEmpty ? '-' : item.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        HomeFeatureFormCard(
          title: 'Canlı Önizleme',
          subtitle: 'Ana sayfadaki kategori kartı yerleşimine yakın görünüm.',
          child: _buildHomePreview(categoryName),
        ),
      ],
    );
  }

  Widget _buildHomePreview(String categoryName) {
    final hasContent = widget.bannerUrls.isNotEmpty ||
        widget.selectedProducts.isNotEmpty ||
        widget.storeName.isNotEmpty;

    if (!hasContent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.view_carousel_outlined,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Banner ve ürün seçtikçe önizleme burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final previewProducts = widget.selectedProducts.take(4).toList();
    final activeBanner = widget.bannerUrls.isNotEmpty
        ? widget.bannerUrls[_bannerPreviewIndex.clamp(0, widget.bannerUrls.length - 1)]
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          if (widget.selectedTemplate != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.selectedTemplate!.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildStoreLogoRow(),
          const SizedBox(height: 12),
          if (activeBanner != null)
            AspectRatio(
              aspectRatio: HomeFeatureAdHelper.recommendedBannerAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OptimizedImage(
                  imageUrlOrPath: activeBanner,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  cacheHeight: 100,
                  errorWidget: ColoredBox(color: Colors.grey.shade200),
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: HomeFeatureAdHelper.recommendedBannerAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Banner seçilmedi',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          if (widget.bannerUrls.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.bannerUrls.length, (i) {
                final selected = i == _bannerPreviewIndex;
                return GestureDetector(
                  onTap: () => setState(() => _bannerPreviewIndex = i),
                  child: Container(
                    width: selected ? 10 : 7,
                    height: selected ? 10 : 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${widget.selectedProducts.length} ürün',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previewProducts.isEmpty)
            const Text(
              'Ürün seçilmedi',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previewProducts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = previewProducts[i];
                  final imageUrl = p['image_url']?.toString();
                  return Container(
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? OptimizedImage(
                                  imageUrlOrPath: imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget:
                                      ColoredBox(color: Colors.grey.shade100),
                                )
                              : ColoredBox(color: Colors.grey.shade100),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            p['name']?.toString() ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreLogoRow() {
    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
                child: ClipOval(
                  child: widget.storeLogoUrl != null &&
                          widget.storeLogoUrl!.isNotEmpty
                      ? OptimizedImage(
                          imageUrlOrPath: widget.storeLogoUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: _storeInitial(),
                        )
                      : _storeInitial(),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: Text(
                  widget.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeInitial() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          widget.storeName.isNotEmpty
              ? widget.storeName[0].toUpperCase()
              : '?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
