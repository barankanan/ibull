import 'dart:convert';

import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/services/store_service.dart';

import 'bulk_product_csv_parser.dart';
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
    final String? mainCategory = await _loadLockedMainCategory();
    final String resolvedMainCategory = mainCategory ?? '';
    final String resolvedSubCategory = _resolveDefaultSubCategory(
      resolvedMainCategory,
    );

    final List<BulkProductImportPreviewRow> validRows = preview.rows
        .where((BulkProductImportPreviewRow row) => row.isValid)
        .toList(growable: false);

    int successfulRows = 0;
    final List<BulkProductImportFailure> failures =
        <BulkProductImportFailure>[];

    for (final BulkProductImportPreviewRow row in validRows) {
      try {
        await _storeService.addProduct(
          _buildSellerProduct(
            row.candidate!,
            row.rowNumber,
            mainCategory: resolvedMainCategory,
            subCategory: resolvedSubCategory,
          ),
          const [],
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
      totalRows: preview.totalRows,
      successfulRows: successfulRows,
      failedRows: preview.totalRows - successfulRows,
      failures: failures,
    );
  }

  SellerProduct _buildSellerProduct(
    BulkProductImportCandidate candidate,
    int rowNumber, {
    required String mainCategory,
    required String subCategory,
  }) {
    final ProductPricingType pricingType = candidate.priceType == 'kg'
        ? ProductPricingType.weight
        : ProductPricingType.portion;
    final DateTime now = DateTime.now();
    final List<String> highlightInfos = List<String>.from(
      candidate.highlightInfos,
    );

    return SellerProduct(
      id: '${now.microsecondsSinceEpoch}$rowNumber',
      name: (candidate.productName?.trim().isNotEmpty ?? false)
          ? candidate.productName!.trim()
          : 'Adsiz Urun',
      brand: candidate.brand?.trim() ?? '',
      mainCategory: mainCategory,
      subCategory: subCategory,
      price: candidate.price ?? 0,
      pricingType: pricingType.storageValue,
      portionPrice: pricingType == ProductPricingType.portion
          ? (candidate.price ?? 0)
          : null,
      pricePerKg: pricingType == ProductPricingType.weight
          ? (candidate.price ?? 0)
          : null,
      stock: candidate.stock ?? 0,
      sku: candidate.modelCode?.trim().isNotEmpty == true
          ? candidate.modelCode!.trim()
          : 'CSV-${now.millisecondsSinceEpoch}-$rowNumber',
      status: 'Aktif',
      description: candidate.description?.trim() ?? '',
      specifications: _buildSpecifications(candidate),
      preparationTime: '${candidate.preparationTimeMinutes ?? 0} dakika',
      createdAt: now,
      attributes: List<String>.from(candidate.productAttributes),
      imageUrls: const <String>[],
      additionalInfoItems: highlightInfos,
      additionalInfo: jsonEncode(highlightInfos),
    );
  }

  String? _buildSpecifications(BulkProductImportCandidate candidate) {
    final Map<String, dynamic> specifications = <String, dynamic>{
      'vatRate': candidate.vatRate ?? 0,
      'features': List<String>.from(candidate.productAttributes),
      'additional_info': List<String>.from(candidate.highlightInfos),
    };
    return jsonEncode(specifications);
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
    if (subCategories.contains('Diğer')) {
      return 'Diğer';
    }
    if (subCategories.contains('Ana Yemek')) {
      return 'Ana Yemek';
    }
    if (subCategories.isNotEmpty) {
      return subCategories.first;
    }
    return '';
  }

  String _friendlyError(Object error) {
    final String message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Ürün eklenirken hata oluştu: ', '')
        .trim();
    if (message.isEmpty) {
      return 'Kayıt oluşturulamadı.';
    }
    return message;
  }
}
