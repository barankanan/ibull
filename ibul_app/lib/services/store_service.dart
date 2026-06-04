import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/runtime_config.dart';
import '../models/seller_product.dart';
import '../models/store_sub_category.dart';
import '../models/sub_admin.dart';
import '../utils/product_create_log.dart';
import '../utils/product_edit_log.dart';
import 'store/store_media_service.dart';
import 'store/store_mapping_helpers.dart';
import 'store_notification_trigger_service.dart';
import 'store/store_table_service.dart';
import 'store/store_upload_progress_details.dart';
import 'store_service_mappers.dart';

class StoreService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, ({DateTime expiresAt, Map<String, dynamic> data})>
  _storePublicInfoCache = {};
  static final Map<String, ({DateTime expiresAt, List<StoreSubCategory> items})>
  _storeSubCategoryCache = {};
  static const Duration _storePublicInfoTtl = Duration(minutes: 10);
  static const Duration _storeSubCategoryTtl = Duration(minutes: 5);
  static const Duration _tableOrderTimeout = Duration(seconds: 10);

  /// Session-level cache for the current seller's business name.
  /// Populated by [getStoreProfile]; invalidated by [updateStoreProfile].
  String? _cachedBusinessName;

  String? get currentUserId => _supabase.auth.currentUser?.id;
  late final StoreMediaService _mediaService = StoreMediaService(
    supabase: _supabase,
    currentUserIdResolver: () => currentUserId,
  );
  late final StoreTableService _tableService = StoreTableService(
    supabase: _supabase,
    currentUserIdResolver: () => currentUserId,
    tableOrderTimeout: _tableOrderTimeout,
  );

  String get _debugSupabaseUrl {
    final raw = AppRuntimeConfig.rawSupabaseUrl.trim();
    return raw.isEmpty ? '(missing)' : raw;
  }

  String _debugRestRequestUrl(
    String table, {
    Map<String, String> query = const <String, String>{},
  }) {
    final encodedQuery = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    if (_debugSupabaseUrl == '(missing)') {
      return 'supabase://$table$encodedQuery';
    }
    return '$_debugSupabaseUrl/rest/v1/$table$encodedQuery';
  }

  // --- Store Profile Methods ---

  /// Mağaza adına göre logo URL döndürür (Supabase stores tablosu). Ürün sayfası / satıcı profili için.
  Future<String?> getStoreLogoUrlByBusinessName(String businessName) async {
    if (businessName.isEmpty) return null;
    final cached = _getCachedStorePublicInfo(businessName);
    if (cached != null) {
      final logoUrl = cached['logoUrl']?.toString();
      if (logoUrl != null && logoUrl.isNotEmpty) return logoUrl;
    }
    try {
      final info = await getStorePublicInfoByBusinessName(businessName);
      return info?['logoUrl'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _storeSubCategoryCacheKey({
    required String sellerId,
    required String mainCategory,
  }) {
    return '${sellerId.trim()}::${mainCategory.trim().toLowerCase()}';
  }

  List<StoreSubCategory>? _getCachedStoreSubCategories({
    required String sellerId,
    required String mainCategory,
  }) {
    final key = _storeSubCategoryCacheKey(
      sellerId: sellerId,
      mainCategory: mainCategory,
    );
    final cached = _storeSubCategoryCache[key];
    if (cached == null) return null;
    if (cached.expiresAt.isBefore(DateTime.now())) {
      _storeSubCategoryCache.remove(key);
      return null;
    }
    return List<StoreSubCategory>.from(cached.items, growable: false);
  }

  void _setCachedStoreSubCategories({
    required String sellerId,
    required String mainCategory,
    required List<StoreSubCategory> items,
  }) {
    final key = _storeSubCategoryCacheKey(
      sellerId: sellerId,
      mainCategory: mainCategory,
    );
    _storeSubCategoryCache[key] = (
      expiresAt: DateTime.now().add(_storeSubCategoryTtl),
      items: List<StoreSubCategory>.from(items, growable: false),
    );
  }

  void _invalidateStoreSubCategoryCache({
    required String sellerId,
    required String mainCategory,
  }) {
    final key = _storeSubCategoryCacheKey(
      sellerId: sellerId,
      mainCategory: mainCategory,
    );
    _storeSubCategoryCache.remove(key);
  }

  /// Mağaza adına göre logo, galeri ve duyuru banner'larını döndürür (harita popup, satıcı profili).
  Future<Map<String, dynamic>?> getStorePublicInfoByBusinessName(
    String businessName,
  ) async {
    if (businessName.isEmpty) return null;
    final cached = _getCachedStorePublicInfo(businessName);
    if (cached != null) return cached;
    try {
      final res = await _supabase
          .from('stores')
          .select('logo_url, gallery_images, banners, seller_videos')
          .ilike('business_name', businessName)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      final List<String> gallery = [];
      if (res['gallery_images'] != null) {
        if (res['gallery_images'] is List) {
          for (final e in res['gallery_images'] as List) {
            if (e != null && e.toString().isNotEmpty) gallery.add(e.toString());
          }
        }
      }
      final List<String> banners = [];
      if (res['banners'] != null) {
        if (res['banners'] is List) {
          for (final e in res['banners'] as List) {
            if (e != null && e.toString().isNotEmpty) banners.add(e.toString());
          }
        }
      }
      final List<String> videos = [];
      if (res['seller_videos'] != null) {
        if (res['seller_videos'] is List) {
          for (final e in res['seller_videos'] as List) {
            if (e != null && e.toString().isNotEmpty) videos.add(e.toString());
          }
        }
      }
      final data = {
        'logoUrl': res['logo_url'] as String?,
        'galleryImages': gallery,
        'banners': banners,
        'sellerVideos': videos,
      };
      _setCachedStorePublicInfo(businessName, data);
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> getStorePublicInfoByBusinessNames(
    List<String> businessNames,
  ) async {
    final requestedNames = businessNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final results = <String, Map<String, dynamic>>{};
    final missingNames = <String>[];

    for (final name in requestedNames) {
      final cached = _getCachedStorePublicInfo(name);
      if (cached != null) {
        results[name] = cached;
      } else {
        missingNames.add(name);
      }
    }
    if (missingNames.isEmpty) return results;

    try {
      final orClause = missingNames
          .map((name) => 'business_name.ilike.${name.replaceAll(',', r'\,')}')
          .join(',');
      final response = await _supabase
          .from('stores')
          .select(
            'business_name, logo_url, gallery_images, banners, seller_videos',
          )
          .or(orClause);
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final businessName = row['business_name']?.toString();
        if (businessName == null || businessName.trim().isEmpty) continue;
        final info = {
          'logoUrl': row['logo_url'] as String?,
          'galleryImages': List<String>.from(row['gallery_images'] ?? const []),
          'banners': List<String>.from(row['banners'] ?? const []),
          'sellerVideos': List<String>.from(row['seller_videos'] ?? const []),
        };
        _setCachedStorePublicInfo(businessName, info);
        results[businessName] = info;
      }
    } catch (_) {}

    return results;
  }

  /// Mağaza ID'sine göre logo, galeri ve duyuru banner'larını döndürür.
  Future<Map<String, dynamic>?> getStorePublicInfoById(String sellerId) async {
    if (sellerId.isEmpty) return null;
    try {
      final res = await _supabase
          .from('stores')
          .select(
            'logo_url, gallery_images, banners, business_name, seller_videos',
          )
          .eq('seller_id', sellerId)
          .maybeSingle();
      if (res == null) return null;

      final List<String> gallery = [];
      if (res['gallery_images'] != null && res['gallery_images'] is List) {
        for (final e in res['gallery_images'] as List) {
          if (e != null && e.toString().isNotEmpty) gallery.add(e.toString());
        }
      }

      final List<String> banners = [];
      if (res['banners'] != null && res['banners'] is List) {
        for (final e in res['banners'] as List) {
          if (e != null && e.toString().isNotEmpty) banners.add(e.toString());
        }
      }

      final List<String> videos = [];
      if (res['seller_videos'] != null && res['seller_videos'] is List) {
        for (final e in res['seller_videos'] as List) {
          if (e != null && e.toString().isNotEmpty) videos.add(e.toString());
        }
      }

      return {
        'logoUrl': res['logo_url'] as String?,
        'businessName': res['business_name'] as String?,
        'galleryImages': gallery,
        'banners': banners,
        'sellerVideos': videos,
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<StoreSubCategory>> getStoreSubCategories({
    required String sellerId,
    required String mainCategory,
    bool forceRefresh = false,
  }) async {
    final trimmedSellerId = sellerId.trim();
    final trimmedMainCategory = mainCategory.trim();
    if (trimmedSellerId.isEmpty || trimmedMainCategory.isEmpty) {
      return const <StoreSubCategory>[];
    }

    if (!forceRefresh) {
      final cached = _getCachedStoreSubCategories(
        sellerId: trimmedSellerId,
        mainCategory: trimmedMainCategory,
      );
      if (cached != null) return cached;
    }

    try {
      final response = await _supabase
          .from('store_sub_categories')
          .select('id, seller_id, main_category, name, is_active, sort_order')
          .eq('seller_id', trimmedSellerId)
          .eq('main_category', trimmedMainCategory)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      final items = List<Map<String, dynamic>>.from(
        response as List,
      ).map(StoreSubCategory.fromMap).toList(growable: false);
      _setCachedStoreSubCategories(
        sellerId: trimmedSellerId,
        mainCategory: trimmedMainCategory,
        items: items,
      );
      return items;
    } catch (error) {
      debugPrint('Error getting store sub categories: $error');
      return const <StoreSubCategory>[];
    }
  }

  Future<StoreSubCategory?> ensureStoreSubCategory({
    required String sellerId,
    required String mainCategory,
    required String name,
  }) async {
    final trimmedSellerId = sellerId.trim();
    final trimmedMainCategory = mainCategory.trim();
    final trimmedName = name.trim();
    if (trimmedSellerId.isEmpty ||
        trimmedMainCategory.isEmpty ||
        trimmedName.isEmpty) {
      return null;
    }

    final existing = await getStoreSubCategories(
      sellerId: trimmedSellerId,
      mainCategory: trimmedMainCategory,
    );
    final normalizedName = trimmedName.toLowerCase();
    for (final item in existing) {
      if (item.normalizedName == normalizedName) {
        return item;
      }
    }

    try {
      final nextSortOrder = existing.isEmpty
          ? 0
          : existing
                    .map((item) => item.sortOrder)
                    .reduce((left, right) => left > right ? left : right) +
                1;
      final response = await _supabase
          .from('store_sub_categories')
          .insert(<String, dynamic>{
            'seller_id': trimmedSellerId,
            'main_category': trimmedMainCategory,
            'name': trimmedName,
            'sort_order': nextSortOrder,
            'is_active': true,
          })
          .select('id, seller_id, main_category, name, is_active, sort_order')
          .single();
      final created = StoreSubCategory.fromMap(
        Map<String, dynamic>.from(response),
      );
      _setCachedStoreSubCategories(
        sellerId: trimmedSellerId,
        mainCategory: trimmedMainCategory,
        items: <StoreSubCategory>[...existing, created],
      );
      return created;
    } catch (error) {
      debugPrint('Error ensuring store sub category: $error');
      _invalidateStoreSubCategoryCache(
        sellerId: trimmedSellerId,
        mainCategory: trimmedMainCategory,
      );
      try {
        final refreshed = await getStoreSubCategories(
          sellerId: trimmedSellerId,
          mainCategory: trimmedMainCategory,
          forceRefresh: true,
        );
        for (final item in refreshed) {
          if (item.normalizedName == normalizedName) {
            return item;
          }
        }
      } catch (_) {}
      return null;
    }
  }

  Future<Map<String, dynamic>> _prepareProductDbData(
    SellerProduct product, {
    required String sellerId,
  }) async {
    final trimmedMainCategory = product.mainCategory.trim();
    final trimmedSubCategory = product.subCategory.trim();
    StoreSubCategory? resolvedSubCategory;
    if (trimmedMainCategory.isNotEmpty && trimmedSubCategory.isNotEmpty) {
      resolvedSubCategory = await ensureStoreSubCategory(
        sellerId: sellerId,
        mainCategory: trimmedMainCategory,
        name: trimmedSubCategory,
      );
    }

    final productMap = <String, dynamic>{
      ...product.toMap(),
      'subCategoryId': resolvedSubCategory?.id ?? product.subCategoryId,
      'subCategory': trimmedSubCategory,
    };
    return StoreServiceMappers.productToSnakeCase(productMap);
  }

  Map<String, dynamic>? _getCachedStorePublicInfo(String businessName) {
    final key = businessName.trim().toLowerCase();
    final cached = _storePublicInfoCache[key];
    if (cached == null) return null;
    if (cached.expiresAt.isBefore(DateTime.now())) {
      _storePublicInfoCache.remove(key);
      return null;
    }
    return cached.data;
  }

  void _setCachedStorePublicInfo(
    String businessName,
    Map<String, dynamic> data,
  ) {
    _storePublicInfoCache[businessName.trim().toLowerCase()] = (
      expiresAt: DateTime.now().add(_storePublicInfoTtl),
      data: data,
    );
  }

  /// Haritada gösterilecek onaylı mağazaları döndürür (store_lat, store_lng dolu olanlar). logo_url ve gallery_images dahil.
  Future<List<Map<String, dynamic>>> getStoresForMap() async {
    try {
      final list = await _supabase
          .from('stores')
          .select(
            'seller_id, business_name, store_lat, store_lng, category, address, city, logo_url, gallery_images, banners',
          )
          .not('store_lat', 'is', null)
          .not('store_lng', 'is', null);
      return List<Map<String, dynamic>>.from(list as List);
    } catch (e) {
      debugPrint('getStoresForMap error: $e');
      return [];
    }
  }

  /// Ana sayfa hızlı teslimat mesafe hesabı için kullanılan hafif fetch.
  /// Yalnızca konum ve kimlik alanlarını çeker; gallery_images/banners gibi
  /// ağır JSON kolonlarını almaz (~10x küçük payload).
  Future<List<Map<String, dynamic>>> getStoresForFastDelivery() async {
    try {
      final list = await _supabase
          .from('stores')
          .select('seller_id, business_name, store_lat, store_lng')
          .not('store_lat', 'is', null)
          .not('store_lng', 'is', null);
      return List<Map<String, dynamic>>.from(list as List);
    } catch (e) {
      debugPrint('getStoresForFastDelivery error: $e');
      return [];
    }
  }

  // Get Store Profile
  Future<Map<String, dynamic>?> getStoreProfile() async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('[StoreService] getStoreProfile skipped: authUserId missing');
      return null;
    }

    final requestUrl = _debugRestRequestUrl(
      'stores',
      query: <String, String>{
        'select':
            'business_name,website,description,slogan,phone,email,whatsapp,'
            'support_phone,address,postal_code,tax_number,instagram,facebook,'
            'twitter,city,district,business_type,working_hours,is_store_open,'
            'accept_new_orders,allow_messaging,is_holiday_mode,logo_url,'
            'cover_url,gallery_images,banners,seller_videos,store_lat,'
            'store_lng,category,rating,is_verified',
        'seller_id': 'eq.$userId',
      },
    );
    debugPrint(
      '[StoreService] getStoreProfile requestUrl=$requestUrl authUserId=$userId',
    );

    const storeProfileColumns =
        'business_name,website,description,slogan,phone,email,whatsapp,'
        'support_phone,address,postal_code,tax_number,instagram,facebook,'
        'twitter,city,district,business_type,working_hours,is_store_open,'
        'accept_new_orders,allow_messaging,is_holiday_mode,logo_url,'
        'cover_url,gallery_images,banners,seller_videos,store_lat,'
        'store_lng,category,rating,is_verified';

    try {
      final data = await _supabase
          .from('stores')
          .select(storeProfileColumns)
          .eq('seller_id', userId)
          .maybeSingle();

      if (data == null) {
        debugPrint(
          '[StoreService] getStoreProfile empty result requestUrl=$requestUrl '
          'authUserId=$userId',
        );
        return null;
      }

      // Map snake_case to camelCase for UI consumption
      final mapped = StoreServiceMappers.storeToCamelCase(data);
      final name = mapped['storeName']?.toString().trim() ?? '';
      if (name.isNotEmpty) _cachedBusinessName = name;
      return mapped;
    } catch (e, stackTrace) {
      debugPrint(
        '[StoreService] getStoreProfile failed requestUrl=$requestUrl '
        'authUserId=$userId error=$e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  // Upload Document (for Seller Application)
  Future<String> uploadDocument(
    String fileName,
    Uint8List fileBytes,
    String contentType,
  ) async {
    return _mediaService.uploadDocument(fileName, fileBytes, contentType);
  }

  // Create Signed URL for document (for Admin)
  Future<String> getDocumentUrl(String path) async {
    return _mediaService.getDocumentUrl(path);
  }

  // Update Store Profile
  Future<void> updateStoreProfile(Map<String, dynamic> data) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    // Map camelCase to snake_case for DB
    final dbData = StoreServiceMappers.storeToSnakeCase(data);
    dbData['updated_at'] = DateTime.now().toIso8601String();
    dbData['seller_id'] = currentUserId; // Ensure ID is set

    await _supabase.from('stores').upsert(dbData);

    // Invalidate cached business name so the next call fetches fresh data.
    _cachedBusinessName = null;

    if (dbData.containsKey('banners')) {
      unawaited(_notifyFollowersStoreAnnouncement());
    }
  }

  // Upload Store Image (Logo, Cover, Gallery)
  Future<String> uploadStoreImage(XFile file, String folderName) async {
    return _mediaService.uploadStoreImage(file, folderName);
  }

  // Upload Store Image from raw bytes (used by cropper flows)
  Future<String> uploadStoreImageBytes(
    Uint8List bytes,
    String folderName, {
    String fileName = 'image.jpg',
  }) async {
    return _mediaService.uploadStoreImageBytes(
      bytes,
      folderName,
      fileName: fileName,
    );
  }

  // Upload Product Video
  Future<String> uploadProductVideo(XFile videoFile) async {
    return _mediaService.uploadProductVideo(videoFile);
  }

  // Upload Store Video (Seller Profile Video)
  Future<String> uploadStoreVideo(XFile videoFile) async {
    return _mediaService.uploadStoreVideo(videoFile);
  }

  Future<String> uploadStoreVideoWithProgress(
    XFile videoFile, {
    void Function(double progress)? onProgress,
    void Function(UploadProgressDetails details)? onProgressDetails,
  }) async {
    return _mediaService.uploadStoreVideoWithProgress(
      videoFile,
      onProgress: onProgress,
      onProgressDetails: onProgressDetails,
    );
  }

  // Get Seller Products with Videos
  Future<List<SellerProduct>> getProductsWithVideos() async {
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('seller_id', currentUserId!)
          .not('video_url', 'is', null) // Correct filter for not null
          .order('created_at', ascending: false);

      return (response as List).map((e) => _mapSnakeCaseToProduct(e)).toList();
    } catch (e) {
      debugPrint('Error fetching products with videos: $e');
      return [];
    }
  }

  // --- Product Methods ---

  // Add Product
  Future<void> addProduct(
    SellerProduct product,
    List<XFile> images, {
    Function(String)? onProgress,
    List<dynamic>?
    variants, // Changed to dynamic to avoid type error if ProductVariant is not imported
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      productCreateLog('product_save_start', extra: {'name': product.name});
      // 1. Ürünü Veritabanına Ekle (Resimsiz Başlangıç)
      Map<String, dynamic> productDbData = await _prepareProductDbData(
        product,
        sellerId: currentUserId!,
      );
      productDbData['seller_id'] = currentUserId;
      productDbData['status'] = 'uploading';
      productDbData['image_urls'] = [];
      productDbData['image_url'] = null;
      productDbData['created_at'] = DateTime.now().toIso8601String();
      if (!productDbData.containsKey('product_type') ||
          (productDbData['product_type']?.toString().trim().isEmpty ?? true)) {
        productDbData['product_type'] = 'product';
      }
      productCreateLog(
        'payload_type',
        extra: {'product_type': productDbData['product_type']},
      );
      if (product.accessories != null) {
        productDbData['accessories'] = product.accessories;
      }

      if (variants != null && variants.isNotEmpty) {
        // Varyantları JSON olarak kaydet
        productDbData['variants'] = variants.map((v) {
          if (v is Map) return v;
          return {
            'color': (v as dynamic).color,
            'size': (v as dynamic).size,
            'ram': (v as dynamic).ram,
            'storage': (v as dynamic).storage,
            'sku': (v as dynamic).sku,
            'stock': (v as dynamic).stock,
            'priceDifference': (v as dynamic).priceDifference,
            'imagePath': (v as dynamic).imagePath,
          };
        }).toList();
      }

      final response = await _runProductWriteWithFallback(
        productDbData,
        (payload) =>
            _supabase.from('products').upsert(payload).select().single(),
      );
      final productId = response['id'].toString();

      // 2. Görselleri Yükle
      List<String> uploadedUrls = [];

      if (images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final file = images[i];
          if (onProgress != null) {
            onProgress('Görsel ${i + 1}/${images.length} yükleniyor...');
          }

          productCreateLog(
            'image_upload_start',
            extra: {'productId': productId, 'index': i, 'name': file.name},
          );
          try {
            final url = await _uploadProductImage(productId, file, i);
            uploadedUrls.add(url);
            productCreateLog(
              'image_upload_success',
              extra: {'productId': productId, 'index': i, 'url': url},
            );
          } catch (uploadError, uploadStack) {
            productCreateLog(
              'product_save_error',
              extra: {
                'errorType': uploadError.runtimeType.toString(),
                'message': uploadError.toString(),
                'phase': 'image_upload',
                'index': i,
              },
            );
            debugPrint('Product image upload stack: $uploadStack');
            throw Exception('Görsel yüklenemedi. Lütfen tekrar deneyin.');
          }
        }
      }

      List<dynamic>? updatedVariants;
      if (variants != null && variants.isNotEmpty) {
        updatedVariants = [];
        for (int i = 0; i < variants.length; i++) {
          final v = variants[i];
          if (v is Map) {
            updatedVariants.add(v);
            continue;
          }

          String? imageUrl;
          try {
            final existing = (v as dynamic).imageUrl;
            if (existing != null && existing.toString().trim().isNotEmpty) {
              imageUrl = existing.toString();
            }
          } catch (_) {}

          if (imageUrl == null) {
            try {
              final file = (v as dynamic).imageFile;
              if (file is XFile) {
                if (onProgress != null) {
                  onProgress(
                    'Varyant görseli ${i + 1}/${variants.length} yükleniyor...',
                  );
                }
                imageUrl = await _uploadVariantImage(productId, file, i);
              }
            } catch (_) {}
          }

          updatedVariants.add({
            'color': (v as dynamic).color,
            'size': (v as dynamic).size,
            'ram': (v as dynamic).ram,
            'storage': (v as dynamic).storage,
            'sku': (v as dynamic).sku,
            'stock': (v as dynamic).stock,
            'priceDifference': (v as dynamic).priceDifference,
            'imageUrl': imageUrl,
          });
        }
      }

      // 3. Ürün Verisini Güncelle (Resim URL'leri ve Durum)
      final Map<String, dynamic> uploadedProductData = <String, dynamic>{
        'image_urls': uploadedUrls,
        'image_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        'status': _canonicalPersistedProductStatus(product.status),
        'updated_at': DateTime.now().toIso8601String(),
      };
      productCreateLog(
        'approval_status_resolved',
        extra: {'status': uploadedProductData['status']},
      );
      if (updatedVariants != null) {
        uploadedProductData['variants'] = updatedVariants;
      }
      await _supabase
          .from('products')
          .update(uploadedProductData)
          .eq('id', productId);

      if (uploadedProductData['status'] == 'Aktif') {
        unawaited(
          _notifyFollowersNewProduct(
            productId: productId,
            productName: product.name,
          ),
        );
      }
      productCreateLog(
        'product_save_success',
        extra: {'productId': productId, 'imageCount': uploadedUrls.length},
      );
    } catch (e, stack) {
      productCreateLog(
        'product_save_error',
        extra: {'errorType': e.runtimeType.toString(), 'message': e.toString()},
      );
      debugPrint('Add Product Error: $e');
      debugPrint('Add Product stack: $stack');
      if (e is Exception && e.toString().contains('Görsel yüklenemedi')) {
        rethrow;
      }
      throw Exception(
        'Ürün eklenirken hata oluştu: ${productCreateErrorMessage(e)}',
      );
    }
  }

  Future<void> updateProduct(
    SellerProduct product, {
    List<XFile>? newImages,
    Function(String)? onProgress,
    String? previousStatus,
    List<dynamic>? variants,
    @Deprecated(
      'Yayın anında Aktif; parametre geriye uyumluluk için tutuluyor.',
    )
    bool bypassApproval = false,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      // Mevcut resimleri koru; yalnızca imageUrl dolu imageUrls boş senaryosunu birleştir
      // (şablon kapak vb. bazı akışlarda image_url güncellenirken liste boş kalabiliyordu).
      List<String> finalImageUrls = List.from(product.imageUrls);
      final String primaryImage = (product.imageUrl ?? '').trim();
      if (primaryImage.isNotEmpty &&
          !finalImageUrls.any((u) => u.trim() == primaryImage)) {
        finalImageUrls = <String>[primaryImage, ...finalImageUrls];
      }

      // Yeni resimler varsa yükle ve listeye ekle
      if (newImages != null && newImages.isNotEmpty) {
        for (int i = 0; i < newImages.length; i++) {
          final file = newImages[i];
          if (onProgress != null) {
            onProgress(
              'Yeni görsel ${i + 1}/${newImages.length} yükleniyor...',
            );
          }

          final url = await _uploadProductImage(
            product.id,
            file,
            finalImageUrls.length + i,
          );
          finalImageUrls.add(url);
        }
      }

      Map<String, dynamic> updateData = await _prepareProductDbData(
        product,
        sellerId: currentUserId!,
      );
      updateData['image_urls'] = finalImageUrls;
      updateData['image_url'] = finalImageUrls.isNotEmpty
          ? finalImageUrls.first
          : null;
      updateData['updated_at'] = DateTime.now().toIso8601String();
      if (product.accessories != null) {
        updateData['accessories'] = product.accessories;
      }

      updateData['status'] = _canonicalPersistedProductStatus(product.status);
      final bool isActiveStatus =
          _canonicalPersistedProductStatus(product.status) == 'Aktif';

      if (variants != null) {
        final updatedVariants = <dynamic>[];
        for (int i = 0; i < variants.length; i++) {
          final v = variants[i];
          if (v is Map) {
            updatedVariants.add(v);
            continue;
          }

          String? imageUrl;
          try {
            final existing = (v as dynamic).imageUrl;
            if (existing != null && existing.toString().trim().isNotEmpty) {
              imageUrl = existing.toString();
            }
          } catch (_) {}

          if (imageUrl == null) {
            try {
              final file = (v as dynamic).imageFile;
              if (file is XFile) {
                if (onProgress != null) {
                  onProgress(
                    'Varyant görseli ${i + 1}/${variants.length} yükleniyor...',
                  );
                }
                imageUrl = await _uploadVariantImage(product.id, file, i);
              }
            } catch (_) {}
          }

          updatedVariants.add({
            'color': (v as dynamic).color,
            'size': (v as dynamic).size,
            'ram': (v as dynamic).ram,
            'storage': (v as dynamic).storage,
            'sku': (v as dynamic).sku,
            'stock': (v as dynamic).stock,
            'priceDifference': (v as dynamic).priceDifference,
            'imageUrl': imageUrl,
          });
        }
        updateData['variants'] = updatedVariants;
      }

      SellerProduct? previousProduct;
      try {
        previousProduct = await getProductById(product.id);
      } catch (_) {}

      await _runProductWriteWithFallback(
        updateData,
        (payload) =>
            _supabase.from('products').update(payload).eq('id', product.id),
      );

      if (isActiveStatus) {
        final hadDiscount = previousProduct?.hasDiscount ?? false;
        if (!hadDiscount && product.hasDiscount) {
          unawaited(
            _notifyFollowersProductDiscount(
              productId: product.id,
              productName: product.name,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Update Product Error: $e');
      throw Exception('Ürün güncellenirken hata: $e');
    }
  }

  Future<SellerProduct> updateProductQuickEdit({
    required SellerProduct product,
    required String name,
    required double price,
    required int stock,
    required String status,
    XFile? replacementImage,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      final Map<String, dynamic> updateData = <String, dynamic>{};
      final trimmedName = name.trim();
      final trimmedStatus = status.trim();
      String normalizeStatus(String value) {
        switch (value.trim().toLowerCase()) {
          case 'active':
          case 'aktif':
            return 'aktif';
          case 'inactive':
          case 'pasif':
            return 'pasif';
          case 'draft':
          case 'taslak':
            return 'taslak';
          case 'pending':
          case 'pending_approval':
          case 'bekleniyor':
            return 'bekleniyor';
          case 'rejected':
          case 'reddedildi':
            return 'reddedildi';
          default:
            return value.trim().toLowerCase();
        }
      }

      if (trimmedName != product.name.trim()) {
        updateData['name'] = trimmedName;
      }
      if (price != product.price) {
        updateData['price'] = price;
        if (product.isWeightPriced) {
          updateData['price_per_kg'] = price;
        } else {
          updateData['portion_price'] = price;
        }
      }
      if (stock != product.stock) {
        updateData['stock'] = stock;
      }
      if (trimmedStatus.isNotEmpty &&
          normalizeStatus(trimmedStatus) != normalizeStatus(product.status)) {
        updateData['status'] = trimmedStatus;
      }

      if (replacementImage != null) {
        final uploadedUrl = await _uploadProductImage(
          product.id,
          replacementImage,
          0,
        );
        final List<String> currentImageUrls = product.imageUrls.isNotEmpty
            ? List<String>.from(product.imageUrls)
            : <String>[
                if ((product.imageUrl ?? '').trim().isNotEmpty)
                  product.imageUrl!.trim(),
              ];
        final List<String> nextImageUrls = currentImageUrls.isEmpty
            ? <String>[uploadedUrl]
            : <String>[uploadedUrl, ...currentImageUrls.skip(1)];
        updateData['image_url'] = uploadedUrl;
        updateData['image_urls'] = nextImageUrls;
      }

      if (updateData.isEmpty) {
        return product;
      }

      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _runProductWriteWithFallback(
        updateData,
        (payload) => _supabase
            .from('products')
            .update(payload)
            .eq('id', product.id)
            .eq('seller_id', currentUserId!),
      );

      return await getProductById(product.id) ?? product;
    } catch (e) {
      debugPrint('Update Product Quick Edit Error: $e');
      throw Exception('Hızlı düzenleme kaydedilemedi: $e');
    }
  }

  Future<void> updateProductPriceStockStatus({
    required String productId,
    required double price,
    required int stock,
    required String pricingType,
    double? portionPrice,
    double? pricePerKg,
    String? status,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      final Map<String, dynamic> updateData = <String, dynamic>{
        'price': price,
        'stock': stock,
        'pricing_type': pricingType,
        'portion_price': portionPrice,
        'price_per_kg': pricePerKg,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final String normalizedStatus = status?.trim() ?? '';
      if (normalizedStatus.isNotEmpty) {
        updateData['status'] = normalizedStatus;
      }

      await _runProductWriteWithFallback(
        updateData,
        (payload) => _supabase
            .from('products')
            .update(payload)
            .eq('id', productId)
            .eq('seller_id', currentUserId!),
      );
    } catch (e) {
      debugPrint('Update Product Price/Stock Error: $e');
      throw Exception('Fiyat ve stok güncellenirken hata: $e');
    }
  }

  Future<String> _uploadProductImage(String productId, XFile file, int index) {
    return _mediaService.uploadProductImage(productId, file, index);
  }

  Future<String> _uploadVariantImage(String productId, XFile file, int index) {
    return _mediaService.uploadVariantImage(productId, file, index);
  }

  Future<void> saveProductDraft(
    SellerProduct product, {
    List<dynamic>? variants,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final productDbData = await _prepareProductDbData(
      product,
      sellerId: currentUserId!,
    );
    productDbData['seller_id'] = currentUserId;
    // Taslakta image_url ile image_urls tutarlı olsun (tek alan dolu kalmayı önle).
    final List<String> mergedImageUrls = List<String>.from(product.imageUrls);
    final String draftPrimary = (product.imageUrl ?? '').trim();
    if (draftPrimary.isNotEmpty &&
        !mergedImageUrls.any((u) => u.trim() == draftPrimary)) {
      mergedImageUrls.insert(0, draftPrimary);
    }
    productDbData['image_urls'] = mergedImageUrls;
    productDbData['image_url'] = draftPrimary.isNotEmpty
        ? draftPrimary
        : (mergedImageUrls.isNotEmpty ? mergedImageUrls.first : null);
    productDbData['status'] = 'Taslak';
    productDbData['updated_at'] = DateTime.now().toIso8601String();
    if (product.accessories != null) {
      productDbData['accessories'] = product.accessories;
    }

    if (variants != null) {
      final updatedVariants = <dynamic>[];
      for (int i = 0; i < variants.length; i++) {
        final v = variants[i];
        if (v is Map) {
          updatedVariants.add(v);
          continue;
        }

        String? imageUrl;
        try {
          final existing = (v as dynamic).imageUrl;
          if (existing != null && existing.toString().trim().isNotEmpty) {
            imageUrl = existing.toString();
          }
        } catch (_) {}

        if (imageUrl == null) {
          try {
            final file = (v as dynamic).imageFile;
            if (file is XFile) {
              imageUrl = await _uploadVariantImage(product.id, file, i);
            }
          } catch (_) {}
        }

        updatedVariants.add({
          'color': (v as dynamic).color,
          'size': (v as dynamic).size,
          'ram': (v as dynamic).ram,
          'storage': (v as dynamic).storage,
          'sku': (v as dynamic).sku,
          'stock': (v as dynamic).stock,
          'priceDifference': (v as dynamic).priceDifference,
          'imageUrl': imageUrl,
        });
      }
      productDbData['variants'] = updatedVariants;
    }

    await _runProductWriteWithFallback(
      productDbData,
      (payload) => _supabase.from('products').upsert(payload),
    );
  }

  // --- Admin Product Approval Methods ---

  static const List<String> _pendingProductStatuses = [
    'pending_approval',
    'Düzenlendi',
    'Bekleniyor',
    'pending',
    'uploading',
  ];

  /// Onay bekleyen veya düzenleme onayı bekleyen ürünleri tek seferde getirir.
  Future<List<SellerProduct>> fetchPendingProducts() async {
    adminProductApprovalLog(
      'pending_query',
      extra: {'statuses': _pendingProductStatuses.join(',')},
    );
    final List<dynamic> response = await _supabase
        .from('products')
        .select()
        .inFilter('status', _pendingProductStatuses)
        .order('created_at', ascending: false);

    final maps = response.cast<Map<String, dynamic>>();
    final sellerIds = maps
        .map((m) => m['seller_id'] as String?)
        .where((id) => id != null && id.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final Map<String, String> storeNames = {};
    if (sellerIds.isNotEmpty) {
      try {
        final List<dynamic> stores = await _supabase
            .from('stores')
            .select('seller_id, business_name')
            .inFilter('seller_id', sellerIds);

        for (final store in stores) {
          final sellerId = store['seller_id']?.toString();
          if (sellerId == null || sellerId.isEmpty) continue;
          storeNames[sellerId] =
              (store['business_name']?.toString().trim().isNotEmpty ?? false)
              ? store['business_name'].toString()
              : 'Bilinmeyen Mağaza';
        }
      } catch (e) {
        debugPrint('Error fetching store names: $e');
      }
    }

    return maps.map((map) {
      final product = _mapSnakeCaseToProduct(map);
      final sellerId = map['seller_id'] as String?;

      if (sellerId != null && storeNames.containsKey(sellerId)) {
        return SellerProduct(
          id: product.id,
          name: product.name,
          brand: product.brand,
          mainCategory: product.mainCategory,
          subCategory: product.subCategory,
          price: product.price,
          discountPrice: product.discountPrice,
          stock: product.stock,
          sku: product.sku,
          status: product.status,
          imageUrl: product.imageUrl,
          imageUrls: product.imageUrls,
          description: product.description,
          createdAt: product.createdAt,
          attributes: product.attributes,
          storeName: storeNames[sellerId],
          videoUrl: product.videoUrl,
          variants: product.variants,
          additionalInfo: product.additionalInfo,
          faq: product.faq,
        );
      }

      return product;
    }).toList();
  }

  /// Eski çağrılar için stream uyumluluğu korunur.
  Stream<List<SellerProduct>> getPendingProducts() async* {
    yield await fetchPendingProducts();
  }

  Future<void> approveProduct(String productId) async {
    adminProductApprovalLog('approve_product', extra: {'productId': productId});
    await _supabase
        .from('products')
        .update({
          'status': 'Aktif',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  Future<void> rejectProduct(String productId, String reason) async {
    adminProductApprovalLog(
      'reject_product',
      extra: {'productId': productId, 'reason': reason},
    );
    await _supabase
        .from('products')
        .update({
          'status': 'rejected',
          'rejection_reason': reason,
          'rejected_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// DB'ye yazılacak ürün durumunu normalize eder.
  static String _canonicalPersistedProductStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'aktif':
      case 'active':
        return 'Aktif';
      case 'taslak':
      case 'draft':
        return 'Taslak';
      case 'pending_approval':
      case 'pending':
      case 'bekleniyor':
      case 'beklemede':
      case 'onay_bekliyor':
        return 'pending_approval';
      case 'rejected':
      case 'reddedildi':
        return 'rejected';
      default:
        return status.trim().isEmpty ? 'Taslak' : status.trim();
    }
  }

  // --- Helper Methods ---

  Future<T> _runProductWriteWithFallback<T>(
    Map<String, dynamic> data,
    Future<T> Function(Map<String, dynamic> payload) action,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt <= optionalProductColumns.length; attempt++) {
      try {
        return await action(data);
      } catch (error, stackTrace) {
        final message = error.toString();
        if (!isOptionalProductColumnError(message)) rethrow;

        final removedColumns = stripUnsupportedProductColumns(data, message);
        if (removedColumns.isEmpty) {
          lastError = error;
          lastStackTrace = stackTrace;
          break;
        }

        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace!);
    }

    throw StateError('Ürün yazma fallback akışı beklenmeyen şekilde sonlandı.');
  }

  Stream<List<SellerProduct>> getProducts() {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', currentUserId!)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => _mapSnakeCaseToProduct(map)).toList());
  }

  Future<List<Map<String, dynamic>>> getStoreTables({
    String? sellerId,
    bool onlyActive = true,
    String? areaId,
  }) {
    return _tableService.getStoreTables(
      sellerId: sellerId,
      onlyActive: onlyActive,
      areaId: areaId,
    );
  }

  Future<List<Map<String, dynamic>>> getTableAreas({
    String? sellerId,
    bool onlyActive = true,
  }) {
    return _tableService.getTableAreas(
      sellerId: sellerId,
      onlyActive: onlyActive,
    );
  }

  Future<Map<String, dynamic>> addTableArea({
    String? sellerId,
    required String name,
  }) {
    return _tableService.addTableArea(sellerId: sellerId, name: name);
  }

  Future<Map<String, dynamic>> ensureDefaultTableArea({
    String? sellerId,
    String defaultName = 'Salon',
  }) {
    return _tableService.ensureDefaultArea(
      sellerId: sellerId,
      defaultName: defaultName,
    );
  }

  Future<Map<String, dynamic>> addStoreTable({
    String? sellerId,
    int? tableNumber,
    bool preferMissingNumber = true,
    String? areaId,
    String? areaName,
    int? areaTableNumber,
    String? tableName,
  }) {
    return _tableService.addStoreTable(
      sellerId: sellerId,
      tableNumber: tableNumber,
      preferMissingNumber: preferMissingNumber,
      areaId: areaId,
      areaName: areaName,
      areaTableNumber: areaTableNumber,
      tableName: tableName,
    );
  }

  Future<void> removeStoreTableById(String tableId) {
    return _tableService.removeStoreTableById(tableId);
  }

  Future<void> updateStoreTableArea({
    required String tableId,
    required String areaId,
    required String areaName,
  }) {
    return _tableService.updateStoreTableArea(
      tableId: tableId,
      areaId: areaId,
      areaName: areaName,
    );
  }

  Future<Map<String, dynamic>?> removeLastStoreTable({String? sellerId}) {
    return _tableService.removeLastStoreTable(sellerId: sellerId);
  }

  Future<List<int>> getActiveTableNumbers(String sellerId) {
    return _tableService.getActiveTableNumbers(sellerId);
  }

  Future<Set<int>> getOccupiedTableNumbers(String sellerId) {
    return _tableService.getOccupiedTableNumbers(sellerId);
  }

  Future<Map<String, dynamic>?> resolveStoreTableQr({
    required String sellerId,
    required int tableNumber,
    required String qrToken,
  }) {
    return _tableService.resolveStoreTableQr(
      sellerId: sellerId,
      tableNumber: tableNumber,
      qrToken: qrToken,
    );
  }

  Future<Map<String, dynamic>> submitTableOrder({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String status = 'new',
    Map<String, dynamic>? tableRow,
    String? placementSource,
  }) {
    return _tableService.submitTableOrder(
      sellerId: sellerId,
      tableNumber: tableNumber,
      items: items,
      status: status,
      tableRow: tableRow,
      placementSource: placementSource,
    );
  }

  Stream<List<Map<String, dynamic>>> getTableOrdersStream(String sellerId) {
    return _tableService.getTableOrdersStream(sellerId);
  }

  Future<List<Map<String, dynamic>>> getTableOrdersSnapshot(
    String sellerId, {
    int? tableNumber,
  }) {
    return _tableService.getTableOrdersSnapshot(
      sellerId,
      tableNumber: tableNumber,
    );
  }

  Future<List<Map<String, dynamic>>> getTableOrdersByTable({
    required String sellerId,
    required int tableNumber,
  }) {
    return _tableService.getTableOrdersByTable(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
  }

  Future<Map<String, dynamic>?> updateTableOrder(
    String orderId, {
    String? status,
    List<Map<String, dynamic>>? items,
    int? revision,
    Map<String, dynamic>? lastEditSummary,
    String? lastEditNote,
  }) {
    return _tableService.updateTableOrder(
      orderId,
      status: status,
      items: items,
      revision: revision,
      lastEditSummary: lastEditSummary,
      lastEditNote: lastEditNote,
    );
  }

  Future<Map<String, dynamic>?> updateTableOrderStatus(
    String orderId,
    String status,
  ) {
    return _tableService.updateTableOrderStatus(orderId, status);
  }

  Future<void> deleteTableOrder(String orderId) {
    return _tableService.deleteTableOrder(orderId);
  }

  Future<void> closeTableOrders({
    required String sellerId,
    required int tableNumber,
  }) {
    return _tableService.closeTableOrders(
      sellerId: sellerId,
      tableNumber: tableNumber,
    );
  }

  Future<void> closeTableWithHistory({
    required String sellerId,
    required int tableNumber,
    required String paymentMethod,
    String? paymentNote,
    String? waiterId,
    String? waiterName,
    String? sessionKey,
  }) {
    return _tableService.closeTableWithHistory(
      sellerId: sellerId,
      tableNumber: tableNumber,
      paymentMethod: paymentMethod,
      paymentNote: paymentNote,
      waiterId: waiterId,
      waiterName: waiterName,
      sessionKey: sessionKey,
    );
  }

  Future<Map<String, dynamic>> recordTablePayment({
    required String sellerId,
    required int tableNumber,
    required double amount,
    required String method,
    String? waiterId,
    String? waiterName,
    String? sessionKey,
    String? note,
  }) {
    return _tableService.recordTablePayment(
      sellerId: sellerId,
      tableNumber: tableNumber,
      amount: amount,
      method: method,
      waiterId: waiterId,
      waiterName: waiterName,
      sessionKey: sessionKey ?? 'default',
      note: note,
    );
  }

  Future<List<Map<String, dynamic>>> getTablePayments({
    required String sellerId,
    required int tableNumber,
    String? sessionKey,
  }) {
    return _tableService.getTablePayments(
      sellerId: sellerId,
      tableNumber: tableNumber,
      sessionKey: sessionKey,
    );
  }

  Future<Map<String, dynamic>> transferTableOrders({
    required String sellerId,
    required int fromTable,
    required int toTable,
    String transferType = 'full',
    List<String> itemIds = const [],
    String? waiterId,
    String? note,
  }) {
    return _tableService.transferTableOrders(
      sellerId: sellerId,
      fromTable: fromTable,
      toTable: toTable,
      transferType: transferType,
      itemIds: itemIds,
      waiterId: waiterId,
      note: note,
    );
  }

  Future<List<Map<String, dynamic>>> getTableOrderHistory({
    required String sellerId,
    int? tableNumber,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) {
    return _tableService.getTableOrderHistory(
      sellerId: sellerId,
      tableNumber: tableNumber,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getWaiterPerformance({
    required String sellerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _tableService.getWaiterPerformance(
      sellerId: sellerId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<List<Map<String, dynamic>>> getProductRecommendations({
    required String sellerId,
    required List<String> currentProductIds,
    int limit = 5,
  }) {
    return _tableService.getProductRecommendations(
      sellerId: sellerId,
      currentProductIds: currentProductIds,
      limit: limit,
    );
  }

  // Get Seller Products
  Stream<List<SellerProduct>> getSellerProducts() {
    if (currentUserId == null) return Stream.value([]);

    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', currentUserId!)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => _mapSnakeCaseToProduct(map)).toList());
  }

  Future<List<SellerProduct>> getSellerProductsSnapshot() async {
    if (currentUserId == null) return const <SellerProduct>[];
    final rows = await _supabase
        .from('products')
        .select()
        .eq('seller_id', currentUserId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows as List<dynamic>,
    ).map(_mapSnakeCaseToProduct).toList(growable: false);
  }

  Future<void> deleteProduct(String productId) async {
    await _supabase.from('products').delete().eq('id', productId);
  }

  /// Tek ürünü ID ile getirir (sadece kendi ürünü).
  Future<SellerProduct?> getProductById(String productId) async {
    if (currentUserId == null) return null;
    final res = await _supabase
        .from('products')
        .select()
        .eq('id', productId)
        .eq('seller_id', currentUserId!)
        .maybeSingle();
    if (res == null) return null;
    return _mapSnakeCaseToProduct(res);
  }

  Future<void> updateProductFaq({
    required String productId,
    required List<Map<String, String>> faq,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      await _supabase
          .from('products')
          .update({'faq': faq, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', productId)
          .eq('seller_id', currentUserId!);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('column') && msg.contains('faq')) {
        throw Exception(
          "Veritabanında 'products.faq' kolonu yok. Supabase SQL migration gerekli.",
        );
      }
      throw Exception('SSS kaydedilemedi: $e');
    }
  }

  Future<void> updateProductOld(
    SellerProduct product, {
    List<XFile>? newImages,
    required String previousStatus,
    Function(String)? onProgress,
  }) async {
    // Deprecated method, kept to satisfy linter or legacy calls until fully refactored
    // Redirect to new method
    await updateProduct(
      product,
      newImages: newImages,
      onProgress: onProgress,
      previousStatus: previousStatus,
    );
  }

  // --- Sub Admin Methods ---
  // Assuming a 'store_sub_admins' table exists

  Stream<List<SubAdmin>> getSubAdmins() {
    if (currentUserId == null) return Stream.value([]);
    // Using simple select as Realtime might not be enabled for this table yet
    // Or we can use stream if we enable RLS + Realtime
    return _supabase
        .from('store_sub_admins')
        .stream(primaryKey: ['id'])
        .eq('store_id', currentUserId!)
        .order('created_at', ascending: false)
        .map(
          (maps) => maps
              .map((map) => SubAdmin.fromMap(map, map['id'].toString()))
              .toList(),
        );
  }

  Future<List<SubAdmin>> getSubAdminsSnapshot() async {
    if (currentUserId == null) return const <SubAdmin>[];
    final rows = await _supabase
        .from('store_sub_admins')
        .select()
        .eq('store_id', currentUserId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List<dynamic>)
        .map((map) => SubAdmin.fromMap(map, map['id'].toString()))
        .toList(growable: false);
  }

  Future<void> inviteSubAdmin({
    String? email,
    String? phone,
    required List<SellerPermission> permissions,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      throw Exception('E‑posta veya telefon gereklidir');
    }

    await _supabase.from('store_sub_admins').insert({
      'store_id': currentUserId,
      'email': email,
      'phone': phone,
      'permissions': permissions.map((e) => e.name).toList(),
      'status': 'invited',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSubAdminPermissions(
    String subAdminId,
    List<SellerPermission> permissions,
  ) async {
    await _supabase
        .from('store_sub_admins')
        .update({'permissions': permissions.map((e) => e.name).toList()})
        .eq('id', subAdminId);
  }

  Future<void> removeSubAdmin(String subAdminId) async {
    await _supabase.from('store_sub_admins').delete().eq('id', subAdminId);
  }

  Future<List<Map<String, dynamic>>> getAllStores() async {
    try {
      final list = await _supabase
          .from('stores')
          .select(
            'seller_id, business_name, category, city, phone, email, logo_url, created_at, is_store_open',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(list as List);
    } catch (e) {
      debugPrint('getAllStores error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchStoresByNameOrCategory(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }
    try {
      final list = await _supabase
          .from('stores')
          .select('seller_id, business_name, category, city, logo_url, banners')
          .or('business_name.ilike.%$trimmed%,category.ilike.%$trimmed%')
          .order('business_name')
          .limit(20);
      return List<Map<String, dynamic>>.from(list as List)
          .map((row) {
            final mapped = Map<String, dynamic>.from(row);
            final banners = row['banners'];
            if (banners is List) {
              final firstBanner = banners
                  .where(
                    (item) => item != null && item.toString().trim().isNotEmpty,
                  )
                  .cast<dynamic>()
                  .map((item) => item.toString())
                  .firstWhere((_) => true, orElse: () => '');
              if (firstBanner.isNotEmpty) {
                mapped['banner_url'] = firstBanner;
              }
            }
            return mapped;
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('searchStoresByNameOrCategory error: $e');
      return [];
    }
  }

  Future<void> deleteStoreAndProducts(String sellerId) async {
    await _supabase.from('products').delete().eq('seller_id', sellerId);
    await _supabase.from('stores').delete().eq('seller_id', sellerId);
  }

  /// Lightweight fetch for the restaurant menu dialog — only columns the
  /// dialog actually uses. Avoids pulling video/thumbnail/variant payload.
  Future<List<Map<String, dynamic>>> getMenuProductsBySellerId(
    String sellerId,
  ) async {
    const richMenuSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, '
        'price, pricing_type, portion_price, price_per_kg, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, '
        'attributes, description, specifications, additional_info, accessories, '
        'short_description, ingredients, features, preparation_time, cooking_time, '
        'station_id, printer_routing_enabled';
    const detailMenuSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, '
        'price, pricing_type, portion_price, price_per_kg, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, '
        'attributes, description, specifications, additional_info, accessories, '
        'station_id, printer_routing_enabled';
    const noSpecificationsSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, '
        'price, pricing_type, portion_price, price_per_kg, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, '
        'attributes, description, additional_info, accessories, '
        'station_id, printer_routing_enabled';
    const menuSelect =
        'id, seller_id, name, image_url, image_urls, sub_category, price, pricing_type, portion_price, price_per_kg, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, attributes, station_id, printer_routing_enabled';

    Future<List<Map<String, dynamic>>> runSelect(String select) async {
      final list = await _supabase
          .from('products')
          .select(select)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(list as List);
    }

    try {
      return await runSelect(richMenuSelect);
    } catch (e) {
      final message = e.toString();
      if (message.contains('short_description') ||
          message.contains('ingredients') ||
          message.contains('features') ||
          message.contains('preparation_time') ||
          message.contains('cooking_time')) {
        try {
          return await runSelect(detailMenuSelect);
        } catch (fallbackError) {
          final fallbackMessage = fallbackError.toString();
          if (fallbackMessage.contains('specifications')) {
            try {
              return await runSelect(noSpecificationsSelect);
            } catch (finalError) {
              debugPrint('getMenuProductsBySellerId error: $finalError');
              return [];
            }
          }
          if (fallbackMessage.contains('pricing_type') ||
              fallbackMessage.contains('portion_price') ||
              fallbackMessage.contains('price_per_kg') ||
              fallbackMessage.contains('service_control_type') ||
              fallbackMessage.contains('min_portion') ||
              fallbackMessage.contains('max_portion') ||
              fallbackMessage.contains('portion_step') ||
              fallbackMessage.contains('default_weight_grams') ||
              fallbackMessage.contains('min_weight_grams') ||
              fallbackMessage.contains('weight_step_grams') ||
              fallbackMessage.contains('max_weight_grams') ||
              fallbackMessage.contains('additional_info') ||
              fallbackMessage.contains('accessories')) {
            try {
              return await runSelect(menuSelect);
            } catch (finalError) {
              debugPrint('getMenuProductsBySellerId error: $finalError');
              return [];
            }
          }
          debugPrint('getMenuProductsBySellerId error: $fallbackError');
          return [];
        }
      }
      if (message.contains('specifications')) {
        try {
          return await runSelect(noSpecificationsSelect);
        } catch (fallbackError) {
          final fallbackMessage = fallbackError.toString();
          if (fallbackMessage.contains('pricing_type') ||
              fallbackMessage.contains('portion_price') ||
              fallbackMessage.contains('price_per_kg') ||
              fallbackMessage.contains('service_control_type') ||
              fallbackMessage.contains('min_portion') ||
              fallbackMessage.contains('max_portion') ||
              fallbackMessage.contains('portion_step') ||
              fallbackMessage.contains('default_weight_grams') ||
              fallbackMessage.contains('min_weight_grams') ||
              fallbackMessage.contains('weight_step_grams') ||
              fallbackMessage.contains('max_weight_grams') ||
              fallbackMessage.contains('additional_info') ||
              fallbackMessage.contains('accessories')) {
            try {
              return await runSelect(menuSelect);
            } catch (finalError) {
              debugPrint('getMenuProductsBySellerId error: $finalError');
              return [];
            }
          }
          debugPrint('getMenuProductsBySellerId error: $fallbackError');
          return [];
        }
      }
      if (message.contains('pricing_type') ||
          message.contains('portion_price') ||
          message.contains('price_per_kg') ||
          message.contains('service_control_type') ||
          message.contains('min_portion') ||
          message.contains('max_portion') ||
          message.contains('portion_step') ||
          message.contains('default_weight_grams') ||
          message.contains('min_weight_grams') ||
          message.contains('weight_step_grams') ||
          message.contains('max_weight_grams') ||
          message.contains('additional_info') ||
          message.contains('accessories')) {
        try {
          return await runSelect(menuSelect);
        } catch (fallbackError) {
          debugPrint('getMenuProductsBySellerId error: $fallbackError');
          return [];
        }
      }
      debugPrint('getMenuProductsBySellerId error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProductsBySellerId(
    String sellerId,
  ) async {
    const fullSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, price, specifications, product_type, pricing_type, pricing_mode, base_price, portion_price, price_per_kg, size_options, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, created_at, attributes, video_url, video_path, video_public_url, thumbnail_path, thumbnail_public_url, video_duration_seconds, video_size_bytes, thumbnail_size_bytes, video_status, variants, accessories, station_id, printer_routing_enabled';
    const fullSelectWithStation = '$fullSelect, stations(name, code)';
    const fallbackSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, price, specifications, product_type, pricing_type, pricing_mode, base_price, portion_price, price_per_kg, size_options, service_control_type, min_portion, max_portion, portion_step, default_weight_grams, min_weight_grams, weight_step_grams, max_weight_grams, stock, status, created_at, attributes, video_url, station_id, printer_routing_enabled';
    const fallbackSelectWithStation = '$fallbackSelect, stations(name, code)';

    Future<List<Map<String, dynamic>>> runSelect(String select) async {
      final list = await _supabase
          .from('products')
          .select(select)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(list as List);
    }

    try {
      return await runSelect(fullSelectWithStation);
    } catch (e) {
      final message = e.toString();
      if (message.contains('stations')) {
        try {
          return await runSelect(fullSelect);
        } catch (inner) {
          debugPrint('getProductsBySellerId stations join fallback: $inner');
        }
      }
      if (message.contains('video_path') ||
          message.contains('video_public_url') ||
          message.contains('thumbnail_path') ||
          message.contains('thumbnail_public_url') ||
          message.contains('video_duration_seconds') ||
          message.contains('video_size_bytes') ||
          message.contains('thumbnail_size_bytes') ||
          message.contains('video_status') ||
          message.contains('variants') ||
          message.contains('accessories')) {
        try {
          return await runSelect(fallbackSelectWithStation);
        } catch (fallbackError) {
          final fallbackMessage = fallbackError.toString();
          if (fallbackMessage.contains('stations')) {
            try {
              return await runSelect(fallbackSelect);
            } catch (finalError) {
              debugPrint('getProductsBySellerId fallback error: $finalError');
              return [];
            }
          }
          debugPrint('getProductsBySellerId fallback error: $fallbackError');
          return [];
        }
      }
      debugPrint('getProductsBySellerId error: $e');
      return [];
    }
  }

  Future<void> deleteProductById(String productId) async {
    await _supabase.from('products').delete().eq('id', productId);
  }

  Future<void> reportProductViolation(String productId, String reason) async {
    await _supabase
        .from('products')
        .update({
          'status': 'ihlal',
          'rejection_reason': reason,
          'rejected_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  // --- Table Order Methods (Garson) ---

  Future<String?> getSellerIdByBusinessName(String businessName) async {
    try {
      final res = await _supabase
          .from('stores')
          .select('seller_id')
          .ilike('business_name', businessName)
          .limit(1)
          .maybeSingle();
      return res?['seller_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessSummaryBySellerId(
    String sellerId,
  ) async {
    final normalizedSellerId = sellerId.trim();
    if (normalizedSellerId.isEmpty) return null;
    try {
      final row = await _supabase
          .from('stores')
          .select('seller_id, business_name, category, logo_url, rating')
          .eq('seller_id', normalizedSellerId)
          .maybeSingle();
      if (row == null) return null;
      return {
        'seller_id': row['seller_id']?.toString() ?? normalizedSellerId,
        'name': row['business_name']?.toString() ?? 'Restoran',
        'category': row['category']?.toString() ?? 'restoran',
        'logo': row['logo_url']?.toString(),
        'rating': row['rating'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessSummaryByBusinessName(
    String businessName,
  ) async {
    final normalizedName = businessName.trim();
    if (normalizedName.isEmpty) return null;
    try {
      final row = await _supabase
          .from('stores')
          .select('seller_id, business_name, category, logo_url, rating')
          .ilike('business_name', normalizedName)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return {
        'seller_id': row['seller_id']?.toString() ?? '',
        'name': row['business_name']?.toString() ?? 'Restoran',
        'category': row['category']?.toString() ?? 'restoran',
        'logo': row['logo_url']?.toString(),
        'rating': row['rating'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> requestStoreDeletion({String? reason}) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      await _supabase.from('store_deletion_requests').upsert({
        'seller_id': currentUserId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      if (error is PostgrestException &&
          (error.code == 'PGRST205' ||
              error.message.contains('store_deletion_requests'))) {
        throw Exception(
          "Magaza kapatma sistemi Supabase'te hazir degil. 'store_deletion_requests' tablosunu olusturmaniz gerekiyor.",
        );
      }
      rethrow;
    }

    try {
      await _supabase
          .from('stores')
          .update({
            'is_deletion_requested': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('seller_id', currentUserId!);
    } catch (error) {
      if (error is PostgrestException &&
          (error.message.contains('is_deletion_requested') ||
              '${error.details ?? ''}'.contains('is_deletion_requested'))) {
        throw Exception(
          "Magaza tablosunda 'is_deletion_requested' kolonu eksik. Once Supabase SQL guncellemesini calistirin.",
        );
      }
      rethrow;
    }
  }

  Future<String> _currentStoreBusinessName() async {
    final userId = currentUserId;
    if (userId == null) return 'Mağaza';

    if (_cachedBusinessName != null && _cachedBusinessName!.isNotEmpty) {
      return _cachedBusinessName!;
    }

    try {
      final row = await _supabase
          .from('stores')
          .select('business_name')
          .eq('seller_id', userId)
          .maybeSingle();
      final name = row?['business_name']?.toString().trim() ?? '';
      if (name.isNotEmpty) _cachedBusinessName = name;
      return name.isNotEmpty ? name : 'Mağaza';
    } catch (_) {
      return 'Mağaza';
    }
  }

  Future<void> _notifyFollowersNewProduct({
    required String productId,
    required String productName,
  }) async {
    final storeId = currentUserId;
    if (storeId == null) return;
    final storeName = await _currentStoreBusinessName();
    await StoreNotificationTriggerService.instance.notifyNewProduct(
      storeId: storeId,
      storeName: storeName,
      productName: productName,
      productId: productId,
    );
  }

  Future<void> _notifyFollowersProductDiscount({
    required String productId,
    required String productName,
  }) async {
    final storeId = currentUserId;
    if (storeId == null) return;
    final storeName = await _currentStoreBusinessName();
    await StoreNotificationTriggerService.instance.notifyProductDiscount(
      storeId: storeId,
      storeName: storeName,
      productName: productName,
      productId: productId,
    );
  }

  Future<void> _notifyFollowersStoreAnnouncement() async {
    final storeId = currentUserId;
    if (storeId == null) return;
    final storeName = await _currentStoreBusinessName();
    await StoreNotificationTriggerService.instance.notifyStoreAnnouncement(
      storeId: storeId,
      storeName: storeName,
    );
  }

  Future<Map<String, dynamic>?> getPendingLocationChangeRequest() async {
    if (currentUserId == null) return null;
    try {
      final data = await _supabase
          .from('store_location_change_requests')
          .select()
          .eq('seller_id', currentUserId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data == null ? null : Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> submitStoreLocationChangeRequest({
    required double requestedLat,
    required double requestedLng,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final store = await _supabase
        .from('stores')
        .select('business_name, address, city, district, store_lat, store_lng')
        .eq('seller_id', currentUserId!)
        .maybeSingle();

    if (store == null) {
      throw Exception('Mağaza profili bulunamadı');
    }

    await _supabase
        .from('store_location_change_requests')
        .delete()
        .eq('seller_id', currentUserId!)
        .eq('status', 'pending');

    await _supabase.from('store_location_change_requests').insert({
      'seller_id': currentUserId,
      'business_name': store['business_name'],
      'address': store['address'],
      'city': store['city'],
      'district': store['district'],
      'current_lat': store['store_lat'],
      'current_lng': store['store_lng'],
      'requested_lat': requestedLat,
      'requested_lng': requestedLng,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  SellerProduct _mapSnakeCaseToProduct(Map<String, dynamic> data) {
    return mapSnakeCaseToProduct(data);
  }
}
