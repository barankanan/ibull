import 'dart:typed_data';

const List<String> bulkProductImportRequiredHeaders = <String>[
  'Ürün Adı',
  'Fiyat',
  'Stok',
];

const List<String> bulkProductImportHeaders = <String>[
  'Ürün Adı',
  'Fiyat',
  'Stok',
  'Açıklama',
  'Marka',
  'Model Kodu',
  'Ürün Özellikleri',
  'Öne Çıkan Bilgiler',
  'Fiyat Tipi',
  'KDV Oranı',
  'Hazırlama Süresi',
];

const Map<String, String> bulkProductImportHeaderAliases = <String, String>{
  'ürün adı': 'Ürün Adı',
  'urun adı': 'Ürün Adı',
  'urun adi': 'Ürün Adı',
  'product_name': 'Ürün Adı',
  'fiyat': 'Fiyat',
  'price': 'Fiyat',
  'stok': 'Stok',
  'stock': 'Stok',
  'açıklama': 'Açıklama',
  'aciklama': 'Açıklama',
  'description': 'Açıklama',
  'marka': 'Marka',
  'brand': 'Marka',
  'model kodu': 'Model Kodu',
  'model kod': 'Model Kodu',
  'model code': 'Model Kodu',
  'model_code': 'Model Kodu',
  'ürün özellikleri': 'Ürün Özellikleri',
  'urun özellikleri': 'Ürün Özellikleri',
  'urun ozellikleri': 'Ürün Özellikleri',
  'attributes': 'Ürün Özellikleri',
  'features': 'Ürün Özellikleri',
  'öne çıkan bilgiler': 'Öne Çıkan Bilgiler',
  'one çıkan bilgiler': 'Öne Çıkan Bilgiler',
  'one cikan bilgiler': 'Öne Çıkan Bilgiler',
  'öne cikan bilgiler': 'Öne Çıkan Bilgiler',
  'additional_info': 'Öne Çıkan Bilgiler',
  'highlights': 'Öne Çıkan Bilgiler',
  'fiyat tipi': 'Fiyat Tipi',
  'price_type': 'Fiyat Tipi',
  'kdv oranı': 'KDV Oranı',
  'kdv orani': 'KDV Oranı',
  'vat_rate': 'KDV Oranı',
  'hazırlama süresi': 'Hazırlama Süresi',
  'hazirlama süresi': 'Hazırlama Süresi',
  'hazirlama suresi': 'Hazırlama Süresi',
  'preparation_time': 'Hazırlama Süresi',
};

const Map<String, List<String>> bulkProductImportCategoryCatalog =
    <String, List<String>>{
      'Elektronik': <String>[
        'Telefonlar',
        'Laptop & Tablet',
        'Televizyon',
        'Gaming',
        'Oyuncu Ekipmanları',
        'Telefon Aksesuarları',
        'Oyun Konsolları',
      ],
      'Spor & Outdoor': <String>[
        'Spor Giyim',
        'Fitness',
        'Outdoor',
        'Sporcu Besinleri',
        'Kamp & Kampçılık',
        'Bisiklet',
      ],
      'Giyim & Aksesuar': <String>[
        'Kadın Giyim',
        'Erkek Giyim',
        'Çocuk Giyim',
        'Ayakkabı',
        'Çanta',
        'Saat & Aksesuar',
      ],
      'Anne & Bebek & Oyuncak': <String>[
        'Bebek Giyim',
        'Bebek Bakım',
        'Oyuncak',
        'Bebek Arabası',
        'Bebek Beslenme',
      ],
      'Kozmetik & Kişisel Bakım': <String>[
        'Cilt Bakım',
        'Makyaj',
        'Parfüm',
        'Saç Bakım',
        'Kişisel Bakım',
        'Erkek Bakım',
      ],
      'Ev & Yaşam': <String>[
        'Mobilya',
        'Dekorasyon',
        'Mutfak',
        'Banyo',
        'Bahçe',
        'Aydınlatma',
        'Ev Tekstili',
      ],
      'Süpermarket & Petshop': <String>[
        'Gıda',
        'İçecek',
        'Temizlik',
        'Petshop',
        'Bebek Ürünleri',
      ],
      'Kitap & Hobi': <String>[
        'Kitap',
        'Müzik & Film',
        'Hobi & Oyun',
        'Kırtasiye',
        'Sanat',
      ],
      '2.el Ürünler': <String>[
        '2.el Elektronik',
        '2.el Giyim',
        '2.el Mobilya',
        '2.el Kitap',
        'Diğer',
      ],
      'Yemek': <String>[
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

const Set<String> bulkProductImportAllowedPriceTypes = <String>{
  'portion',
  'kg',
};

const Set<String> bulkProductImportAllowedServiceTypes = <String>{
  'dine_in',
  'takeaway',
  'delivery',
};

const Set<String> bulkProductImportAllowedServiceTimes = <String>{
  'immediate',
  'scheduled',
};

const String bulkProductImportTemplateCsv =
    'Ürün Adı,Fiyat,Stok,Açıklama,Marka,Model Kodu,Ürün Özellikleri,Öne Çıkan Bilgiler,Fiyat Tipi,KDV Oranı,Hazırlama Süresi\n'
    '"Adana Kebap","189.90","48","Odun ateşinde pişirilmiş, özel sos ile servis edilen porsiyon kebap","Kebapçı Usta","SKU-ADN-001","Acısız, Soğansız, Ekstra Peynir","El Yapımı, Günlük Üretim, Şef Önerisi","Porsiyon","10","25"\n';

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
    this.price,
    this.stock,
    this.vatRate,
    this.preparationTimeMinutes,
    this.priceType,
    this.description,
    this.brand,
    this.modelCode,
    this.productAttributes = const <String>[],
    this.highlightInfos = const <String>[],
  });

  final String? productName;
  final double? price;
  final int? stock;
  final num? vatRate;
  final int? preparationTimeMinutes;
  final String? priceType;
  final String? description;
  final String? brand;
  final String? modelCode;
  final List<String> productAttributes;
  final List<String> highlightInfos;
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
    this.fileErrors = const <String>[],
  });

  final String fileName;
  final List<String> headers;
  final List<BulkProductImportPreviewRow> rows;
  final List<String> fileErrors;

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
  });

  final int totalRows;
  final int successfulRows;
  final int failedRows;
  final List<BulkProductImportFailure> failures;
}
