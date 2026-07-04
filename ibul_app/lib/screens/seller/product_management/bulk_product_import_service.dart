import 'package:ibul_app/core/category_pricing_helper.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/services/store_service.dart';

import 'bulk_product_csv_parser.dart';
import 'bulk_product_import_mapping.dart';
import 'bulk_product_import_models.dart';
import 'bulk_product_import_validator.dart';

class BulkProductImportService {
  BulkProductImportService({
    StoreService? storeService,
    BulkProductCsvParser? parser,
    BulkProductImportValidator? validator,
  }) : _storeService = storeService ?? StoreService(),
       _parser = parser ?? const BulkProductCsvParser(),
       _validator = validator ?? const BulkProductImportValidator();

  final StoreService _storeService;
  final BulkProductCsvParser _parser;
  final BulkProductImportValidator _validator;

  Future<BulkProductImportPreview> buildPreview(
    BulkProductSelectedFile file,
  ) async {
    final BulkProductCsvDocument document = _parser.parseBytes(file.bytes);
    final String? lockedMainCategory = await _loadLockedMainCategory();
    final BulkProductImportPreview preview = _validator.validate(
      fileName: file.name,
      document: document,
      lockedMainCategory: lockedMainCategory,
    );

    if (lockedMainCategory == null || lockedMainCategory.trim().isEmpty) {
      return BulkProductImportPreview(
        fileName: preview.fileName,
        headers: preview.headers,
        rows: preview.rows,
        fileErrors: <String>[
          ...preview.fileErrors,
          'Mağaza kategorisi bulunamadı. Toplu yükleme için önce satıcı kategorisi gerekli.',
        ],
      );
    }

    return preview;
  }

  Future<BulkProductImportExecutionSummary> importValidRows(
    BulkProductImportPreview preview,
  ) async {
    final String? storeMainCategory = await _loadLockedMainCategory();
    final List<BulkProductImportPreviewRow> validRows = preview.rows
        .where((BulkProductImportPreviewRow row) => row.isValid)
        .toList(growable: false);

    final Set<String> seenSkus = <String>{};
    final Set<String> seenBarcodes = <String>{};
    final List<String> duplicateWarnings = <String>[];
    int successfulRows = 0;
    final List<BulkProductImportFailure> failures =
        <BulkProductImportFailure>[];

    for (final BulkProductImportPreviewRow row in validRows) {
      final BulkProductImportCandidate candidate = row.candidate!;
      final String mainCategory =
          (candidate.mainCategory?.trim().isNotEmpty ?? false)
          ? candidate.mainCategory!.trim()
          : (storeMainCategory ?? '');
      final String subCategory = candidate.subCategory?.trim().isNotEmpty == true
          ? candidate.subCategory!.trim()
          : _resolveDefaultSubCategory(mainCategory);

      final String? sku = candidate.sku?.trim();
      if (sku != null && sku.isNotEmpty) {
        final String skuKey = sku.toLowerCase();
        if (!seenSkus.add(skuKey)) {
          duplicateWarnings.add('Satır ${row.rowNumber}: SKU tekrarı ($sku)');
        }
      }
      final String? barcode = candidate.barcode?.trim();
      if (barcode != null && barcode.isNotEmpty) {
        final String barcodeKey = barcode.toLowerCase();
        if (!seenBarcodes.add(barcodeKey)) {
          duplicateWarnings.add(
            'Satır ${row.rowNumber}: Barkod tekrarı ($barcode)',
          );
        }
      }

      try {
        final SellerProduct product = _buildSellerProduct(
          candidate,
          row.rowNumber,
          mainCategory: mainCategory,
          subCategory: subCategory,
        );
        await _storeService.addProduct(
          product,
          const [],
          variants: candidate.variants.isEmpty ? null : candidate.variants,
        );
        successfulRows++;
      } catch (error) {
        failures.add(
          BulkProductImportFailure(
            rowNumber: row.rowNumber,
            message: _friendlyError(error),
          ),
        );
      }
    }

    return BulkProductImportExecutionSummary(
      totalRows: validRows.length,
      successfulRows: successfulRows,
      failedRows: validRows.length - successfulRows,
      failures: failures,
      duplicateWarnings: duplicateWarnings,
    );
  }

  SellerProduct buildSellerProductForPreview(
    BulkProductImportCandidate candidate,
    int rowNumber, {
    required String mainCategory,
    required String subCategory,
  }) {
    return _buildSellerProduct(
      candidate,
      rowNumber,
      mainCategory: mainCategory,
      subCategory: subCategory,
    );
  }

  SellerProduct _buildSellerProduct(
    BulkProductImportCandidate candidate,
    int rowNumber, {
    required String mainCategory,
    required String subCategory,
  }) {
    final bool food = isFoodPricingCategory(mainCategory, subCategory);
    final ProductPricingType pricingType = food
        ? (candidate.priceType == 'kg'
              ? ProductPricingType.weight
              : ProductPricingType.portion)
        : ProductPricingType.portion;

    final double basePrice = candidate.price ?? 0;
    final DateTime now = DateTime.now();
    final List<String> attributeLines = buildBulkImportAttributeLines(candidate);
    final List<String> highlightItems = List<String>.from(candidate.highlightInfos);

    final List<String> imageUrls = List<String>.from(candidate.imageUrls);
    final String? mainImage = candidate.mainImageUrl?.trim().isNotEmpty == true
        ? candidate.mainImageUrl
        : (imageUrls.isNotEmpty ? imageUrls.first : null);

    return SellerProduct(
      id: '${now.microsecondsSinceEpoch}$rowNumber',
      name: candidate.productName?.trim().isNotEmpty == true
          ? candidate.productName!.trim()
          : 'Adsiz Urun',
      brand: candidate.brand?.trim() ?? '',
      mainCategory: mainCategory,
      subCategory: subCategory,
      price: basePrice,
      pricingType: pricingType.storageValue,
      portionPrice: food
          ? (candidate.portionPrice ?? basePrice)
          : basePrice,
      pricePerKg: food ? candidate.kiloPrice : null,
      minWeightGrams: food ? candidate.minGram : null,
      defaultWeightGrams: food ? candidate.defaultGram : null,
      weightStepGrams: food ? candidate.gramStep : null,
      maxWeightGrams: food ? candidate.maxGram : null,
      discountPrice: candidate.salePrice,
      stock: candidate.stock ?? 0,
      sku: candidate.sku?.trim().isNotEmpty == true
          ? candidate.sku!.trim()
          : (candidate.modelCode?.trim().isNotEmpty == true
                ? candidate.modelCode!.trim()
                : 'CSV-${now.millisecondsSinceEpoch}-$rowNumber'),
      status: bulkProductImportPersistedStatus(candidate.status),
      description: normalizeBulkImportDescription(candidate.description),
      specifications: buildBulkImportSpecificationsJson(
        candidate,
        food: food,
      ),
      preparationTime: food
          ? '${candidate.preparationTimeMinutes ?? 0} dakika'
          : null,
      createdAt: now,
      attributes: attributeLines,
      imageUrl: mainImage,
      imageUrls: imageUrls,
      videoUrl: candidate.videoUrl,
      variants: candidate.variants.isEmpty ? null : candidate.variants,
      additionalInfoItems: highlightItems,
      additionalInfo: highlightItems.isEmpty ? null : highlightItems.join('\n'),
    );
  }

  Future<String?> _loadLockedMainCategory() async {
    final Map<String, dynamic>? profile = await _storeService.getStoreProfile();
    final String? category = profile?['category']?.toString();
    return _storeCategoryToMainCategory(category);
  }

  String? _storeCategoryToMainCategory(String? storeCategory) {
    if (storeCategory == null || storeCategory.trim().isEmpty) {
      return null;
    }
    final String category = storeCategory.trim();
    if (category == 'Yemek') return 'Yemek';
    if (category == 'Elektronik') return 'Elektronik';
    if (category == 'Giyim & Aksesuar' || category == 'Ayakkabı & Çanta') {
      return 'Giyim & Aksesuar';
    }
    if (category == 'Ev & Yaşam' || category == 'Yapı Market & Bahçe') {
      return 'Ev & Yaşam';
    }
    if (category == 'Kozmetik & Kişisel Bakım') {
      return 'Kozmetik & Kişisel Bakım';
    }
    if (category == 'Spor & Outdoor') return 'Spor & Outdoor';
    if (category == 'Anne & Bebek & Oyuncak') {
      return 'Anne & Bebek & Oyuncak';
    }
    if (category == 'Kitap, Müzik, Film, Hobi') return 'Kitap & Hobi';
    if (category == 'Süpermarket' || category == 'Petshop') {
      return 'Süpermarket & Petshop';
    }
    if (category == 'Otomotiv & Motosiklet') return '2.el Ürünler';
    return category;
  }

  String _resolveDefaultSubCategory(String mainCategory) {
    final List<String> subCategories =
        bulkProductImportCategoryCatalog[mainCategory] ?? const <String>[];
    if (subCategories.contains('Diğer')) return 'Diğer';
    if (subCategories.contains('Ana Yemek')) return 'Ana Yemek';
    if (subCategories.isNotEmpty) return subCategories.first;
    return 'Diğer';
  }

  String _friendlyError(Object error) {
    final String message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Ürün eklenirken hata oluştu: ', '')
        .trim();
    if (message.isEmpty) return 'Kayıt oluşturulamadı.';
    return message;
  }
}
