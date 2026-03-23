import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seller_product.dart';
import '../models/sub_admin.dart';
import 'store/store_media_service.dart';
import 'store/store_mapping_helpers.dart';
import 'store/store_table_service.dart';
import 'store/store_upload_progress_details.dart';
import 'store_service_mappers.dart';

class StoreService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, ({DateTime expiresAt, Map<String, dynamic> data})>
  _storePublicInfoCache = {};
  static const Duration _storePublicInfoTtl = Duration(minutes: 10);
  static const Duration _tableOrderTimeout = Duration(seconds: 10);

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
    if (currentUserId == null) return null;

    try {
      final data = await _supabase
          .from('stores')
          .select()
          .eq('seller_id', currentUserId!)
          .maybeSingle();

      if (data == null) return null;

      // Map snake_case to camelCase for UI consumption
      return StoreServiceMappers.storeToCamelCase(data);
    } catch (e) {
      debugPrint('Error getting store profile: $e');
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
      // 1. Ürünü Veritabanına Ekle (Resimsiz Başlangıç)
      Map<String, dynamic> productDbData =
          StoreServiceMappers.productToSnakeCase(product.toMap());
      productDbData['seller_id'] = currentUserId;
      productDbData['status'] = 'uploading';
      productDbData['image_urls'] = [];
      productDbData['image_url'] = null;
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

      dynamic response;
      try {
        response = await _supabase
            .from('products')
            .upsert(productDbData)
            .select()
            .single();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('additional_info') ||
            msg.contains('faq') ||
            msg.contains('accessories') ||
            msg.contains('video_path') ||
            msg.contains('video_public_url') ||
            msg.contains('thumbnail_path') ||
            msg.contains('thumbnail_public_url') ||
            msg.contains('video_duration_seconds') ||
            msg.contains('video_size_bytes') ||
            msg.contains('thumbnail_size_bytes') ||
            msg.contains('video_status')) {
          _stripOptionalProductColumns(productDbData);
          response = await _supabase
              .from('products')
              .upsert(productDbData)
              .select()
              .single();
        } else {
          rethrow;
        }
      }
      final productId = response['id'].toString();

      // 2. Görselleri Yükle
      List<String> uploadedUrls = [];

      if (images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final file = images[i];
          if (onProgress != null)
            onProgress('Görsel ${i + 1}/${images.length} yükleniyor...');

          final url = await _uploadProductImage(productId, file, i);
          uploadedUrls.add(url);
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
                if (onProgress != null)
                  onProgress(
                    'Varyant görseli ${i + 1}/${variants.length} yükleniyor...',
                  );
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
      await _supabase
          .from('products')
          .update({
            'image_urls': uploadedUrls,
            'image_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
            if (updatedVariants != null) 'variants': updatedVariants,
            'status': (product.status == 'Aktif')
                ? 'pending_approval'
                : product.status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);
    } catch (e) {
      debugPrint('Add Product Error: $e');
      throw Exception('Ürün eklenirken hata oluştu: $e');
    }
  }

  Future<void> updateProduct(
    SellerProduct product, {
    List<XFile>? newImages,
    Function(String)? onProgress,
    String? previousStatus,
    List<dynamic>? variants,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    try {
      // Mevcut resimleri koru
      List<String> finalImageUrls = List.from(product.imageUrls);

      // Yeni resimler varsa yükle ve listeye ekle
      if (newImages != null && newImages.isNotEmpty) {
        for (int i = 0; i < newImages.length; i++) {
          final file = newImages[i];
          if (onProgress != null)
            onProgress(
              'Yeni görsel ${i + 1}/${newImages.length} yükleniyor...',
            );

          final url = await _uploadProductImage(
            product.id,
            file,
            finalImageUrls.length + i,
          );
          finalImageUrls.add(url);
        }
      }

      Map<String, dynamic> updateData = StoreServiceMappers.productToSnakeCase(
        product.toMap(),
      );
      updateData['image_urls'] = finalImageUrls;
      updateData['image_url'] = finalImageUrls.isNotEmpty
          ? finalImageUrls.first
          : null;
      updateData['updated_at'] = DateTime.now().toIso8601String();
      if (product.accessories != null) {
        updateData['accessories'] = product.accessories;
      }

      if (product.status == 'Aktif') {
        updateData['status'] = 'pending_approval';
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
                if (onProgress != null)
                  onProgress(
                    'Varyant görseli ${i + 1}/${variants.length} yükleniyor...',
                  );
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

      try {
        await _supabase
            .from('products')
            .update(updateData)
            .eq('id', product.id);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('additional_info') ||
            msg.contains('faq') ||
            msg.contains('accessories') ||
            msg.contains('video_path') ||
            msg.contains('video_public_url') ||
            msg.contains('thumbnail_path') ||
            msg.contains('thumbnail_public_url') ||
            msg.contains('video_duration_seconds') ||
            msg.contains('video_size_bytes') ||
            msg.contains('thumbnail_size_bytes') ||
            msg.contains('video_status')) {
          _stripOptionalProductColumns(updateData);
          await _supabase
              .from('products')
              .update(updateData)
              .eq('id', product.id);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Update Product Error: $e');
      throw Exception('Ürün güncellenirken hata: $e');
    }
  }

  Future<String> _uploadProductImage(
    String productId,
    XFile file,
    int index,
  ) {
    return _mediaService.uploadProductImage(productId, file, index);
  }

  Future<String> _uploadVariantImage(
    String productId,
    XFile file,
    int index,
  ) {
    return _mediaService.uploadVariantImage(productId, file, index);
  }

  Future<void> saveProductDraft(
    SellerProduct product, {
    List<dynamic>? variants,
  }) async {
    if (currentUserId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final productDbData = StoreServiceMappers.productToSnakeCase(
      product.toMap(),
    );
    productDbData['seller_id'] = currentUserId;
    // Taslakta image_url ve image_urls zaten product içinde varsa kullanılır
    // Eğer product.imageUrls boşsa boş array, değilse mevcutları kullan
    productDbData['image_urls'] = product.imageUrls;
    productDbData['image_url'] = product.imageUrl;
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

    try {
      await _supabase.from('products').upsert(productDbData);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('additional_info') ||
          msg.contains('faq') ||
          msg.contains('accessories') ||
          msg.contains('video_path') ||
          msg.contains('video_public_url') ||
          msg.contains('thumbnail_path') ||
          msg.contains('thumbnail_public_url') ||
          msg.contains('video_duration_seconds') ||
          msg.contains('video_size_bytes') ||
          msg.contains('thumbnail_size_bytes') ||
          msg.contains('video_status')) {
        _stripOptionalProductColumns(productDbData);
        await _supabase.from('products').upsert(productDbData);
      } else {
        rethrow;
      }
    }
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
    await _supabase
        .from('products')
        .update({
          'status': 'Aktif',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  Future<void> rejectProduct(String productId, String reason) async {
    await _supabase
        .from('products')
        .update({
          'status': 'rejected',
          'rejection_reason': reason,
          'rejected_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productId);
  }

  // --- Helper Methods ---

  void _stripOptionalProductColumns(Map<String, dynamic> data) {
    stripOptionalProductColumns(data);
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
  }) {
    return _tableService.getStoreTables(
      sellerId: sellerId,
      onlyActive: onlyActive,
    );
  }

  Future<Map<String, dynamic>> addStoreTable({
    String? sellerId,
    int? tableNumber,
    bool preferMissingNumber = true,
  }) {
    return _tableService.addStoreTable(
      sellerId: sellerId,
      tableNumber: tableNumber,
      preferMissingNumber: preferMissingNumber,
    );
  }

  Future<void> removeStoreTableById(String tableId) {
    return _tableService.removeStoreTableById(tableId);
  }

  Future<Map<String, dynamic>?> removeLastStoreTable({String? sellerId}) {
    return _tableService.removeLastStoreTable(sellerId: sellerId);
  }

  Future<List<int>> getActiveTableNumbers(String sellerId) {
    return _tableService.getActiveTableNumbers(sellerId);
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
  }) {
    return _tableService.submitTableOrder(
      sellerId: sellerId,
      tableNumber: tableNumber,
      items: items,
      status: status,
    );
  }

  Stream<List<Map<String, dynamic>>> getTableOrdersStream(String sellerId) {
    return _tableService.getTableOrdersStream(sellerId);
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

  Future<void> updateTableOrder(
    String orderId, {
    String? status,
    List<Map<String, dynamic>>? items,
  }) {
    return _tableService.updateTableOrder(
      orderId,
      status: status,
      items: items,
    );
  }

  Future<void> updateTableOrderStatus(String orderId, String status) {
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

  Future<List<Map<String, dynamic>>> getProductsBySellerId(
    String sellerId,
  ) async {
    const fullSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, price, stock, status, created_at, attributes, video_url, video_path, video_public_url, thumbnail_path, thumbnail_public_url, video_duration_seconds, video_size_bytes, thumbnail_size_bytes, video_status, variants, accessories, station_id, printer_routing_enabled';
    const fallbackSelect =
        'id, seller_id, name, brand, image_url, image_urls, main_category, sub_category, price, stock, status, created_at, attributes, video_url, station_id, printer_routing_enabled';

    try {
      final list = await _supabase
          .from('products')
          .select(fullSelect)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(list as List);
    } catch (e) {
      final message = e.toString();
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
          final list = await _supabase
              .from('products')
              .select(fallbackSelect)
              .eq('seller_id', sellerId)
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(list as List);
        } catch (fallbackError) {
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
