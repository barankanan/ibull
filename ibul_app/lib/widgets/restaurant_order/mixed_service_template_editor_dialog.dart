import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/mixed_service_order.dart';
import '../../models/product_pricing.dart';
import '../../models/seller_product.dart';
import '../optimized_image.dart';

enum MixedServiceTemplateSubmitAction { draft, publish }

class MixedServiceTemplateEditorResult {
  const MixedServiceTemplateEditorResult({
    required this.action,
    required this.templateProductType,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.pricingMode,
    required this.fixedPrice,
    required this.templateItems,
  });

  final MixedServiceTemplateSubmitAction action;
  final String templateProductType;
  final String name;
  final String description;
  final String? coverImageUrl;
  final String pricingMode;
  final double fixedPrice;
  final List<Map<String, dynamic>> templateItems;
}

Future<MixedServiceTemplateEditorResult?> showMixedServiceTemplateEditorDialog({
  required BuildContext context,
  required List<SellerProduct> products,
  SellerProduct? initialProduct,
  String templateProductType = MixedServiceOrder.serviceTemplateProductType,
}) {
  return showDialog<MixedServiceTemplateEditorResult>(
    context: context,
    builder: (dialogContext) {
      return _MixedServiceTemplateEditorDialog(
        products: products,
        initialProduct: initialProduct,
        templateProductType: templateProductType,
      );
    },
  );
}

class _MixedServiceTemplateEditorDialog extends StatefulWidget {
  const _MixedServiceTemplateEditorDialog({
    required this.products,
    this.initialProduct,
    required this.templateProductType,
  });

  final List<SellerProduct> products;
  final SellerProduct? initialProduct;
  final String templateProductType;

  @override
  State<_MixedServiceTemplateEditorDialog> createState() =>
      _MixedServiceTemplateEditorDialogState();
}

class _MixedServiceTemplateEditorDialogState
    extends State<_MixedServiceTemplateEditorDialog> {
  late final TextEditingController _searchController;
  late final TextEditingController _nameController;
  final Map<String, _TemplateChildDraft> _selectedItems =
      <String, _TemplateChildDraft>{};
  final Map<String, _TemplateChildDraft> _selectionDrafts =
      <String, _TemplateChildDraft>{};
  String _searchQuery = '';
  String _pricingMode = MixedServiceOrder.autoSumPriceMode;
  String? _coverProductId;

  String get _resolvedTemplateProductType => widget.initialProduct == null
      ? MixedServiceOrder.normalizeTemplateProductType(
          widget.templateProductType,
        )
      : MixedServiceOrder.productTypeFromProduct(widget.initialProduct!);

  bool get _isMenuTemplate =>
      _resolvedTemplateProductType == MixedServiceOrder.menuTemplateProductType;

  String get _templateTypeLabel => _isMenuTemplate ? 'Menü' : 'Servis';

  String get _titleText {
    if (widget.initialProduct != null) {
      return _isMenuTemplate ? 'Menüyü Düzenle' : 'Servisi Düzenle';
    }
    return _isMenuTemplate ? 'Menü Oluştur' : 'Servis Oluştur';
  }

  String get _subtitleText => _isMenuTemplate
      ? 'Hazır set ürününü oluşturun. Garson ekranında tek tuşla taslağa eklensin.'
      : 'Seçilebilir ürün havuzunu oluşturun. Garson ekranında ürünler tek tek seçilsin.';

  String get _nameFieldLabel => _isMenuTemplate ? 'Menü adı' : 'Servis adı';

  String get _nameFieldHint => _isMenuTemplate
      ? 'Örn: Izgara Karışık Menü'
      : 'Örn: Serpme Kahvaltı Servisi';

  String get _listTitle =>
      _isMenuTemplate ? 'Dahil Ürünler' : 'Seçilebilir Ürün Havuzu';

  String get _listSubtitle => _isMenuTemplate
      ? 'Eklemeden önce porsiyon veya gramaj seçimi yapılır. Garson ekranında bu set tek seferde siparişe gelir.'
      : 'Buradaki ürünler servis açıldığında tek tek seçilir. Porsiyon ve gramaj sipariş anında düzenlenir.';

  String get _selectedPillLabel => _isMenuTemplate ? 'Menüde' : 'Havuzda';

  String get _addButtonLabel => _isMenuTemplate ? 'Menüye Ekle' : 'Havuza Ekle';

  String get _summaryTotalLabel =>
      _isMenuTemplate ? 'Menü Toplamı' : 'Servis Önizleme Toplamı';

  String get _serviceFlowInfoText =>
      'Servis kurgusu bu havuz üzerinden çalışır. Ürünler garson ekranında doğrudan eklenmez; seçim yapıldıktan sonra siparişe girer.';

  List<SellerProduct> get _selectableProducts =>
      widget.products
          .where((product) => !MixedServiceOrder.isTemplateProduct(product))
          .where((product) {
            final query = _searchQuery.trim().toLowerCase();
            if (query.isEmpty) return true;
            final haystack = [
              product.name,
              product.mainCategory,
              product.subCategory,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          })
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<SellerProduct> get _selectedProducts => widget.products
      .where((product) => _selectedItems.containsKey(product.id))
      .toList(growable: false);

  double get _currentTotal {
    return _selectedProducts.fold<double>(0, (sum, product) {
      final draft = _selectedItems[product.id];
      if (draft == null) return sum;
      final double unitPrice;
      if (!product.usesPortionLikeStepper &&
          product.resolvedPricingType == ProductPricingType.portion) {
        unitPrice =
            product.effectiveBaseUnitPrice *
            (draft.selectedServiceAmount ?? 1.0);
      } else {
        unitPrice = MixedServiceOrder.productUnitPriceForSelection(
          product,
          selectedServiceAmount: draft.selectedServiceAmount,
          selectedWeightGrams: draft.selectedWeightGrams,
        );
      }
      return sum + (unitPrice * draft.quantity);
    });
  }

  bool get _canSubmit {
    if (_nameController.text.trim().isEmpty) return false;
    return _selectedItems.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _nameController = TextEditingController(
      text: widget.initialProduct?.name ?? '',
    );

    final templateConfig = widget.initialProduct == null
        ? null
        : MixedServiceOrder.templateConfigFromProduct(widget.initialProduct!);
    _pricingMode = _isMenuTemplate
        ? MixedServiceOrder.normalizeTemplatePricingMode(
            templateConfig?['pricing_mode']?.toString(),
          )
        : (templateConfig?['pricing_mode']?.toString().trim().isNotEmpty ??
              false)
        ? templateConfig!['pricing_mode'].toString().trim()
        : MixedServiceOrder.autoSumPriceMode;

    for (final item in MixedServiceOrder.normalizeTemplateItems(
      templateConfig?['template_items'],
    )) {
      final productId = item['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      _selectedItems[productId] = _TemplateChildDraft(
        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        selectedServiceAmount:
            (item['selected_portion_value'] as num?)?.toDouble() ??
            (item['selected_service_amount'] as num?)?.toDouble() ??
            (item['selectedServiceAmount'] as num?)?.toDouble(),
        selectedWeightGrams:
            (item['selected_weight_grams'] as num?)?.toInt() ??
            (item['selectedWeightGrams'] as num?)?.toInt(),
        serviceRound: MixedServiceOrder.normalizeServiceRound(
          item['service_round'],
        ),
        note: item['note']?.toString() ?? '',
      );
    }

    _coverProductId = _initialCoverProductId();
    _nameController.addListener(() {
      setState(() {});
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  String? _initialCoverProductId() {
    final initialUrl = widget.initialProduct?.imageUrl?.trim() ?? '';
    if (initialUrl.isNotEmpty) {
      for (final product in widget.products) {
        if ((product.imageUrl?.trim() ?? '') == initialUrl) {
          return product.id;
        }
      }
    }
    for (final product in _selectedProducts) {
      if ((product.imageUrl?.trim() ?? '').isNotEmpty) {
        return product.id;
      }
    }
    return _selectedProducts.isEmpty ? null : _selectedProducts.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  _TemplateChildDraft _selectionDraftForProduct(SellerProduct product) {
    final existingSelection = _selectionDrafts[product.id];
    if (existingSelection != null) {
      return existingSelection;
    }
    final selectedItem = _selectedItems[product.id];
    double? defaultServiceAmount;
    if (product.usesPortionLikeStepper) {
      defaultServiceAmount =
          selectedItem?.selectedServiceAmount ??
          product.resolvedDefaultServiceAmount;
    } else if (product.resolvedPricingType == ProductPricingType.portion) {
      defaultServiceAmount = selectedItem?.selectedServiceAmount ?? 1.0;
    }
    int? defaultWeightGrams;
    if (product.resolvedServiceControlType ==
        ProductServiceControlType.weightStepper) {
      defaultWeightGrams =
          selectedItem?.selectedWeightGrams ??
          product.resolvedDefaultWeightGrams;
    }
    final created = _TemplateChildDraft(
      quantity: 1,
      selectedServiceAmount: defaultServiceAmount,
      selectedWeightGrams: defaultWeightGrams,
    );
    _selectionDrafts[product.id] = created;
    return created;
  }

  void _updateSelectionDraft(
    SellerProduct product, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    final current = _selectionDraftForProduct(product);
    final isPortionType =
        product.usesPortionLikeStepper ||
        product.resolvedPricingType == ProductPricingType.portion;
    setState(() {
      _selectionDrafts[product.id] = current.copyWith(
        quantity: 1,
        selectedServiceAmount: isPortionType ? selectedServiceAmount : null,
        selectedWeightGrams:
            product.resolvedServiceControlType ==
                ProductServiceControlType.weightStepper
            ? selectedWeightGrams
            : null,
      );
    });
  }

  void _changeSelectionPreset(SellerProduct product, int delta) {
    if (product.usesPortionLikeStepper) {
      final currentDraft = _selectionDraftForProduct(product);
      final options = ProductPriceCalculator.buildPresetPortionOptions(
        type: product.resolvedServiceControlType,
        minPortion: product.minPortion,
        maxPortion: product.maxPortion,
        portionStep: product.portionStep,
      );
      final currentValue =
          currentDraft.selectedServiceAmount ??
          product.resolvedDefaultServiceAmount;
      var currentIndex = options.indexWhere(
        (value) => (value - currentValue).abs() < 0.001,
      );
      if (currentIndex < 0) currentIndex = 0;
      final nextIndex = (currentIndex + delta).clamp(0, options.length - 1);
      _updateSelectionDraft(product, selectedServiceAmount: options[nextIndex]);
      return;
    }

    if (product.resolvedPricingType == ProductPricingType.portion) {
      const options = [0.5, 1.0, 1.5, 2.0];
      final currentValue =
          _selectionDraftForProduct(product).selectedServiceAmount ?? 1.0;
      var currentIndex = options.indexWhere(
        (v) => (v - currentValue).abs() < 0.001,
      );
      if (currentIndex < 0) currentIndex = 1;
      final nextIndex = (currentIndex + delta).clamp(0, options.length - 1);
      _updateSelectionDraft(product, selectedServiceAmount: options[nextIndex]);
      return;
    }

    if (product.resolvedServiceControlType ==
        ProductServiceControlType.weightStepper) {
      final currentDraft = _selectionDraftForProduct(product);
      final options = ProductPriceCalculator.buildPresetWeightOptions(
        minWeightGrams: product.minWeightGrams,
        defaultWeightGrams: product.defaultWeightGrams,
        weightStepGrams: product.weightStepGrams,
        maxWeightGrams: product.maxWeightGrams,
      );
      final currentValue =
          currentDraft.selectedWeightGrams ??
          product.resolvedDefaultWeightGrams;
      var currentIndex = options.indexOf(currentValue);
      if (currentIndex < 0) currentIndex = 0;
      final nextIndex = (currentIndex + delta).clamp(0, options.length - 1);
      _updateSelectionDraft(product, selectedWeightGrams: options[nextIndex]);
    }
  }

  void _addCurrentSelectionToMenu(SellerProduct product) {
    final pending = _selectionDraftForProduct(product);
    final existing = _selectedItems[product.id];
    // setState her zaman burada çağrılır; _canSubmit yeniden hesaplanır.
    setState(() {
      _selectedItems[product.id] = (existing ?? const _TemplateChildDraft())
          .copyWith(
            quantity: existing?.quantity ?? 1,
            selectedServiceAmount: pending.selectedServiceAmount,
            selectedWeightGrams: pending.selectedWeightGrams,
          );
      _coverProductId ??= product.id;
    });
  }

  void _removeFromMenu(SellerProduct product) {
    // setState burada da çağrılır; _canSubmit seçili liste değişince güncellenir.
    setState(() {
      _selectedItems.remove(product.id);
      if (_coverProductId == product.id) {
        _coverProductId = _selectedProducts
            .where((p) => p.id != product.id)
            .cast<SellerProduct?>()
            .firstWhere(
              (p) => (p?.imageUrl?.trim() ?? '').isNotEmpty,
              orElse: () => null,
            )
            ?.id;
      }
    });
  }

  double _previewUnitPriceForProduct(SellerProduct product) {
    final draft = _selectionDraftForProduct(product);
    if (!product.usesPortionLikeStepper &&
        product.resolvedPricingType == ProductPricingType.portion) {
      final amount = draft.selectedServiceAmount ?? 1.0;
      return product.effectiveBaseUnitPrice * amount;
    }
    return MixedServiceOrder.productUnitPriceForSelection(
      product,
      selectedServiceAmount: draft.selectedServiceAmount,
      selectedWeightGrams: draft.selectedWeightGrams,
    );
  }

  String _previewSelectionLabelForProduct(SellerProduct product) {
    final draft = _selectionDraftForProduct(product);
    return MixedServiceOrder.productAmountLabelForSelection(
      product,
      selectedServiceAmount: draft.selectedServiceAmount,
      selectedWeightGrams: draft.selectedWeightGrams,
    );
  }

  String _basePriceLabelForProduct(SellerProduct product) {
    if (product.resolvedServiceControlType ==
        ProductServiceControlType.weightStepper) {
      return ProductPriceCalculator.formatPerKgLabel(product.pricePerKg);
    }
    final basePrice = product.effectiveBaseUnitPrice;
    return ProductPriceCalculator.formatCurrency(basePrice);
  }

  Widget _buildSelectionStepper(SellerProduct product) {
    final isImplicitPortion =
        !product.usesServiceControlStepper &&
        product.resolvedPricingType == ProductPricingType.portion;
    if (!product.usesServiceControlStepper && !isImplicitPortion) {
      return const _InfoPill(label: 'Standart');
    }
    final String label;
    final String caption;
    if (isImplicitPortion) {
      final amount =
          _selectionDraftForProduct(product).selectedServiceAmount ?? 1.0;
      label = ProductPriceCalculator.formatPortionLabel(amount);
      caption = 'Porsiyon';
    } else {
      label = _previewSelectionLabelForProduct(product);
      caption =
          product.resolvedServiceControlType ==
              ProductServiceControlType.weightStepper
          ? 'Gramaj'
          : 'Porsiyon';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          _StepperButton(
            icon: Icons.remove,
            onTap: () => _changeSelectionPreset(product, -1),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 92),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.isEmpty ? '1 Porsiyon' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: () => _changeSelectionPreset(product, 1),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _templateItemsForSubmit() {
    return _selectedProducts
        .map((product) {
          final draft = _selectedItems[product.id]!;
          final payload = MixedServiceOrder.buildChildItemPayload(
            product,
            quantity: draft.quantity,
            selectedServiceAmount: draft.selectedServiceAmount,
            selectedWeightGrams: draft.selectedWeightGrams,
            serviceRound: draft.serviceRound,
            note: draft.note.trim(),
          );
          double unitPriceSnapshot = MixedServiceOrder.parsePrice(
            payload['unit_price'],
          );
          if (!product.usesPortionLikeStepper &&
              product.resolvedPricingType == ProductPricingType.portion) {
            final amount = draft.selectedServiceAmount ?? 1.0;
            unitPriceSnapshot = product.effectiveBaseUnitPrice * amount;
          }
          final safeQty = draft.quantity <= 0 ? 1 : draft.quantity;
          return <String, dynamic>{
            ...payload,
            'unit_price': unitPriceSnapshot,
            'unit_price_snapshot': unitPriceSnapshot,
            'line_total': unitPriceSnapshot * safeQty,
          };
        })
        .toList(growable: false);
  }

  String? _coverImageUrl() {
    if (_coverProductId == null) return null;
    final product = widget.products.cast<SellerProduct?>().firstWhere(
      (candidate) => candidate?.id == _coverProductId,
      orElse: () => null,
    );
    final imageUrl = product?.imageUrl?.trim() ?? '';
    return imageUrl.isEmpty ? null : imageUrl;
  }

  void _submit(MixedServiceTemplateSubmitAction action) {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      MixedServiceTemplateEditorResult(
        action: action,
        templateProductType: _resolvedTemplateProductType,
        name: _nameController.text.trim(),
        description: widget.initialProduct?.description?.trim() ?? '',
        coverImageUrl: _coverImageUrl(),
        pricingMode: _isMenuTemplate
            ? _pricingMode
            : widget.initialProduct == null
            ? MixedServiceOrder.autoSumPriceMode
            : _pricingMode,
        fixedPrice: _currentTotal,
        templateItems: _templateItemsForSubmit(),
      ),
    );
  }

  String _pricingModeLabel(String pricingMode) {
    switch (pricingMode) {
      case MixedServiceOrder.autoSumPriceMode:
        return 'Otomatik';
      case MixedServiceOrder.manualAllowedPriceMode:
        return 'Manuel';
      default:
        return 'Otomatik';
    }
  }

  String _formatMoney(double amount) {
    return '₺${amount.toStringAsFixed(2)}';
  }

  Widget _buildProductListSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _listTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _listSubtitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectableProducts.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              final product = _selectableProducts[index];
              final draft = _selectedItems[product.id];
              final imageUrl = product.imageUrl?.trim() ?? '';
              final previewPrice = _previewUnitPriceForProduct(product);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final content = <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isEmpty
                            ? Container(
                                width: 52,
                                height: 52,
                                color: const Color(0xFFE5E7EB),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.fastfood_rounded,
                                  size: 20,
                                  color: Color(0xFF9CA3AF),
                                ),
                              )
                            : OptimizedImage(
                                imageUrlOrPath: imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                if (!compact && draft != null)
                                  _InfoPill(label: _selectedPillLabel),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.subCategory.trim().isEmpty ? product.mainCategory : '${product.mainCategory} • ${product.subCategory}'} • Baz: ${_basePriceLabelForProduct(product)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (!compact) _buildSelectionStepper(product),
                                if (!compact)
                                  _InfoPill(
                                    label: _formatMoney(previewPrice),
                                    emphasized: true,
                                  ),
                                if (draft != null)
                                  _InfoPill(label: _selectedPillLabel),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: compact ? 108 : 132,
                        child: draft != null
                            ? OutlinedButton(
                                onPressed: () => _removeFromMenu(product),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Çıkar',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    _addCurrentSelectionToMenu(product),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  _addButtonLabel,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: content.take(3).toList(growable: false),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildSelectionStepper(product)),
                              const SizedBox(width: 10),
                              _InfoPill(
                                label: _formatMoney(previewPrice),
                                emphasized: true,
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 120,
                                child: draft != null
                                    ? OutlinedButton(
                                        onPressed: () =>
                                            _removeFromMenu(product),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Çıkar'),
                                      )
                                    : FilledButton(
                                        onPressed: () =>
                                            _addCurrentSelectionToMenu(product),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: Text(_addButtonLabel),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: content,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalInset = screenWidth > 1200
        ? 96.0
        : screenWidth > 800
        ? 36.0
        : 12.0;
    return Dialog(
      backgroundColor: const Color(0xFFF7F7FC),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 900),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_isMenuTemplate
                                              ? const Color(0xFF0F766E)
                                              : AppColors.primary)
                                          .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _templateTypeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _isMenuTemplate
                                        ? const Color(0xFF0F766E)
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _subtitleText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: _nameFieldLabel,
                        hintText: _nameFieldHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (_isMenuTemplate) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            const <String>[
                                  MixedServiceOrder.autoSumPriceMode,
                                  MixedServiceOrder.manualAllowedPriceMode,
                                ]
                                .map((mode) {
                                  final selected = _pricingMode == mode;
                                  return ChoiceChip(
                                    label: Text(_pricingModeLabel(mode)),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _pricingMode = mode;
                                      });
                                    },
                                  );
                                })
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _pricingMode ==
                                  MixedServiceOrder.manualAllowedPriceMode
                              ? 'Menü toplamı child item fiyatlarından hesaplanır, siparişte manuel fiyat override açık kalır.'
                              : 'Menü fiyatı child item toplamlarından otomatik hesaplanır.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _serviceFlowInfoText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Ürün ara',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildProductListSection(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7FC),
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _summaryTotalLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        Text(
                          _formatMoney(_currentTotal),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _canSubmit
                              ? () => _submit(
                                  MixedServiceTemplateSubmitAction.draft,
                                )
                              : null,
                          icon: const Icon(Icons.drafts_outlined),
                          label: const Text('Taslak Kaydet'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _canSubmit
                              ? () => _submit(
                                  MixedServiceTemplateSubmitAction.publish,
                                )
                              : null,
                          icon: const Icon(Icons.publish_rounded),
                          label: const Text('Yayınla'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChildDraft {
  const _TemplateChildDraft({
    this.quantity = 1,
    this.selectedServiceAmount,
    this.selectedWeightGrams,
    this.serviceRound = 1,
    this.note = '',
  });

  final int quantity;
  final double? selectedServiceAmount;
  final int? selectedWeightGrams;
  final int serviceRound;
  final String note;

  _TemplateChildDraft copyWith({
    int? quantity,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? serviceRound,
    String? note,
  }) {
    return _TemplateChildDraft(
      quantity: quantity ?? this.quantity,
      selectedServiceAmount:
          selectedServiceAmount ?? this.selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams ?? this.selectedWeightGrams,
      serviceRound: serviceRound ?? this.serviceRound,
      note: note ?? this.note,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.10)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized ? AppColors.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: emphasized ? AppColors.primary : const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
    );
  }
}
