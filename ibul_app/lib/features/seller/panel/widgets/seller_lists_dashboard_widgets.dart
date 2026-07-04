import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/models/product_list_model.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/services/store_service.dart';
import 'package:ibul_app/widgets/image_cropper_widget.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants.dart';

abstract final class SellerListsDashboardTokens {
  static const cardRadius = 14.0;
  static const cardBorder = Color(0xFFE5E7EB);
  static const cardShadow = Color(0x08000000);
  static const pageGap = 14.0;
  static const inputBorder = Color(0xFFE2E8F0);
}

const double kListCoverAspectRatio = 1200 / 450;
const int kListCoverMaxUploadBytes = 5 * 1024 * 1024;
const String kSellerListCoverGuidanceText =
    'Önerilen: 1200 × 450 px · Minimum: 800 × 300 px · Format: JPG / PNG / WebP · Oran: 8:3';

class SellerListMetricItem {
  const SellerListMetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;
}

List<SellerListMetricItem> buildSellerListMetrics({
  required int totalLists,
  required int addableProducts,
  required int publicLists,
  required int campaignReadyLists,
  String? productsSubtitle,
}) {
  return [
    SellerListMetricItem(
      title: 'Toplam Liste',
      value: '$totalLists',
      icon: Icons.collections_bookmark_outlined,
      accent: AppColors.primary,
      subtitle: 'Oluşturduğunuz koleksiyonlar',
    ),
    SellerListMetricItem(
      title: 'Listeye Eklenebilir Ürün',
      value: '$addableProducts',
      icon: Icons.inventory_2_outlined,
      accent: const Color(0xFF0EA5E9),
      subtitle: productsSubtitle ?? 'Mağaza ürünleri',
    ),
    SellerListMetricItem(
      title: 'Yayında / Açık Liste',
      value: '$publicLists',
      icon: Icons.public_outlined,
      accent: const Color(0xFF059669),
      subtitle: 'Herkese açık listeler',
    ),
    SellerListMetricItem(
      title: 'Kampanyada Kullanılabilir',
      value: '$campaignReadyLists',
      icon: Icons.campaign_outlined,
      accent: const Color(0xFFD97706),
      subtitle: 'Ürün içeren listeler',
    ),
  ];
}

class SellerListsHeader extends StatelessWidget {
  const SellerListsHeader({
    super.key,
    required this.totalLists,
    required this.onCreateList,
    this.onRefresh,
  });

  final int totalLists;
  final VoidCallback onCreateList;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerListsDashboardTokens.cardRadius),
        border: Border.all(color: SellerListsDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SellerListsDashboardTokens.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listeler',
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ürünlerinizi koleksiyonlar halinde gruplandırın ve kampanyalarda kullanın.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$totalLists liste',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF475569),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: onCreateList,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Liste Oluştur'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class SellerListMetricGrid extends StatelessWidget {
  const SellerListMetricGrid({super.key, required this.metrics});

  final List<SellerListMetricItem> metrics;

  int _columnsForWidth(double width) {
    if (width >= 1100) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : itemWidth,
                  child: _SellerListMetricCard(item: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SellerListMetricCard extends StatelessWidget {
  const _SellerListMetricCard({required this.item});

  final SellerListMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerListsDashboardTokens.cardRadius),
        border: Border.all(color: SellerListsDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SellerListsDashboardTokens.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 15, color: item.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class ListsEmptyState extends StatelessWidget {
  const ListsEmptyState({super.key, required this.onCreateList});

  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerListsDashboardTokens.cardRadius),
        border: Border.all(color: SellerListsDashboardTokens.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.collections_bookmark_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Henüz liste oluşturmadınız',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ürünlerinizi koleksiyonlar halinde gruplandırarak kampanyalarda kullanabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateList,
            icon: const Icon(Icons.add_rounded),
            label: const Text('İlk Listeyi Oluştur'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerListCard extends StatelessWidget {
  const SellerListCard({
    super.key,
    required this.list,
    required this.onAddProducts,
    required this.onEdit,
    required this.onDelete,
    required this.onBoost,
    required this.onRemoveProduct,
  });

  final ProductList list;
  final VoidCallback onAddProducts;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBoost;
  final void Function(Product product) onRemoveProduct;

  @override
  Widget build(BuildContext context) {
    final productCount = list.productCount;
    final visibleProducts = list.products.take(3).toList(growable: false);
    final extraCount = list.products.length > 3 ? list.products.length - 3 : 0;
    final statusLabel = list.isPublic ? 'Açık' : 'Gizli';
    final statusColor =
        list.isPublic ? const Color(0xFF059669) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SellerListsDashboardTokens.cardRadius),
        border: Border.all(color: SellerListsDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: SellerListsDashboardTokens.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: kListCoverAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCoverImage(),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _statusChip(statusLabel, statusColor),
                ),
                if (productCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBoost,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_outlined,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Öne çıkar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (list.description ?? '').trim().isEmpty
                      ? 'Açıklama eklenmedi.'
                      : list.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.inventory_2_outlined, '$productCount ürün'),
                    if ((list.category ?? '').trim().isNotEmpty)
                      _metaChip(Icons.category_outlined, list.category!),
                    _metaChip(
                      Icons.schedule_outlined,
                      '${list.updatedAt.day.toString().padLeft(2, '0')}.${list.updatedAt.month.toString().padLeft(2, '0')}.${list.updatedAt.year}',
                    ),
                  ],
                ),
                if (visibleProducts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...visibleProducts.map(
                        (product) => _productChip(
                          product.name,
                          () => onRemoveProduct(product),
                        ),
                      ),
                      if (extraCount > 0)
                        _metaChip(Icons.more_horiz, '+$extraCount ürün'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onAddProducts,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('Ürün ekle'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Düzenle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Sil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    if ((list.iconUrl ?? '').trim().isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'Kapak görseli yok',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    return OptimizedImage(
      imageUrlOrPath: list.iconUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

InputDecoration sellerListInputDecoration({
  required String hint,
  String? errorText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: SellerListsDashboardTokens.inputBorder),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    errorText: errorText,
    filled: true,
    fillColor: const Color(0xFFFCFCFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
  );
}

const TextStyle sellerListFieldLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF475569),
);

typedef SellerListPersistCallback = Future<void> Function({
  required String name,
  required String description,
  required ProductListVisibility visibility,
  required String? coverUrl,
  required bool isCreate,
  String? listId,
});

class SellerListEditDialog extends StatefulWidget {
  const SellerListEditDialog({
    super.key,
    this.existingList,
    required this.storeService,
    required this.picker,
    required this.onPersist,
  });

  final ProductList? existingList;
  final StoreService storeService;
  final ImagePicker picker;
  final SellerListPersistCallback onPersist;

  @override
  State<SellerListEditDialog> createState() => _SellerListEditDialogState();
}

class _SellerListEditDialogState extends State<SellerListEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late ProductListVisibility _visibility;
  String? _remoteCoverUrl;
  Uint8List? _localCoverBytes;
  bool _coverCleared = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isCreate => widget.existingList == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingList;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _visibility = existing?.visibility ?? ProductListVisibility.private;
    _remoteCoverUrl = existing?.iconUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropCover() async {
    final picked = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > kListCoverMaxUploadBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görsel çok büyük. Lütfen 5 MB altında bir dosya seçin.'),
        ),
      );
      return;
    }

    Uint8List? croppedBytes;
    if (!kIsWeb) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (cropContext) => ImageCropperWidget(
          imageData: bytes,
          aspectRatio: kListCoverAspectRatio,
          suggestedWidth: 600,
          title: 'Liste görselini kırpın',
          helpText:
              'Liste banner oranı 8:3 (1200×450 px). Yatay görseli sürükleyip yakınlaştırarak kırpın.',
          onCropped: (data) => croppedBytes = data,
        ),
      );
      if (croppedBytes == null) return;
    } else {
      croppedBytes = bytes;
    }

    setState(() {
      _localCoverBytes = croppedBytes;
      _coverCleared = false;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Liste adı girmelisiniz.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String? resolvedCoverUrl = _coverCleared ? null : _remoteCoverUrl;
      if (_localCoverBytes != null) {
        resolvedCoverUrl = await widget.storeService.uploadStoreImageBytes(
          _localCoverBytes!,
          'product-list-covers',
          fileName: 'list-cover-${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      await widget.onPersist(
        name: name,
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        coverUrl: resolvedCoverUrl,
        isCreate: _isCreate,
        listId: widget.existingList?.id,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _isCreate
            ? 'Liste oluşturulamadı: $error'
            : 'Liste güncellenemedi: $error';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= 720 ? 600.0 : width * 0.94;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCreate ? 'Yeni liste' : 'Listeyi düzenle',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Liste bilgilerini ve görselini güncelleyin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildImageSection(),
                    const SizedBox(height: 16),
                    const Text('Liste bilgileri', style: sellerListFieldLabelStyle),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Liste adı *', style: sellerListFieldLabelStyle),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: sellerListInputDecoration(
                            hint: 'Örn: Yaz Fırsatları',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Açıklama', style: sellerListFieldLabelStyle),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: sellerListInputDecoration(
                            hint: 'Listenizi kısaca anlatın',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Görünürlük', style: sellerListFieldLabelStyle),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ProductListVisibility>(
                          initialValue: _visibility,
                          decoration: sellerListInputDecoration(hint: 'Seçin'),
                          items: const [
                            DropdownMenuItem(
                              value: ProductListVisibility.private,
                              child: Text('Gizli (Özel)'),
                            ),
                            DropdownMenuItem(
                              value: ProductListVisibility.public,
                              child: Text('Herkese açık'),
                            ),
                          ],
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _visibility = value);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 420;
                  final cancel = OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    child: const Text('Vazgeç'),
                  );
                  final save = FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_isCreate ? Icons.add_rounded : Icons.save_rounded,
                            size: 16),
                    label: Text(
                      _isSaving
                          ? (_isCreate ? 'Oluşturuluyor...' : 'Kaydediliyor...')
                          : (_isCreate ? 'Liste oluştur' : 'Kaydet'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cancel, const SizedBox(height: 8), save],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 8), save],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final hasPreview =
        !_coverCleared &&
        (_localCoverBytes != null ||
            (_remoteCoverUrl ?? '').trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Liste görseli', style: sellerListFieldLabelStyle),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: kListCoverAspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!hasPreview)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 34, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        'Kapak görseli seçin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  )
                else if (_localCoverBytes != null)
                  Image.memory(_localCoverBytes!, fit: BoxFit.cover)
                else
                  OptimizedImage(
                    imageUrlOrPath: _remoteCoverUrl!,
                    fit: BoxFit.cover,
                  ),
                if (hasPreview)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kSellerListCoverGuidanceText,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickAndCropCover,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(_isCreate ? 'Görsel seç' : 'Görseli değiştir'),
            ),
            if (_localCoverBytes != null)
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickAndCropCover,
                icon: const Icon(Icons.crop_rounded, size: 16),
                label: const Text('Kırp'),
              ),
            if (hasPreview)
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                          _localCoverBytes = null;
                          _remoteCoverUrl = null;
                          _coverCleared = true;
                        }),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Kaldır'),
              ),
          ],
        ),
      ],
    );
  }
}
