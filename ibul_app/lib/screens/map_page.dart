import 'dart:convert';
import 'dart:ui'; // ScrollBehavior için gerekli
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import '../data/business_data.dart';
import '../widgets/map_filter_bottom_sheet.dart';
import 'business_detail_page.dart';

class MapPage extends StatefulWidget {
  final Product? product;
  final String? targetStoreName;
  final Map<String, dynamic>? targetBusiness;
  
  const MapPage({super.key, this.product, this.targetStoreName, this.targetBusiness});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();
  int _selectedBusinessIndex = -1;
  static const LatLng _initialPosition = LatLng(36.2025, 36.1605); // Hatay/Antakya
  List<DBProduct> _allProducts = [];
  bool _isLoading = true;
  List<int> _filteredBusinessIndices = [];
  String _searchQuery = '';
  // Make _businesses mutable and initialized in initState
  List<Map<String, dynamic>> _businesses = [];
  
  // Animation controller for smooth map movement
  late AnimationController _moveAnimationController;
  
  // Filter state - NOT final so they can be updated
  double _filterDistance = 10.0;
  List<String> _filterCategories = [];
  bool _filterOpenNow = false;

  String _normalize(String s) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }
  
  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _moveAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));

    // Initialize businesses from constant data
    _businesses = List.from(businessData);
    
    // If target business is provided and not in list, add it
    if (widget.targetBusiness != null) {
      final exists = _businesses.any((b) => 
        _normalize(b['name'].toString()) == _normalize(widget.targetBusiness!['name'].toString())
      );
      if (!exists) {
        _businesses.add(widget.targetBusiness!);
      }
    }
    
    _filteredBusinessIndices = List.generate(_businesses.length, (index) => index);
    _initializeMap();
  }
  
  @override
  void dispose() {
    _moveAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    // Önce ürünleri yükle
    await _loadProducts();
    
    // Eğer hedef mağaza (nesne olarak) varsa, onu bul ve göster
    if (widget.targetBusiness != null) {
      final index = _businesses.indexWhere((b) => 
        _normalize(b['name'].toString()) == _normalize(widget.targetBusiness!['name'].toString())
      );
      
      if (index != -1) {
        _onBusinessSelected(index);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showBusinessDetail(_businesses[index]);
          }
        });
        return;
      }
    }

    // Eğer hedef mağaza ismi varsa, onu bul ve göster
    if (widget.targetStoreName != null) {
      final index = _businesses.indexWhere((b) => 
        _normalize(b['name'].toString()) == _normalize(widget.targetStoreName!)
      );
      
      if (index != -1) {
        _onBusinessSelected(index);
        // Harita hareketinden sonra detayları göster
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showBusinessDetail(_businesses[index]);
          }
        });
        return;
      }
    }
    
    // Eğer ürün parametresi varsa, otomatik arama yap
    if (widget.product != null) {
      _searchController.text = widget.product!.name;
      _performSearch(widget.product!.name);
    }
  }
  
  // _businesses is now an instance variable, initialized in initState


  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _allProducts = await _dbHelper.getAllProducts();
    } catch (e) {
      print('Ürünler yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Product _convertToProduct(DBProduct dbProduct) {
    // Görselleri parse et
    List<String> images = [];
    
    // imageUrls JSON array ise decode et
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // JSON decode başarısız olursa imageUrl kullan
        if (dbProduct.imageUrl.isNotEmpty) {
          images.add(dbProduct.imageUrl);
        }
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }
    
    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }

    return Product(
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
    );
  }
  
  List<Product> _getStoreProducts(String storeName) {
    final storeProducts = _allProducts.where((product) {
      if (product.store == null) return false;
      return _normalize(product.store!) == _normalize(storeName);
    }).toList();
    
    return storeProducts.map((dbProduct) => _convertToProduct(dbProduct)).toList();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some latlng tween
    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom,
        end: destZoom);

    // Reset controller
    _moveAnimationController.reset();
    
    // Start animation
    _moveAnimationController.forward();

    // Listen to animation
    void listener() {
      final lat = latTween.evaluate(_moveAnimationController);
      final lng = lngTween.evaluate(_moveAnimationController);
      final zoom = zoomTween.evaluate(_moveAnimationController);
      
      _mapController.move(LatLng(lat, lng), zoom);
    }

    _moveAnimationController.addListener(listener);

    // Cleanup listener when animation is done or canceled
    _moveAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _moveAnimationController.removeListener(listener);
      }
    });
  }

  void _onBusinessSelected(int index) {
    setState(() {
      _selectedBusinessIndex = index;
    });
    final business = _businesses[index];
    final location = business['location'] as LatLng;
    _animatedMapMove(location, 17.5);
  }

  void _applyMapFilters(Map<String, dynamic> filters) {
    setState(() {
      _filterDistance = filters['distance'];
      _filterCategories = filters['categories'];
      _filterOpenNow = filters['openNow'];
      
      // Re-filter businesses based on new criteria
      // Note: Distance filtering is simulated here since we don't have real user location calculation
      // In a real app, you would calculate distance between user location and business location
      
      final filteredIndices = <int>[];
      
      for (int i = 0; i < _businesses.length; i++) {
        final business = _businesses[i];
        
        // Category Filter
        if (_filterCategories.isNotEmpty) {
          final category = business['category'] as String? ?? 'other';
          // Simple mapping or direct comparison
          bool categoryMatch = _filterCategories.any((c) => c.toLowerCase() == category.toLowerCase());
          if (!categoryMatch) continue;
        }
        
        // Open Now Filter (Simulated)
        if (_filterOpenNow) {
          // Assume randomly some are closed for demo or check business hours if available
          // For now, let's just say index % 5 == 0 are closed
          if (i % 5 == 0) continue; 
        }
        
        // Search Query Filter (preserve existing search logic)
        if (_searchQuery.isNotEmpty) {
           // This part is handled by _performSearch, but we need to combine them.
           // For simplicity, if search is active, we might want to re-run search logic
           // or just apply filters on top of search results.
           // Let's rely on _performSearch to handle text search, and this function to handle property filters.
           // But here we are rebuilding _filteredBusinessIndices from scratch.
           // So we should check search query match here too.
           
           final name = _normalize(business['name'].toString());
           final normalizedQuery = _normalize(_searchQuery);
           if (!name.contains(normalizedQuery)) continue;
        }

        filteredIndices.add(i);
      }
      
      _filteredBusinessIndices = filteredIndices;
      
      if (_filteredBusinessIndices.isNotEmpty) {
        // Automatically select first result if current selection is filtered out
        if (!_filteredBusinessIndices.contains(_selectedBusinessIndex)) {
           _selectedBusinessIndex = _filteredBusinessIndices.first;
           _onBusinessSelected(_selectedBusinessIndex);
        }
      }
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtreler uygulandı: ${_filteredBusinessIndices.length} sonuç'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MapFilterBottomSheet(
        onApply: _applyMapFilters,
        currentDistance: _filterDistance,
        currentCategories: _filterCategories,
        openNow: _filterOpenNow,
      ),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      final normalizedQuery = _normalize(_searchQuery);
      
      if (_searchQuery.isEmpty) {
        // Boş arama - tüm mağazaları göster
        _filteredBusinessIndices = List.generate(_businesses.length, (index) => index);
      } else {
        print('🔍 Arama yapılıyor: "$_searchQuery"');
        print('📦 Toplam ürün sayısı: ${_allProducts.length}');
        
        // Gelişmiş ürün arama - kelime kelime eşleşme
        final searchWords = _searchQuery.split(' ').where((w) => w.isNotEmpty).toList();
        final productStoreNames = <String>{};
        
        for (var product in _allProducts) {
          final productName = _normalize(product.name);
          final productBrand = _normalize(product.brand);
          
          // Tüm arama kelimelerinin ürün adında veya markasında olup olmadığını kontrol et
          final matchesAllWords = searchWords.every((word) => 
            productName.contains(_normalize(word)) || productBrand.contains(_normalize(word))
          );
          
          // Veya basit içerir kontrolü
          final containsQuery = productName.contains(normalizedQuery) || 
                                productBrand.contains(normalizedQuery);
          
          if (matchesAllWords || containsQuery) {
            final storeName = product.store == null ? '' : _normalize(product.store!);
            if (storeName.isNotEmpty) {
              productStoreNames.add(storeName);
              print('✅ Ürün bulundu: ${product.name} - Mağaza: ${product.store}');
            }
          }
        }
        
        print('🏪 Bulunan mağaza adları: $productStoreNames');
        
        // Ürünü satan mağazaları bul
        final productStoreIndices = <int>[];
        for (int i = 0; i < _businesses.length; i++) {
          final businessName = _normalize(_businesses[i]['name'].toString());
          
          // Tam eşleşme veya mağaza adının arama sonucunda olması
          if (productStoreNames.contains(businessName)) {
            productStoreIndices.add(i);
            print('🎯 Mağaza eşleşti: ${_businesses[i]['name']}');
          }
        }
        
        // Eğer ürün sonucu varsa, SADECE ürünü satan mağazaları göster
        if (productStoreIndices.isNotEmpty) {
          _filteredBusinessIndices = productStoreIndices;
          print('📍 ${productStoreIndices.length} mağaza haritada gösteriliyor');
        } else {
          print('⚠️ Ürün bulunamadı, mağaza adında aranıyor...');
          // Ürün bulunamadıysa, mağaza adında ara
          final storeIndices = <int>[];
          for (int i = 0; i < _businesses.length; i++) {
            final storeName = _normalize(_businesses[i]['name'].toString());
            if (storeName.contains(normalizedQuery)) {
              storeIndices.add(i);
            }
          }
          _filteredBusinessIndices = storeIndices;
        }
        
        _filteredBusinessIndices.sort();
        
        // Sonuç varsa ilk mağazayı seç ve haritada göster
        if (_filteredBusinessIndices.isNotEmpty) {
          _selectedBusinessIndex = _filteredBusinessIndices.first;
          final business = _businesses[_selectedBusinessIndex];
          final location = business['location'] as LatLng;
          _animatedMapMove(location, 17.5);
        } else {
          print('❌ Hiç sonuç bulunamadı!');
        }
      }
    });
  }

  void _showBusinessDetail(Map<String, dynamic> business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBusinessDetailSheet(business),
    );
  }

  List<String> _getStoreImagePaths(String storeName) {
    final name = storeName.toLowerCase();
    String prefix = '';

    if (name.contains('teknosa')) {
      prefix = 'teknosa';
    } else if (name.contains('arçelik') || name.contains('arcelik')) {
      prefix = 'arcelik';
    } else if (name.contains('lc waikiki')) {
      prefix = 'lc-waikiki';
    } else if (name.contains('destina')) {
      prefix = 'destina';
    } else {
      return [];
    }

    return List.generate(3, (index) {
      final num = index + 1;
      return 'assets/images/stores/$prefix-magaza-$num.png';
    });
  }

  Widget _buildBusinessDetailSheet(Map<String, dynamic> business) {
    final imagePaths = _getStoreImagePaths(business['name']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: AppColors.primary, size: 24),
              padding: const EdgeInsets.all(8),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with logo and info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: StoreLogoHelper.hasLogo(business['name'])
                            ? Image.asset(
                                StoreLogoHelper.getStoreLogo(business['name'])!,
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.red,
                                    alignment: Alignment.center,
                                    child: Text(
                                      business['name'].toString().substring(0, 1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.red,
                                alignment: Alignment.center,
                                child: Text(
                                  business['name'].toString().substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Name and rating
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    business['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '8.2',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Followers button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6200EE),
                                borderRadius: BorderRadius.circular(16),
                                ),
                              child: const Text(
                                '9.8B Takipçi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rozet
                      const Icon(
                        Icons.military_tech,
                        color: Colors.amber,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Address or Description
                  Text(
                    business['description'] ?? 'Teknolojinin Adresi',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // GÖRSELLERİ AŞAĞI İTMEK İÇİN BOŞLUK
                  const SizedBox(height: 20), 
                  // Image cards
                  if (imagePaths.isNotEmpty)
                    Row(
                      children: imagePaths.map((path) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                              image: DecorationImage(
                                image: AssetImage(path),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )).toList(),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      final storeProducts = _getStoreProducts(business['name']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessDetailPage(
                            business: business,
                            storeProducts: storeProducts,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6200EE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'DÜKKANI ZİYARET ET',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _businesses.asMap().entries.map((entry) {
      final index = entry.key;
      final business = entry.value;
      final isSelected = index == _selectedBusinessIndex;
      final businessName = business['name'] as String;
      final truncatedName = businessName.length > 10 
          ? '${businessName.substring(0, 10)}...' 
          : businessName;
      
      // Kategori bazlı ikon seçimi
      IconData markerIcon;
      final category = business['category'] as String? ?? 'other';
      
      switch (category) {
        case 'restoran': markerIcon = Icons.restaurant; break;
        case 'teknoloji': markerIcon = Icons.devices; break;
        case 'giyim': markerIcon = Icons.checkroom; break;
        case 'market': markerIcon = Icons.shopping_cart; break;
        case 'kozmetik': markerIcon = Icons.face_retouching_natural; break;
        case 'kitap': markerIcon = Icons.menu_book; break;
        case 'oyuncak': markerIcon = Icons.toys; break;
        case 'tamir': markerIcon = Icons.build; break;
        default: markerIcon = Icons.store;
      }
      
      return Marker(
        point: business['location'] as LatLng,
        width: 80,
        height: 70,
        child: GestureDetector(
          onTap: () {
            _onBusinessSelected(index);
            if (MediaQuery.of(context).size.width <= 800) {
              _showBusinessDetail(business);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  markerIcon,
                  color: isSelected ? AppColors.primary : Colors.white,
                  size: isSelected ? 45 : 40,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  truncatedName,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Header: Search bar + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              if (widget.product != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            _performSearch(value);
                            setState(() {}); // Clear butonu için UI'ı güncelle
                          },
                          decoration: InputDecoration(
                            hintText: 'Ürün veya mağaza ara (örn: Samsung S24)',
                            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                          child: Icon(Icons.clear, color: Colors.grey[600], size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _showFilterSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: const [
                        Icon(Icons.filter_alt, color: Colors.white, size: 20),
                        SizedBox(width: 4),
                        Text('Filtrele', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Mağaza kartları
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: _filteredBusinessIndices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Sonuç bulunamadı',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredBusinessIndices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final businessIndex = _filteredBusinessIndices[i];
                    final b = _businesses[businessIndex];
                    final selected = businessIndex == _selectedBusinessIndex;
                    final name = b['name'] as String;
                    final distance = b['distance'] as String;
                    
                    return GestureDetector(
                      onTap: () => _onBusinessSelected(businessIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: selected 
                                  ? AppColors.primary.withOpacity(0.3) 
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: selected ? 12 : 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_mall_directory_rounded,
                              color: selected ? Colors.white : AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected 
                                    ? Colors.white.withOpacity(0.25) 
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                distance,
                                style: TextStyle(
                                  color: selected ? Colors.white : AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Harita
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialPosition,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ibul_app',
                ),
                MarkerLayer(
                  markers: _buildMarkers(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        _buildThinRail(),
        Expanded(
          child: Stack(
            children: [
              // 1. Harita (En altta, tüm alanı kaplar)
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialPosition,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ibul_app',
                    ),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),
              ),

              // 2. Üst Bar: Arama Kutusu + Mağazalar (Yatay Slider)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arama Kutusu
                    Container(
                      width: 350,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _performSearch(value);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Mağaza veya ürün Ara',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch('');
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.search, color: Colors.blue),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),

                    // Mağazalar Listesi (Yatay Slider - Store Names)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredBusinessIndices.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final index = _filteredBusinessIndices[i];
                              final business = _businesses[index];
                              final isSelected = index == _selectedBusinessIndex;
                              return _buildCompactBusinessCard(business, index, isSelected);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Detay Paneli (Sadece seçim yapıldığında görünür, arama barının altında)
              if (_selectedBusinessIndex != -1)
                Positioned(
                  top: 70, // Arama barının yüksekliği + boşluk
                  left: 10,
                  // bottom: 10, // Kaldırıldı: İçerik kadar yer kaplasın
                  width: 350, // Arama barı genişliği ile aynı
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height - 100, // Ekrandan taşmaması için sınır
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildWebDetailView(),
                    ),
                  ),
                ),
                
              // Zoom Controls (Bottom Right)
               Positioned(
                bottom: 24,
                right: 24,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'zoom_in',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () {
                         final currentZoom = _mapController.camera.zoom;
                         _mapController.move(_mapController.camera.center, currentZoom + 1);
                      },
                      child: const Icon(Icons.add, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'zoom_out',
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () {
                         final currentZoom = _mapController.camera.zoom;
                         _mapController.move(_mapController.camera.center, currentZoom - 1);
                      },
                      child: const Icon(Icons.remove, color: Colors.black87),
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

  Widget _buildCompactBusinessCard(Map<String, dynamic> business, int index, bool isSelected) {
    return InkWell(
      onTap: () {
        _onBusinessSelected(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store, 
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              business['name'],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
             Row(
               children: [
                 Icon(Icons.star, size: 14, color: isSelected ? Colors.white : Colors.amber),
                 const SizedBox(width: 2),
                 Text(
                   '4.5', // Dummy rating
                   style: TextStyle(
                     fontSize: 12, 
                     color: isSelected ? Colors.white : Colors.grey[600],
                     fontWeight: FontWeight.bold
                   ),
                 ),
               ],
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinRail() {
    return Container(
      width: 70,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 20),
          IconButton(
            icon: const Icon(Icons.arrow_back), 
            onPressed: () => Navigator.pop(context),
            tooltip: 'Geri Dön',
          ),
          const SizedBox(height: 20),
          _buildRailIcon(Icons.bookmark, 'Kaydedilen'),
          const SizedBox(height: 20),
          _buildRailIcon(Icons.favorite, 'Beğenilen'),
          const SizedBox(height: 20),
          _buildRailIcon(Icons.history, 'Son'),
          const Spacer(),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRailIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[700]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildWebListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _performSearch(value);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Mağaza veya ürün Ara',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildWebFilterChip('Restoranlar', Icons.restaurant),
              const SizedBox(width: 8),
              _buildWebFilterChip('Oteller', Icons.hotel),
              const SizedBox(width: 8),
              _buildWebFilterChip('Yapılacaklar', Icons.attractions),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        
        Expanded(
          child: _filteredBusinessIndices.isEmpty
              ? Center(child: Text('Sonuç bulunamadı', style: TextStyle(color: Colors.grey[600])))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredBusinessIndices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final index = _filteredBusinessIndices[i];
                    final business = _businesses[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.store, color: Colors.grey[600]),
                      ),
                      title: Text(business['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(business['category'] ?? 'Genel'),
                      onTap: () {
                        _onBusinessSelected(index);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWebDetailView() {
    if (_selectedBusinessIndex == -1) return const SizedBox.shrink();
    final business = _businesses[_selectedBusinessIndex];
    final imagePaths = _getStoreImagePaths(business['name']);
    
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min, // İçerik kadar yer kaplasın
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable Content
          Flexible( // Flexible kullanarak gerekirse scroll olmasını sağla
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBusinessIndex = -1;
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.blue, size: 20),
                    ),
                  ),
                  
                  // Header: Logo + Name + Rating + Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: StoreLogoHelper.hasLogo(business['name'])
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                StoreLogoHelper.getStoreLogo(business['name'])!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Center(
                              child: Text(
                                business['name'].substring(0, 1),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Name & Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6200EE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '9.8B Takipçi',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '8.2',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.military_tech, color: Colors.amber, size: 24),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Teknolojinin Adresi',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Images Row
                  Row(
                    children: [
                      if (imagePaths.isNotEmpty)
                        ...imagePaths.take(3).map((path) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                path,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ))
                      else
                        ...List.generate(3, (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        )),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Fixed Bottom Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              // border: Border(top: BorderSide(color: Colors.grey.shade200)), // Border kaldırıldı
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                       final storeProducts = _getStoreProducts(business['name']);
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => BusinessDetailPage(
                             business: business,
                             storeProducts: storeProducts,
                           ),
                         ),
                       );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6200EE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'DÜKKANI ZİYARET ET',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFilterChip(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
