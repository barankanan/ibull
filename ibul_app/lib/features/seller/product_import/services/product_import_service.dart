import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/services/store_service.dart';

import '../adapters/adapter_registry.dart';
import '../adapters/shopify_product_adapter.dart';
import '../models/imported_product.dart';
import '../security/product_import_security.dart';
import 'product_quality_service.dart';
import 'product_variation_combiner.dart';

/// İçe aktarım operasyonunun nihai özeti
class ProductImportExecutionResult {
  final int totalCount;
  final int successCount;
  final int failedCount;
  final int duplicateCount;
  final List<ImportedProductData> products;
  final List<({String productName, String sku, String error})> failures;

  const ProductImportExecutionResult({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.duplicateCount,
    required this.products,
    required this.failures,
  });

  bool get isAllSuccessful => failedCount == 0;
  bool get hasFailures => failedCount > 0;
}

/// Ürün İçe Aktarma Merkezi Ana Servisi
class ProductImportService {
  ProductImportService({
    StoreService? storeService,
    AdapterRegistry? registry,
    ProductQualityService? qualityService,
    ProductVariationCombiner? variationCombiner,
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
    Future<String?> Function(Uri uri)? customFetcher,
  })  : _injectedStoreService = storeService,
        _registry = registry ?? AdapterRegistry(),
        _qualityService = qualityService ?? const ProductQualityService(),
        _variationCombiner = variationCombiner ?? const ProductVariationCombiner(),
        _injectedSupabase = supabaseClient,
        _httpClient = httpClient ?? http.Client(),
        _customFetcher = customFetcher;

  final StoreService? _injectedStoreService;
  final AdapterRegistry _registry;
  final ProductQualityService _qualityService;
  final ProductVariationCombiner _variationCombiner;
  final SupabaseClient? _injectedSupabase;
  final http.Client _httpClient;
  final Future<String?> Function(Uri uri)? _customFetcher;

  SupabaseClient? get _supabase {
    if (_injectedSupabase != null) return _injectedSupabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  StoreService get _storeService => _injectedStoreService ?? StoreService();

  /// URL listesini tarar, SSRF korumasını uygular, ürünleri ayrıştırır ve kalite raporunu oluşturur.
  Future<List<ImportedProductData>> scanUrls(
    List<String> rawUrls, {
    Function(int current, int total, String status)? onProgress,
  }) async {
    final List<String> validUrls = [];
    final List<ImportedProductData> foundProducts = [];

    // 1. URL'leri temizle ve SSRF doğrulaması yap
    for (final raw in rawUrls) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final check = ProductImportSecurity.validateUrl(trimmed);
      if (check.isValid && check.uri != null) {
        validUrls.add(check.uri.toString());
      }
    }

    if (validUrls.isEmpty) {
      throw Exception('Lütfen geçerli ve güvenli en az bir ürün URL\'si girin.');
    }

    onProgress?.call(0, validUrls.length, 'Tarama görevi başlatılıyor...');

    // 2. Asenkron iş kaydı oluştur (İzlenebilirlik)
    String? jobId;
    try {
      final client = _supabase;
      final user = client?.auth.currentUser;
      if (client != null && user != null) {
        final job = await client
            .from('product_import_jobs')
            .insert({
              'seller_id': user.id,
              'status': 'scanning',
              'source_urls': validUrls,
              'total_products': validUrls.length,
            })
            .select('id')
            .maybeSingle();
        jobId = job?['id']?.toString();
      }
    } catch (e) {
      debugPrint('İş kuyruğu kaydı oluşturulamadı (RLS veya tablo yok): $e');
    }

    final List<String> errorDetails = [];

    // 3. Her URL için içerik çek ve adaptörlerden geçir
    for (int i = 0; i < validUrls.length; i++) {
      final urlStr = validUrls[i];
      final uri = Uri.parse(urlStr);
      onProgress?.call(i + 1, validUrls.length, '${uri.host} taranıyor...');

      try {
        List<ImportedProductData> parsedList = [];

        // 1. Akıllı Shopify Doğrudan Endpoint Entegrasyonu:
        // Eğer URL '/products/' içeriyorsa HTML kazımadan önce '.js' ekleyerek
        // doğrudan Shopify Product REST JSON endpoint'ine istek at. Bu Cloudflare challenge'larını baypas eder.
        if (uri.path.contains('/products/')) {
          final shopifyEndpointUri = ShopifyProductAdapter.buildEndpointUri(uri);
          try {
            final shopifyJson = await _fetchPageHtmlSafely(shopifyEndpointUri);
            if (shopifyJson != null && _isLikelyShopifyJson(shopifyJson)) {
              const shopifyAdapter = ShopifyProductAdapter();
              parsedList = await shopifyAdapter.parse(uri: uri, html: shopifyJson);
            }
          } catch (shopifyErr) {
            debugPrint('Shopify .js endpoint çağrısı başarısız ($shopifyEndpointUri), standart HTML deneniyor: $shopifyErr');
          }
        }

        // 2. Standart HTML taraması ve adaptör zinciri
        if (parsedList.isEmpty) {
          final html = await _fetchPageHtmlSafely(uri);
          if (html == null || html.trim().isEmpty) {
            throw Exception('Kaynak sayfadan içerik alınamadı.');
          }

          parsedList = await _registry.parseProductPage(uri: uri, html: html);
          if (parsedList.isEmpty) {
            throw Exception('Bu sayfada desteklenen bir ürün yapısı bulunamadı.');
          }
        }

        for (final p in parsedList) {
          // Kategori eşleştirmesi
          String mainCat = p.mainCategory;
          if (mainCat.isEmpty) {
            mainCat = _qualityService.mapToMainCategory(p.name);
          } else {
            final mapped = _qualityService.mapToMainCategory(mainCat);
            if (mapped.isNotEmpty) mainCat = mapped;
          }

          final enriched = p.copyWith(
            mainCategory: mainCat,
            subCategory: p.subCategory.isNotEmpty ? p.subCategory : 'Diğer',
          );

          // Kalite değerlendirmesi
          final quality = _qualityService.evaluateQuality(enriched);
          foundProducts.add(enriched.copyWith(quality: quality));
        }
      } catch (err) {
        final errText = err.toString().replaceFirst('Exception: ', '');
        debugPrint('URL tarama hatası ($urlStr): $errText');
        errorDetails.add(errText);
      }
    }

    // 4. İş kaydını güncelle
    if (jobId != null) {
      try {
        await _supabase?.from('product_import_jobs').update({
          'status': 'ready',
          'total_products': foundProducts.length,
          'processed_products': validUrls.length,
          'result_payload': {
            'found_count': foundProducts.length,
          },
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', jobId);
      } catch (_) {}
    }

    // 5. Eğer hiçbir ürün bulunamadıysa ve hata oluştuysa satıcıya şeffaf hata fırlat
    if (foundProducts.isEmpty && errorDetails.isNotEmpty) {
      final uniqueErrors = errorDetails.toSet().toList();
      if (uniqueErrors.length == 1) {
        throw Exception(uniqueErrors.first);
      }
      throw Exception(
        'Taranan adreslerde hata oluştu:\n${uniqueErrors.join('\n')}',
      );
    }

    return foundProducts;
  }

  bool _isLikelyShopifyJson(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
    return (trimmed.contains('"title"') || trimmed.contains('"name"')) &&
        (trimmed.contains('"variants"') || trimmed.contains('"price"') || trimmed.contains('"vendor"'));
  }

  /// SSL veya sertifika uyuşmazlığı hatalarını tespit eder.
  static bool isSslOrCertError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('invalid peer certificate') ||
        lower.contains('notvalidforname') ||
        lower.contains('certificate') ||
        lower.contains('handshake') ||
        lower.contains('ssl') ||
        lower.contains('tls');
  }

  /// Hostname başında www. yoksa ekler (IP adresleri hariç).
  static Uri addWwwPrefix(Uri uri) {
    if (!uri.host.startsWith('www.') && !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host)) {
      return uri.replace(host: 'www.${uri.host}');
    }
    return uri;
  }

  /// Protokolü http'ye dönüştürür.
  static Uri toHttpScheme(Uri uri) {
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'http');
    }
    return uri;
  }

  /// Güvenli HTTP isteği: Tüm harici sayfa taramaları SSRF korumalı 'product-crawler' Edge Function üzerinden yürütülür.
  /// İstemci tarafında doğrudan kontrolsüz GET isteği atılması güvenlik (SSRF/CORS) nedeniyle engellenmiştir.
  Future<String?> _fetchPageHtmlSafely(Uri uri, {bool allowRetry = true}) async {
    final fetcher = _customFetcher;
    if (fetcher != null) {
      try {
        return await fetcher(uri);
      } catch (e) {
        final errStr = e.toString().replaceFirst('Exception: ', '');
        if (allowRetry && isSslOrCertError(errStr)) {
          // 1. www. denemesi
          if (!uri.host.startsWith('www.') && !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host)) {
            final wwwUri = addWwwPrefix(uri);
            try {
              return await _fetchPageHtmlSafely(wwwUri, allowRetry: false);
            } catch (wwwErr) {
              final wwwErrStr = wwwErr.toString().replaceFirst('Exception: ', '');
              if (!isSslOrCertError(wwwErrStr)) rethrow;
            }
          }
          // 2. http denemesi
          if (uri.scheme == 'https') {
            final httpUri = toHttpScheme(uri);
            try {
              return await _fetchPageHtmlSafely(httpUri, allowRetry: false);
            } catch (_) {}
          }
        }
        rethrow;
      }
    }

    final client = _supabase;
    if (client == null) {
      throw Exception('Ürün tarama servisi için satıcı oturumu gereklidir. Lütfen satıcı girişi yapın.');
    }

    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Ürün tarama servisi için satıcı oturumu gereklidir. Lütfen satıcı girişi yapın.');
    }

    try {
      final res = await client.functions.invoke(
        'product-crawler',
        body: {'url': uri.toString()},
      );

      if (res.status == 200 && res.data is Map && res.data['ok'] == true) {
        final results = res.data['results'];
        if (results is List && results.isNotEmpty) {
          final first = results.first;
          if (first['success'] == true && first['html'] is String) {
            return first['html'] as String;
          } else if (first['error'] != null) {
            throw Exception(first['error']);
          }
        }
      } else if (res.data is Map && res.data['error'] != null) {
        final err = res.data['error'].toString();
        if (err == 'AUTH_REQUIRED' || err == 'AUTH_INVALID') {
          throw Exception('Ürün tarama servisi için satıcı girişi gereklidir.');
        }
        throw Exception(err);
      } else {
        final status = res.status;
        if (status == 403 || status == 429) {
          throw Exception('Site bot koruması nedeniyle doğrudan erişimi engelledi ($status). Bu mağaza için satıcı API anahtarı gereklidir.');
        } else if (status == 401) {
          throw Exception('Erişim yetkisi reddedildi (401). Satıcı oturumunuzu kontrol edin.');
        } else if (status == 404) {
          throw Exception('Ürün sayfası bulunamadı (404). Lütfen URL adresini kontrol edin.');
        } else if (status >= 500) {
          throw Exception('Kaynak site veya tarama servisi sunucu hatası döndürdü ($status).');
        }
        throw Exception('Tarama servisi geçersiz yanıt döndürdü (HTTP $status).');
      }
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');

      // SSL Telafi ve Otomatik 'www.' / 'http://' Yönlendirmesi
      if (allowRetry && isSslOrCertError(errStr)) {
        // 1. 'www.' yoksa, hostname başına 'www.' ekleyerek yeniden dene
        if (!uri.host.startsWith('www.') && !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host)) {
          final wwwUri = addWwwPrefix(uri);
          try {
            debugPrint('SSL hatası nedeniyle www eklendi ve yeniden deneniyor: $wwwUri');
            return await _fetchPageHtmlSafely(wwwUri, allowRetry: false);
          } catch (wwwErr) {
            final wwwErrStr = wwwErr.toString().replaceFirst('Exception: ', '');
            if (!isSslOrCertError(wwwErrStr)) {
              rethrow;
            }
          }
        }

        // 2. Alternatif olarak http:// üzerinden dene (sunucu yönlendirmesini takip etsin)
        if (uri.scheme == 'https') {
          final httpUri = toHttpScheme(uri);
          try {
            debugPrint('SSL hatası nedeniyle http protokolüne fallback yapılıyor: $httpUri');
            return await _fetchPageHtmlSafely(httpUri, allowRetry: false);
          } catch (_) {
            // http fallback de başarısız olursa orijinal hatayı fırlat
          }
        }
      }

      if (errStr.contains('bot koruması') ||
          errStr.contains('kısıtlandı') ||
          errStr.contains('engellendi') ||
          errStr.contains('HTTP 403') ||
          errStr.contains('HTTP 429') ||
          errStr.contains('403') ||
          errStr.contains('401') ||
          errStr.contains('404') ||
          errStr.contains('500') ||
          errStr.contains('zaman aşımı') ||
          errStr.contains('bulunamadı') ||
          errStr.contains('satıcı API anahtarı') ||
          errStr.contains('satıcı oturumu') ||
          isSslOrCertError(errStr)) {
        rethrow;
      }
      throw Exception(
        'Ürün tarama servisi bağlantı hatası: $errStr. '
        'Lütfen internet bağlantınızı kontrol edin.',
      );
    }

    return null;
  }

  /// Toplu Fiyat Düzenleme: Seçilen ürünlerin fiyatlarını yüzde veya sabit tutar ile günceller
  List<ImportedProductData> batchApplyPriceMarkup(
    List<ImportedProductData> products, {
    double? percent,
    double? fixedAmount,
    bool roundToInteger = false,
  }) {
    return products.map((p) {
      if (!p.isSelected) return p;

      double newPrice = p.price;
      if (percent != null && percent != 0) {
        newPrice = newPrice * (1 + (percent / 100));
      }
      if (fixedAmount != null) {
        newPrice = newPrice + fixedAmount;
      }
      if (newPrice < 0) newPrice = 0;
      if (roundToInteger) {
        newPrice = newPrice.roundToDouble();
      }

      // Varyasyon fiyatlarını da aynı oranda güncelle
      final updatedVariants = p.realVariants.map((v) {
        double vPrice = v.price;
        if (percent != null && percent != 0) {
          vPrice = vPrice * (1 + (percent / 100));
        }
        if (fixedAmount != null) {
          vPrice = vPrice + fixedAmount;
        }
        if (vPrice < 0) vPrice = 0;
        if (roundToInteger) {
          vPrice = vPrice.roundToDouble();
        }
        return v.copyWith(price: vPrice);
      }).toList();

      final updatedProduct = p.copyWith(
        price: newPrice,
        realVariants: updatedVariants,
      );
      final newQuality = _qualityService.evaluateQuality(updatedProduct);
      return updatedProduct.copyWith(quality: newQuality);
    }).toList();
  }

  /// Toplu Kategori Değiştirme
  List<ImportedProductData> batchSetCategory(
    List<ImportedProductData> products, {
    required String mainCategory,
    required String subCategory,
  }) {
    return products.map((p) {
      if (!p.isSelected) return p;
      final updated = p.copyWith(
        mainCategory: mainCategory,
        subCategory: subCategory,
      );
      final quality = _qualityService.evaluateQuality(updated);
      return updated.copyWith(quality: quality);
    }).toList();
  }

  /// Toplu Marka Belirleme
  List<ImportedProductData> batchSetBrand(
    List<ImportedProductData> products, {
    required String brand,
  }) {
    return products.map((p) {
      if (!p.isSelected) return p;
      final updated = p.copyWith(brand: brand);
      final quality = _qualityService.evaluateQuality(updated);
      return updated.copyWith(quality: quality);
    }).toList();
  }

  /// Seçili ürünleri mevcut İBUL altyapısını kullanarak mağazaya 'Taslak' olarak aktarır.
  Future<ProductImportExecutionResult> importSelectedProducts(
    List<ImportedProductData> products, {
    Function(int current, int total, String status)? onProgress,
  }) async {
    final selectedProducts = products.where((p) => p.isSelected).toList();
    if (selectedProducts.isEmpty) {
      return ProductImportExecutionResult(
        totalCount: 0,
        successCount: 0,
        failedCount: 0,
        duplicateCount: 0,
        products: products,
        failures: const [],
      );
    }

    final currentUserId = _supabase?.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Satıcı oturumu bulunamadı. Lütfen tekrar giriş yapın.');
    }

    // 1. Mükerrer Link ve SKU Kontrolü (Satıcının mevcut ürünleri)
    // Başlık benzerliği nedeniyle yanlış eşleşme yapılmaz; sadece kesin URL veya SKU kullanılır.
    final existingData = await _loadExistingSellerData(currentUserId);
    final existingSkus = existingData.skus;
    final existingUrls = existingData.sourceUrls;

    int successCount = 0;
    int failedCount = 0;
    int duplicateCount = 0;
    final List<({String productName, String sku, String error})> failures = [];
    final List<ImportedProductData> updatedProductList = List.from(products);

    for (int i = 0; i < selectedProducts.length; i++) {
      final prod = selectedProducts[i];
      final indexInList = updatedProductList.indexWhere((p) => p.id == prod.id);

      onProgress?.call(
        i + 1,
        selectedProducts.length,
        '${prod.name} (${i + 1}/${selectedProducts.length}) aktarılıyor...',
      );

      // Mükerrer kontrolü: URL veya SKU
      final cleanSku = prod.sku.trim().toLowerCase();
      final cleanUrl = prod.sourceUrl.trim().toLowerCase();

      bool isDuplicate = false;
      String duplicateMsg = '';

      if (cleanUrl.isNotEmpty && existingUrls.contains(cleanUrl)) {
        isDuplicate = true;
        duplicateMsg = 'Bu ürün linki (${prod.sourceUrl}) mağazanızda zaten daha önce aktarılmış.';
      } else if (cleanSku.isNotEmpty && existingSkus.contains(cleanSku)) {
        isDuplicate = true;
        duplicateMsg = 'Bu SKU ($cleanSku) mağazanızdaki başka bir üründe zaten kayıtlı.';
      }

      if (isDuplicate) {
        duplicateCount++;
        if (indexInList != -1) {
          updatedProductList[indexInList] = prod.copyWith(
            importStatus: ProductImportStatus.duplicate,
            errorMessage: duplicateMsg,
          );
        }
        continue;
      }

      try {
        // 2. Görselleri İndir ve XFile Listesine Çevir (SSRF Korumalı)
        final List<XFile> downloadedFiles = [];
        for (int imgIndex = 0; imgIndex < prod.imageUrls.length; imgIndex++) {
          final rawImgUrl = prod.imageUrls[imgIndex].trim();
          if (rawImgUrl.isEmpty) continue;

          // SSRF URL kontrolü
          final imgCheck = ProductImportSecurity.validateUrl(rawImgUrl);
          if (!imgCheck.isValid || imgCheck.uri == null) {
            debugPrint('Güvenlik riski taşıyan görsel URL\'si atlandı: $rawImgUrl');
            continue;
          }

          // Desktop/Mobile ortamında DNS kontrolü (Yerel ağ / Cloud metadata engeli)
          if (!kIsWeb) {
            final dns = await ProductImportSecurity.verifyDnsResolution(imgCheck.uri!.host);
            if (!dns.isValid) {
              debugPrint('Özel IP adresine çözümlenen görsel engellendi: $rawImgUrl');
              continue;
            }
          }

          try {
            final imgResponse = await _httpClient.get(imgCheck.uri!).timeout(const Duration(seconds: 10));
            if (imgResponse.statusCode == 200 &&
                imgResponse.bodyBytes.isNotEmpty &&
                imgResponse.bodyBytes.length <= 10 * 1024 * 1024) {
              final contentType = imgResponse.headers['content-type'] ?? '';
              final isImage = contentType.startsWith('image/') ||
                  rawImgUrl.contains('.jpg') ||
                  rawImgUrl.contains('.jpeg') ||
                  rawImgUrl.contains('.png') ||
                  rawImgUrl.contains('.webp');
              if (isImage && !contentType.contains('svg') && !rawImgUrl.contains('.svg')) {
                downloadedFiles.add(
                  XFile.fromData(
                    imgResponse.bodyBytes,
                    name: 'imported_${DateTime.now().millisecondsSinceEpoch}_$imgIndex.jpg',
                    mimeType: 'image/jpeg',
                  ),
                );
              }
            }
          } catch (imgErr) {
            debugPrint('Görsel indirme hatası ($rawImgUrl): $imgErr');
          }
        }

        // 3. Varyantları İBUL formatına dönüştür
        final dbVariants = _variationCombiner.toDbVariants(
          prod.realVariants,
          basePrice: prod.price,
        );

        // 4. SellerProduct modelini oluştur ('Taslak' statüsünde)
        final now = DateTime.now();
        final String generatedId = '${now.microsecondsSinceEpoch}$i';

        // Metadata zenginleştirme (Kaynak URL ve bilinmeyen stok durumu)
        final updatedSpecs = Map<String, dynamic>.from(prod.specifications);
        updatedSpecs['source_url'] = prod.sourceUrl;
        updatedSpecs['adapter_name'] = prod.adapterName;
        updatedSpecs['stock_known'] = prod.isStockKnown;
        if (!prod.isStockKnown) {
          updatedSpecs['stock_note'] = 'Kaynakta stok belirtilmemiş (0 olarak kaydedildi)';
        }

        final sellerProduct = SellerProduct(
          id: generatedId,
          name: prod.name.trim(),
          brand: prod.brand.trim(),
          mainCategory: prod.mainCategory.trim().isNotEmpty ? prod.mainCategory.trim() : 'Genel',
          subCategory: prod.subCategory.trim().isNotEmpty ? prod.subCategory.trim() : 'Diğer',
          price: prod.price,
          portionPrice: prod.price,
          discountPrice: prod.discountPrice,
          stock: prod.stock != null && prod.stock! > 0 ? prod.stock! : 0, // Güvenli varsayılan: Bilinmeyen stok 0 kaydedilir
          sku: prod.sku.trim(),
          status: 'Taslak', // İlk aktarımda zorunlu olarak Taslak kaydedilir
          description: prod.description.isNotEmpty ? prod.description : null,
          createdAt: now,
          specifications: jsonEncode(updatedSpecs),
          imageUrls: prod.imageUrls,
          variants: dbVariants.isNotEmpty ? dbVariants : null,
        );

        // 5. StoreService üzerinden güvenli kayıt
        await _storeService.addProduct(
          sellerProduct,
          downloadedFiles,
          variants: dbVariants.isNotEmpty ? dbVariants : null,
        );

        // Başarılı
        successCount++;
        if (cleanSku.isNotEmpty) existingSkus.add(cleanSku);
        if (cleanUrl.isNotEmpty) existingUrls.add(cleanUrl);

        if (indexInList != -1) {
          updatedProductList[indexInList] = prod.copyWith(
            importStatus: ProductImportStatus.success,
            createdProductId: generatedId,
          );
        }
      } catch (saveError) {
        // Hata durumunda diğer ürünlerin aktarımı durmaz (Safe Isolation)
        failedCount++;
        final friendlyErr = saveError.toString().replaceFirst('Exception: ', '').trim();
        failures.add((
          productName: prod.name,
          sku: prod.sku,
          error: friendlyErr,
        ));
        if (indexInList != -1) {
          updatedProductList[indexInList] = prod.copyWith(
            importStatus: ProductImportStatus.failed,
            errorMessage: friendlyErr,
          );
        }
      }
    }

    return ProductImportExecutionResult(
      totalCount: selectedProducts.length,
      successCount: successCount,
      failedCount: failedCount,
      duplicateCount: duplicateCount,
      products: updatedProductList,
      failures: failures,
    );
  }

  /// Satıcının mağazasındaki mevcut SKU ve kaynak URL değerlerini çeker
  Future<({Set<String> skus, Set<String> sourceUrls})> _loadExistingSellerData(String sellerId) async {
    final Set<String> skus = {};
    final Set<String> sourceUrls = {};
    final client = _supabase;
    if (client == null) return (skus: skus, sourceUrls: sourceUrls);
    try {
      final rows = await client
          .from('products')
          .select('sku, specifications')
          .eq('seller_id', sellerId);
      for (final row in rows) {
        final s = row['sku']?.toString().trim().toLowerCase();
        if (s != null && s.isNotEmpty) {
          skus.add(s);
        }
        final specs = row['specifications'];
        if (specs is String && specs.contains('source_url')) {
          try {
            final decoded = jsonDecode(specs);
            if (decoded is Map && decoded['source_url'] != null) {
              sourceUrls.add(decoded['source_url'].toString().trim().toLowerCase());
            }
          } catch (_) {}
        } else if (specs is Map && specs['source_url'] != null) {
          sourceUrls.add(specs['source_url'].toString().trim().toLowerCase());
        }
      }
    } catch (_) {}
    return (skus: skus, sourceUrls: sourceUrls);
  }

  /// Web ve mobil ortamda güvenli CSV çözümleme:
  /// Bytes doğrudan utf8.decode ile okunur (asla .path üzerinden File açılmaz).
  /// CsvToListConverter(shouldParseNumbers: false) kullanılarak JSON alanlarındaki virgüller korunur.
  List<Map<String, String>> parseCsvBytes(Uint8List bytes) {
    final String content = utf8.decode(bytes, allowMalformed: true);
    return parseCsvString(content);
  }

  /// CSV metnini standart parser ile satır ve sütun haritasına dönüştürür.
  List<Map<String, String>> parseCsvString(String csvString) {
    final String sanitized = csvString
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final int firstNewline = sanitized.indexOf('\n');
    final String headerLine =
        firstNewline >= 0 ? sanitized.substring(0, firstNewline) : sanitized;
    final int commas = ','.allMatches(headerLine).length;
    final int semicolons = ';'.allMatches(headerLine).length;
    final String delimiter = semicolons > commas ? ';' : ',';

    final List<List<dynamic>> matrix = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(sanitized);

    if (matrix.isEmpty) return <Map<String, String>>[];

    final List<String> headers = matrix.first
        .map((dynamic h) => (h?.toString() ?? '').trim())
        .toList(growable: false);

    final List<Map<String, String>> rows = <Map<String, String>>[];
    for (final List<dynamic> rawRow in matrix.skip(1)) {
      if (rawRow.every((dynamic c) => (c?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      final Map<String, String> row = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        final String header = headers[i];
        if (header.isEmpty) continue;
        row[header] = i < rawRow.length ? (rawRow[i]?.toString() ?? '').trim() : '';
      }
      rows.add(row);
    }
    return rows;
  }
}
