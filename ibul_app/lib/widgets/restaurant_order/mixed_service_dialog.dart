import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/mixed_service_order.dart';
import '../../models/product_pricing.dart';
import '../../models/seller_product.dart';
import '../optimized_image.dart';

enum MixedServiceDialogMode { create, edit }

Future<Map<String, dynamic>?> showMixedServiceDialog({
  required BuildContext context,
  required List<SellerProduct> products,
  Map<String, dynamic>? initialItem,
  List<String>? availablePricingModes,
  MixedServiceDialogMode mode = MixedServiceDialogMode.create,
  String? title,
  String? subtitle,
  String? submitLabel,
  String? headerImageUrl,
  bool showItemNameField = true,
  String? noteHintText,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return _MixedServiceDialog(
        products: products,
        mode: mode,
        initialItem: initialItem,
        title: title,
        subtitle: subtitle,
        submitLabel: submitLabel,
        headerImageUrl: headerImageUrl,
        showItemNameField: showItemNameField,
        noteHintText: noteHintText,
        availablePricingModes:
            availablePricingModes ??
            const <String>[
              MixedServiceOrder.autoSumPriceMode,
              MixedServiceOrder.manualPriceMode,
            ],
      );
    },
  );
}

class _MixedServiceDialog extends StatefulWidget {
  const _MixedServiceDialog({
    required this.products,
    required this.availablePricingModes,
    required this.mode,
    this.initialItem,
    this.title,
    this.subtitle,
    this.submitLabel,
    this.headerImageUrl,
    this.showItemNameField = true,
    this.noteHintText,
  });

  final List<SellerProduct> products;
  final List<String> availablePricingModes;
  final MixedServiceDialogMode mode;
  final Map<String, dynamic>? initialItem;
  final String? title;
  final String? subtitle;
  final String? submitLabel;
  final String? headerImageUrl;
  final bool showItemNameField;
  final String? noteHintText;

  @override
  State<_MixedServiceDialog> createState() => _MixedServiceDialogState();
}

class _MixedServiceDialogState extends State<_MixedServiceDialog> {
  late final TextEditingController _searchController;
  late final TextEditingController _itemNameController;
  late final TextEditingController _manualPriceController;
  late final TextEditingController _fixedPriceController;
  late final TextEditingController _noteController;
  late final ScrollController _contentScrollController;
  late final FocusNode _generalNoteFocusNode;
  final Map<int, Map<String, _SelectedChildDraft>> _selectedItemsByMode =
      <int, Map<String, _SelectedChildDraft>>{};
  final Map<int, Map<String, _SelectedChildDraft>> _selectionDraftsByMode =
      <int, Map<String, _SelectedChildDraft>>{};
  // 0 = Standart (düz liste), 1-5 = tabak/sipariş grupları
  int _tableCount = 0;
  // Hangi seçili ürünün "Özelleştir" paneli açık
  final Set<String> _expandedProductIds = <String>{};
  final GlobalKey _generalNoteKey = GlobalKey();
  String _pricingMode = MixedServiceOrder.autoSumPriceMode;
  String _searchQuery = '';
  int _localRowSeed = 0;
  bool _summaryExpanded = false;
  // Tracks last known keyboard height to re-trigger scroll when keyboard grows.
  double _lastKeyboardHeight = 0;

  // Plate-mode (tableCount≥1) shares a single bucket so items added while
  // switching between plate-1 / plate-2 / … tabs stay visible together.
  // Standard mode (tableCount=0) keeps its own separate bucket.
  int get _effectiveBucket => _tableCount > 0 ? 1 : 0;

  /// The currently active plate number (= _tableCount when in plate mode).
  /// Used to scope product card state to the selected plate.
  int get _activeRound => _tableCount > 0 ? _tableCount : 1;

  /// Number of plates to show in the UI (at least _tableCount, but capped up
  /// to the highest serviceRound actually used in items).
  int get _effectivePlateCount {
    if (_tableCount <= 0) return 0;
    if (_selectedItems.isEmpty) return _tableCount;
    final maxRound = _selectedItems.values
        .map((d) => d.serviceRound)
        .fold(0, math.max);
    return math.max(_tableCount, maxRound);
  }

  Map<String, _SelectedChildDraft> get _selectedItems => _selectedItemsByMode
      .putIfAbsent(_effectiveBucket, () => <String, _SelectedChildDraft>{});

  Map<String, _SelectedChildDraft> get _selectionDrafts =>
      _selectionDraftsByMode.putIfAbsent(
        _effectiveBucket,
        () => <String, _SelectedChildDraft>{},
      );

  List<SellerProduct> get _sortedProducts {
    final filtered = widget.products
        .where((product) {
          if (MixedServiceOrder.isTemplateProduct(product)) return false;
          final query = _searchQuery.trim().toLowerCase();
          if (query.isEmpty) return true;
          final haystack = [
            product.name,
            product.mainCategory,
            product.subCategory,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  bool get _isEditing => widget.mode == MixedServiceDialogMode.edit;

  double get _autoTotal {
    return _selectedItems.values.fold<double>(0, (sum, draft) {
      final product = _productById(draft.productId);
      if (product == null) return sum;
      final selectionSnapshot =
          MixedServiceOrder.childSelectionSnapshotForProduct(
            product,
            quantity: draft.quantity,
            selectedServiceAmount: draft.selectedServiceAmount,
            selectedWeightGrams: draft.selectedWeightGrams,
          );
      return sum +
          MixedServiceOrder.parsePrice(selectionSnapshot['line_total']);
    });
  }

  double get _manualTotal {
    return MixedServiceOrder.parsePrice(_manualPriceController.text);
  }

  double get _fixedTotal {
    return MixedServiceOrder.parsePrice(_fixedPriceController.text);
  }

  double get _resolvedTotal {
    return MixedServiceOrder.resolveMainItemTotal(<String, dynamic>{
      'pricing_mode': _pricingMode,
      'fixed_price': _fixedTotal,
      'manual_price': _manualTotal,
      'child_items': _childItemsForSubmit(),
    });
  }

  /// Total for a specific plate (service_round). Only makes sense when
  /// _tableCount > 0; falls back to _autoTotal when ungrouped.
  double _plateTotal(int round) {
    return _selectedItems.values
        .where((draft) => draft.serviceRound == round)
        .fold<double>(0, (sum, draft) {
          final product = _productById(draft.productId);
          if (product == null) return sum;
          final snap = MixedServiceOrder.childSelectionSnapshotForProduct(
            product,
            quantity: draft.quantity,
            selectedServiceAmount: draft.selectedServiceAmount,
            selectedWeightGrams: draft.selectedWeightGrams,
          );
          return sum + MixedServiceOrder.parsePrice(snap['line_total']);
        });
  }

  /// Returns rounds (1..tableCount) that have at least one selected item.
  List<int> get _populatedRounds {
    if (_tableCount <= 0) return const [];
    return List.generate(_effectivePlateCount, (i) => i + 1)
        .where(
          (round) => _selectedItems.values.any((d) => d.serviceRound == round),
        )
        .toList(growable: false);
  }

  bool get _canSubmit {
    if (_selectedItems.isEmpty) return false;
    if (_pricingMode == MixedServiceOrder.manualPriceMode) {
      return _manualTotal > 0;
    }
    if (_pricingMode == MixedServiceOrder.fixedPriceMode) {
      return _fixedTotal > 0;
    }
    return _autoTotal > 0;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _contentScrollController = ScrollController();
    _generalNoteFocusNode = FocusNode()..addListener(_handleGeneralNoteFocus);
    if (_isEditing && widget.initialItem != null) {
      final initial = MixedServiceOrder.normalizeOrderItem(widget.initialItem!);
      _itemNameController = TextEditingController(
        text: initial['item_name']?.toString().trim().isNotEmpty == true
            ? initial['item_name'].toString().trim()
            : MixedServiceOrder.defaultItemName,
      );
      _manualPriceController = TextEditingController(
        text: _initialManualPriceText(initial),
      );
      _fixedPriceController = TextEditingController(
        text: _initialFixedPriceText(initial),
      );
      _noteController = TextEditingController(
        text: initial['note']?.toString() ?? '',
      );

      final preferredMode = initial['pricing_mode']?.toString();
      _pricingMode = widget.availablePricingModes.contains(preferredMode)
          ? preferredMode!
          : widget.availablePricingModes.first;
      _hydrateInitialItem(initial);
    } else {
      _itemNameController = TextEditingController(
        text: MixedServiceOrder.defaultItemName,
      );
      _manualPriceController = TextEditingController();
      _fixedPriceController = TextEditingController();
      _noteController = TextEditingController();
      _pricingMode = widget.availablePricingModes.first;
      _tableCount = 0;
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-scroll the general-note field into view whenever the keyboard grows.
    // This pairs with _handleGeneralNoteFocus to cover the case where
    // the keyboard finishes animating AFTER the focus listener fires.
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    if (kbHeight > _lastKeyboardHeight && _generalNoteFocusNode.hasFocus) {
      _ensureVisible(
        _generalNoteKey,
        alignment: 0.16,
        delay: const Duration(milliseconds: 200),
      );
    }
    _lastKeyboardHeight = kbHeight;
  }

  void _hydrateInitialItem(Map<String, dynamic> item) {
    final initialTableCount = MixedServiceOrder.serviceRoundCountForItem(item);
    _tableCount = initialTableCount;
    // Use _effectiveBucket so all plate-mode items share bucket=1 and
    // are still visible when the user switches between plate counts.
    final initialSelections = _selectedItemsByMode.putIfAbsent(
      _effectiveBucket,
      () => <String, _SelectedChildDraft>{},
    );
    for (final child in MixedServiceOrder.normalizeChildItems(
      item['child_items'],
    )) {
      final productId = child['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final localRowId = MixedServiceOrder.normalizeChildLocalRowId(
        child,
        fallbackProductId: productId,
        fallbackIndex: _localRowSeed,
      );
      initialSelections[localRowId] = _SelectedChildDraft(
        localRowId: localRowId,
        productId: productId,
        quantity: (child['quantity'] as num?)?.toInt() ?? 1,
        selectedServiceAmount:
            (child['selected_portion_value'] as num?)?.toDouble() ??
            (child['selected_service_amount'] as num?)?.toDouble() ??
            (child['selectedServiceAmount'] as num?)?.toDouble(),
        selectedWeightGrams:
            (child['selected_weight_grams'] as num?)?.toInt() ??
            (child['selectedWeightGrams'] as num?)?.toInt(),
        serviceRound: _normalizedServiceRoundForCount(
          MixedServiceOrder.normalizeServiceRound(child['service_round']),
          initialTableCount,
        ),
        note: child['note']?.toString() ?? '',
        selectedAttrs: (child['attributes'] as List?)
                ?.whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .map((s) => s.trim())
                .toList() ??
            const <String>[],
      );
      _localRowSeed += 1;
    }
  }

  String _initialManualPriceText(Map<String, dynamic> item) {
    final manualPrice = MixedServiceOrder.parsePrice(item['manual_price']);
    if (manualPrice > 0) {
      return manualPrice.toStringAsFixed(2);
    }
    return '';
  }

  String _initialFixedPriceText(Map<String, dynamic> item) {
    final fixedPrice = MixedServiceOrder.parsePrice(item['fixed_price']);
    if (fixedPrice > 0) {
      return fixedPrice.toStringAsFixed(2);
    }
    final pricingMode = item['pricing_mode']?.toString().trim();
    if (pricingMode == MixedServiceOrder.fixedPriceMode) {
      final total = MixedServiceOrder.parsePrice(
        item['total_price'] ?? item['price'],
      );
      if (total > 0) {
        return total.toStringAsFixed(2);
      }
    }
    return '';
  }

  @override
  void dispose() {
    _generalNoteFocusNode
      ..removeListener(_handleGeneralNoteFocus)
      ..dispose();
    _contentScrollController.dispose();
    _searchController.dispose();
    _itemNameController.dispose();
    _manualPriceController.dispose();
    _fixedPriceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleGeneralNoteFocus() {
    if (_generalNoteFocusNode.hasFocus) {
      _ensureVisible(_generalNoteKey, alignment: 0.16);
    }
  }

  void _ensureVisible(
    GlobalKey key, {
    double alignment = 0.14,
    Duration delay = const Duration(milliseconds: 120),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      final targetContext = key.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      await Scrollable.ensureVisible(
        targetContext,
        alignment: alignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Returns a draft scoped to the current active plate.
  /// When in plate mode, only considers items in the current round so that
  /// switching from plate-1 to plate-2 shows plate-2-specific state.
  _SelectedChildDraft _activeDraftForProduct(SellerProduct product) {
    final round = _activeRound;
    // Prefer a stored draft if it already targets the active round.
    final fromDrafts = _selectionDrafts[product.id];
    if (fromDrafts != null && fromDrafts.serviceRound == round) {
      return fromDrafts;
    }
    // Look for an existing selected row in the current round.
    final rows = _selectedRowsForProduct(
      product,
    ).where((d) => d.serviceRound == round);
    if (rows.isNotEmpty) return rows.first.copyWith(quantity: 0);
    // Nothing yet for this round – use options from base draft but set correct round.
    final base = _selectionDraftForProduct(product);
    return base.copyWith(serviceRound: round);
  }

  _SelectedChildDraft _selectionDraftForProduct(SellerProduct product) {
    final fromDrafts = _selectionDrafts[product.id];
    if (fromDrafts != null) return fromDrafts;
    final selected = _firstSelectedRowForProduct(product);
    if (selected != null) {
      return selected.copyWith(quantity: 0);
    }
    return _SelectedChildDraft(
      productId: product.id,
      quantity: 0,
      selectedServiceAmount: product.usesPortionLikeStepper
          ? product.resolvedDefaultServiceAmount
          : null,
      selectedWeightGrams:
          product.resolvedServiceControlType ==
              ProductServiceControlType.weightStepper
          ? product.resolvedDefaultWeightGrams
          : null,
      // Default to the currently active plate so that opening a product
      // in "plate-2 mode" and clicking + immediately sends it to plate 2.
      serviceRound: _tableCount > 0 ? _tableCount : 1,
    );
  }

  void _applyTableCount(int nextCount) {
    final sanitizedCount = nextCount.clamp(0, 5);
    setState(() {
      _tableCount = sanitizedCount;
    });
  }

  int _normalizedServiceRoundForCount(int serviceRound, int tableCount) {
    if (tableCount <= 0) return 1;
    if (serviceRound <= 0 || serviceRound > tableCount) {
      return 1;
    }
    return serviceRound;
  }

  SellerProduct? _productById(String productId) {
    return widget.products.cast<SellerProduct?>().firstWhere(
      (candidate) => candidate?.id == productId,
      orElse: () => null,
    );
  }

  List<_SelectedChildDraft> _selectedRowsForProduct(SellerProduct product) {
    return _selectedItems.values
        .where((draft) => draft.productId == product.id)
        .toList(growable: false);
  }

  _SelectedChildDraft? _firstSelectedRowForProduct(SellerProduct product) {
    final rows = _selectedRowsForProduct(product);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  _SelectedChildDraft? _matchingSelectedRowForDraft(
    SellerProduct product,
    _SelectedChildDraft draft,
  ) {
    for (final row in _selectedRowsForProduct(product)) {
      if (_sameSelectionSnapshot(row, draft)) {
        return row;
      }
    }
    return null;
  }

  bool _sameSelectionSnapshot(
    _SelectedChildDraft left,
    _SelectedChildDraft right,
  ) {
    final samePortion =
        (left.selectedServiceAmount == null &&
            right.selectedServiceAmount == null) ||
        ((left.selectedServiceAmount ?? 0) - (right.selectedServiceAmount ?? 0))
                .abs() <
            0.001;
    return left.productId == right.productId &&
        left.serviceRound == right.serviceRound &&
        left.selectedWeightGrams == right.selectedWeightGrams &&
        samePortion;
  }

  String _nextLocalRowId(SellerProduct product, _SelectedChildDraft draft) {
    _localRowSeed += 1;
    final selectionSnapshot =
        MixedServiceOrder.childSelectionSnapshotForProduct(
          product,
          quantity: 1,
          selectedServiceAmount: draft.selectedServiceAmount,
          selectedWeightGrams: draft.selectedWeightGrams,
        );
    return MixedServiceOrder.buildChildLocalRowId(
      productId: product.id,
      serviceRound: _normalizedServiceRoundForCount(
        draft.serviceRound,
        _effectivePlateCount,
      ),
      selectedPricingType: selectionSnapshot['selected_pricing_type']
          ?.toString(),
      selectedPortionValue:
          (selectionSnapshot['selected_portion_value'] as num?)?.toDouble(),
      selectedWeightGrams: (selectionSnapshot['selected_weight_grams'] as num?)
          ?.toInt(),
      suffix: '$_localRowSeed',
    );
  }

  void _updateSelectionDraft(
    SellerProduct product, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? serviceRound,
    String? note,
    List<String>? selectedAttrs,
  }) {
    final current = _selectionDraftForProduct(product);
    final next = current.copyWith(
      selectedServiceAmount:
          selectedServiceAmount ?? current.selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams ?? current.selectedWeightGrams,
      serviceRound: serviceRound ?? current.serviceRound,
      note: note ?? current.note,
      selectedAttrs: selectedAttrs ?? current.selectedAttrs,
    );
    setState(() {
      // When the user changes the plate selector for an already-added item,
      // propagate the new serviceRound to the stored selected item so that
      // the order summary (childItemDisplayEntries) shows the correct plate.
      if (serviceRound != null && serviceRound != current.serviceRound) {
        final matched = _matchingSelectedRowForDraft(product, current);
        if (matched != null) {
          _selectedItems[matched.localRowId] = matched.copyWith(
            serviceRound: serviceRound,
          );
        }
      }
      _selectionDrafts[product.id] = next.copyWith(productId: product.id);
    });
  }

  void _changeItemQuantity(SellerProduct product, int delta) {
    // IMPORTANT: use _activeDraftForProduct in plate mode so that the write
    // path always targets the currently-active round. Using
    // _selectionDraftForProduct here would return the stale stored draft
    // (e.g. serviceRound=1) even after the user has switched to Tabak 2,
    // because all plate-modes share the same selection bucket.
    final pendingDraft =
        (_tableCount > 0
                ? _activeDraftForProduct(product)
                : _selectionDraftForProduct(product))
            .copyWith(productId: product.id);
    final selected = _matchingSelectedRowForDraft(product, pendingDraft);
    final nextQuantity = (selected?.quantity ?? 0) + delta;
    setState(() {
      if (nextQuantity <= 0) {
        if (selected != null) {
          _selectedItems.remove(selected.localRowId);
        }
        return;
      }
      final localRowId =
          selected?.localRowId ?? _nextLocalRowId(product, pendingDraft);
      final base =
          selected ??
          pendingDraft.copyWith(
            localRowId: localRowId,
            productId: product.id,
            quantity: 0,
          );
      _selectedItems[localRowId] = base.copyWith(
        localRowId: localRowId,
        productId: product.id,
        quantity: nextQuantity,
      );
      _selectionDrafts[product.id] = pendingDraft.copyWith(quantity: 0);
      // TODO(debug): remove before production
      debugPrint(
        '[ROUND_WRITE] product=${product.name} '
        'activeRound=$_activeRound '
        'writtenRound=${pendingDraft.serviceRound} '
        'newQty=$nextQuantity '
        'allRoundState=${_selectedItems.values.map((d) => '${d.productId}:r${d.serviceRound}:q${d.quantity}').toList()}',
      );
    });
  }

  void _changeSelectionOption(SellerProduct product, int delta) {
    final current = _selectionDraftForProduct(product);
    if (product.resolvedServiceControlType ==
        ProductServiceControlType.weightStepper) {
      final options = ProductPriceCalculator.buildPresetWeightOptions(
        minWeightGrams: product.minWeightGrams,
        defaultWeightGrams: product.defaultWeightGrams,
        weightStepGrams: product.weightStepGrams,
        maxWeightGrams: product.maxWeightGrams,
      );
      final selectedValue =
          current.selectedWeightGrams ?? product.resolvedDefaultWeightGrams;
      var index = options.indexOf(selectedValue);
      if (index < 0) index = 0;
      final nextIndex = (index + delta).clamp(0, options.length - 1);
      _updateSelectionDraft(product, selectedWeightGrams: options[nextIndex]);
      return;
    }

    if (product.usesPortionLikeStepper) {
      final options = ProductPriceCalculator.buildPresetPortionOptions(
        type: product.resolvedServiceControlType,
        minPortion: product.minPortion,
        maxPortion: product.maxPortion,
        portionStep: product.portionStep,
      );
      final selectedValue =
          current.selectedServiceAmount ?? product.resolvedDefaultServiceAmount;
      var index = options.indexWhere(
        (value) => (value - selectedValue).abs() < 0.001,
      );
      if (index < 0) index = 0;
      final nextIndex = (index + delta).clamp(0, options.length - 1);
      _updateSelectionDraft(product, selectedServiceAmount: options[nextIndex]);
    }
  }

  void _updateChildDraft(String productId, {int? serviceRound, String? note}) {
    final product = widget.products.cast<SellerProduct?>().firstWhere(
      (candidate) => candidate?.id == productId,
      orElse: () => null,
    );
    if (product == null) return;
    _updateSelectionDraft(product, serviceRound: serviceRound, note: note);
  }

  Future<void> _openCustomizePopup(
    SellerProduct product,
    _SelectedChildDraft draft, {
    String? selectedLocalRowId,
  }) async {
    if (!mounted) return;

    final type = product.resolvedServiceControlType;
    final isWeight =
        type == ProductServiceControlType.weightStepper ||
        product.resolvedPricingType == ProductPricingType.weight;

    var grams = (draft.selectedWeightGrams ?? product.resolvedDefaultWeightGrams);
    grams = ProductPriceCalculator.clampWeightSelection(
      grams,
      minWeightGrams: product.minWeightGrams,
      weightStepGrams: product.weightStepGrams,
      maxWeightGrams: product.maxWeightGrams,
    );
    var amount = draft.selectedServiceAmount ?? product.resolvedDefaultServiceAmount;
    amount = ProductPriceCalculator.clampPortionSelection(
      amount,
      type: product.resolvedServiceControlType,
      minPortion: product.minPortion,
      maxPortion: product.maxPortion,
      portionStep: product.portionStep,
    );
    final selectedAttrs = <String>{...draft.selectedAttrs};
    final noteController = TextEditingController(text: draft.note);

    double resolveUnitPrice() {
      return ProductPriceCalculator.resolveServiceControlledUnitPrice(
        serviceControlType: product.resolvedServiceControlType,
        pricingType: product.resolvedPricingType,
        pricingMode: product.resolvedPricingMode,
        basePrice: product.basePrice,
        portionPrice: product.portionPrice,
        pricePerKg: product.pricePerKg,
        sizeOptions: product.normalizedSizeOptions,
        selectedSizeName: product.selectedSizeName,
        selectedSizePrice: product.selectedSizePrice,
        fallbackPrice: product.price,
        selectedAmount: amount,
        selectedWeightGrams: grams,
      );
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final unitPrice = resolveUnitPrice();
            final amountLabel = MixedServiceOrder.productAmountLabelForSelection(
              product,
              selectedServiceAmount: amount,
              selectedWeightGrams: grams,
            );
            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      '${ProductPriceCalculator.formatCurrency(unitPrice)}${amountLabel.trim().isEmpty ? '' : ' • $amountLabel'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (product.usesServiceControlStepper || isWeight) ...[
                      Text(
                        isWeight ? 'Kilo Seçimi' : 'Porsiyon Seçimi',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StepperButton(
                            buttonKey: ValueKey<String>(
                              'mixed-service-popup-minus-${product.id}',
                            ),
                            icon: Icons.remove,
                            onTap: () {
                              setModalState(() {
                                if (isWeight) {
                                  grams = ProductPriceCalculator.clampWeightSelection(
                                    grams - product.resolvedWeightStepGrams,
                                    minWeightGrams: product.minWeightGrams,
                                    weightStepGrams: product.weightStepGrams,
                                    maxWeightGrams: product.maxWeightGrams,
                                  );
                                } else {
                                  amount = ProductPriceCalculator.clampPortionSelection(
                                    amount - product.resolvedPortionStepAmount,
                                    type: product.resolvedServiceControlType,
                                    minPortion: product.minPortion,
                                    maxPortion: product.maxPortion,
                                    portionStep: product.portionStep,
                                  );
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isWeight
                                    ? ProductPriceCalculator.formatWeight(grams)
                                    : ProductPriceCalculator.formatPortionLabel(amount),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StepperButton(
                            buttonKey: ValueKey<String>(
                              'mixed-service-popup-plus-${product.id}',
                            ),
                            icon: Icons.add,
                            onTap: () {
                              setModalState(() {
                                if (isWeight) {
                                  grams = ProductPriceCalculator.clampWeightSelection(
                                    grams + product.resolvedWeightStepGrams,
                                    minWeightGrams: product.minWeightGrams,
                                    weightStepGrams: product.weightStepGrams,
                                    maxWeightGrams: product.maxWeightGrams,
                                  );
                                } else {
                                  amount = ProductPriceCalculator.clampPortionSelection(
                                    amount + product.resolvedPortionStepAmount,
                                    type: product.resolvedServiceControlType,
                                    minPortion: product.minPortion,
                                    maxPortion: product.maxPortion,
                                    portionStep: product.portionStep,
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (product.attributes.isNotEmpty) ...[
                      const Text(
                        'Özellikler',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.attributes.map((attr) {
                          final selected = selectedAttrs.contains(attr);
                          return ChoiceChip(
                            label: Text(attr),
                            selected: selected,
                            onSelected: (v) {
                              setModalState(() {
                                if (v) {
                                  selectedAttrs.add(attr);
                                } else {
                                  selectedAttrs.remove(attr);
                                }
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Açıklama / Not (isteğe bağlı)',
                        hintText: 'Örn: az yağlı, yanında ketçap',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop(<String, dynamic>{
                            'grams': grams,
                            'amount': amount,
                            'attrs': selectedAttrs.toList(growable: false),
                            'note': noteController.text,
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Onayla',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    if (result == null || !mounted) return;

    // Persist selection to draft + any already-selected row.
    final nextGrams = (result['grams'] as num?)?.toInt();
    final nextAmount = (result['amount'] as num?)?.toDouble();
    final nextNote = result['note']?.toString() ?? '';
    final nextAttrs =
        (result['attrs'] as List?)?.whereType<String>().toList() ??
            const <String>[];

    setState(() {
      _updateSelectionDraft(
        product,
        selectedWeightGrams: nextGrams,
        selectedServiceAmount: nextAmount,
        note: nextNote,
        selectedAttrs: nextAttrs,
      );

      // Update the already-selected row deterministically when possible.
      final localRowId = (selectedLocalRowId ?? '').trim();
      if (localRowId.isNotEmpty) {
        final existing = _selectedItems[localRowId];
        if (existing != null) {
          _selectedItems[localRowId] = existing.copyWith(
            selectedWeightGrams: nextGrams,
            selectedServiceAmount: nextAmount,
            note: nextNote,
            selectedAttrs: nextAttrs,
          );
        }
      } else {
        // Fallback: attempt to match by draft signature.
        final pendingDraft = (_tableCount > 0
                ? _activeDraftForProduct(product)
                : _selectionDraftForProduct(product))
            .copyWith(productId: product.id);
        final matched = _matchingSelectedRowForDraft(product, pendingDraft);
        if (matched != null) {
          _selectedItems[matched.localRowId] = matched.copyWith(
            selectedWeightGrams: nextGrams,
            selectedServiceAmount: nextAmount,
            note: nextNote,
            selectedAttrs: nextAttrs,
          );
        }
      }
    });
  }

  List<Map<String, dynamic>> _childItemsForSubmit() {
    return _selectedItems.values
        .map((draft) {
          final product = _productById(draft.productId);
          if (product == null) return null;
          return MixedServiceOrder.buildChildItemPayload(
            product,
            quantity: draft.quantity,
            selectedServiceAmount: draft.selectedServiceAmount,
            selectedWeightGrams: draft.selectedWeightGrams,
            serviceRound: draft.serviceRound,
            note: draft.note.trim(),
            attributes: draft.selectedAttrs,
            localRowId: draft.localRowId,
          );
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void _submit() {
    if (!_canSubmit) return;
    final childItems = _childItemsForSubmit();
    if (childItems.isEmpty) return;

    final initialItem = widget.initialItem == null
        ? null
        : MixedServiceOrder.normalizeOrderItem(widget.initialItem!);
    final sourceTemplateId =
        initialItem?['source_template_id']?.toString().trim().isNotEmpty == true
        ? initialItem!['source_template_id'].toString().trim()
        : null;
    final sourceProductType =
        initialItem?['source_product_type']?.toString().trim().isNotEmpty ==
            true
        ? initialItem!['source_product_type'].toString().trim()
        : null;

    final selectedProducts = _selectedItems.values
        .map((draft) => _productById(draft.productId))
        .whereType<SellerProduct>()
        .toList(growable: false);
    final itemName = _itemNameController.text.trim().isEmpty
        ? MixedServiceOrder.defaultItemName
        : _itemNameController.text.trim();
    final stationId = MixedServiceOrder.resolveStationIdForProducts(
      selectedProducts,
    );
    final printerRoutingEnabled =
        MixedServiceOrder.resolvePrinterRoutingEnabled(selectedProducts);

    Navigator.of(context).pop(
      MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
        'item_type': MixedServiceOrder.itemType,
        'name': itemName,
        'item_name': itemName,
        'price': _resolvedTotal,
        'total_price': _resolvedTotal,
        'line_total': _resolvedTotal,
        'quantity': 1,
        'product_id': sourceTemplateId,
        'source_template_id': sourceTemplateId,
        'source_product_type': sourceProductType,
        'product_type': sourceProductType,
        'note': _noteController.text.trim(),
        'notes': _noteController.text.trim(),
        'general_note': _noteController.text.trim(),
        'pricing_mode': _pricingMode,
        'fixed_price': _fixedTotal,
        'manual_price': _pricingMode == MixedServiceOrder.manualPriceMode
            ? _manualTotal
            : null,
        'manual_price_allowed':
            _pricingMode == MixedServiceOrder.manualAllowedPriceMode,
        'child_items': childItems,
        'service_round_count': _effectivePlateCount,
        'plate_count': _effectivePlateCount,
        'station_id': stationId,
        'printer_routing_enabled': printerRoutingEnabled,
        'attributes': const <String>[],
        'gramaj': '',
      }),
    );
  }

  Widget _buildProductCustomizePanel(
    SellerProduct product,
    _SelectedChildDraft draft,
  ) {
    final valueLabel = MixedServiceOrder.productAmountLabelForSelection(
      product,
      selectedServiceAmount: draft.selectedServiceAmount,
      selectedWeightGrams: draft.selectedWeightGrams,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          if (product.usesServiceControlStepper)
            Row(
              children: [
                Text(
                  product.resolvedServiceControlType ==
                          ProductServiceControlType.weightStepper
                      ? 'Gramaj'
                      : 'Porsiyon',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                _QtyStepper(
                  quantity: 1,
                  valueLabel: valueLabel,
                  decrementButtonKey: ValueKey<String>(
                    'mixed-service-option-minus-${product.id}',
                  ),
                  incrementButtonKey: ValueKey<String>(
                    'mixed-service-option-plus-${product.id}',
                  ),
                  onDecrement: () => _changeSelectionOption(product, -1),
                  onIncrement: () => _changeSelectionOption(product, 1),
                ),
              ],
            ),
          if (_effectivePlateCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Tabak',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_effectivePlateCount, (i) {
                        final tabakNo = i + 1;
                        final selected = draft.serviceRound == tabakNo;
                        return GestureDetector(
                          key: ValueKey<String>(
                            'mixed-service-round-${product.id}-$tabakNo',
                          ),
                          onTap: () => _updateChildDraft(
                            product.id,
                            serviceRound: tabakNo,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              '$tabakNo. Tabak',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            key: ValueKey<String>('mixed-service-note-${product.id}'),
            controller: TextEditingController(text: draft.note)
              ..selection = TextSelection.collapsed(offset: draft.note.length),
            onChanged: (value) => _updateChildDraft(product.id, note: value),
            decoration: InputDecoration(
              labelText: 'Not',
              hintText: 'İsteğe bağlı',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSelector() {
    const options = <Object>['Standart', 1, 2, 3, 4, 5];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sipariş Yapısı',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final opt = options[i];
              final val = opt is int ? opt : 0;
              final selected = _tableCount == val;
              return GestureDetector(
                key: ValueKey<String>('mixed-service-mode-$val'),
                onTap: () => _applyTableCount(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    opt is int ? '$opt' : 'Standart',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_tableCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Ürünler $_effectivePlateCount tabağa dağıtılabilir. Ürün içinde 1. tabak, 2. tabak gibi seçim yapabilirsiniz.',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductListItem(SellerProduct product) {
    // When in plate mode, scope the draft and selection state to the active
    // round only so that items from plate-1 are not shown on plate-2 cards.
    final draft = _tableCount > 0
        ? _activeDraftForProduct(product)
        : _selectionDraftForProduct(product);
    final selected = _matchingSelectedRowForDraft(product, draft);
    final hasAnySelection = _tableCount > 0
        ? _selectedRowsForProduct(
            product,
          ).any((d) => d.serviceRound == _activeRound)
        : _selectedRowsForProduct(product).isNotEmpty;
    final quantity = selected?.quantity ?? 0;
    // TODO(debug): remove before production
    debugPrint(
      '[ROUND_CARD_STATE] product=${product.name} '
      'activeRound=$_activeRound '
      'qtyActiveRound=$quantity '
      'qtyAllRounds=${_selectedRowsForProduct(product).fold(0, (s, d) => s + d.quantity)} '
      'isHighlighted=$hasAnySelection',
    );
    final imageUrl = product.imageUrl?.trim() ?? '';
    final effectiveDraft = selected ?? draft;
    final selectionSnapshot =
        MixedServiceOrder.childSelectionSnapshotForProduct(
          product,
          quantity: quantity > 0 ? quantity : 1,
          selectedServiceAmount: effectiveDraft.selectedServiceAmount,
          selectedWeightGrams: effectiveDraft.selectedWeightGrams,
        );
    final amountLabel =
        selectionSnapshot['selected_option_label']?.toString() ?? '';
    final unitPrice = MixedServiceOrder.parsePrice(
      selectionSnapshot['unit_price'],
    );
    final lineTotal = MixedServiceOrder.parsePrice(
      selectionSnapshot['line_total'],
    );
    final isExpanded = _expandedProductIds.contains(product.id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasAnySelection
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withValues(alpha: 0.45)
              : hasAnySelection
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: hasAnySelection
                ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: hasAnySelection ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final titleSection = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  maxLines: isCompact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  amountLabel.isNotEmpty
                      ? amountLabel
                      : product.subCategory.trim().isEmpty
                      ? product.mainCategory
                      : product.subCategory,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (effectiveDraft.note.trim().isNotEmpty ||
                    effectiveDraft.selectedAttrs.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (effectiveDraft.selectedAttrs.isNotEmpty)
                        effectiveDraft.selectedAttrs.join(', '),
                      if (effectiveDraft.note.trim().isNotEmpty)
                        'Not: ${effectiveDraft.note.trim()}',
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
                if (_tableCount > 0 && quantity > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${draft.serviceRound}. Tabak',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );

          final quantityControls = Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasAnySelection
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  buttonKey: ValueKey<String>(
                    'mixed-service-qty-minus-${product.id}',
                  ),
                  icon: Icons.remove,
                  onTap: () => _changeItemQuantity(product, -1),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _StepperButton(
                  buttonKey: ValueKey<String>(
                    'mixed-service-qty-plus-${product.id}',
                  ),
                  icon: Icons.add,
                  onTap: () => _changeItemQuantity(product, 1),
                ),
              ],
            ),
          );

          final customizeButton = SizedBox(
            height: 32,
            child: OutlinedButton(
              key: ValueKey<String>('mixed-service-customize-${product.id}'),
              onPressed: () {
                _openCustomizePopup(
                  product,
                  effectiveDraft,
                  selectedLocalRowId: selected?.localRowId,
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: isExpanded
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.white,
                side: BorderSide(
                  color: isExpanded
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Özelleştir',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          );

          final priceLabel = SizedBox(
            width: isCompact ? null : 82,
            child: Text(
              _formatMoney(quantity > 0 ? lineTotal : unitPrice),
              textAlign: isCompact ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          );

          return Column(
            children: [
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isEmpty
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFFE5E7EB),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.fastfood_rounded,
                                    size: 18,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                )
                              : OptimizedImage(
                                  imageUrlOrPath: imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 40,
                                        height: 40,
                                        color: const Color(0xFFE5E7EB),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 18,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        titleSection,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [quantityControls, priceLabel, customizeButton],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isEmpty
                          ? Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFFE5E7EB),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.fastfood_rounded,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            )
                          : OptimizedImage(
                              imageUrlOrPath: imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 40,
                                    height: 40,
                                    color: const Color(0xFFE5E7EB),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 18,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    titleSection,
                    const SizedBox(width: 8),
                    quantityControls,
                    const SizedBox(width: 10),
                    priceLabel,
                    const SizedBox(width: 8),
                    customizeButton,
                  ],
                ),
              if (isExpanded) ...[
                const SizedBox(height: 10),
                _buildProductCustomizePanel(product, draft),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiyatlandırma',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.availablePricingModes
              .map(
                (mode) => ChoiceChip(
                  label: Text(_pricingModeLabel(mode)),
                  selected: _pricingMode == mode,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _pricingMode = mode),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        if (_pricingMode == MixedServiceOrder.fixedPriceMode) ...[
          TextField(
            controller: _fixedPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Sabit toplam fiyat',
              prefixText: '₺',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_pricingMode == MixedServiceOrder.manualAllowedPriceMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Toplam child item fiyatlarından canlı hesaplanır. Manuel fiyat override açık.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_pricingMode == MixedServiceOrder.manualPriceMode) ...[
          TextField(
            controller: _manualPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Manuel toplam fiyat',
              prefixText: '₺',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildGeneralNoteField() {
    return Container(
      key: _generalNoteKey,
      child: TextField(
        controller: _noteController,
        focusNode: _generalNoteFocusNode,
        maxLines: 3,
        minLines: 2,
        textInputAction: TextInputAction.done,
        onTap: () => _ensureVisible(_generalNoteKey, alignment: 0.16),
        decoration: InputDecoration(
          labelText: 'Genel not',
          hintText:
              widget.noteHintText ??
              'Örn: Az pişmiş, soğansız, acısız, yanına lavaş ekleyin',
          alignLabelWithHint: true,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBottomBar({required bool compactLayout}) {
    final populatedRounds = _populatedRounds;
    final showPlateSummary = _tableCount > 0 && populatedRounds.isNotEmpty;
    final canExpandSummary = showPlateSummary;
    final totalQuantity = _selectedItems.values.fold<int>(
      0,
      (sum, draft) => sum + draft.quantity,
    );
    final showSummaryDetails = canExpandSummary && _summaryExpanded;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compactLayout ? 12 : 16,
        8,
        compactLayout ? 12 : 16,
        compactLayout ? 12 : 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7FC),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalQuantity > 0)
            GestureDetector(
              onTap: canExpandSummary
                  ? () => setState(() => _summaryExpanded = !_summaryExpanded)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                margin: EdgeInsets.only(bottom: showSummaryDetails ? 8 : 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showPlateSummary ? 'Sipariş Özeti' : 'Mini Özet',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            showPlateSummary
                                ? '${populatedRounds.length} tabak • $totalQuantity ürün'
                                : '$totalQuantity ürün seçildi',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatMoney(_resolvedTotal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    if (canExpandSummary) ...[
                      const SizedBox(width: 8),
                      Icon(
                        _summaryExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // ── Per-plate mini summary ─────────────────────────────────────
          if (showPlateSummary && showSummaryDetails) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...populatedRounds.map((round) {
                    final plateTotal = _plateTotal(round);
                    final draftsForRound = _selectedItems.values
                        .where((d) => d.serviceRound == round)
                        .toList(growable: false);
                    // TODO(debug): remove before production
                    debugPrint(
                      '[ROUND_SUMMARY_GROUP] round=$round '
                      'count=${draftsForRound.length} total=$plateTotal',
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tabak $round',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatMoney(plateTotal),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...draftsForRound.map((draft) {
                            final product = _productById(draft.productId);
                            if (product == null) return const SizedBox.shrink();
                            // TODO(debug): remove before production
                            debugPrint(
                              '[ROUND_SUMMARY_ITEM] product=${product.name} '
                              'itemRound=${draft.serviceRound} '
                              'itemRoundLabel=Tabak ${draft.serviceRound} '
                              'qty=${draft.quantity}',
                            );
                            final snap =
                                MixedServiceOrder.childSelectionSnapshotForProduct(
                                  product,
                                  quantity: draft.quantity,
                                  selectedServiceAmount:
                                      draft.selectedServiceAmount,
                                  selectedWeightGrams:
                                      draft.selectedWeightGrams,
                                );
                            final amountLbl =
                                snap['selected_option_label']
                                    ?.toString()
                                    .trim() ??
                                '';
                            final noteLbl = draft.note.trim();
                            final details = <String>[
                              if (amountLbl.isNotEmpty) amountLbl,
                              if (noteLbl.isNotEmpty) 'Not: $noteLbl',
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 2,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '- ${product.name} x${draft.quantity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (details.isNotEmpty)
                                    Text(
                                      details.join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // ── Total row ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Text(
                  showPlateSummary ? 'Genel Toplam' : 'Toplam',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatMoney(_resolvedTotal),
                  style: const TextStyle(
                    fontSize: 15,
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
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, compactLayout ? 46 : 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Vazgeç',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const ValueKey<String>('mixed-service-save'),
                  onPressed: _canSubmit ? _submit : null,
                  icon: const Icon(
                    Icons.playlist_add_check_circle_outlined,
                    size: 18,
                  ),
                  label: Text(
                    widget.submitLabel ?? 'Kaydet',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, compactLayout ? 46 : 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  String _formatMoney(double amount) {
    return '₺${amount.toStringAsFixed(2)}';
  }

  String _pricingModeLabel(String pricingMode) {
    switch (pricingMode) {
      case MixedServiceOrder.fixedPriceMode:
        return 'Sabit Fiyat';
      case MixedServiceOrder.manualAllowedPriceMode:
        return 'Manuel Fiyat İzinli';
      case MixedServiceOrder.manualPriceMode:
        return 'Manuel Fiyat';
      case MixedServiceOrder.autoSumPriceMode:
      default:
        return 'Otomatik Toplam';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width > 720;
    final isCompactLayout = mediaQuery.size.width < 720;
    final filteredProducts = _sortedProducts;
    final maxDialogHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom -
        24;
    final dialogHeight = math.max(
      0.0,
      math.min(
        isWide ? 920.0 : mediaQuery.size.height * 0.92,
        maxDialogHeight.toDouble(),
      ),
    );
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 16 : 12,
        isWide ? 14 : 12,
        isWide ? 16 : 12,
        6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((widget.headerImageUrl?.trim().isNotEmpty ?? false)) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: OptimizedImage(
                imageUrlOrPath: widget.headerImageUrl!.trim(),
                width: isWide ? 58 : 52,
                height: isWide ? 58 : 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ??
                      (_isEditing
                          ? 'Karışık Servisi Düzenle'
                          : 'Karışık Servis Ekle'),
                  style: TextStyle(
                    fontSize: isWide ? 19 : 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle ??
                      'Ürünleri doğrudan listeden yönetin, miktarı artırın ve gerekirse özelleştirin.',
                  style: const TextStyle(
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
            icon: Icon(isWide ? Icons.close_rounded : Icons.arrow_back_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );

    final content = AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Column(
        children: [
          header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _contentScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 16 : 12,
                    6,
                    isWide ? 16 : 12,
                    isCompactLayout ? 132 : 104,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showItemNameField) ...[
                          TextField(
                            controller: _itemNameController,
                            decoration: InputDecoration(
                              labelText: 'Sipariş adı',
                              hintText: MixedServiceOrder.defaultItemName,
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildTableSelector(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                            ),
                            hintText: 'Ürün ara…',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...filteredProducts.map(_buildProductListItem),
                        const SizedBox(height: 14),
                        _buildPricingSection(),
                        const SizedBox(height: 12),
                        _buildGeneralNoteField(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildBottomBar(compactLayout: isCompactLayout),
        ],
      ),
    );

    if (!isWide) {
      return Material(
        color: const Color(0xFFF7F7FC),
        child: SafeArea(child: content),
      );
    }

    return Dialog(
      backgroundColor: const Color(0xFFF7F7FC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(width: 760, height: dialogHeight, child: content),
    );
  }
}

class _SelectedChildDraft {
  const _SelectedChildDraft({
    this.localRowId = '',
    this.productId = '',
    this.quantity = 1,
    this.selectedServiceAmount,
    this.selectedWeightGrams,
    this.serviceRound = 1,
    this.note = '',
    this.selectedAttrs = const <String>[],
  });

  final String localRowId;
  final String productId;
  final int quantity;
  final double? selectedServiceAmount;
  final int? selectedWeightGrams;
  final int serviceRound;
  final String note;
  final List<String> selectedAttrs;

  _SelectedChildDraft copyWith({
    String? localRowId,
    String? productId,
    int? quantity,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? serviceRound,
    String? note,
    List<String>? selectedAttrs,
  }) {
    return _SelectedChildDraft(
      localRowId: localRowId ?? this.localRowId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      selectedServiceAmount:
          selectedServiceAmount ?? this.selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams ?? this.selectedWeightGrams,
      serviceRound: serviceRound ?? this.serviceRound,
      note: note ?? this.note,
      selectedAttrs: selectedAttrs ?? this.selectedAttrs,
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.valueLabel,
    this.decrementButtonKey,
    this.incrementButtonKey,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String? valueLabel;
  final Key? decrementButtonKey;
  final Key? incrementButtonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          buttonKey: decrementButtonKey,
          icon: Icons.remove,
          onTap: onDecrement,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          alignment: Alignment.center,
          child: Text(
            valueLabel ?? '$quantity',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        _StepperButton(
          buttonKey: incrementButtonKey,
          icon: Icons.add,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.buttonKey,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
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
