import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/product_pricing.dart';
import '../../core/providers/category_attribute_form_provider.dart';
import '../../models/seller_product.dart';
import '../../services/category_attribute_service.dart';
import '../../services/media/media_picker_service.dart';
import '../../services/media/product_media_repository.dart';
import '../../services/media/product_media_types.dart';
import '../../services/store_service.dart';
import '../../utils/preparation_time_formatter.dart';
import '../../utils/xfile_image_provider.dart';
import '../../widgets/dynamic_category_attribute_form.dart';
import '../../widgets/seller/pricing_type_selector.dart';
import '../../widgets/seller/service_control_selector.dart';
import '../../widgets/seller/service_stepper_fields.dart';
import '../../widgets/seller/weight_pricing_fields.dart';

/// Satıcı Ürün Ekleme/Düzenleme Sayfası
/// Gelişmiş özellikler ve adım adım form yapısı
class AddProductPage extends StatefulWidget {
  final bool isEdit;
  final String? productId;

  const AddProductPage({super.key, this.isEdit = false, this.productId});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Form Controllers
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _productColorController = TextEditingController();
  final _longDescController = TextEditingController();
  final _portionPriceController = TextEditingController();
  final _pricePerKgController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _minPortionController = TextEditingController();
  final _maxPortionController = TextEditingController();
  final _portionStepController = TextEditingController();
  final _minWeightController = TextEditingController();
  final _weightStepController = TextEditingController();
  final _defaultWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _preparationTimeController = TextEditingController();
  // _additionalInfoController removed

  // Selected Values
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  ProductPricingType _selectedPricingType = ProductPricingType.portion;
  ProductServiceControlType _selectedServiceControlType =
      ProductServiceControlType.none;
  final TextEditingController _subCategoryController = TextEditingController();
  List<String> _productAttributes = [];
  List<Map<String, String>> _nonFoodAttributeRows = [];
  String _selectedVatRate = '%18';
  String _selectedShippingOption = 'Ücretsiz Kargo';
  String? _selectedServiceType;
  String? _selectedServiceTime;
  Map<String, dynamic> _foodSpecificationSeed = <String, dynamic>{};

  /// Mağazanın başvuruda seçtiği kategori; sadece bu kategoride ürün eklenebilir. Null ise henüz yüklenmedi veya kısıtlama yok.
  String? _storeMainCategory;
  bool _storeCategoryLocked = false;

  // Ürün Görselleri
  final List<XFile?> _productImages = List.filled(8, null);

  /// Düzenleme modunda mevcut görsellerin URL'leri (yeni yükleme yoksa bunlar kullanılır).
  List<String> _existingImageUrls = [];

  // Ürün Videosu
  XFile? _videoFile;
  ProductVideoMetadata? _selectedVideoMetadata;
  String? _existingVideoUrl;
  String? _existingVideoPath;
  String? _existingThumbnailPath;
  String? _existingThumbnailUrl;
  int? _existingVideoDurationSeconds;
  int? _existingVideoSizeBytes;
  int? _existingThumbnailSizeBytes;
  String? _existingVideoStatus;
  UploadCancelToken? _activeUploadCancelToken;
  ProductMediaStage _mediaStage = ProductMediaStage.idle;
  String _mediaStageLabel = 'Hazır';
  double _mediaUploadProgress = 0;
  bool _isMediaUploadActive = false;

  /// Düzenleme modunda ürünün önceki durumu (Aktif ise kayıt sonrası 'Düzenlendi' yapılır).
  String _initialProductStatus = 'Taslak';
  final ImagePicker _picker = ImagePicker();
  final StoreService _storeService = StoreService();
  final CategoryAttributeService _categoryAttributeService =
      CategoryAttributeService.instance;
  late final CategoryAttributeFormProvider _attributeFormProvider;
  final MediaPickerService _mediaPickerService = MediaPickerService();
  final ProductMediaRepository _productMediaRepository =
      ProductMediaRepository();

  // Varyantlar (Kategoriye göre)
  List<ProductVariant> _variants = []; // Removed final keyword
  List<Map<String, dynamic>> _complementaryCandidates = [];
  final Set<String> _selectedAccessoryIds = <String>{};
  bool _isLoadingComplementaryCandidates = false;

  // Ek Bilgiler (Bullet Points)
  List<String> _additionalInfos = [];

  // Sıkça Sorulan Sorular
  List<Map<String, String>> _faqs = [];
  bool _isFaqSaving = false;
  int? _lastSavedFaqIndex;
  String? _faqDraftProductId;

  // Stok alarm seviyesi
  int _stockAlertLevel = 10;

  bool get _isFoodCategory {
    final cat = _storeMainCategory ?? _selectedMainCategory;
    return cat == 'Yemek';
  }

  bool get _isWeightPricingActive =>
      _isFoodCategory &&
      (_selectedServiceControlType == ProductServiceControlType.weightStepper ||
          (_selectedServiceControlType == ProductServiceControlType.none &&
              _selectedPricingType == ProductPricingType.weight));

  bool get _usesPortionLikeServiceControl =>
      _isFoodCategory &&
      ProductPriceCalculator.usesPortionLikeStepper(
        _selectedServiceControlType,
      );

  ProductPricingType get _pricingTypeForSave => !_isFoodCategory
      ? ProductPricingType.portion
      : _selectedServiceControlType == ProductServiceControlType.weightStepper
      ? ProductPricingType.weight
      : _selectedServiceControlType ==
                ProductServiceControlType.portionStepper ||
            _selectedServiceControlType ==
                ProductServiceControlType.skewerStepper
      ? ProductPricingType.portion
      : _selectedPricingType;

  TextEditingController get _activePriceController =>
      _pricingTypeForSave == ProductPricingType.weight
      ? _pricePerKgController
      : _portionPriceController;

  double get _portionPriceValue => _parseCurrency(_portionPriceController.text);

  double get _pricePerKgValue => _parseCurrency(_pricePerKgController.text);

  double get _activePriceValue => _parseCurrency(_activePriceController.text);

  static const List<String> _foodAttributeSuggestions = [
    'Acısız',
    'Az Acılı',
    'Acılı',
    'Soğansız',
    'Domatessiz',
    'Az Tuzlu',
    'Bol Peynirli',
    'Ekstra Sos',
  ];

  static const List<String> _serviceTypeOptions = [
    'Paket Servis',
    'Gel-Al',
    'Masa Servisi',
    'Hepsi',
  ];

  static const List<int> _preparationTimeQuickOptions = [
    10,
    15,
    20,
    30,
    45,
    60,
    90,
  ];

  static const List<String> _preparationTimeSpecificationKeys = [
    'preparationTime',
    'preparation_time',
    'estimatedReadyTime',
    'estimated_ready_time',
    'readyTime',
    'ready_time',
    'deliveryTime',
    'delivery_time',
    'hazirlanma_suresi',
    'hazirlanma',
  ];

  static const List<String> _serviceTimeOptions = [
    'Her Zaman',
    'Sadece Öğle',
    'Sadece Akşam',
  ];

  static const List<String> _allMainCategories = [
    'Elektronik',
    'Spor & Outdoor',
    'Giyim & Aksesuar',
    'Anne & Bebek & Oyuncak',
    'Kozmetik & Kişisel Bakım',
    'Ev & Yaşam',
    'Süpermarket & Petshop',
    'Kitap & Hobi',
    '2.el Ürünler',
    'Yemek',
  ];

  /// Başvuru kategorisini ürün ana kategorisine eşler (stores.category -> add_product mainCategory).
  static String? _storeCategoryToMainCategory(String? storeCategory) {
    if (storeCategory == null || storeCategory.isEmpty) return null;
    final c = storeCategory.trim();
    if (c == 'Yemek') return 'Yemek';
    if (c == 'Elektronik') return 'Elektronik';
    if (c == 'Giyim & Aksesuar' || c == 'Ayakkabı & Çanta') {
      return 'Giyim & Aksesuar';
    }
    if (c == 'Ev & Yaşam' || c == 'Yapı Market & Bahçe') return 'Ev & Yaşam';
    if (c == 'Kozmetik & Kişisel Bakım') return 'Kozmetik & Kişisel Bakım';
    if (c == 'Spor & Outdoor') return 'Spor & Outdoor';
    if (c == 'Anne & Bebek & Oyuncak') return 'Anne & Bebek & Oyuncak';
    if (c == 'Kitap, Müzik, Film, Hobi') return 'Kitap & Hobi';
    if (c == 'Süpermarket' || c == 'Petshop') return 'Süpermarket & Petshop';
    if (c == 'Otomotiv & Motosiklet') return '2.el Ürünler';
    return c;
  }

  void _syncWeightDefaultsIfNeeded({required bool force}) {
    if (force || _minWeightController.text.trim().isEmpty) {
      _minWeightController.text = ProductPriceCalculator.defaultMinWeightGrams
          .toString();
    }
    if (force || _weightStepController.text.trim().isEmpty) {
      _weightStepController.text = ProductPriceCalculator.defaultWeightStepGrams
          .toString();
    }
    if (force || _defaultWeightController.text.trim().isEmpty) {
      _defaultWeightController.text = ProductPriceCalculator
          .defaultWeightSelectionGrams
          .toString();
    }
  }

  void _syncServiceControlDefaultsIfNeeded({
    required ProductServiceControlType type,
    required bool force,
  }) {
    if (!ProductPriceCalculator.usesPortionLikeStepper(type)) return;
    final defaults = switch (type) {
      ProductServiceControlType.skewerStepper => (
        ProductPriceCalculator.defaultMinSkewer,
        ProductPriceCalculator.defaultMaxSkewer,
        ProductPriceCalculator.defaultSkewerStep,
      ),
      _ => (
        ProductPriceCalculator.defaultMinPortion,
        ProductPriceCalculator.defaultMaxPortion,
        ProductPriceCalculator.defaultPortionStep,
      ),
    };
    if (force || _minPortionController.text.trim().isEmpty) {
      _minPortionController.text = ProductPriceCalculator.formatNumericAmount(
        defaults.$1,
      );
    }
    if (force || _maxPortionController.text.trim().isEmpty) {
      _maxPortionController.text = ProductPriceCalculator.formatNumericAmount(
        defaults.$2,
      );
    }
    if (force || _portionStepController.text.trim().isEmpty) {
      _portionStepController.text = ProductPriceCalculator.formatNumericAmount(
        defaults.$3,
      );
    }
  }

  int? _parseOptionalWeightField(String text) {
    final value = _parseNumber(text);
    return value > 0 ? value : null;
  }

  double? _parseOptionalDecimalField(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;
    return value;
  }

  String? _cleanSelection(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parsePreparationMinutesFromText(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final directValue = int.tryParse(trimmed);
    if (directValue != null) return directValue;

    final matches = RegExp(r'\d+')
        .allMatches(trimmed)
        .map((match) => int.parse(match.group(0)!))
        .toList(growable: false);
    if (matches.isEmpty) return null;
    return matches.last;
  }

  int? _preparationMinutesValue() {
    final trimmed = _preparationTimeController.text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  int? _validatedPreparationMinutesValue() {
    final minutes = _preparationMinutesValue();
    if (minutes == null || minutes < 1 || minutes > 300) return null;
    return minutes;
  }

  String? _preparationTimeValueForSave() {
    final minutes = _validatedPreparationMinutesValue();
    return minutes?.toString();
  }

  String? _preparationTimeValidationMessage() {
    final trimmed = _preparationTimeController.text.trim();
    if (trimmed.isEmpty) {
      return 'Tahmini hazırlanma süresi boş olamaz';
    }

    final minutes = int.tryParse(trimmed);
    if (minutes == null) {
      return 'Tahmini hazırlanma süresi sadece sayı olmalı';
    }
    if (minutes < 1) {
      return 'Tahmini hazırlanma süresi en az 1 dakika olmalı';
    }
    if (minutes > 300) {
      return 'Tahmini hazırlanma süresi en fazla 300 dakika olabilir';
    }
    return null;
  }

  bool _validatePreparationTime({bool showError = true}) {
    final validationMessage = _preparationTimeValidationMessage();
    if (validationMessage == null) return true;
    if (showError) {
      _showError(validationMessage);
    }
    return false;
  }

  void _setPreparationMinutes(int minutes) {
    final value = minutes.toString();
    _preparationTimeController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Map<String, dynamic> _decodeSpecifications(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String? _firstSpecValue(Map<String, dynamic> specMap, List<String> keys) {
    for (final key in keys) {
      final value = _cleanSelection(specMap[key]?.toString());
      if (value != null) return value;
    }
    return null;
  }

  List<String> _dropdownItems(List<String> baseItems, String? currentValue) {
    final current = _cleanSelection(currentValue);
    if (current == null || baseItems.contains(current)) {
      return baseItems;
    }
    return <String>[current, ...baseItems];
  }

  int _parsedMinWeight() =>
      _parseOptionalWeightField(_minWeightController.text) ??
      ProductPriceCalculator.defaultMinWeightGrams;

  int _parsedWeightStep() =>
      _parseOptionalWeightField(_weightStepController.text) ??
      ProductPriceCalculator.defaultWeightStepGrams;

  int _parsedDefaultWeight() =>
      _parseOptionalWeightField(_defaultWeightController.text) ??
      ProductPriceCalculator.defaultWeightSelectionGrams;

  int? _parsedMaxWeight() =>
      _parseOptionalWeightField(_maxWeightController.text);

  double _parsedMinPortion() =>
      _parseOptionalDecimalField(_minPortionController.text) ??
      ProductPriceCalculator.resolveMinPortionAmount(
        _selectedServiceControlType,
        null,
      );

  double _parsedMaxPortion() =>
      _parseOptionalDecimalField(_maxPortionController.text) ??
      ProductPriceCalculator.resolveMaxPortionAmount(
        _selectedServiceControlType,
        null,
        minPortion: _parsedMinPortion(),
      );

  double _parsedPortionStep() =>
      _parseOptionalDecimalField(_portionStepController.text) ??
      ProductPriceCalculator.resolvePortionStepAmount(
        _selectedServiceControlType,
        null,
      );

  String _portionOptionsPreview() {
    if (!_usesPortionLikeServiceControl) return '';
    final options = ProductPriceCalculator.buildPresetPortionOptions(
      type: _selectedServiceControlType,
      minPortion: _parsedMinPortion(),
      maxPortion: _parsedMaxPortion(),
      portionStep: _parsedPortionStep(),
    );
    return options
        .map(
          (value) => ProductPriceCalculator.formatServiceAmountLabel(
            type: _selectedServiceControlType,
            amount: value,
          ),
        )
        .join(' / ');
  }

  String _weightOptionsPreview() {
    if (!_isWeightPricingActive) return '';
    final options = ProductPriceCalculator.buildPresetWeightOptions(
      minWeightGrams: _parsedMinWeight(),
      defaultWeightGrams: _parsedDefaultWeight(),
      weightStepGrams: _parsedWeightStep(),
      maxWeightGrams: _parsedMaxWeight(),
    );
    return options.map(ProductPriceCalculator.formatWeight).join(' / ');
  }

  @override
  void initState() {
    super.initState();
    _syncWeightDefaultsIfNeeded(force: true);
    _attributeFormProvider = CategoryAttributeFormProvider(
      service: _categoryAttributeService,
    );
    _loadComplementaryCandidates();
    if (widget.isEdit && widget.productId != null) {
      _loadProduct(widget.productId!).whenComplete(_loadStoreCategory);
    } else {
      _loadStoreCategory();
    }
  }

  Future<void> _loadProduct(String productId) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final product = await _storeService.getProductById(productId);
      if (product == null || !mounted) return;
      setState(() {
        _initialProductStatus = product.status;
        _foodSpecificationSeed = _decodeSpecifications(product.specifications);
        _productNameController.text = product.name;
        _brandController.text = product.brand;
        _longDescController.text = product.description ?? '';
        _selectedPricingType = ProductPricingType.fromValue(
          product.pricingType,
        );
        _selectedServiceControlType = ProductServiceControlType.fromValue(
          product.serviceControlType,
        );
        final portionPriceSeed =
            product.portionPrice ??
            (_selectedPricingType == ProductPricingType.portion
                ? product.price
                : 0);
        final kgPriceSeed =
            product.pricePerKg ??
            (_selectedPricingType == ProductPricingType.weight
                ? product.price
                : 0);
        _portionPriceController.text = portionPriceSeed > 0
            ? portionPriceSeed.toStringAsFixed(0)
            : '';
        _pricePerKgController.text = kgPriceSeed > 0
            ? kgPriceSeed.toStringAsFixed(0)
            : '';
        _discountPriceController.text = product.discountPrice != null
            ? product.discountPrice!.toStringAsFixed(0)
            : '';
        _minPortionController.text = product.minPortion != null
            ? ProductPriceCalculator.formatNumericAmount(product.minPortion!)
            : '';
        _maxPortionController.text = product.maxPortion != null
            ? ProductPriceCalculator.formatNumericAmount(product.maxPortion!)
            : '';
        _portionStepController.text = product.portionStep != null
            ? ProductPriceCalculator.formatNumericAmount(product.portionStep!)
            : '';
        _minWeightController.text =
            product.minWeightGrams?.toString() ??
            ProductPriceCalculator.defaultMinWeightGrams.toString();
        _weightStepController.text =
            product.weightStepGrams?.toString() ??
            ProductPriceCalculator.defaultWeightStepGrams.toString();
        _defaultWeightController.text =
            product.defaultWeightGrams?.toString() ??
            ProductPriceCalculator.defaultWeightSelectionGrams.toString();
        _maxWeightController.text = product.maxWeightGrams?.toString() ?? '';
        _stockController.text = product.stock.toString();
        _skuController.text = product.sku;
        // Split by newline
        _additionalInfos = (product.additionalInfo ?? '')
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .toList();
        _faqs = List<Map<String, String>>.from(product.faq ?? []);

        _selectedMainCategory = product.mainCategory;
        final initialPreparationMinutes = _parsePreparationMinutesFromText(
          _cleanSelection(product.preparationTime) ??
              _firstSpecValue(
                _foodSpecificationSeed,
                _preparationTimeSpecificationKeys,
              ),
        );
        _preparationTimeController.text =
            initialPreparationMinutes?.toString() ?? '';
        _selectedServiceType = _firstSpecValue(_foodSpecificationSeed, const [
          'serviceType',
          'service_type',
          'servisTipi',
          'servis_tipi',
        ]);
        _selectedServiceTime = _firstSpecValue(_foodSpecificationSeed, const [
          'serviceTime',
          'service_time',
          'servisZamani',
          'servis_zamani',
        ]);
        // _selectedSubCategory'i güncelle
        _selectedSubCategory = product.subCategory.isEmpty
            ? null
            : product.subCategory;
        // _subCategoryController opsiyonel, manuel giriş için
        _subCategoryController.text = product.subCategory;

        _productAttributes = List<String>.from(product.attributes);
        final colorAttr = _productAttributes.cast<String?>().firstWhere(
          (a) => (a ?? '').toLowerCase().startsWith('renk:'),
          orElse: () => null,
        );
        if (colorAttr != null) {
          final idx = colorAttr.indexOf(':');
          if (idx > -1) {
            _productColorController.text = colorAttr.substring(idx + 1).trim();
          }
        }
        _hydrateNonFoodAttributeRows();
        _existingImageUrls = List<String>.from(
          product.imageUrls.isNotEmpty
              ? product.imageUrls
              : (product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? [product.imageUrl!]
                    : const []),
        );
        _existingVideoUrl = product.videoUrl;
        _existingVideoPath = product.videoPath;
        _existingThumbnailPath = product.thumbnailPath;
        _existingThumbnailUrl = product.thumbnailPublicUrl;
        _existingVideoDurationSeconds = product.videoDurationSeconds;
        _existingVideoSizeBytes = product.videoSizeBytes;
        _existingThumbnailSizeBytes = product.thumbnailSizeBytes;
        _existingVideoStatus = product.videoStatus;
        _selectedVideoMetadata =
            (product.videoDurationSeconds != null &&
                product.videoSizeBytes != null)
            ? ProductVideoMetadata(
                duration: Duration(seconds: product.videoDurationSeconds!),
                sizeBytes: product.videoSizeBytes!,
                width: 0,
                height: 0,
                extension: 'mp4',
                mimeType: 'video/mp4',
              )
            : null;

        // Varyantları JSON'dan yükle
        if (product.variants != null) {
          _variants = product.variants!
              .map((v) {
                // Eğer v zaten bir ProductVariant değilse (muhtemelen dynamic Map), parse et
                if (v is ProductVariant) return v;

                // Map ise dönüştür
                final map = v as Map<String, dynamic>;
                final rawUrl =
                    map['imageUrl'] ??
                    map['image_url'] ??
                    map['imagePath'] ??
                    map['image_path'];
                final imageUrl = rawUrl?.toString();
                return ProductVariant(
                  color: map['color'] ?? '',
                  size: map['size'] ?? '',
                  ram: map['ram'],
                  storage: map['storage'],
                  sku: map['sku'] ?? '',
                  stock: map['stock'] ?? 0,
                  priceDifference:
                      (map['priceDifference'] as num?)?.toDouble() ?? 0.0,
                  imagePath: imageUrl,
                  imageUrl: imageUrl,
                );
              })
              .cast<ProductVariant>()
              .toList();
        }

        _selectedAccessoryIds
          ..clear()
          ..addAll(product.accessories ?? const []);

        if (_storeMainCategory == null && product.mainCategory.isNotEmpty) {
          _storeMainCategory = product.mainCategory;
          _storeCategoryLocked = true;
        }
      });
      _syncServiceControlDefaultsIfNeeded(
        type: _selectedServiceControlType,
        force: false,
      );
      _syncWeightDefaultsIfNeeded(force: false);
      await _refreshDynamicAttributeDefinitions(
        initialValues: _extractExistingAttributeMap(
          specificationsJson: product.specifications,
          attributeLines: product.attributes,
        ),
      );
    } catch (e) {
      debugPrint('Error loading product: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, String> _extractExistingAttributeMap({
    String? specificationsJson,
    List<String> attributeLines = const <String>[],
  }) {
    final values = <String, String>{};

    final specMap = CategoryAttributeService.decodeProductSpecifications(
      specificationsJson,
    );
    values.addAll(specMap);

    for (final rawLine in attributeLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separatorIndex = line.indexOf(':');
      if (separatorIndex <= 0) continue;
      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      values.putIfAbsent(key, () => value);
    }

    return values;
  }

  Future<void> _refreshDynamicAttributeDefinitions({
    Map<String, String> initialValues = const <String, String>{},
  }) async {
    if (_isFoodCategory) {
      _attributeFormProvider.clear();
      return;
    }

    final mainCategory = (_selectedMainCategory ?? _storeMainCategory ?? '')
        .trim();
    final subCategory = (_selectedSubCategory ?? _subCategoryController.text)
        .trim();

    if (mainCategory.isEmpty || subCategory.isEmpty) {
      _attributeFormProvider.clear();
      return;
    }

    await _attributeFormProvider.loadForCategory(
      mainCategory: mainCategory,
      subCategory: subCategory,
      initialValues: initialValues,
    );
  }

  Future<void> _loadComplementaryCandidates() async {
    final sellerId = _storeService.currentUserId;
    if (sellerId == null) return;
    if (mounted) {
      setState(() => _isLoadingComplementaryCandidates = true);
    }
    try {
      final products = await _storeService.getProductsBySellerId(sellerId);
      if (!mounted) return;
      setState(() {
        _complementaryCandidates = products;
      });
    } catch (e) {
      debugPrint('Error loading complementary candidates: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingComplementaryCandidates = false);
      }
    }
  }

  void _toggleAccessorySelection(String productId) {
    setState(() {
      if (_selectedAccessoryIds.contains(productId)) {
        _selectedAccessoryIds.remove(productId);
        return;
      }
      if (_selectedAccessoryIds.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bir ürün için en fazla 2 tamamlayıcı ürün seçebilirsiniz.',
            ),
          ),
        );
        return;
      }
      _selectedAccessoryIds.add(productId);
    });
  }

  Future<void> _loadStoreCategory() async {
    try {
      final profile = await _storeService.getStoreProfile();
      if (profile == null || !mounted) return;
      final cat = profile['category'] as String?;
      final mainCat = _storeCategoryToMainCategory(cat);
      if (mounted && mainCat != null) {
        final isEditing = widget.isEdit && widget.productId != null;
        final shouldInitializeCategory =
            !isEditing || (_selectedMainCategory == null);
        setState(() {
          _storeMainCategory = mainCat;
          _storeCategoryLocked = true;
          if (shouldInitializeCategory) {
            _selectedMainCategory = mainCat;
            _selectedSubCategory = null;
            _subCategoryController.clear();
            _resetNonFoodAttributeRowsForCategory();
          }
        });
        if (shouldInitializeCategory) {
          await _refreshDynamicAttributeDefinitions();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
    _productColorController.dispose();
    _longDescController.dispose();
    _portionPriceController.dispose();
    _pricePerKgController.dispose();
    _discountPriceController.dispose();
    _minPortionController.dispose();
    _maxPortionController.dispose();
    _portionStepController.dispose();
    _minWeightController.dispose();
    _weightStepController.dispose();
    _defaultWeightController.dispose();
    _maxWeightController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _preparationTimeController.dispose();
    _subCategoryController.dispose();
    _attributeFormProvider.dispose();
    // _additionalInfoController.dispose(); // Removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactLayout = screenWidth < 1040;
    final isPhoneLayout = screenWidth < 720;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isMediaUploadActive) {
          _showUploadInProgressWarning();
          return;
        }
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => _showExitDialog(),
            icon: const Icon(Icons.close, color: Colors.black87),
          ),
          title: Text(
            widget.isEdit ? 'Ürün Düzenle' : 'Yeni Ürün Ekle',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (!isCompactLayout) ...[
              TextButton.icon(
                onPressed: _isLoading ? null : _saveDraft,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Taslak Kaydet'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishProduct,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Yayınla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (isCompactLayout)
              PopupMenuButton<String>(
                tooltip: 'İşlemler',
                onSelected: (value) {
                  if (_isLoading) return;
                  if (value == 'draft') {
                    _saveDraft();
                  } else if (value == 'publish') {
                    _publishProduct();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'draft',
                    child: Text('Taslak Kaydet'),
                  ),
                  PopupMenuItem<String>(
                    value: 'publish',
                    child: Text('Yayınla'),
                  ),
                ],
              ),
          ],
        ),
        body: isCompactLayout
            ? SingleChildScrollView(
                padding: EdgeInsets.all(isPhoneLayout ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 18),
                    _buildCurrentStepContent(),
                  ],
                ),
              )
            : Row(
                children: [
                  // Sol Taraf - Form
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepIndicator(),
                          const SizedBox(height: 32),
                          _buildCurrentStepContent(),
                        ],
                      ),
                    ),
                  ),

                  // Sağ Taraf - Önizleme ve Hesaplamalar
                  Container(
                    width: 380,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildDesktopRightSidebar(),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isCompactLayout
            ? SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _saveDraft,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Taslak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _publishProduct,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Yayınla'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildStepIndicator() {
    final isFood = _isFoodCategory;
    final steps = isFood
        ? [
            {'icon': Icons.restaurant_menu, 'label': 'Menü Bilgileri'},
            {'icon': Icons.attach_money, 'label': 'Fiyat & Porsiyon'},
            {'icon': Icons.image_outlined, 'label': 'Menü Görselleri'},
            {'icon': Icons.tune, 'label': 'Seçenekler'},
            {'icon': Icons.delivery_dining, 'label': 'Servis Ayarları'},
          ]
        : [
            {'icon': Icons.info_outline, 'label': 'Temel Bilgiler'},
            {'icon': Icons.attach_money, 'label': 'Fiyat & Stok'},
            {'icon': Icons.image_outlined, 'label': 'Görseller'},
            {'icon': Icons.palette_outlined, 'label': 'Varyantlar'},
            {'icon': Icons.local_shipping_outlined, 'label': 'Kargo & Boyut'},
          ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : isCompleted
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check
                          : steps[index]['icon'] as IconData,
                      color: isActive || isCompleted
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                steps[index]['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildPricingStep();
      case 2:
        return _buildImagesStep();
      case 3:
        return _buildVariantsStep();
      case 4:
        return _buildShippingStep();
      default:
        return Container();
    }
  }

  // Adım 1: Temel Bilgiler
  Widget _buildBasicInfoStep() {
    final isFood = _isFoodCategory;
    final showInlineSidePanel = MediaQuery.of(context).size.width < 1040;
    final selectedMainCategory =
        (_selectedMainCategory ?? _storeMainCategory ?? '').trim();
    final selectedSubCategory =
        (_selectedSubCategory ?? _subCategoryController.text).trim();
    final selectedColor = _productColorController.text.trim();
    final readyAttributeCount = _attributeFormProvider.definitions.length;
    final categorySummary = selectedMainCategory.isEmpty
        ? 'Kategori seçilmedi'
        : selectedMainCategory;
    final subCategorySummary = selectedSubCategory.isEmpty
        ? 'Alt kategori bekleniyor'
        : selectedSubCategory;
    final attributeSummary = isFood
        ? '${_productAttributes.length} servis tercihi'
        : readyAttributeCount > 0
        ? '$readyAttributeCount hazır alan'
        : selectedSubCategory.isEmpty
        ? 'Alt kategori seçildiğinde gelir'
        : 'Manuel giriş kullanılacak';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final mainColumn = [
          _buildBasicSectionCard(
            title: isFood ? 'Menü Vitrini' : 'Vitrin Bilgileri',
            subtitle: isFood
                ? 'Müşterinin ilk bakışta göreceği adı ve marka bilgisini sade ama güçlü tutun.'
                : 'Arama sonuçlarında daha iyi görünmek için ürün adını, markayı ve model bilgisini net yazın.',
            icon: isFood ? Icons.restaurant_menu : Icons.inventory_2_outlined,
            accentColor: isFood ? const Color(0xFFEA580C) : AppColors.primary,
            child: Column(
              children: [
                _buildTextField(
                  controller: _productNameController,
                  label: isFood ? 'Yemek Adı' : 'Ürün Adı',
                  hint: isFood
                      ? 'Örn: Kaşarlı Tavuk Dürüm'
                      : 'Örn: iPhone 15 Pro Max 256GB Titanyum Mavi',
                  required: true,
                  helperText: isFood
                      ? 'Kısa, net ve iştah açıcı bir isim tercih edin'
                      : 'Model, kapasite ve ayırt edici bilgileri başlıkta verin',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _brandController,
                        label: isFood ? 'Mutfak / Marka' : 'Marka',
                        hint: isFood
                            ? 'Örn: Türk Mutfağı, Dünya Mutfağı...'
                            : 'Marka seçin veya yazın',
                        required: true,
                        helperText: isFood
                            ? 'Mutfak türü veya marka kimliğini belirtin'
                            : 'Kullanıcının filtreleyebileceği marka adı',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _skuController,
                        label: 'Model/Kod',
                        hint: 'Opsiyonel',
                        helperText: isFood
                            ? 'Restoran içi kod veya varyant referansı'
                            : 'Model kodu, stok kodu veya seri adı',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (!isFood) ...[
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _productColorController,
                    label: 'Ürün Rengi',
                    hint: 'Örn: Beyaz, Siyah, Titanyum Mavi',
                    helperText: 'Varyant yoksa ana rengi burada belirtin',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBasicSectionCard(
            title: 'Kategori Yerleşimi',
            subtitle:
                'Doğru kategori seçimi filtrelenme, keşfedilme ve hazır özelliklerin yüklenmesi için kritik.',
            icon: Icons.account_tree_outlined,
            accentColor: const Color(0xFF0F766E),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _storeCategoryLocked && _storeMainCategory != null
                          ? _buildLockedCategoryField(
                              'Ana Kategori',
                              _storeMainCategory!,
                            )
                          : _buildDropdownField(
                              label: 'Ana Kategori',
                              value: _selectedMainCategory,
                              items: _allMainCategories,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMainCategory = value;
                                  _selectedSubCategory = null;
                                  _subCategoryController.clear();
                                  _resetNonFoodAttributeRowsForCategory();
                                });
                                _attributeFormProvider.clear();
                              },
                              required: true,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSubCategoryField()),
                  ],
                ),
                if (selectedSubCategory.isNotEmpty ||
                    readyAttributeCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0F766E,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_motion_outlined,
                            color: Color(0xFF0F766E),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedSubCategory.isEmpty
                                    ? 'Alt kategori bekleniyor'
                                    : '$selectedMainCategory / $selectedSubCategory',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                readyAttributeCount > 0
                                    ? '$readyAttributeCount hazır özellik alanı otomatik yüklendi.'
                                    : 'Hazır özellikler alt kategoriye göre burada açılır.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (isFood) ...[
            _buildBasicSectionCard(
              title: 'Servis Tercihleri',
              subtitle:
                  'Müşteri sipariş verirken seçebileceği hızlı tercihleri buradan ekleyin.',
              icon: Icons.tune,
              accentColor: const Color(0xFFEA580C),
              child: _buildAttributesSection(),
            ),
            const SizedBox(height: 20),
          ],
          _buildBasicSectionCard(
            title: 'Açıklama ve Hikaye',
            subtitle:
                'Ürünün ne sunduğunu, neden iyi olduğunu ve ayırt edici detaylarını kısa paragraflarla anlatın.',
            icon: Icons.notes_outlined,
            accentColor: const Color(0xFF1D4ED8),
            child: Column(
              children: [
                _buildRichTextEditor(
                  controller: _longDescController,
                  label: 'Detaylı Açıklama',
                  required: true,
                ),
                const SizedBox(height: 18),
                _buildAIDescriptionAssistant(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBasicSectionCard(
            title: 'Öne Çıkan Bilgiler',
            subtitle:
                'Kullanıcının hızlı tarayacağı kısa madde maddeleri ekleyin.',
            icon: Icons.format_list_bulleted_outlined,
            accentColor: const Color(0xFF2563EB),
            child: _buildAdditionalInfoSection(),
          ),
          const SizedBox(height: 20),
          _buildBasicSectionCard(
            title: 'Sıkça Sorulan Sorular',
            subtitle:
                'Tekrar eden müşteri sorularını önceden cevaplayarak dönüşümü artırın.',
            icon: Icons.quiz_outlined,
            accentColor: const Color(0xFF7C3AED),
            child: _buildFAQSection(),
          ),
          if (!isFood && _selectedMainCategory != null) ...[
            const SizedBox(height: 20),
            _buildNonFoodAttributeSection(),
          ],
          const SizedBox(height: 28),
          _buildNavigationButtons(),
        ];

        final sidePanel = _buildBasicInfoSidePanel(
          isFood: isFood,
          categorySummary: categorySummary,
          subCategorySummary: subCategorySummary,
          attributeSummary: attributeSummary,
          selectedColor: selectedColor,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoHero(
              isFood: isFood,
              categorySummary: categorySummary,
              subCategorySummary: subCategorySummary,
              attributeSummary: attributeSummary,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildBasicInfoSummaryTile(
                  icon: Icons.category_outlined,
                  label: 'Kategori',
                  value: categorySummary,
                  accentColor: const Color(0xFF0F766E),
                ),
                _buildBasicInfoSummaryTile(
                  icon: Icons.widgets_outlined,
                  label: 'Alt Kategori',
                  value: subCategorySummary,
                  accentColor: const Color(0xFF1D4ED8),
                ),
                _buildBasicInfoSummaryTile(
                  icon: isFood ? Icons.room_service : Icons.fact_check_outlined,
                  label: isFood ? 'Tercihler' : 'Özellik Sistemi',
                  value: attributeSummary,
                  accentColor: isFood
                      ? const Color(0xFFEA580C)
                      : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isWide || !showInlineSidePanel)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mainColumn,
              )
            else ...[
              sidePanel,
              const SizedBox(height: 20),
              ...mainColumn,
            ],
          ],
        );
      },
    );
  }

  Widget _buildBasicInfoHero({
    required bool isFood,
    required String categorySummary,
    required String subCategorySummary,
    required String attributeSummary,
  }) {
    final accentColor = isFood
        ? const Color(0xFFEA580C)
        : const Color(0xFF1D4ED8);
    final accentSoft = accentColor.withValues(alpha: 0.10);
    final title = isFood ? 'Menü Bilgileri' : 'Temel Bilgiler';
    final subtitle = isFood
        ? 'Hızlı, sade ve iştah açıcı bir menü kartı oluşturun. İlk adımda kullanıcıya görünen tüm temel bilgileri tamamlayın.'
        : 'Ürünün başlığını, konumunu ve açıklamasını tek ekranda net şekilde hazırlayın. Doğru bilgiler ürünün daha kolay bulunmasını sağlar.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentSoft, Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isFood ? Icons.restaurant_menu : Icons.storefront_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroPill(
                icon: Icons.category_outlined,
                text: categorySummary,
              ),
              _buildHeroPill(
                icon: Icons.widgets_outlined,
                text: subCategorySummary,
              ),
              _buildHeroPill(
                icon: isFood ? Icons.room_service : Icons.auto_awesome_motion,
                text: attributeSummary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInfoSidePanel({
    required bool isFood,
    required String categorySummary,
    required String subCategorySummary,
    required String attributeSummary,
    required String selectedColor,
  }) {
    final checks = [
      (
        label: isFood ? 'Menü adı yazıldı' : 'Ürün adı tamamlandı',
        done: _productNameController.text.trim().isNotEmpty,
      ),
      (
        label: 'Ana kategori seçildi',
        done: categorySummary != 'Kategori seçilmedi',
      ),
      (
        label: 'Alt kategori seçildi',
        done: subCategorySummary != 'Alt kategori bekleniyor',
      ),
      (
        label: isFood ? 'Mutfak/marka yazıldı' : 'Marka alanı dolu',
        done: _brandController.text.trim().isNotEmpty,
      ),
      (
        label: 'Açıklama hazırlandı',
        done: _longDescController.text.trim().isNotEmpty,
      ),
    ];
    final completedChecks = checks.where((item) => item.done).length;
    final progress = checks.isEmpty ? 0.0 : completedChecks / checks.length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hızlı Kontrol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedChecks / ${checks.length} temel alan hazır',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...checks.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        item.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: item.done
                            ? const Color(0xFF22C55E)
                            : Colors.white.withValues(alpha: 0.40),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yayın Kalitesi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _buildQualityTip(
                'Başlıkta marka + model + ayırt edici detay kullanın.',
              ),
              _buildQualityTip(
                'Alt kategoriyi doğru seçerseniz filtreler ve hazır özellikler daha iyi çalışır.',
              ),
              _buildQualityTip(
                isFood
                    ? 'Açıklamada porsiyon, içerik ve servis stilini belirtin.'
                    : 'Açıklamada kullanım alanı, teknik fark ve garanti bilgisini verin.',
              ),
              if (!isFood && selectedColor.isNotEmpty)
                _buildQualityTip('Seçilen renk: $selectedColor'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seçili yapı',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      categorySummary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subCategorySummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      attributeSummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRightSidebar() {
    final isFood = _isFoodCategory;
    final selectedMainCategory =
        (_selectedMainCategory ?? _storeMainCategory ?? '').trim();
    final selectedSubCategory =
        (_selectedSubCategory ?? _subCategoryController.text).trim();
    final selectedColor = _productColorController.text.trim();
    final readyAttributeCount = _attributeFormProvider.definitions.length;
    final categorySummary = selectedMainCategory.isEmpty
        ? 'Kategori seçilmedi'
        : selectedMainCategory;
    final subCategorySummary = selectedSubCategory.isEmpty
        ? 'Alt kategori bekleniyor'
        : selectedSubCategory;
    final attributeSummary = isFood
        ? '${_productAttributes.length} servis tercihi'
        : readyAttributeCount > 0
        ? '$readyAttributeCount hazır alan'
        : selectedSubCategory.isEmpty
        ? 'Alt kategori seçildiğinde gelir'
        : 'Manuel giriş kullanılacak';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductPreview(),
        const SizedBox(height: 20),
        _buildBasicInfoSidePanel(
          isFood: isFood,
          categorySummary: categorySummary,
          subCategorySummary: subCategorySummary,
          attributeSummary: attributeSummary,
          selectedColor: selectedColor,
        ),
        const SizedBox(height: 20),
        _buildProfitCalculator(),
        const SizedBox(height: 20),
        _buildQuickTips(),
      ],
    );
  }

  Widget _buildQualityTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonFoodAttributeSection() {
    return ChangeNotifierProvider<CategoryAttributeFormProvider>.value(
      value: _attributeFormProvider,
      child: Consumer<CategoryAttributeFormProvider>(
        builder: (context, provider, child) {
          if ((_selectedSubCategory ?? _subCategoryController.text)
              .trim()
              .isEmpty) {
            return _buildBasicSectionCard(
              title: 'Ürün Özellikleri',
              subtitle:
                  'Hazır özellikleri görmek için önce alt kategori seçin.',
              icon: Icons.fact_check_outlined,
              accentColor: AppColors.primary,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Alt kategori seçildiğinde bu bölüm otomatik dolacaktır.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            );
          }

          if (provider.hasDefinitions || provider.isLoading) {
            return const DynamicCategoryAttributeForm(
              title: 'Kategoriye Özel Özellikler',
              subtitle:
                  'Bu alanlar seçilen alt kategoriye göre hazır gelir. Sadece değer girmeniz yeterlidir.',
            );
          }

          return _buildBasicSectionCard(
            title: 'Manuel Ürün Özellikleri',
            subtitle: provider.errorMessage == null
                ? 'Bu alt kategori için hazır attribute bulunamadı. Geçici olarak manuel giriş kullanılacak.'
                : 'Hazır attribute yüklenemedi. Geçici olarak manuel giriş kullanılacak.',
            icon: Icons.edit_note_outlined,
            accentColor: const Color(0xFF2563EB),
            child: _buildNonFoodAttributeEditor(),
          );
        },
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      children: [
        ..._additionalInfos.asMap().entries.map((entry) {
          final index = entry.key;
          final info = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purple Dot
                Container(
                  margin: const EdgeInsets.only(top: 14, right: 12),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                // Text Field
                Expanded(
                  child: TextFormField(
                    initialValue: info,
                    decoration: InputDecoration(
                      hintText: 'Bilgi ekleyin...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _additionalInfos.removeAt(index);
                          });
                        },
                      ),
                    ),
                    maxLines: null,
                    onChanged: (value) {
                      _additionalInfos[index] = value;
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        // Add Button
        InkWell(
          onTap: () {
            setState(() {
              _additionalInfos.add('');
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Yeni Madde Ekle',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQSection() {
    return Column(
      children: [
        ..._faqs.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Soru ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _faqs.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: faq['question'],
                  decoration: const InputDecoration(
                    labelText: 'Soru',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    faq['question'] = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: faq['answer'],
                  decoration: const InputDecoration(
                    labelText: 'Cevap',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    faq['answer'] = value;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_lastSavedFaqIndex == index) ...[
                      Text(
                        'Kaydedildi',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isFaqSaving
                          ? null
                          : () => _saveFaqsInline(sourceIndex: index),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: _faqs.length >= 5
              ? null
              : () {
                  setState(() {
                    _faqs.add({'question': '', 'answer': ''});
                  });
                },
          icon: const Icon(Icons.add),
          label: const Text('Soru Ekle'),
        ),
      ],
    );
  }

  List<Map<String, String>> _cleanFaqs(List<Map<String, String>> faqs) {
    return faqs
        .map(
          (m) => {
            'question': (m['question'] ?? '').toString().trim(),
            'answer': (m['answer'] ?? '').toString().trim(),
          },
        )
        .where((m) => m['question']!.isNotEmpty && m['answer']!.isNotEmpty)
        .take(5)
        .toList();
  }

  Future<void> _saveFaqsInline({required int sourceIndex}) async {
    if (_isFaqSaving) return;
    final cleanedFaqs = _cleanFaqs(_faqs);

    if (cleanedFaqs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydetmek için en az 1 soru ve cevap girin'),
        ),
      );
      return;
    }

    setState(() {
      _isFaqSaving = true;
    });

    try {
      final productId =
          widget.productId ??
          _faqDraftProductId ??
          DateTime.now().millisecondsSinceEpoch.toString();
      if (widget.productId == null && _faqDraftProductId == null) {
        _faqDraftProductId = productId;
        final draft = SellerProduct(
          id: productId,
          name: _productNameController.text.isEmpty
              ? 'Taslak Ürün'
              : _productNameController.text,
          brand: _brandController.text,
          mainCategory: _selectedMainCategory ?? '',
          subCategory: _selectedSubCategory ?? '',
          price: _activePriceValue,
          pricingType: _pricingTypeForSave.storageValue,
          portionPrice: _portionPriceValue > 0 ? _portionPriceValue : null,
          pricePerKg: _pricePerKgValue > 0 ? _pricePerKgValue : null,
          serviceControlType:
              _selectedServiceControlType == ProductServiceControlType.none
              ? null
              : _selectedServiceControlType.storageValue,
          minPortion: _usesPortionLikeServiceControl
              ? _parsedMinPortion()
              : null,
          maxPortion: _usesPortionLikeServiceControl
              ? _parsedMaxPortion()
              : null,
          portionStep: _usesPortionLikeServiceControl
              ? _parsedPortionStep()
              : null,
          defaultWeightGrams: _pricingTypeForSave == ProductPricingType.weight
              ? _parsedDefaultWeight()
              : null,
          minWeightGrams: _pricingTypeForSave == ProductPricingType.weight
              ? _parsedMinWeight()
              : null,
          weightStepGrams: _pricingTypeForSave == ProductPricingType.weight
              ? _parsedWeightStep()
              : null,
          maxWeightGrams: _pricingTypeForSave == ProductPricingType.weight
              ? _parsedMaxWeight()
              : null,
          discountPrice:
              _selectedServiceControlType == ProductServiceControlType.none &&
                  _pricingTypeForSave == ProductPricingType.portion &&
                  _discountPriceController.text.isNotEmpty
              ? _parseCurrency(_discountPriceController.text)
              : null,
          stock: _parseNumber(_stockController.text),
          sku: _skuController.text.isEmpty
              ? 'SKU${DateTime.now().millisecondsSinceEpoch}'
              : _skuController.text,
          status: 'Taslak',
          imageUrl: null,
          description: _longDescController.text,
          specifications: _finalSpecificationsForSave(),
          preparationTime: _preparationTimeValueForSave(),
          createdAt: DateTime.now(),
          attributes: _finalAttributesForSave(),
          videoUrl: _existingVideoUrl,
          videoPath: _existingVideoPath,
          videoPublicUrl: _existingVideoUrl,
          thumbnailPath: _existingThumbnailPath,
          thumbnailPublicUrl: _existingThumbnailUrl,
          videoDurationSeconds: _existingVideoDurationSeconds,
          videoSizeBytes: _existingVideoSizeBytes,
          thumbnailSizeBytes: _existingThumbnailSizeBytes,
          videoStatus: _existingVideoStatus,
          accessories: _selectedAccessoryIds.toList(),
        );
        await _storeService.saveProductDraft(draft, variants: _variants);
        await _persistStructuredProductAttributes(productId);
      }

      await _storeService.updateProductFaq(
        productId: productId,
        faq: cleanedFaqs,
      );

      if (mounted) {
        setState(() {
          _lastSavedFaqIndex = sourceIndex;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (_lastSavedFaqIndex != sourceIndex) return;
          setState(() {
            _lastSavedFaqIndex = null;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFaqSaving = false;
        });
      }
    }
  }

  // Adım 2: Fiyat & Stok
  Widget _buildPricingStep() {
    final isFood = _isFoodCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isFood ? 'Fiyatlandırma ve Porsiyon' : 'Fiyatlandırma ve Stok',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          isFood
              ? 'Yemeğin fiyatlandirma tipini, fiyatini ve stok bilgisini girin'
              : 'Fiyat, stok ve vergi bilgilerini girin',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),
        if (isFood) ...[
          PricingTypeSelector(
            value: _pricingTypeForSave,
            onChanged: (value) {
              setState(() {
                _selectedPricingType = value;
                if (value == ProductPricingType.weight) {
                  _selectedServiceControlType =
                      ProductServiceControlType.weightStepper;
                  _syncWeightDefaultsIfNeeded(force: false);
                } else {
                  if (_selectedServiceControlType ==
                          ProductServiceControlType.weightStepper ||
                      _selectedServiceControlType ==
                          ProductServiceControlType.none) {
                    _selectedServiceControlType =
                        ProductServiceControlType.portionStepper;
                  }
                  _syncServiceControlDefaultsIfNeeded(
                    type: _selectedServiceControlType,
                    force: false,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 20),
          if (_pricingTypeForSave == ProductPricingType.portion) ...[
            ServiceControlSelector(
              value: _selectedServiceControlType,
              title: 'Porsiyon Yapısı',
              options: const <ProductServiceControlType>[
                ProductServiceControlType.none,
                ProductServiceControlType.portionStepper,
                ProductServiceControlType.skewerStepper,
              ],
              onChanged: (value) {
                setState(() {
                  _selectedServiceControlType = value;
                  if (value == ProductServiceControlType.none) return;
                  _syncServiceControlDefaultsIfNeeded(
                    type: value,
                    force: false,
                  );
                });
              },
            ),
            const SizedBox(height: 20),
          ],
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _activePriceController,
                label: _isWeightPricingActive
                    ? '1 Kilogram Fiyati'
                    : _selectedServiceControlType ==
                          ProductServiceControlType.portionStepper
                    ? '1 Porsiyon Fiyati'
                    : _selectedServiceControlType ==
                          ProductServiceControlType.skewerStepper
                    ? 'Tek Sis Fiyati'
                    : 'Satis Fiyati',
                hint: '0.00',
                prefix: '₺',
                required: true,
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
              ),
            ),
            if (!_isWeightPricingActive &&
                _selectedServiceControlType ==
                    ProductServiceControlType.none) ...[
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _discountPriceController,
                  label: 'Indirimli Fiyat',
                  hint: 'Opsiyonel',
                  prefix: '₺',
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField(
                label: 'KDV Oranı',
                value: _selectedVatRate,
                items: ['%1', '%8', '%18', '%20'],
                onChanged: (value) {
                  setState(() {
                    _selectedVatRate = value!;
                  });
                },
                required: true,
              ),
            ),
          ],
        ),

        if (!_isWeightPricingActive &&
            _selectedServiceControlType == ProductServiceControlType.none &&
            _discountPriceController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Indirim Orani: ${_calculateDiscountRate()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        if (_usesPortionLikeServiceControl) ...[
          const SizedBox(height: 20),
          ServiceStepperFields(
            serviceControlType: _selectedServiceControlType,
            minController: _minPortionController,
            maxController: _maxPortionController,
            stepController: _portionStepController,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Onizleme: ${ProductPriceCalculator.formatCurrency(_portionPriceValue)} · ${ProductPriceCalculator.buildServiceControlSummary(type: _selectedServiceControlType, minPortion: _parsedMinPortion(), maxPortion: _parsedMaxPortion(), portionStep: _parsedPortionStep())}\nSecenekler: ${_portionOptionsPreview()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],

        if (_isWeightPricingActive) ...[
          const SizedBox(height: 20),
          WeightPricingFields(
            minWeightController: _minWeightController,
            weightStepController: _weightStepController,
            defaultWeightController: _defaultWeightController,
            maxWeightController: _maxWeightController,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Onizleme: ${ProductPriceCalculator.formatPerKgLabel(_pricePerKgValue)} · ${ProductPriceCalculator.buildWeightRangeLabel(minWeightGrams: _parsedMinWeight(), defaultWeightGrams: _parsedDefaultWeight())}\nSecenekler: ${_weightOptionsPreview()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _stockController,
                label: 'Stok Miktarı',
                hint: '0',
                required: true,
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: TextEditingController(
                  text: _stockAlertLevel.toString(),
                ),
                label: 'Stok Alarm Seviyesi',
                hint: '10',
                helperText: 'Bu seviyenin altında bildirim alırsınız',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _stockAlertLevel = int.tryParse(value) ?? 10;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Video alanı kaldırıldı
        const SizedBox(height: 32),
        _buildNavigationButtons(),
      ],
    );
  }

  // Adım 3: Görseller
  Widget _buildImagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ürün Görselleri',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'En az 1, en fazla 8 görsel ekleyebilirsiniz',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'İlk görsel ana görsel olarak kullanılacaktır. Beyaz arka planlı, yüksek çözünürlüklü görseller kullanın.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ...List.generate(_existingImageUrls.length, (index) {
              return _buildImageUploadBox(
                index: null,
                isMain: index == 0 && _productImages.every((x) => x == null),
                imageFile: null,
                imageUrl: _existingImageUrls[index],
                onRemoveExisting: () =>
                    setState(() => _existingImageUrls.removeAt(index)),
              );
            }),
            ...List.generate(8, (index) {
              return _buildImageUploadBox(
                index: index,
                isMain: _existingImageUrls.isEmpty && index == 0,
                imageFile: _productImages[index],
                imageUrl: null,
              );
            }),
          ],
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickMultipleImages,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Toplu Yükleme'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Arka Plan Sil (AI)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // --- Video Ekleme Alanı ---
        const Text(
          'Ürün Tanıtım Videosu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Maksimum 30 saniye. Upload öncesi 720p (H264/AAC) optimize edilir. (Opsiyonel)',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        _buildVideoSelectionPanel(),

        const SizedBox(height: 32),
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildVideoSelectionPanel() {
    final hasVideo = _videoFile != null || _existingVideoUrl != null;
    final metadata = _selectedVideoMetadata;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasVideo ? AppColors.primary : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isMediaUploadActive ? null : _pickVideo,
                icon: const Icon(Icons.video_library_outlined, size: 18),
                label: Text(hasVideo ? 'Videoyu Değiştir' : 'Video Seç'),
              ),
              const SizedBox(width: 8),
              if (hasVideo)
                OutlinedButton.icon(
                  onPressed: _isMediaUploadActive
                      ? null
                      : () {
                          setState(() {
                            _videoFile = null;
                            _existingVideoUrl = null;
                            _selectedVideoMetadata = null;
                            _existingVideoPath = null;
                            _existingThumbnailPath = null;
                            _existingThumbnailUrl = null;
                            _existingVideoDurationSeconds = null;
                            _existingVideoSizeBytes = null;
                            _existingThumbnailSizeBytes = null;
                            _existingVideoStatus = null;
                            _mediaStage = ProductMediaStage.idle;
                            _mediaStageLabel = 'Video kaldırıldı';
                            _mediaUploadProgress = 0;
                          });
                        },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Kaldır'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasVideo)
            Text(
              'Liste ekranlarında video oynatılmaz. Bu alanda sadece metadata ve thumbnail kullanılır.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          if (hasVideo) ...[
            _buildVideoThumbnailPreview(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (metadata != null)
                  _buildInfoChip(
                    Icons.timer_outlined,
                    '${metadata.duration.inSeconds} sn',
                  )
                else if (_existingVideoDurationSeconds != null)
                  _buildInfoChip(
                    Icons.timer_outlined,
                    '$_existingVideoDurationSeconds sn',
                  ),
                if (metadata != null)
                  _buildInfoChip(
                    Icons.sd_storage_outlined,
                    _formatBytes(metadata.sizeBytes),
                  )
                else if (_existingVideoSizeBytes != null)
                  _buildInfoChip(
                    Icons.sd_storage_outlined,
                    _formatBytes(_existingVideoSizeBytes!),
                  ),
                if (metadata != null &&
                    metadata.width > 0 &&
                    metadata.height > 0)
                  _buildInfoChip(
                    Icons.aspect_ratio_outlined,
                    '${metadata.width}x${metadata.height}',
                  ),
                if (metadata != null)
                  _buildInfoChip(
                    Icons.description_outlined,
                    metadata.extension.toUpperCase(),
                  ),
              ],
            ),
          ],
          if (_mediaStage != ProductMediaStage.idle ||
              _isMediaUploadActive) ...[
            const SizedBox(height: 12),
            _buildMediaPipelineStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoThumbnailPreview() {
    final thumbUrl = _existingThumbnailUrl?.trim();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: Colors.black,
          child: thumbUrl != null && thumbUrl.isNotEmpty
              ? OptimizedImage(
                  imageUrlOrPath: thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildVideoFallbackPreview(),
                )
              : _buildVideoFallbackPreview(),
        ),
      ),
    );
  }

  Widget _buildVideoFallbackPreview() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.white,
        size: 44,
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMediaPipelineStatus() {
    final steps = <Map<String, dynamic>>[
      {'label': 'Video seçiliyor', 'stage': ProductMediaStage.picking},
      {'label': 'Optimize ediliyor', 'stage': ProductMediaStage.optimizing},
      {
        'label': 'Thumbnail hazırlanıyor',
        'stage': ProductMediaStage.generatingThumbnail,
      },
      {'label': 'Upload ediliyor', 'stage': ProductMediaStage.uploading},
      {'label': 'Veri kaydediliyor', 'stage': ProductMediaStage.saving},
    ];

    int stageIndex(ProductMediaStage stage) {
      return switch (stage) {
        ProductMediaStage.picking => 0,
        ProductMediaStage.readingMetadata => 0,
        ProductMediaStage.optimizing => 1,
        ProductMediaStage.generatingThumbnail => 2,
        ProductMediaStage.uploading => 3,
        ProductMediaStage.saving => 4,
        ProductMediaStage.done => 5,
        ProductMediaStage.failed => 5,
        ProductMediaStage.cancelled => 5,
        ProductMediaStage.idle => -1,
      };
    }

    final activeIndex = stageIndex(_mediaStage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mediaStageLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: _mediaUploadProgress > 0 ? _mediaUploadProgress : null,
          minHeight: 6,
          backgroundColor: Colors.grey.shade300,
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final done =
                activeIndex > index || _mediaStage == ProductMediaStage.done;
            final active = activeIndex == index;
            final color = done || active
                ? AppColors.primary
                : Colors.grey.shade500;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  item['label'] as String,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // Adım 4: Varyantlar
  Widget _buildVariantsStep() {
    String variantTitle = 'Ürün Seçenekleri';
    String variantSubtitle = 'Seçenek ekleyin';

    if (_selectedMainCategory == 'Yemek') {
      variantTitle = 'Porsiyon & Ek Malzeme';
      variantSubtitle = 'Porsiyon boyutu veya ek malzemeler ekleyin';
    } else if (_selectedMainCategory == 'Giyim & Aksesuar' ||
        _selectedSubCategory == 'Ayakkabı') {
      variantTitle = 'Beden & Renk';
      variantSubtitle = 'Beden ve renk seçeneklerini tanımlayın';
    } else if (_selectedMainCategory == 'Elektronik') {
      variantTitle = 'Kapasite & Renk';
      variantSubtitle = 'Hafıza ve renk seçenekleri';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variantTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    variantSubtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addVariant,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        if (_variants.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz seçenek eklenmedi',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Müşterilerinize sunmak istediğiniz seçenekleri ekleyin',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _variants.asMap().entries.map((entry) {
              final index = entry.key;
              final variant = entry.value;
              return _buildVariantCard(variant, index);
            }).toList(),
          ),

        const SizedBox(height: 28),
        _buildComplementaryProductsEditor(),
        const SizedBox(height: 32),
        _buildNavigationButtons(),
      ],
    );
  }

  // Adım 5: Kargo & Boyut
  Widget _buildShippingStep() {
    if (_isFoodCategory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Servis ve Hazırlık Bilgileri',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Müşterilerin sipariş verirken göreceği servis ve süre bilgilerini tanımlayın',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          _buildDropdownField(
            label: 'Servis Tipi',
            items: _dropdownItems(_serviceTypeOptions, _selectedServiceType),
            value: _selectedServiceType,
            onChanged: (value) => setState(() => _selectedServiceType = value),
          ),
          const SizedBox(height: 24),
          _buildPreparationTimeField(),
          const SizedBox(height: 24),
          _buildDropdownField(
            label: 'Servis Zamanı',
            items: _dropdownItems(_serviceTimeOptions, _selectedServiceTime),
            value: _selectedServiceTime,
            onChanged: (value) => setState(() => _selectedServiceTime = value),
          ),
          const SizedBox(height: 32),
          _buildNavigationButtons(isLastStep: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kargo ve Boyut Bilgileri',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ürün boyutları ve kargo seçeneklerini girin',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Ağırlık',
                hint: '0.0',
                suffix: 'kg',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                label: 'En',
                hint: '0',
                suffix: 'cm',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                label: 'Boy',
                hint: '0',
                suffix: 'cm',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                label: 'Yükseklik',
                hint: '0',
                suffix: 'cm',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                size: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Otomatik Desi Hesaplama: ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                '0.00',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildDropdownField(
          label: 'Kargo Seçeneği',
          value: _selectedShippingOption,
          items: ['Ücretsiz Kargo', 'Alıcı Öder', 'Sabit Ücret'],
          onChanged: (value) {
            setState(() {
              _selectedShippingOption = value!;
            });
          },
          required: true,
        ),

        if (_selectedShippingOption == 'Sabit Ücret')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildTextField(
              label: 'Kargo Ücreti',
              hint: '0.00',
              prefix: '₺',
              keyboardType: TextInputType.number,
            ),
          ),

        const SizedBox(height: 24),

        _buildDropdownField(
          label: 'Tahmini Teslimat Süresi',
          items: [
            '24 saatte kargoda',
            '2-3 iş günü',
            '3-5 iş günü',
            '5-7 iş günü',
          ],
          onChanged: (value) {},
          required: true,
        ),

        const SizedBox(height: 32),
        _buildNavigationButtons(isLastStep: true),
      ],
    );
  }

  // Ürün Özellikleri artık Temel Bilgiler adımında

  Widget _buildImageUploadBox({
    required int? index,
    required bool isMain,
    XFile? imageFile,
    String? imageUrl,
    VoidCallback? onRemoveExisting,
  }) {
    final hasImage = imageFile != null || imageUrl != null;
    return GestureDetector(
      onTap: index != null ? () => _pickImage(index) : null,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(
            color: isMain ? AppColors.primary : Colors.grey.shade300,
            width: isMain ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasImage ? Colors.white : Colors.grey.shade50,
        ),
        child: hasImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: imageFile != null
                        ? Image(
                            image: xFileImageProvider(imageFile),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined, size: 40),
                          )
                        : OptimizedImage(
                            imageUrlOrPath: imageUrl!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined, size: 40),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: imageUrl != null
                          ? onRemoveExisting
                          : (index != null ? () => _removeImage(index) : null),
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                  if (isMain)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Ana Görsel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: isMain ? AppColors.primary : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isMain ? 'Ana Görsel' : 'Görsel Ekle',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMain ? AppColors.primary : Colors.grey.shade600,
                      fontWeight: isMain ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isMain)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '(Zorunlu)',
                        style: TextStyle(fontSize: 9, color: Colors.red),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildVariantCard(ProductVariant variant, int index) {
    final isElectronics = _selectedMainCategory == 'Elektronik';

    final displayNetworkUrl = (variant.imageUrl ?? '').trim().isNotEmpty
        ? variant.imageUrl
        : ((variant.imagePath ?? '').trim().startsWith('http')
              ? variant.imagePath
              : null);

    // Safety check: Don't create XFile from a URL string
    final isLocalPath =
        (variant.imagePath ?? '').trim().isNotEmpty &&
        !(variant.imagePath!.startsWith('http'));
    final displayXFile =
        variant.imageFile ?? (isLocalPath ? XFile(variant.imagePath!) : null);

    final storage = (variant.storage ?? '').trim();
    final ram = (variant.ram ?? '').trim();
    final color = variant.color.trim().isEmpty ? '-' : variant.color.trim();
    final size = variant.size.trim().isEmpty ? '-' : variant.size.trim();
    final diff = variant.priceDifference;
    final diffText = diff == 0
        ? 'Fiyat farkı: Ana fiyat'
        : 'Fiyat farkı: ${diff > 0 ? '+' : '-'}₺${diff.abs().toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickVariantImage(index),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade50,
              ),
              child: (displayNetworkUrl != null || displayXFile != null)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: displayNetworkUrl != null
                          ? OptimizedImage(
                              imageUrlOrPath: displayNetworkUrl,
                              fit: BoxFit.cover,
                            )
                          : Image(
                              image: xFileImageProvider(displayXFile!),
                              fit: BoxFit.cover,
                            ),
                    )
                  : const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isElectronics)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (storage.isNotEmpty)
                        _variantBadge('Kapasite: $storage'),
                      if (ram.isNotEmpty) _variantBadge('RAM: $ram'),
                    ],
                  )
                else
                  _variantBadge('Boyut: $size'),
                const SizedBox(height: 8),
                Text(
                  'Renk: $color',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  diffText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: diff >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${variant.sku.isEmpty ? '-' : variant.sku} • Stok: ${variant.stock}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editVariant(index),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Düzenle',
          ),
          IconButton(
            onPressed: () => _removeVariant(index),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _variantBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildComplementaryProductsEditor() {
    final currentProductId = widget.productId;
    final candidates = _complementaryCandidates
        .where((item) => item['id']?.toString() != currentProductId)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEE8FF), Color(0xFFF7F3FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Birlikte İyi Gider',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ürün sayfasında ana ürünün yanında göstermek istediğiniz en fazla 2 kendi ürününüzü seçin.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_selectedAccessoryIds.length}/2 seçildi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingComplementaryCandidates)
            const Center(child: CircularProgressIndicator())
          else if (candidates.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Burada seçim yapabilmek için önce mağazanıza en az 2 ürün yükleyin.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: candidates
                  .map((product) => _buildComplementaryCandidateCard(product))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildComplementaryCandidateCard(Map<String, dynamic> product) {
    final id = product['id']?.toString() ?? '';
    final isSelected = _selectedAccessoryIds.contains(id);
    String imageUrl = (product['image_url'] ?? '').toString();
    if (imageUrl.isEmpty && product['image_urls'] is List) {
      final urls = List<String>.from(product['image_urls'] as List);
      if (urls.isNotEmpty) {
        imageUrl = urls.first;
      }
    }
    final name = (product['name'] ?? 'Ürün').toString();
    final brand = (product['brand'] ?? '').toString();
    final rawPrice = product['price'];
    final priceText = rawPrice == null ? '-' : '₺${rawPrice.toString()}';

    return InkWell(
      onTap: id.isEmpty ? null : () => _toggleAccessorySelection(id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8F8FB),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isEmpty
                  ? Icon(Icons.image_outlined, color: Colors.grey.shade400)
                  : OptimizedImage(
                      imageUrlOrPath: imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.isEmpty ? 'Mağaza ürünü' : brand,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    String? hint,
    String? helperText,
    String? prefix,
    String? suffix,
    String? initialValue,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller:
              controller ??
              (initialValue != null
                  ? TextEditingController(text: initialValue)
                  : null),
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixText: prefix,
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedCategoryField(String label, String categoryValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  categoryValue,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Icon(Icons.lock, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mağaza kategoriniz. Değiştirmek için Destek > Kategori değişimi talebi oluşturun.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSubCategoryField() {
    final suggestions = _getSubCategories(_selectedMainCategory);
    final hintText = _selectedMainCategory == null
        ? 'Önce Ana Kategori seçin'
        : (suggestions.isNotEmpty
              ? 'Örn: ${suggestions.take(3).join(', ')}...'
              : 'Alt kategori yazın');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Alt Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _subCategoryController,
          enabled: _selectedMainCategory != null,
          onChanged: (v) async {
            setState(() {
              _selectedSubCategory = v.trim().isEmpty ? null : v.trim();
              _resetNonFoodAttributeRowsForCategory();
            });
            await _refreshDynamicAttributeDefinitions(
              initialValues: _extractExistingAttributeMap(
                attributeLines: _productAttributes,
              ),
            );
          },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            filled: true,
            fillColor: _selectedMainCategory == null
                ? const Color(0xFFF9FAFB)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF6B21A8),
                width: 1.5,
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            suffixIcon: suggestions.isNotEmpty
                ? PopupMenuButton<String>(
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade500,
                    ),
                    onSelected: (v) {
                      setState(() {
                        _subCategoryController.text = v;
                        _selectedSubCategory = v;
                        _resetNonFoodAttributeRowsForCategory();
                      });
                      _refreshDynamicAttributeDefinitions(
                        initialValues: _extractExistingAttributeMap(
                          attributeLines: _productAttributes,
                        ),
                      );
                    },
                    itemBuilder: (ctx) => suggestions
                        .map(
                          (s) => PopupMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : null,
          ),
        ),
        if (suggestions.isNotEmpty && _selectedMainCategory != 'Yemek') ...[
          const SizedBox(height: 6),
          Text(
            'Öneri: ${suggestions.take(3).join(', ')}...',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  Widget _buildNonFoodAttributeEditor() {
    if (_nonFoodAttributeRows.isEmpty) {
      _resetNonFoodAttributeRowsForCategory();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Özellik Başlığı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Açıklama / Değer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(width: 36),
          ],
        ),
        const SizedBox(height: 8),
        ..._nonFoodAttributeRows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row['key'] ?? '',
                    onChanged: (v) => _nonFoodAttributeRows[index]['key'] = v,
                    decoration: InputDecoration(
                      hintText: 'Örn: Garanti Süresi',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: row['value'] ?? '',
                    onChanged: (v) => _nonFoodAttributeRows[index]['value'] = v,
                    decoration: InputDecoration(
                      hintText: 'Örn: 1 Yıl',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _nonFoodAttributeRows.length <= 1
                      ? null
                      : () => setState(
                          () => _nonFoodAttributeRows.removeAt(index),
                        ),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => setState(
              () => _nonFoodAttributeRows.add({'key': '', 'value': ''}),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Satır Ekle'),
          ),
        ),
      ],
    );
  }

  void _hydrateNonFoodAttributeRows() {
    if (_isFoodCategory) return;
    final rows = <Map<String, String>>[];
    for (final attr in _productAttributes) {
      final text = attr.trim();
      if (text.isEmpty) continue;
      final idx = text.indexOf(':');
      if (idx <= 0) continue;
      rows.add({
        'key': text.substring(0, idx).trim(),
        'value': text.substring(idx + 1).trim(),
      });
    }
    _nonFoodAttributeRows = rows;
    if (_nonFoodAttributeRows.isEmpty) {
      _resetNonFoodAttributeRowsForCategory();
    }
  }

  void _resetNonFoodAttributeRowsForCategory() {
    if (_isFoodCategory) {
      _nonFoodAttributeRows = [];
      return;
    }
    if (_selectedMainCategory == 'Elektronik') {
      _nonFoodAttributeRows = [
        {'key': 'Dahili Hafıza', 'value': '64 GB'},
        {'key': 'Kozmetik Durum', 'value': 'B seviye-Çok İyi'},
        {'key': 'Garanti Süresi', 'value': '1 Yıl'},
        {'key': 'Pil Gücü (mAh)', 'value': '2800 ve üstü'},
        {'key': 'Ana Kamera Çözünürlük Aralığı', 'value': '10 - 15 MP'},
        {'key': 'Garanti Tipi', 'value': 'Yenilenmiş Ürün (12 Ay Garanti)'},
        {'key': 'Renk', 'value': 'Beyaz'},
        {'key': 'Ekran Boyutu', 'value': '6,8 inç'},
        {'key': 'Kamera Çözünürlüğü', 'value': '10 - 15 MP'},
        {'key': 'RAM Kapasitesi', 'value': '3 GB'},
        {'key': 'Batarya Kapasitesi Aralığı', 'value': '2000-3000 mAh'},
        {'key': 'Menşei', 'value': 'TR'},
        {'key': 'Cep Telefonu Modeli', 'value': 'iPhone 11'},
      ];
      return;
    }
    if (_nonFoodAttributeRows.isEmpty) {
      _nonFoodAttributeRows = [
        {'key': '', 'value': ''},
      ];
    }
  }

  List<String> _finalAttributesForSave() {
    if (_isFoodCategory) {
      return _productAttributes;
    }
    if (_attributeFormProvider.hasDefinitions) {
      final attributeLines = _attributeFormProvider.attributeLines();
      if (attributeLines.isNotEmpty) {
        return attributeLines;
      }
    }
    final rows = _nonFoodAttributeRows
        .map(
          (r) => {
            'key': (r['key'] ?? '').trim(),
            'value': (r['value'] ?? '').trim(),
          },
        )
        .where((r) => r['key']!.isNotEmpty && r['value']!.isNotEmpty)
        .toList();

    final selectedColor = _productColorController.text.trim();
    if (selectedColor.isNotEmpty) {
      final colorIndex = rows.indexWhere(
        (r) => r['key']!.toLowerCase() == 'renk',
      );
      if (colorIndex >= 0) {
        rows[colorIndex]['value'] = selectedColor;
      } else {
        rows.insert(0, {'key': 'Renk', 'value': selectedColor});
      }
    }

    return rows
        .map(
          (row) =>
              '${(row['key'] ?? '').trim()}: ${(row['value'] ?? '').trim()}',
        )
        .where((line) {
          final parts = line.split(':');
          if (parts.length < 2) return false;
          final key = parts.first.trim();
          final value = parts.sublist(1).join(':').trim();
          return key.isNotEmpty && value.isNotEmpty;
        })
        .toList();
  }

  Map<String, String> _finalStructuredAttributesMap() {
    final values = _attributeFormProvider.valuesByName();
    if (values.isNotEmpty) {
      final selectedColor = _productColorController.text.trim();
      final colorKey = values.keys.cast<String?>().firstWhere(
        (key) => (key ?? '').trim().toLowerCase() == 'renk',
        orElse: () => null,
      );
      if (selectedColor.isNotEmpty && colorKey != null) {
        values[colorKey] = selectedColor;
      }
      return values;
    }
    return _extractExistingAttributeMap(
      attributeLines: _finalAttributesForSave(),
    );
  }

  String? _finalSpecificationsForSave() {
    if (_isFoodCategory) {
      final foodSpecs = Map<String, dynamic>.from(_foodSpecificationSeed);
      final preparationMinutes = _validatedPreparationMinutesValue();
      final serviceType = _cleanSelection(_selectedServiceType);
      final serviceTime = _cleanSelection(_selectedServiceTime);

      for (final key in _preparationTimeSpecificationKeys) {
        foodSpecs.remove(key);
      }
      foodSpecs.remove('service_type');
      foodSpecs.remove('service_time');
      foodSpecs.remove('servis_tipi');
      foodSpecs.remove('servis_zamani');

      if (preparationMinutes != null) {
        foodSpecs['preparationTime'] = preparationMinutes;
      }

      if (serviceType == null) {
        foodSpecs.remove('serviceType');
      } else {
        foodSpecs['serviceType'] = serviceType;
      }

      if (serviceTime == null) {
        foodSpecs.remove('serviceTime');
      } else {
        foodSpecs['serviceTime'] = serviceTime;
      }

      return foodSpecs.isEmpty ? null : jsonEncode(foodSpecs);
    }
    final values = _finalStructuredAttributesMap();
    if (values.isEmpty) return null;
    return jsonEncode(values);
  }

  Future<void> _persistStructuredProductAttributes(String productId) async {
    if (_isFoodCategory || !_attributeFormProvider.hasDefinitions) {
      _categoryAttributeService.invalidateProductCache(productId);
      return;
    }

    await _categoryAttributeService.saveProductAttributes(
      productId: productId,
      definitions: _attributeFormProvider.definitions,
      valuesByAttributeId: _attributeFormProvider.valuesByAttributeId,
    );
  }

  Widget _buildAttributesSection() {
    final attrController = TextEditingController();
    final bool isFood =
        _selectedMainCategory == 'Yemek' || _storeMainCategory == 'Yemek';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: Color(0xFF6B21A8)),
              const SizedBox(width: 8),
              const Text(
                'Ürün Özellikleri',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'İsteğe Bağlı',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B21A8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isFood
                ? 'Müşterilerin sipariş sırasında seçebileceği yemek özelliklerini ekleyin. Örn: Domatessiz, Acısız, Ekstra Peynir'
                : 'Müşterilerin sipariş sırasında seçebileceği özellikler ekleyin. Örn: Renk, Beden, Boyut',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          if (isFood) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foodAttributeSuggestions.map((s) {
                final selected = _productAttributes.contains(s);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _productAttributes.remove(s);
                      } else {
                        _productAttributes.add(s);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6B21A8) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          s,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF6B21A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (_productAttributes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _productAttributes.map((attr) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _productAttributes.remove(attr)),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: attrController,
                  onFieldSubmitted: (v) {
                    final trimmed = v.trim();
                    if (trimmed.isNotEmpty &&
                        !_productAttributes.contains(trimmed)) {
                      setState(() => _productAttributes.add(trimmed));
                      attrController.clear();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Özellik adı (Enter ile ekle)',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF6B21A8),
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatefulBuilder(
                builder: (ctx, setBtn) {
                  return GestureDetector(
                    onTap: () {
                      final trimmed = attrController.text.trim();
                      if (trimmed.isNotEmpty &&
                          !_productAttributes.contains(trimmed)) {
                        setState(() => _productAttributes.add(trimmed));
                        attrController.clear();
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B21A8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationTimeField() {
    final selectedMinutes = _preparationMinutesValue();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Tahmini Hazırlanma Süresi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              ' *',
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _preparationTimeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Örn. 45',
            helperText: '1 - 300 dakika arası',
            suffixText: 'dk',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _preparationTimeQuickOptions
              .map((minutes) {
                final isSelected = selectedMinutes == minutes;
                return ChoiceChip(
                  label: Text('$minutes dk'),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _setPreparationMinutes(minutes)),
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.32)
                        : Colors.grey.shade300,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade800,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool required = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: enabled ? onChanged : null,
          hint: const Text('Seçiniz'),
        ),
      ],
    );
  }

  Widget _buildRichTextEditor({
    required TextEditingController controller,
    required String label,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    _buildEditorButton(Icons.format_bold, 'Kalın'),
                    _buildEditorButton(Icons.format_italic, 'İtalik'),
                    _buildEditorButton(Icons.format_list_bulleted, 'Liste'),
                    _buildEditorButton(
                      Icons.format_list_numbered,
                      'Numaralı Liste',
                    ),
                    const Spacer(),
                    Text(
                      '${controller.text.length} karakter',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Text Area
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Ürününüzü detaylı olarak tanıtın...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorButton(IconData icon, String tooltip) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildAIDescriptionAssistant() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.purple.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Açıklama Sihirbazı',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anahtar kelimeleri girin, profesyonel açıklama oluşturalım',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons({bool isLastStep = false}) {
    final canContinue = _currentStep == 1
        ? _validatePricingStep(showErrors: false)
        : true;
    return Row(
      children: [
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
            child: const Text('Geri'),
          ),
        const Spacer(),
        if (!isLastStep)
          ElevatedButton(
            onPressed: canContinue
                ? () {
                    if (_validateCurrentStep()) {
                      setState(() {
                        _currentStep++;
                      });
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Devam Et'),
          ),
      ],
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Temel Bilgiler
        if (_productNameController.text.isEmpty) {
          _showError('Ürün adı zorunludur');
          return false;
        }
        if (_selectedMainCategory == null) {
          _showError('Ana kategori seçmelisiniz');
          return false;
        }
        if (_selectedSubCategory == null) {
          _showError('Alt kategori seçmelisiniz');
          return false;
        }
        if (_brandController.text.isEmpty) {
          _showError('Marka zorunludur');
          return false;
        }
        if (_longDescController.text.isEmpty) {
          _showError('Detaylı açıklama zorunludur');
          return false;
        }
        return true;

      case 1: // Fiyat & Stok
        return _validatePricingStep(showErrors: true);

      case 2: // Görseller
        if (_existingImageUrls.isEmpty &&
            _productImages.every((x) => x == null)) {
          _showError('En az 1 ürün görseli yüklemelisiniz');
          return false;
        }
        return true;

      case 3: // Varyantlar (opsiyonel)
        return true;

      case 4: // Kargo & Boyut (opsiyonel)
        if (_isFoodCategory && !_validatePreparationTime()) {
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Sağ Panel - Ürün Önizleme
  Widget _buildProductPreview() {
    final effectivePricingType = _pricingTypeForSave;
    final currentPrice = _activePriceValue;
    final previewPriceText = effectivePricingType == ProductPricingType.weight
        ? ProductPriceCalculator.formatPerKgLabel(currentPrice)
        : ProductPriceCalculator.formatCurrency(currentPrice);
    final previewWeightInfo = _isWeightPricingActive
        ? ProductPriceCalculator.buildWeightRangeLabel(
            minWeightGrams: _parsedMinWeight(),
            defaultWeightGrams: _parsedDefaultWeight(),
          )
        : _usesPortionLikeServiceControl
        ? ProductPriceCalculator.buildServiceControlSummary(
            type: _selectedServiceControlType,
            minPortion: _parsedMinPortion(),
            maxPortion: _parsedMaxPortion(),
            portionStep: _parsedPortionStep(),
          )
        : null;
    final previewPreparationMinutes = _preparationMinutesValue();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ürün Önizleme',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _productImages[0] != null
                ? Image(
                    image: xFileImageProvider(_productImages[0]!),
                    fit: BoxFit.cover,
                  )
                : const Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            _productNameController.text.isEmpty
                ? 'Ürün Adı'
                : _productNameController.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (_activePriceController.text.isNotEmpty)
            Text(
              previewPriceText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          if (previewWeightInfo != null) ...[
            const SizedBox(height: 6),
            Text(
              previewWeightInfo,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (_isFoodCategory && previewPreparationMinutes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Hazırlanma: ${formatPreparationTime(previewPreparationMinutes)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Kâr Hesaplayıcı
  Widget _buildProfitCalculator() {
    final price = _activePriceValue;
    final discountPrice =
        !_isWeightPricingActive &&
            _selectedServiceControlType == ProductServiceControlType.none
        ? _parseCurrency(_discountPriceController.text)
        : 0.0;
    final finalPrice = discountPrice > 0 ? discountPrice : price;

    final vatRate = double.parse(_selectedVatRate.replaceAll('%', '')) / 100;
    final priceWithoutVat = finalPrice / (1 + vatRate);
    final commission = priceWithoutVat * 0.15; // %15 komisyon
    final shipping = 25.0; // Sabit kargo
    final netProfit = priceWithoutVat - commission - shipping;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Kazanç Hesaplayıcı',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProfitRow('Satış Fiyatı', finalPrice),
          _buildProfitRow(
            'KDV ($_selectedVatRate)',
            finalPrice - priceWithoutVat,
            isDeduction: true,
          ),
          _buildProfitRow('Komisyon (%15)', commission, isDeduction: true),
          _buildProfitRow('Tahmini Kargo', shipping, isDeduction: true),
          const Divider(),
          _buildProfitRow('Net Kazanç', netProfit, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildProfitRow(
    String label,
    double amount, {
    bool isDeduction = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green.shade900 : Colors.grey.shade700,
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}₺${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal
                  ? Colors.green.shade900
                  : (isDeduction ? Colors.red.shade700 : Colors.grey.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'İpuçları',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Kaliteli görseller kullanın'),
          _buildTipItem('Detaylı açıklama yazın'),
          _buildTipItem('Doğru kategori seçin'),
          _buildTipItem('Rekabetçi fiyat belirleyin'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  List<String> _getSubCategories(String? mainCategory) {
    if (mainCategory == null) return [];

    final Map<String, List<String>> subCategories = {
      'Elektronik': [
        'Telefonlar',
        'Laptop & Tablet',
        'Televizyon',
        'Gaming',
        'Oyuncu Ekipmanları',
        'Telefon Aksesuarları',
        'Oyun Konsolları',
      ],
      'Spor & Outdoor': [
        'Spor Giyim',
        'Fitness',
        'Outdoor',
        'Sporcu Besinleri',
        'Kamp & Kampçılık',
        'Bisiklet',
      ],
      'Giyim & Aksesuar': [
        'Kadın Giyim',
        'Erkek Giyim',
        'Çocuk Giyim',
        'Ayakkabı',
        'Çanta',
        'Saat & Aksesuar',
      ],
      'Anne & Bebek & Oyuncak': [
        'Bebek Giyim',
        'Bebek Bakım',
        'Oyuncak',
        'Bebek Arabası',
        'Bebek Beslenme',
      ],
      'Kozmetik & Kişisel Bakım': [
        'Cilt Bakım',
        'Makyaj',
        'Parfüm',
        'Saç Bakım',
        'Kişisel Bakım',
        'Erkek Bakım',
      ],
      'Ev & Yaşam': [
        'Mobilya',
        'Dekorasyon',
        'Mutfak',
        'Banyo',
        'Bahçe',
        'Aydınlatma',
        'Ev Tekstili',
      ],
      'Süpermarket & Petshop': [
        'Gıda',
        'İçecek',
        'Temizlik',
        'Petshop',
        'Bebek Ürünleri',
      ],
      'Kitap & Hobi': [
        'Kitap',
        'Müzik & Film',
        'Hobi & Oyun',
        'Kırtasiye',
        'Sanat',
      ],
      '2.el Ürünler': [
        '2.el Elektronik',
        '2.el Giyim',
        '2.el Mobilya',
        '2.el Kitap',
        'Diğer',
      ],
      'Yemek': [
        'Ana Yemek',
        'Çorba',
        'Salata',
        'Tatlı',
        'İçecek',
        'Atıştırmalık',
        'Kahvaltı',
        'Diğer',
      ],
    };
    return subCategories[mainCategory] ?? [];
  }

  String _calculateDiscountRate() {
    final price = _portionPriceValue;
    final discountPrice = _parseCurrency(_discountPriceController.text);

    if (price > 0 && discountPrice > 0) {
      final rate = ((price - discountPrice) / price * 100);
      return rate.toStringAsFixed(0);
    }
    return '0';
  }

  Future<void> _pickImage(int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );
      if (image != null) {
        setState(() {
          _productImages[index] = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickVideoFromSource(source);
  }

  Future<void> _pickVideoFromSource(ImageSource source) async {
    try {
      _setMediaStage(ProductMediaStage.picking, 'Video seçiliyor...');
      final picked = await _mediaPickerService.pickVideo(source: source);
      if (picked == null) return;

      _setMediaStage(
        ProductMediaStage.readingMetadata,
        'Video bilgileri okunuyor...',
      );
      if (!picked.metadata.isDurationValid) {
        _showError(
          'Video süresi en fazla 30 saniye olabilir. Seçilen süre: ${picked.metadata.duration.inSeconds} sn.',
        );
        return;
      }

      setState(() {
        _videoFile = picked.file;
        _selectedVideoMetadata = picked.metadata;
        _existingVideoUrl = null;
        _existingVideoPath = null;
        _existingThumbnailPath = null;
        _existingThumbnailUrl = null;
        _existingVideoDurationSeconds = null;
        _existingVideoSizeBytes = null;
        _existingThumbnailSizeBytes = null;
        _existingVideoStatus = 'selected';
      });

      _setMediaStage(ProductMediaStage.idle, 'Video seçildi');
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video seçilirken hata oluştu: $e')),
        );
      }
      _setMediaStage(ProductMediaStage.failed, 'Video seçimi başarısız');
    }
  }

  void _setMediaStage(
    ProductMediaStage stage,
    String label, {
    double? progress,
  }) {
    if (!mounted) return;
    setState(() {
      _mediaStage = stage;
      _mediaStageLabel = label;
      if (progress != null) {
        _mediaUploadProgress = progress;
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[index]}';
  }

  Future<void> _pickVariantImage(int variantIndex) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          if (variantIndex < _variants.length) {
            _variants[variantIndex].imagePath = image.path;
            _variants[variantIndex].imageFile = image;
            _variants[variantIndex].imageUrl = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking variant image: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70,
      );
      if (!mounted) return;
      if (images.isNotEmpty) {
        int uploadedCount = 0;
        for (var i = 0; i < images.length && i < 8; i++) {
          // Boş slot bul
          int emptyIndex = _productImages.indexOf(null);
          if (emptyIndex == -1) break;

          setState(() {
            _productImages[emptyIndex] = images[i];
          });
          uploadedCount++;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$uploadedCount görsel seçildi')),
        );
      }
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _productImages[index] = null;
    });
  }

  Future<void> _addVariant() async {
    final result = await showDialog<ProductVariant>(
      context: context,
      builder: (context) => _AddVariantDialog(
        isElectronics: _selectedMainCategory == 'Elektronik',
        isClothing:
            _selectedMainCategory == 'Giyim & Aksesuar' ||
            _selectedSubCategory == 'Ayakkabı',
        isFood: _selectedMainCategory == 'Yemek',
      ),
    );

    if (result != null) {
      setState(() {
        _variants.add(result);
      });
    }
  }

  Future<void> _editVariant(int index) async {
    if (index < 0 || index >= _variants.length) return;
    final current = _variants[index];
    final result = await showDialog<ProductVariant>(
      context: context,
      builder: (context) => _AddVariantDialog(
        isElectronics: _selectedMainCategory == 'Elektronik',
        isClothing:
            _selectedMainCategory == 'Giyim & Aksesuar' ||
            _selectedSubCategory == 'Ayakkabı',
        isFood: _selectedMainCategory == 'Yemek',
        initialVariant: current,
        submitLabel: 'Güncelle',
      ),
    );
    if (result != null) {
      setState(() {
        _variants[index] = ProductVariant(
          color: result.color,
          size: result.size,
          ram: result.ram,
          storage: result.storage,
          sku: result.sku,
          stock: result.stock,
          priceDifference: result.priceDifference,
          imagePath: result.imagePath ?? current.imagePath,
          imageFile: result.imageFile ?? current.imageFile,
          imageUrl: result.imageUrl ?? current.imageUrl,
        );
      });
    }
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  void _showExitDialog() {
    if (_isMediaUploadActive) {
      _showUploadInProgressWarning();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Değişiklikleri Kaydet'),
        content: const Text(
          'Yaptığınız değişiklikleri kaydetmeden çıkmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Çık', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveDraft();
            },
            child: const Text('Taslak Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showUploadInProgressWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Video yükleme devam ediyor. Sayfadan çıkmadan önce yüklemeyi iptal edin veya tamamlanmasını bekleyin.',
        ),
      ),
    );
  }

  double _parseCurrency(String text) {
    if (text.isEmpty) return 0.0;
    // Remove dots (thousands separators) and replace comma with dot (decimal)
    String cleanText = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleanText) ?? 0.0;
  }

  int _parseNumber(String text) {
    if (text.isEmpty) return 0;
    // Remove dots
    String cleanText = text.replaceAll('.', '');
    return int.tryParse(cleanText) ?? 0;
  }

  bool _validateServiceControlConfiguration({bool showErrors = true}) {
    if (_usesPortionLikeServiceControl) {
      final errors = ProductPriceCalculator.validatePortionConfiguration(
        type: _selectedServiceControlType,
        minPortion: _parseOptionalDecimalField(_minPortionController.text),
        maxPortion: _parseOptionalDecimalField(_maxPortionController.text),
        portionStep: _parseOptionalDecimalField(_portionStepController.text),
      );
      if (errors.isNotEmpty) {
        if (showErrors) {
          _showError(errors.first);
        }
        return false;
      }
    }
    if (_pricingTypeForSave == ProductPricingType.weight) {
      final errors = ProductPriceCalculator.validateWeightConfiguration(
        minWeightGrams: _parsedMinWeight(),
        defaultWeightGrams: _parsedDefaultWeight(),
        weightStepGrams: _parsedWeightStep(),
        maxWeightGrams: _parsedMaxWeight(),
      );
      if (errors.isNotEmpty) {
        if (showErrors) {
          _showError(errors.first);
        }
        return false;
      }
    }
    return true;
  }

  bool _validatePricingStep({required bool showErrors}) {
    final effectivePricingType = _pricingTypeForSave;
    final priceController = effectivePricingType == ProductPricingType.weight
        ? _pricePerKgController
        : _portionPriceController;
    final priceValue = effectivePricingType == ProductPricingType.weight
        ? _pricePerKgValue
        : _portionPriceValue;

    if (priceController.text.trim().isEmpty || priceValue <= 0) {
      if (showErrors) {
        _showError(
          effectivePricingType == ProductPricingType.weight
              ? 'Geçerli bir kilogram fiyatı giriniz'
              : 'Geçerli bir satış fiyatı giriniz',
        );
      }
      return false;
    }

    if (_selectedVatRate.trim().isEmpty) {
      if (showErrors) {
        _showError('KDV oranı zorunludur');
      }
      return false;
    }

    if (!_validateServiceControlConfiguration(showErrors: showErrors)) {
      return false;
    }

    if (_stockController.text.trim().isEmpty) {
      if (showErrors) {
        _showError('Geçerli bir stok miktarı giriniz');
      }
      return false;
    }

    return true;
  }

  Future<void> _saveDraft() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final mainCategory = (_selectedMainCategory ?? _storeMainCategory ?? '')
        .trim();
    final subCategory = (_selectedSubCategory ?? _subCategoryController.text)
        .trim();
    final existingImageUrls = List<String>.from(_existingImageUrls);
    final cleanedFaqs = _faqs
        .map(
          (m) => {
            'question': (m['question'] ?? '').toString().trim(),
            'answer': (m['answer'] ?? '').toString().trim(),
          },
        )
        .where((m) => m['question']!.isNotEmpty && m['answer']!.isNotEmpty)
        .take(5)
        .toList();

    // Taslak ürün verilerini oluştur
    final product = SellerProduct(
      id: widget.productId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _productNameController.text.isEmpty
          ? 'Taslak Ürün'
          : _productNameController.text,
      brand: _brandController.text,
      mainCategory: mainCategory,
      subCategory: subCategory,
      price: _activePriceValue,
      pricingType: _pricingTypeForSave.storageValue,
      portionPrice: _portionPriceValue > 0 ? _portionPriceValue : null,
      pricePerKg: _pricePerKgValue > 0 ? _pricePerKgValue : null,
      serviceControlType:
          _selectedServiceControlType == ProductServiceControlType.none
          ? null
          : _selectedServiceControlType.storageValue,
      minPortion: _usesPortionLikeServiceControl ? _parsedMinPortion() : null,
      maxPortion: _usesPortionLikeServiceControl ? _parsedMaxPortion() : null,
      portionStep: _usesPortionLikeServiceControl ? _parsedPortionStep() : null,
      defaultWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedDefaultWeight()
          : null,
      minWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedMinWeight()
          : null,
      weightStepGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedWeightStep()
          : null,
      maxWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedMaxWeight()
          : null,
      discountPrice:
          _selectedServiceControlType == ProductServiceControlType.none &&
              _pricingTypeForSave == ProductPricingType.portion &&
              _discountPriceController.text.isNotEmpty
          ? _parseCurrency(_discountPriceController.text)
          : null,
      stock: _parseNumber(_stockController.text),
      sku: _skuController.text.isEmpty
          ? 'SKU${DateTime.now().millisecondsSinceEpoch}'
          : _skuController.text,
      status: 'Taslak',
      imageUrl: existingImageUrls.isNotEmpty ? existingImageUrls.first : null,
      imageUrls: existingImageUrls,
      description: _longDescController.text,
      specifications: _finalSpecificationsForSave(),
      preparationTime: _preparationTimeValueForSave(),
      createdAt: DateTime.now(),
      attributes: _finalAttributesForSave(),
      videoUrl: _existingVideoUrl,
      videoPath: _existingVideoPath,
      videoPublicUrl: _existingVideoUrl,
      thumbnailPath: _existingThumbnailPath,
      thumbnailPublicUrl: _existingThumbnailUrl,
      videoDurationSeconds: _existingVideoDurationSeconds,
      videoSizeBytes: _existingVideoSizeBytes,
      thumbnailSizeBytes: _existingThumbnailSizeBytes,
      videoStatus: _existingVideoStatus,
      accessories: _selectedAccessoryIds.toList(),
      additionalInfo: _additionalInfos.isNotEmpty
          ? _additionalInfos.join('\n')
          : null,
      faq: cleanedFaqs.isNotEmpty ? cleanedFaqs : null,
    );

    try {
      // Varyantları gönder
      // Not: store_service.saveProductDraft içinde varyantları kaydetme mantığı henüz eklenmedi.
      // Şimdilik sadece ana ürünü kaydediyoruz.
      await _storeService.saveProductDraft(product, variants: _variants);
      await _persistStructuredProductAttributes(product.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün taslak olarak kaydedildi')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    final msg = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('Ürün eklenirken hata: ', '')
        .trim();
    if (msg.contains('timed out') || msg.contains('zaman aşımı')) {
      return 'İnternet yavaş olduğu için işlem zaman aşımına uğradı. Daha küçük görsel deneyin veya tekrar deneyin.';
    }
    if (msg.contains('unauthorized') || msg.contains('permission-denied')) {
      return 'Yetki hatası: Storage/Firestore kuralları yüklemeyi engelliyor.';
    }
    return msg.isEmpty ? 'Bilinmeyen hata oluştu' : msg;
  }

  bool _validateForPublish() {
    if (_productNameController.text.isEmpty) {
      _showError('Ürün adı zorunludur');
      return false;
    }
    if (_selectedMainCategory == null) {
      _showError('Ana kategori seçmelisiniz');
      return false;
    }
    if (_selectedSubCategory == null) {
      _showError('Alt kategori seçmelisiniz');
      return false;
    }
    if (_brandController.text.isEmpty) {
      _showError('Marka zorunludur');
      return false;
    }
    if (_longDescController.text.isEmpty) {
      _showError('Detaylı açıklama zorunludur');
      return false;
    }
    if (!_validatePricingStep(showErrors: true)) {
      return false;
    }
    final hasNewImage = _productImages.any((x) => x != null);
    final hasExistingImages = _existingImageUrls.isNotEmpty;
    if (!hasNewImage && !hasExistingImages) {
      _showError('En az 1 ürün görseli yüklemelisiniz');
      return false;
    }
    if (_selectedVideoMetadata != null &&
        _selectedVideoMetadata!.duration.inSeconds > 30) {
      _showError('Video süresi 30 saniyeyi aşamaz');
      return false;
    }
    if (_isFoodCategory && !_validatePreparationTime()) {
      return false;
    }
    return true;
  }

  Future<void> _publishProduct() async {
    if (_isLoading) return;

    if (!_validateForPublish()) return;

    setState(() {
      _isLoading = true;
      _mediaStage = ProductMediaStage.idle;
      _mediaStageLabel = 'Yayın hazırlığı başladı';
      _mediaUploadProgress = 0;
    });

    final ValueNotifier<String> progressNotifier = ValueNotifier<String>(
      'Ürün görselleri hazırlanıyor...',
    );
    final ValueNotifier<double> uploadProgressNotifier = ValueNotifier<double>(
      0,
    );
    final ValueNotifier<ProductMediaStage> stageNotifier =
        ValueNotifier<ProductMediaStage>(ProductMediaStage.idle);
    final ValueNotifier<bool> canCancelNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: uploadProgressNotifier,
                  builder: (context, progress, _) {
                    final hasValue = progress > 0;
                    return Column(
                      children: [
                        CircularProgressIndicator(
                          value: hasValue ? progress : null,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: hasValue ? progress : null,
                          minHeight: 6,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: progressNotifier,
                  builder: (context, value, child) {
                    return Text(value, textAlign: TextAlign.center);
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<ProductMediaStage>(
                  valueListenable: stageNotifier,
                  builder: (context, stage, _) {
                    return Text(
                      _stageText(stage),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: canCancelNotifier,
                  builder: (context, canCancel, _) {
                    return OutlinedButton.icon(
                      onPressed: canCancel
                          ? () {
                              _activeUploadCancelToken?.cancel();
                              progressNotifier.value =
                                  'Yükleme iptal ediliyor...';
                            }
                          : null,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('İptal'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Ürün verilerini oluştur
    // Yeni ürünlerde status 'Aktif' gönderilir; StoreService.addProduct bunu 'pending_approval' yapar
    // Böylece Admin panelindeki onay listesine düşer.
    final String targetStatus = 'Aktif';
    final String productId =
        widget.productId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Video medya alanları
    String? uploadedVideoUrl = _existingVideoUrl;
    String? uploadedVideoPath = _existingVideoPath;
    String? uploadedThumbnailPath = _existingThumbnailPath;
    String? uploadedThumbnailUrl = _existingThumbnailUrl;
    int? uploadedVideoDurationSeconds = _existingVideoDurationSeconds;
    int? uploadedVideoSizeBytes = _existingVideoSizeBytes;
    int? uploadedThumbnailSizeBytes = _existingThumbnailSizeBytes;
    String? uploadedVideoStatus = _existingVideoStatus;
    ProductMediaUploadResult? uploadedMedia;

    if (_videoFile != null) {
      try {
        final sellerId = _storeService.currentUserId;
        if (sellerId == null || sellerId.isEmpty) {
          throw Exception('Kullanıcı oturumu bulunamadı.');
        }

        _activeUploadCancelToken = UploadCancelToken();
        canCancelNotifier.value = true;
        setState(() {
          _isMediaUploadActive = true;
          _mediaStage = ProductMediaStage.optimizing;
          _mediaStageLabel = 'Video optimize ediliyor...';
          _mediaUploadProgress = 0;
        });

        final media = await _productMediaRepository.uploadProductMedia(
          sellerId: sellerId,
          productId: productId,
          sourceVideo: _videoFile!,
          previousVideoPath: _existingVideoPath,
          previousThumbnailPath: _existingThumbnailPath,
          cancelToken: _activeUploadCancelToken,
          onStage: (stage, label) {
            stageNotifier.value = stage;
            progressNotifier.value = label;
            _setMediaStage(
              stage,
              label,
              progress: uploadProgressNotifier.value,
            );
          },
          onUploadProgress: (progress) {
            uploadProgressNotifier.value = progress.progress;
            stageNotifier.value = ProductMediaStage.uploading;
            progressNotifier.value =
                'Upload ediliyor... %${(progress.progress * 100).toStringAsFixed(0)}';
            _setMediaStage(
              ProductMediaStage.uploading,
              progressNotifier.value,
              progress: progress.progress,
            );
          },
        );

        uploadedMedia = media;
        uploadedVideoUrl = media.video.publicUrl;
        uploadedVideoPath = media.video.path;
        uploadedThumbnailPath = media.thumbnail.path;
        uploadedThumbnailUrl = media.thumbnail.publicUrl;
        uploadedVideoDurationSeconds = media.videoMetadata.duration.inSeconds;
        uploadedVideoSizeBytes = media.video.sizeBytes;
        uploadedThumbnailSizeBytes = media.thumbnail.sizeBytes;
        uploadedVideoStatus = media.videoStatus;

        uploadProgressNotifier.value = 1;
        _setMediaStage(ProductMediaStage.done, 'Video hazır', progress: 1);
      } on UploadCancelledException {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video yükleme iptal edildi')),
          );
        }
        return;
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video yüklenemedi: $e'),
              action: SnackBarAction(
                label: 'Tekrar dene',
                onPressed: _publishProduct,
              ),
            ),
          );
        }
        return;
      } finally {
        canCancelNotifier.value = false;
        setState(() {
          _isMediaUploadActive = false;
        });
      }
    } else if (_existingVideoUrl == null &&
        ((_existingVideoPath ?? '').isNotEmpty ||
            (_existingThumbnailPath ?? '').isNotEmpty)) {
      progressNotifier.value = 'Eski video dosyaları temizleniyor...';
      await _productMediaRepository.cleanupProductMedia(
        videoPath: _existingVideoPath,
        thumbnailPath: _existingThumbnailPath,
      );
      uploadedVideoPath = null;
      uploadedThumbnailPath = null;
      uploadedThumbnailUrl = null;
      uploadedVideoDurationSeconds = null;
      uploadedVideoSizeBytes = null;
      uploadedThumbnailSizeBytes = null;
      uploadedVideoStatus = null;
      uploadProgressNotifier.value = 1;
    }

    final cleanedFaqs = _faqs
        .map(
          (m) => {
            'question': (m['question'] ?? '').toString().trim(),
            'answer': (m['answer'] ?? '').toString().trim(),
          },
        )
        .where((m) => m['question']!.isNotEmpty && m['answer']!.isNotEmpty)
        .take(5)
        .toList();

    // Ürün nesnesini oluştur
    final product = SellerProduct(
      id: productId,
      name: _productNameController.text,
      brand: _brandController.text,
      mainCategory: _selectedMainCategory ?? '',
      subCategory: _selectedSubCategory ?? '',
      price: _activePriceValue,
      pricingType: _pricingTypeForSave.storageValue,
      portionPrice: _portionPriceValue > 0 ? _portionPriceValue : null,
      pricePerKg: _pricePerKgValue > 0 ? _pricePerKgValue : null,
      serviceControlType:
          _selectedServiceControlType == ProductServiceControlType.none
          ? null
          : _selectedServiceControlType.storageValue,
      minPortion: _usesPortionLikeServiceControl ? _parsedMinPortion() : null,
      maxPortion: _usesPortionLikeServiceControl ? _parsedMaxPortion() : null,
      portionStep: _usesPortionLikeServiceControl ? _parsedPortionStep() : null,
      defaultWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedDefaultWeight()
          : null,
      minWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedMinWeight()
          : null,
      weightStepGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedWeightStep()
          : null,
      maxWeightGrams: _pricingTypeForSave == ProductPricingType.weight
          ? _parsedMaxWeight()
          : null,
      discountPrice:
          _selectedServiceControlType == ProductServiceControlType.none &&
              _pricingTypeForSave == ProductPricingType.portion &&
              _discountPriceController.text.isNotEmpty
          ? _parseCurrency(_discountPriceController.text)
          : null,
      stock: _parseNumber(_stockController.text),
      sku: _skuController.text.isEmpty
          ? 'SKU${DateTime.now().millisecondsSinceEpoch}'
          : _skuController.text,
      status: targetStatus,
      imageUrl: _existingImageUrls.isNotEmpty ? _existingImageUrls.first : null,
      imageUrls: _existingImageUrls,
      description: _longDescController.text.isEmpty
          ? null
          : _longDescController.text,
      specifications: _finalSpecificationsForSave(),
      preparationTime: _preparationTimeValueForSave(),
      createdAt: DateTime.now(),
      attributes: _finalAttributesForSave(),
      videoUrl: uploadedVideoUrl,
      videoPath: uploadedVideoPath,
      videoPublicUrl: uploadedVideoUrl,
      thumbnailPath: uploadedThumbnailPath,
      thumbnailPublicUrl: uploadedThumbnailUrl,
      videoDurationSeconds: uploadedVideoDurationSeconds,
      videoSizeBytes: uploadedVideoSizeBytes,
      thumbnailSizeBytes: uploadedThumbnailSizeBytes,
      videoStatus: uploadedVideoStatus,
      variants: _variants, // Varyantları nesne içinde de gönderelim
      accessories: _selectedAccessoryIds.toList(),
      additionalInfo: _additionalInfos.isNotEmpty
          ? _additionalInfos.join('\n')
          : null,
      faq: cleanedFaqs.isNotEmpty ? cleanedFaqs : null,
    );

    try {
      final List<XFile> validImages = _productImages
          .where((i) => i != null)
          .cast<XFile>()
          .toList();
      stageNotifier.value = ProductMediaStage.saving;
      progressNotifier.value = 'Ürün verileri kaydediliyor...';

      if (widget.isEdit && widget.productId != null) {
        // GÜNCELLEME İŞLEMİ
        await _storeService.updateProduct(
          product,
          newImages: validImages.isEmpty ? null : validImages,
          previousStatus: _initialProductStatus,
          variants: _variants, // Varyantları gönder
          onProgress: (status) {
            progressNotifier.value = status;
          },
        );
      } else {
        // YENİ EKLEME İŞLEMİ
        await _storeService.addProduct(
          product,
          validImages,
          variants: _variants, // Varyantları gönder
          onProgress: (status) {
            progressNotifier.value = status;
          },
        );
      }

      if (uploadedMedia != null) {
        await _productMediaRepository.saveProductMediaToDatabase(
          productId: productId,
          media: uploadedMedia,
        );
      }

      await _persistStructuredProductAttributes(productId);

      setState(() {
        _existingVideoUrl = uploadedVideoUrl;
        _existingVideoPath = uploadedVideoPath;
        _existingThumbnailPath = uploadedThumbnailPath;
        _existingThumbnailUrl = uploadedThumbnailUrl;
        _existingVideoDurationSeconds = uploadedVideoDurationSeconds;
        _existingVideoSizeBytes = uploadedVideoSizeBytes;
        _existingThumbnailSizeBytes = uploadedThumbnailSizeBytes;
        _existingVideoStatus = uploadedVideoStatus;
        _selectedVideoMetadata =
            uploadedVideoDurationSeconds != null &&
                uploadedVideoSizeBytes != null
            ? ProductVideoMetadata(
                duration: Duration(seconds: uploadedVideoDurationSeconds),
                sizeBytes: uploadedVideoSizeBytes,
                width: 0,
                height: 0,
                extension: 'mp4',
                mimeType: 'video/mp4',
              )
            : null;
        _videoFile = null;
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Ürün başarıyla güncellendi.'
                  : 'Ürün başarıyla yayınlandı!',
            ),
          ),
        );
        Navigator.pop(context, true); // Close add product page
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      progressNotifier.dispose();
      uploadProgressNotifier.dispose();
      stageNotifier.dispose();
      canCancelNotifier.dispose();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMediaUploadActive = false;
          _activeUploadCancelToken = null;
        });
      }
    }
  }

  String _stageText(ProductMediaStage stage) {
    return switch (stage) {
      ProductMediaStage.idle => 'Hazırlanıyor',
      ProductMediaStage.picking => 'Video seçiliyor',
      ProductMediaStage.readingMetadata => 'Video metadata okunuyor',
      ProductMediaStage.optimizing => 'Video optimize ediliyor',
      ProductMediaStage.generatingThumbnail => 'Thumbnail hazırlanıyor',
      ProductMediaStage.uploading => 'Supabase Storage upload',
      ProductMediaStage.saving => 'Veritabanına kaydediliyor',
      ProductMediaStage.done => 'Tamamlandı',
      ProductMediaStage.failed => 'Hata',
      ProductMediaStage.cancelled => 'İptal edildi',
    };
  }
}

class ProductVariant {
  String color;
  String size;
  String? ram;
  String? storage;
  String sku;
  int stock;
  double priceDifference;
  String? imagePath;
  XFile? imageFile;
  String? imageUrl;

  ProductVariant({
    required this.color,
    required this.size,
    this.ram,
    this.storage,
    required this.sku,
    required this.stock,
    required this.priceDifference,
    this.imagePath,
    this.imageFile,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'color': color,
      'size': size,
      'ram': ram,
      'storage': storage,
      'sku': sku,
      'stock': stock,
      'priceDifference': priceDifference,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
    };
  }
}

// SellerProduct ve SellerProductService seller_panel_page.dart'tan import ediliyor

class _AddVariantDialog extends StatefulWidget {
  final bool isElectronics;
  final bool isClothing;
  final bool isFood;
  final ProductVariant? initialVariant;
  final String submitLabel;

  const _AddVariantDialog({
    this.isElectronics = false,
    this.isClothing = false,
    this.isFood = false,
    this.initialVariant,
    this.submitLabel = 'Ekle',
  });

  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _priceDiffController = TextEditingController(text: '0');
  final _ramController = TextEditingController();
  final _storageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final v = widget.initialVariant;
    if (v != null) {
      _colorController.text = v.color;
      _sizeController.text = v.size;
      _skuController.text = v.sku;
      _stockController.text = v.stock.toString();
      _priceDiffController.text = v.priceDifference.toString();
      _ramController.text = v.ram ?? '';
      _storageController.text = v.storage ?? '';
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    _sizeController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _priceDiffController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFood
        ? 'Porsiyon & Ek Malzeme Ekle'
        : (widget.isClothing ? 'Beden & Renk Ekle' : 'Seçenek Ekle');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Varyant bilgilerini doldurun. Daha sonra karttan da düzenleyebilirsiniz.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                if (widget.isElectronics) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          controller: _storageController,
                          label: 'Hafıza',
                          hint: 'Örn: 256GB',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          controller: _ramController,
                          label: 'RAM',
                          hint: 'Örn: 8GB',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _dialogField(
                        controller: _colorController,
                        label: widget.isFood ? 'Porsiyon Adı' : 'Renk',
                        hint: widget.isFood
                            ? 'Örn: Büyük Porsiyon'
                            : 'Örn: Siyah',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogField(
                        controller: _sizeController,
                        label: widget.isFood ? 'Açıklama/Not' : 'Beden / Boyut',
                        hint: widget.isFood ? 'Örn: Ekstra peynirli' : 'Örn: L',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _dialogField(
                        controller: _skuController,
                        label: 'Varyant Kodu (Opsiyonel)',
                        hint: 'Örn: SKU-RED-128',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogField(
                        controller: _stockController,
                        label: 'Stok Adedi',
                        hint: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _dialogField(
                  controller: _priceDiffController,
                  label: 'Fiyat Farkı (+/-)',
                  hint: '0',
                  helper: 'Ana fiyata eklenecek/çıkarılacak tutar',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        final variant = ProductVariant(
                          color: _colorController.text.trim(),
                          size: _sizeController.text.trim(),
                          ram: widget.isElectronics
                              ? _ramController.text.trim()
                              : null,
                          storage: widget.isElectronics
                              ? _storageController.text.trim()
                              : null,
                          sku: _skuController.text.trim(),
                          stock: int.tryParse(_stockController.text) ?? 0,
                          priceDifference:
                              double.tryParse(
                                _priceDiffController.text.replaceAll(',', '.'),
                              ) ??
                              0,
                          imagePath: widget.initialVariant?.imagePath,
                          imageFile: widget.initialVariant?.imageFile,
                          imageUrl: widget.initialVariant?.imageUrl,
                        );
                        Navigator.pop(context, variant);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(widget.submitLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove all dots to get raw number
    String cleanText = newValue.text.replaceAll('.', '');

    // Check if it's a valid number
    if (int.tryParse(cleanText) == null) {
      return oldValue;
    }

    // Format
    final formatter = NumberFormat('#,###', 'tr_TR');
    String newText = formatter.format(int.parse(cleanText));

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
