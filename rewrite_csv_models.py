import os

MODELS_PATH = 'ibul_app/lib/screens/seller/product_management/bulk_product_import_models.dart'

new_content = """import 'dart:convert';
import 'dart:typed_data';

import 'package:ibul_app/core/mobile_category_catalog.dart';
import 'package:ibul_app/core/product_rich_description.dart';

/// Canonical CSV kolon adları (İngilizce snake_case).
const List<String> bulkProductImportCanonicalHeaders = <String>[
  'product_name',
  'brand',
  'model_code',
  'main_category',
  'sub_category',
  'description',
  'price',
  'stock_quantity',
  'status',
  'color',
  'sku',
  'barcode',
  'sale_price',
  'tax_rate',
  'currency',
  'warranty_months',
  'origin_country',
  'condition',
  'is_featured',
  'main_image_url',
  'image_urls',
  'video_url',
  'attributes_json',
  'variants_json',
  'kargo_agirlik_kg',
  'en_cm',
  'boy_cm',
  'yukseklik_cm',
  'cargo_shipping_profile',
  'free_shipping',
  'highlights_json',
  'faq_json',
  'delivery_time',
  'estimated_delivery_days',
  'portion_price',
  'kilo_price',
  'min_gram',
  'default_gram',
  'gram_step',
  'max_gram',
];

const List<String> bulkProductImportRequiredHeaders = <String>[
  'product_name',
  'brand',
  'main_category',
  'sub_category',
  'price',
  'stock_quantity',
  'status',
];

const Set<String> bulkProductImportAllowedStatuses = <String>{
  'pending_approval',
  'draft',
  'passive',
};

/// CSV status değerini kaydedilecek ürün durumuna çevirir.
String normalizeBulkProductImportStatus(String raw) {
  final String normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
  if (normalized.isEmpty) {
    return 'pending_approval';
  }
  switch (normalized) {
    case 'draft':
    case 'taslak':
      return 'draft';
    case 'passive':
    case 'pasif':
      return 'passive';
    case 'active':
    case 'aktif':
    case 'pending_approval':
    case 'pending':
    case 'onay_bekliyor':
    case 'beklemede':
    case 'bekleniyor':
      return 'pending_approval';
    default:
      return normalized;
  }
}

/// Veritabanına yazılacak Türkçe/teknik ürün durumu.
String bulkProductImportPersistedStatus(String raw) {
  switch (normalizeBulkProductImportStatus(raw)) {
    case 'draft':
      return 'Taslak';
    case 'passive':
      return 'Pasif';
    case 'pending_approval':
    default:
      return 'pending_approval';
  }
}

const Set<String> bulkProductImportAllowedPriceTypes = <String>{
  'portion',
  'kg',
};

/// Eski Türkçe başlıklar ve yeni İngilizce başlıklar canonical ada eşlenir.
const Map<String, String> bulkProductImportHeaderAliases = <String, String>{
  'product_name': 'product_name',
  'ürün adı': 'product_name',
  'urun adı': 'product_name',
  'urun adi': 'product_name',
  'brand': 'brand',
  'marka': 'brand',
  'model_code': 'model_code',
  'model kodu': 'model_code',
  'model kod': 'model_code',
  'main_category': 'main_category',
  'ana kategori': 'main_category',
  'sub_category': 'sub_category',
  'alt kategori': 'sub_category',
  'description': 'description',
  'açıklama': 'description',
  'aciklama': 'description',
  'price': 'price',
  'fiyat': 'price',
  'stock_quantity': 'stock_quantity',
  'stok': 'stock_quantity',
  'stock': 'stock_quantity',
  'status': 'status',
  'durum': 'status',
  'color': 'color',
  'renk': 'color',
  'sku': 'sku',
  'barcode': 'barcode',
  'barkod': 'barcode',
  'sale_price': 'sale_price',
  'indirimli fiyat': 'sale_price',
  'tax_rate': 'tax_rate',
  'kdv oranı': 'tax_rate',
  'kdv orani': 'tax_rate',
  'vat_rate': 'tax_rate',
  'currency': 'currency',
  'para birimi': 'currency',
  'warranty_months': 'warranty_months',
  'garanti süresi': 'warranty_months',
  'garanti suresi': 'warranty_months',
  'origin_country': 'origin_country',
  'menşei': 'origin_country',
  'mensei': 'origin_country',
  'condition': 'condition',
  'durum ürün': 'condition',
  'is_featured': 'is_featured',
  'öne çıkan': 'is_featured',
  'main_image_url': 'main_image_url',
  'ana görsel': 'main_image_url',
  'image_urls': 'image_urls',
  'görsel url': 'image_urls',
  'video_url': 'video_url',
  'attributes_json': 'attributes_json',
  'ürün özellikleri': 'attributes_json',
  'urun ozellikleri': 'attributes_json',
  'variants_json': 'variants_json',
  'cargo_weight_kg': 'cargo_weight_kg',
  'kargo_agirlik_kg': 'cargo_weight_kg',
  'kargo ağırlık': 'cargo_weight_kg',
  'kargo agirlik': 'cargo_weight_kg',
  'kargo ağırlığı': 'cargo_weight_kg',
  'kargo agirligi': 'cargo_weight_kg',
  'kargo ağırlık (kg)': 'cargo_weight_kg',
  'kargo agirlik (kg)': 'cargo_weight_kg',
  'ağırlık (kg)': 'cargo_weight_kg',
  'agirlik (kg)': 'cargo_weight_kg',
  'cargo_width_cm': 'cargo_width_cm',
  'en_cm': 'cargo_width_cm',
  'en (cm)': 'cargo_width_cm',
  'en': 'cargo_width_cm',
  'kargo en': 'cargo_width_cm',
  'kargo en (cm)': 'cargo_width_cm',
  'cargo_height_cm': 'cargo_height_cm',
  'yukseklik_cm': 'cargo_height_cm',
  'yükseklik (cm)': 'cargo_height_cm',
  'yukseklik (cm)': 'cargo_height_cm',
  'yükseklik': 'cargo_height_cm',
  'yukseklik': 'cargo_height_cm',
  'kargo yükseklik': 'cargo_height_cm',
  'kargo yukseklik': 'cargo_height_cm',
  'cargo_length_cm': 'cargo_length_cm',
  'boy_cm': 'cargo_length_cm',
  'boy (cm)': 'cargo_length_cm',
  'boy': 'cargo_length_cm',
  'kargo boy': 'cargo_length_cm',
  'kargo boy (cm)': 'cargo_length_cm',
  'cargo_shipping_profile': 'cargo_shipping_profile',
  'free_shipping': 'free_shipping',
  'ücretsiz kargo': 'free_shipping',
  'highlights_json': 'highlights_json',
  'key_features': 'highlights_json',
  'faq_json': 'faq_json',
  'delivery_time': 'delivery_time',
  'tahmini teslimat': 'delivery_time',
  'estimated_delivery_days': 'estimated_delivery_days',
  'tahmini teslimat günü': 'estimated_delivery_days',
  
  // Eskileri uyarı ve redirect için (description'a eklenmeli)
  'rich_description_json': 'description',
  'description_image_urls': 'description',
  'açıklama görselleri': 'description',
  'aciklama gorselleri': 'description',
  'description_image_captions': 'description',
  'açıklama görsel açıklamaları': 'description',
  'aciklama gorsel aciklamalari': 'description',
  'long_description': 'description',
  'uzun açıklama': 'description',
  'uzun aciklama': 'description',
  'package_weight_kg': 'cargo_weight_kg',
  'package_width_cm': 'cargo_width_cm',
  'package_height_cm': 'cargo_height_cm',
  'package_length_cm': 'cargo_length_cm',
  'portion_price': 'portion_price',
  'porsiyon fiyatı': 'portion_price',
  'porsiyon fiyati': 'portion_price',
  'kilo_price': 'kilo_price',
  'kiloluk fiyat': 'kilo_price',
  'min_gram': 'min_gram',
  'default_gram': 'default_gram',
  'gram_step': 'gram_step',
  'max_gram': 'max_gram',
  'fiyat tipi': 'price_type',
  'price_type': 'price_type',
  'hazırlama süresi': 'preparation_time_minutes',
  'hazirlama suresi': 'preparation_time_minutes',
  'öne çıkan bilgiler': 'highlights_json',
  'one cikan bilgiler': 'highlights_json',
};

/// CSV önizleme ve şablon için okunabilir kolon başlıkları.
const Map<String, String> bulkProductImportHeaderDisplayLabels =
    <String, String>{
  'product_name': 'Ürün Adı',
  'brand': 'Marka',
  'model_code': 'Model Kodu',
  'main_category': 'Ana Kategori',
  'sub_category': 'Alt Kategori',
  'description': 'Açıklama',
  'price': 'Fiyat',
  'stock_quantity': 'Stok',
  'status': 'Durum',
  'attributes_json': 'Ürün Özellikleri (JSON)',
  'variants_json': 'Varyantlar (JSON)',
  'cargo_weight_kg': 'Kargo Ağırlık (kg)',
  'kargo_agirlik_kg': 'Kargo Ağırlık (kg)',
  'cargo_width_cm': 'En (cm)',
  'en_cm': 'En (cm)',
  'cargo_length_cm': 'Boy (cm)',
  'boy_cm': 'Boy (cm)',
  'cargo_height_cm': 'Yükseklik (cm)',
  'yukseklik_cm': 'Yükseklik (cm)',
  'cargo_shipping_profile': 'Kargo Profili',
  'free_shipping': 'Ücretsiz Kargo',
  'highlights_json': 'Öne Çıkan Bilgiler (JSON)',
  'faq_json': 'SSS (JSON)',
  'delivery_time': 'Tahmini Teslimat',
  'estimated_delivery_days': 'Tahmini Teslimat (Gün)',
};

String bulkProductImportHeaderLabel(String header) {
  final String trimmed = header.trim();
  if (trimmed.isEmpty) {
    return header;
  }
  final String? direct = bulkProductImportHeaderDisplayLabels[trimmed];
  if (direct != null) {
    return direct;
  }
  final String? canonical =
      bulkProductImportHeaderAliases[trimmed.toLowerCase()];
  if (canonical != null) {
    return bulkProductImportHeaderDisplayLabels[canonical] ?? trimmed;
  }
  return trimmed;
}

/// Ürün ekleme akışındaki "Kargo ve Boyut Bilgileri" adımı ile aynı alanlar.
const List<String> bulkProductImportCargoHeaders = <String>[
  'kargo_agirlik_kg',
  'en_cm',
  'boy_cm',
  'yukseklik_cm',
  'cargo_shipping_profile',
  'free_shipping',
];

/// Toplu import validasyonu için kategori kataloğu — seller katalog ile senkron.
Map<String, List<String>> get bulkProductImportCategoryCatalog =>
    sellerProductSubCategoriesByMain;

const String bulkProductImportTemplateFileName =
    'ibul_toplu_urun_sablonu.csv';

/// UTF-8 BOM ile CSV şablonu baytları.
Uint8List buildBulkProductImportTemplateBytes(bool isFoodCategory) {
  return Uint8List.fromList(<int>[
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(buildBulkProductImportTemplateCsv(isFoodCategory)),
  ]);
}

String buildBulkProductImportTemplateCsv(bool isFoodCategory) {
  final List<String> currentHeaders = bulkProductImportCanonicalHeaders.where((header) {
    if (!isFoodCategory) {
      if (['portion_price', 'kilo_price', 'min_gram', 'default_gram', 'gram_step', 'max_gram', 'preparation_time_minutes'].contains(header)) {
        return false;
      }
    }
    return true;
  }).toList();
  
  final String header = currentHeaders.join(',');
  
  // Örnekleri Food olup olmamasına göre ayıralım
  final List<String> rows = <String>[header];
  
  if (!isFoodCategory) {
    rows.add(
      _csvRow(<String>[
        'iPhone 15 Pro 256 GB', // product_name
        'Apple', // brand
        'A3101', // model_code
        'Elektronik', // main_category
        'Telefon', // sub_category
        'Güçlü A17 Pro işlemcisi, gelişmiş kamera sistemi ve uzun pil ömrüyle günlük kullanım için üst seviye akıllı telefon.', // description
        '64999', // price
        '12', // stock_quantity
        'pending_approval', // status
        'Titanyum Mavi', // color
        'IPH15P-256', // sku
        '1234567890123', // barcode
        '61999', // sale_price
        '20', // tax_rate
        'TRY', // currency
        '24', // warranty_months
        'Çin', // origin_country
        'new', // condition
        'true', // is_featured
        'https://example.com/iphone-main.jpg', // main_image_url
        'https://example.com/iphone-1.jpg|https://example.com/iphone-2.jpg', // image_urls
        '', // video_url
        r'{"Dahili Hafıza":"256 GB","RAM Kapasitesi":"8 GB","Ekran Boyutu":"6.7 inç","Garanti Süresi":"24 Ay"}', // attributes_json
        r'[{"Renk":"Siyah","Stok":10,"Fiyat":64999,"SKU":"IPH15P-256-BLK"},{"Renk":"Beyaz","Stok":5,"Fiyat":65500,"SKU":"IPH15P-256-WHT"}]', // variants_json
        '0.4', // kargo_agirlik_kg
        '10', // en_cm
        '18', // boy_cm
        '5', // yukseklik_cm
        'standart', // cargo_shipping_profile
        'false', // free_shipping
        r'["256 GB depolama","6.7 inç ProMotion ekran","24 ay garanti"]', // highlights_json
        r'[{"Soru":"Şarj aleti çıkıyor mu?","Cevap":"Hayır, kutu içeriğinde sadece şarj kablosu mevcuttur."}]', // faq_json
        '2-3 iş günü', // delivery_time
        '3', // estimated_delivery_days
      ])
    );
  } else {
    rows.add(
      _csvRow(<String>[
        'Karışık Kebab', // product_name
        'Şefin Mutfağı', // brand
        '', // model_code
        'Yemek', // main_category
        'Ana Yemek', // sub_category
        'Usta ellerden çıkma, lezzetli ve doyurucu karışık kebab tabağı. İçerisinde Adana, Urfa ve tavuk şiş bulunur.', // description
        '450', // price
        '50', // stock_quantity
        'pending_approval', // status
        '', // color
        'KEBAP-KARISIK-01', // sku
        '', // barcode
        '', // sale_price
        '10', // tax_rate
        'TRY', // currency
        '', // warranty_months
        'Türkiye', // origin_country
        'new', // condition
        'true', // is_featured
        'https://example.com/kebap.jpg', // main_image_url
        '', // image_urls
        '', // video_url
        r'{"Porsiyon":"1.5","Acı Durumu":"Acılı"}', // attributes_json
        '', // variants_json
        '', // kargo_agirlik_kg
        '', // en_cm
        '', // boy_cm
        '', // yukseklik_cm
        '', // cargo_shipping_profile
        'false', // free_shipping
        r'["Bol porsiyon","Özel soslu"]', // highlights_json
        '', // faq_json
        '30-45 dk', // delivery_time
        '1', // estimated_delivery_days
        '450', // portion_price
        '1200', // kilo_price
        '100', // min_gram
        '150', // default_gram
        '50', // gram_step
        '500', // max_gram
      ])
    );
  }

  return rows.join('\\n');
}

String _csvRow(List<String> cells) {
  return cells.map(_escapeCsvCell).join(',');
}

String _escapeCsvCell(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\\n') ||
      value.contains('|')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

List<String> parsePipeSeparated(String? value) {
  if (value == null || value.trim().isEmpty) return <String>[];
  return value
      .split('|')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> parseCommaSeparated(String? value) {
  if (value == null || value.trim().isEmpty) return <String>[];
  return value
      .split(',')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

class BulkProductSelectedFile {
  const BulkProductSelectedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class BulkProductCsvDocument {
  const BulkProductCsvDocument({required this.headers, required this.rows});

  final List<String> headers;
  final List<Map<String, String>> rows;
}

class BulkProductImportCandidate {
  const BulkProductImportCandidate({
    this.productName,
    this.brand,
    this.modelCode,
    this.mainCategory,
    this.subCategory,
    this.description,
    this.price,
    this.stock,
    this.status = 'pending_approval',
    this.color,
    this.sku,
    this.barcode,
    this.salePrice,
    this.vatRate,
    this.currency = 'TRY',
    this.warrantyMonths,
    this.originCountry,
    this.condition,
    this.isFeatured = false,
    this.mainImageUrl,
    this.imageUrls = const <String>[],
    this.videoUrl,
    this.attributesMap = const <String, String>{},
    this.variants = const <Map<String, dynamic>>[],
    this.cargoWeightKg,
    this.cargoWidthCm,
    this.cargoHeightCm,
    this.cargoLengthCm,
    this.cargoShippingProfile,
    this.freeShipping = false,
    this.portionPrice,
    this.kiloPrice,
    this.minGram,
    this.defaultGram,
    this.gramStep,
    this.maxGram,
    this.priceType,
    this.preparationTimeMinutes,
    this.highlightInfos = const <String>[],
    this.faqs = const <Map<String, String>>[],
    this.deliveryTime,
    this.estimatedDeliveryDays,
    this.richDescriptionBlocks = const <ProductRichDescriptionBlock>[],
  });

  final String? productName;
  final String? brand;
  final String? modelCode;
  final String? mainCategory;
  final String? subCategory;
  final String? description;
  final double? price;
  final int? stock;
  final String status;
  final String? color;
  final String? sku;
  final String? barcode;
  final double? salePrice;
  final num? vatRate;
  final String currency;
  final int? warrantyMonths;
  final String? originCountry;
  final String? condition;
  final bool isFeatured;
  final String? mainImageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final Map<String, String> attributesMap;
  final List<Map<String, dynamic>> variants;
  final double? cargoWeightKg;
  final double? cargoWidthCm;
  final double? cargoHeightCm;
  final double? cargoLengthCm;
  final String? cargoShippingProfile;
  final bool freeShipping;
  final double? portionPrice;
  final double? kiloPrice;
  final int? minGram;
  final int? defaultGram;
  final int? gramStep;
  final int? maxGram;
  final String? priceType;
  final int? preparationTimeMinutes;
  final List<String> highlightInfos;
  final List<Map<String, String>> faqs;
  final String? deliveryTime;
  final int? estimatedDeliveryDays;
  final List<ProductRichDescriptionBlock> richDescriptionBlocks;
}

class BulkProductImportPreviewRow {
  const BulkProductImportPreviewRow({
    required this.rowNumber,
    required this.rawValues,
    required this.errors,
    this.candidate,
  });

  final int rowNumber;
  final Map<String, String> rawValues;
  final List<String> errors;
  final BulkProductImportCandidate? candidate;

  bool get isValid => errors.isEmpty && candidate != null;
}

class BulkProductImportPreview {
  const BulkProductImportPreview({
    required this.fileName,
    required this.headers,
    required this.rows,
    required this.isFoodCategory,
    this.fileErrors = const <String>[],
  });

  final String fileName;
  final List<String> headers;
  final List<BulkProductImportPreviewRow> rows;
  final List<String> fileErrors;
  final bool isFoodCategory;

  int get totalRows => rows.length;

  int get validRowCount => rows.where((BulkProductImportPreviewRow row) {
    return row.isValid;
  }).length;

  int get invalidRowCount => totalRows - validRowCount;

  bool get hasValidRows => validRowCount > 0;
}

class BulkProductImportFailure {
  const BulkProductImportFailure({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;
}

class BulkProductImportExecutionSummary {
  const BulkProductImportExecutionSummary({
    required this.totalRows,
    required this.successfulRows,
    required this.failedRows,
    required this.failures,
    this.duplicateWarnings = const <String>[],
  });

  final int totalRows;
  final int successfulRows;
  final int failedRows;
  final List<BulkProductImportFailure> failures;
  final List<String> duplicateWarnings;
}

/// Geriye dönük uyumluluk — runtime şablonu kullanın.
String get bulkProductImportTemplateCsv => buildBulkProductImportTemplateCsv(false);
"""

with open(MODELS_PATH, 'w') as f:
    f.write(new_content)
