import 'package:flutter/material.dart';

import '../../../widgets/optimized_image.dart';
import '../../helpers/home_feature_ad_helper.dart';
import '../../models/home_card_template.dart';
import 'home_feature_form_card.dart';

class HomeFeatureCampaignInfoSection extends StatelessWidget {
  const HomeFeatureCampaignInfoSection({
    required this.storeName,
    required this.campaignNameController,
    required this.templates,
    required this.selectedTemplate,
    required this.onTemplateChanged,
    super.key,
  });

  final String storeName;
  final TextEditingController campaignNameController;
  final List<HomeCardTemplate> templates;
  final HomeCardTemplate? selectedTemplate;
  final ValueChanged<HomeCardTemplate?> onTemplateChanged;

  @override
  Widget build(BuildContext context) {
    return HomeFeatureFormCard(
      title: 'Kampanya Bilgileri',
      child: Column(
        children: [
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Mağaza adı',
              hintText: storeName,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            controller: TextEditingController(text: storeName),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<HomeCardTemplate>(
            key: ValueKey(selectedTemplate?.id),
            initialValue: selectedTemplate,
            decoration: const InputDecoration(
              labelText: 'Kart / Kategori seçimi',
              border: OutlineInputBorder(),
            ),
            items: templates
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.displayLabel),
                  ),
                )
                .toList(),
            onChanged: templates.isEmpty ? null : onTemplateChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: campaignNameController,
            decoration: const InputDecoration(
              labelText: 'Kampanya adı (opsiyonel)',
              hintText: 'Boş bırakılırsa otomatik oluşturulur',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeFeatureBannerSection extends StatelessWidget {
  const HomeFeatureBannerSection({
    required this.bannerUrls,
    required this.storeBannerOptions,
    required this.onToggleStoreBanner,
    required this.onRemoveBanner,
    required this.onMoveBanner,
    required this.onPickBanner,
    super.key,
  });

  final List<String> bannerUrls;
  final List<String> storeBannerOptions;
  final void Function(String url, bool selected) onToggleStoreBanner;
  final ValueChanged<int> onRemoveBanner;
  final void Function(int from, int to) onMoveBanner;
  final VoidCallback onPickBanner;

  @override
  Widget build(BuildContext context) {
    return HomeFeatureFormCard(
      title: 'Banner Görselleri',
      subtitle:
          'Ana sayfadaki 1200×200 alanında gösterilecek görselleri seçin.',
      trailing: TextButton.icon(
        onPressed: bannerUrls.length >= HomeFeatureAdHelper.maxBannerImages
            ? null
            : onPickBanner,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
        label: const Text('Görsel ekle'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${bannerUrls.length}/${HomeFeatureAdHelper.maxBannerImages} görsel seçildi • Önerilen ölçü: 1200×200 px',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (bannerUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Seçili bannerlar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bannerUrls.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _SelectedBannerChip(
                  url: bannerUrls[i],
                  index: i,
                  total: bannerUrls.length,
                  onRemove: () => onRemoveBanner(i),
                  onMoveLeft: i > 0 ? () => onMoveBanner(i, i - 1) : null,
                  onMoveRight: i < bannerUrls.length - 1
                      ? () => onMoveBanner(i, i + 1)
                      : null,
                ),
              ),
            ),
          ],
          if (storeBannerOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Mağaza duyurusundan seç',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
              ),
              itemCount: storeBannerOptions.length,
              itemBuilder: (_, i) {
                final url = storeBannerOptions[i];
                final selected = bannerUrls.contains(url);
                final disabled = !selected &&
                    bannerUrls.length >= HomeFeatureAdHelper.maxBannerImages;
                return _StoreBannerTile(
                  url: url,
                  selected: selected,
                  disabled: disabled,
                  onTap: () => onToggleStoreBanner(url, selected),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Mağaza duyurusu bulunamadı. Özel görsel yükleyebilirsiniz.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedBannerChip extends StatelessWidget {
  const _SelectedBannerChip({
    required this.url,
    required this.index,
    required this.total,
    required this.onRemove,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final String url;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          OptimizedImage(
            imageUrlOrPath: url,
            width: 200,
            height: 92,
            fit: BoxFit.cover,
            errorWidget: ColoredBox(color: Colors.grey.shade200),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}/$total',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMoveLeft != null)
                  _MiniIconButton(icon: Icons.arrow_back, onTap: onMoveLeft!),
                if (onMoveRight != null)
                  _MiniIconButton(
                      icon: Icons.arrow_forward, onTap: onMoveRight!),
                _MiniIconButton(icon: Icons.close, onTap: onRemove),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}

class _StoreBannerTile extends StatelessWidget {
  const _StoreBannerTile({
    required this.url,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String url;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: OptimizedImage(
                  imageUrlOrPath: url,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: ColoredBox(color: Colors.grey.shade200),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mağaza duyurusu',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFF2563EB),
                    child: Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeFeatureProductSection extends StatelessWidget {
  const HomeFeatureProductSection({
    required this.searchController,
    required this.allProducts,
    required this.filteredProducts,
    required this.selectedProductIds,
    required this.onToggleProduct,
    required this.onMoveProduct,
    super.key,
  });

  final TextEditingController searchController;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> filteredProducts;
  final List<String> selectedProductIds;
  final void Function(String id, bool selected) onToggleProduct;
  final void Function(int from, int to) onMoveProduct;

  @override
  Widget build(BuildContext context) {
    return HomeFeatureFormCard(
      title: 'Öne Çıkarılacak Ürünler',
      subtitle:
          'Ana sayfada reklam kartınızın altında gösterilecek ürünleri seçin.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${selectedProductIds.length} / ${HomeFeatureAdHelper.maxProducts} ürün seçildi',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Ürün veya kategori ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (selectedProductIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seçili sıra',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedProductIds.asMap().entries.map((entry) {
                final id = entry.value;
                final product = allProducts.cast<Map<String, dynamic>?>().firstWhere(
                      (p) => p?['id']?.toString() == id,
                      orElse: () => null,
                    );
                final name = product?['name']?.toString() ?? id;
                final index = entry.key;
                return InputChip(
                  label: Text('${index + 1}. $name', style: const TextStyle(fontSize: 11)),
                  onDeleted: () => onToggleProduct(id, true),
                  deleteIcon: const Icon(Icons.close, size: 16),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          if (filteredProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aramanızla eşleşen ürün bulunamadı.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredProducts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = filteredProducts[i];
                final id = p['id']?.toString() ?? '';
                final selected = selectedProductIds.contains(id);
                final selectedIndex = selectedProductIds.indexOf(id);
                final price = (p['price'] as num?)?.toDouble();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: p['image_url'] != null
                        ? OptimizedImage(
                            imageUrlOrPath: p['image_url'].toString(),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget:
                                ColoredBox(color: Colors.grey.shade100),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image_outlined, size: 20),
                          ),
                  ),
                  title: Text(
                    p['name']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      if (p['sub_category']?.toString().isNotEmpty == true)
                        p['sub_category'].toString(),
                      if (price != null && price > 0)
                        '${price.toStringAsFixed(0)} TRY',
                    ].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected && selectedIndex > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: () =>
                              onMoveProduct(selectedIndex, selectedIndex - 1),
                        ),
                      if (selected &&
                          selectedIndex >= 0 &&
                          selectedIndex < selectedProductIds.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: () =>
                              onMoveProduct(selectedIndex, selectedIndex + 1),
                        ),
                      Checkbox(
                        value: selected,
                        onChanged: (v) => onToggleProduct(id, selected),
                      ),
                    ],
                  ),
                  onTap: () => onToggleProduct(id, selected),
                );
              },
            ),
        ],
      ),
    );
  }
}
