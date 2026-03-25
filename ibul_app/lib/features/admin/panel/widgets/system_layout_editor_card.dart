import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../services/store_service.dart';
import 'admin_panel_section_label.dart';

class SystemLayoutEditorCard extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final int index;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onDelete;

  const SystemLayoutEditorCard({
    super.key,
    required this.initialData,
    required this.index,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<SystemLayoutEditorCard> createState() => _SystemLayoutEditorCardState();
}

class _SystemLayoutEditorCardState extends State<SystemLayoutEditorCard> {
  // Removed duplicate declarations from here

  // State
  List<Map<String, dynamic>> _searchResults = [];

  // Multiple selected stores
  final List<Map<String, dynamic>> _selectedStores = [];
  Map<String, dynamic>?
  _activeStoreForProducts; // Store whose products are currently being selected

  List<Map<String, dynamic>> _storeProducts = [];

  // Map of StoreID -> Set of ProductIDs
  final Map<String, Set<String>> _selectedProductIdsByStore = {};

  // Map to cache product details for preview (ProductID -> Product Map)
  // Making this static or global to the state to persist across rebuilds?
  // Actually, better to keep it instance based but ensure it's not cleared unnecessarily.
  final Map<String, Map<String, dynamic>> _productDetailsCache = {};

  // Helper to get all selected product IDs flattened
  List<String> get _allSelectedProductIds {
    return _selectedProductIdsByStore.values.expand((e) => e).toList();
  }

  bool _isLoading = false;

  final TextEditingController _adImageController = TextEditingController();

  late TextEditingController _titleController;
  late TextEditingController _brandSearchController;
  late int _slot;
  String? _targetCategory;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadInitialData();
  }

  void _initControllers() {
    _titleController = TextEditingController(
      text: widget.initialData['title'] ?? '',
    );
    _brandSearchController =
        TextEditingController(); // Don't prefill search text
    _adImageController.text =
        widget.initialData['ad_image_url'] ??
        ''; // Set text on existing controller

    final slotVal = widget.initialData['slot'];
    _slot = (slotVal is int)
        ? slotVal
        : (int.tryParse(slotVal?.toString() ?? '') ?? (widget.index + 1));
    _targetCategory = widget.initialData['target_category'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _brandSearchController.dispose();
    _adImageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // If we've already loaded data for this card, skip to prevent flickering loop
    if (_selectedStores.isNotEmpty || _isLoading) return;

    final storeNames = widget.initialData['store_name'] as String?;
    final brandIds =
        widget.initialData['brand_name']
            as String?; // Contains JSON or comma-separated IDs
    final productIds = widget.initialData['product_ids'];

    List<String> idsToFetch = [];
    List<Map<String, dynamic>> parsedStores = [];

    // Try parsing JSON first (new format)
    if (brandIds != null && brandIds.startsWith('%5B')) {
      try {
        final decoded = Uri.decodeComponent(brandIds);
        final List<dynamic> jsonList = json.decode(decoded);
        parsedStores = jsonList
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (e) {
        debugPrint('Error parsing store JSON: $e');
      }
    } else if (brandIds != null && brandIds.isNotEmpty) {
      // Fallback to comma-separated IDs
      idsToFetch = brandIds
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    // Fallback: If no IDs found, try to search by names in store_name
    List<String> namesToSearch = [];
    if (parsedStores.isEmpty &&
        idsToFetch.isEmpty &&
        storeNames != null &&
        storeNames.isNotEmpty) {
      namesToSearch = storeNames
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      final service = StoreService();

      // If we have parsed stores from JSON, use them directly but refresh data if needed
      if (parsedStores.isNotEmpty) {
        for (var store in parsedStores) {
          final hydratedStore = await _hydrateStorePreviewData(store);
          if (!_selectedStores.any(
            (s) => s['seller_id'] == hydratedStore['seller_id'],
          )) {
            _selectedStores.add(hydratedStore);
            await _loadProductsForStore(hydratedStore, productIds);
          }
        }
      }
      // Fetch by IDs (Old format fallback)
      else if (idsToFetch.isNotEmpty) {
        // TODO: Implement getStoresByIds if needed.
        // For now, let's assume namesToSearch fallback will handle it if IDs fail or we skip.
      }

      // Fetch by Names (Fallback)
      if (namesToSearch.isNotEmpty) {
        for (var name in namesToSearch) {
          final results = await service.searchStoresByNameOrCategory(
            name.trim(),
          );
          if (results.isNotEmpty) {
            final store = results.firstWhere(
              (s) =>
                  (s['business_name'] as String).toLowerCase() ==
                  name.trim().toLowerCase(),
              orElse: () => results.first,
            );
            final hydratedStore = await _hydrateStorePreviewData(store);

            if (!_selectedStores.any(
              (s) => s['seller_id'] == hydratedStore['seller_id'],
            )) {
              _selectedStores.add(hydratedStore);
              await _loadProductsForStore(hydratedStore, productIds);
            }
          }
        }
      }

      // Set first store as active
      if (_selectedStores.isNotEmpty) {
        if (mounted) _switchToStore(_selectedStores.first);
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductsForStore(
    Map<String, dynamic> store,
    dynamic allProductIds,
  ) async {
    final sellerId = store['seller_id']?.toString();
    if (sellerId != null) {
      final products = await StoreService().getProductsBySellerId(sellerId);

      // Cache products for preview
      for (var p in products) {
        _productDetailsCache[p['id'].toString()] = p;
      }

      if (allProductIds != null && allProductIds is List) {
        final Set<String> ids = allProductIds.map((e) => e.toString()).toSet();
        final storeProductIds = products.map((p) => p['id'].toString()).toSet();
        final intersection = ids.intersection(storeProductIds);

        if (intersection.isNotEmpty) {
          _selectedProductIdsByStore[sellerId] = intersection;
        }
      }
    }
  }

  Future<Map<String, dynamic>> _hydrateStorePreviewData(
    Map<String, dynamic> store,
  ) async {
    final hydrated = Map<String, dynamic>.from(store);
    final businessName = hydrated['business_name']?.toString().trim() ?? '';
    if (businessName.isEmpty) {
      return hydrated;
    }

    try {
      final publicInfo = await StoreService().getStorePublicInfoByBusinessName(
        businessName,
      );
      if (publicInfo == null) {
        return hydrated;
      }

      final bannerUrls = <String>[];
      final rawBanners = publicInfo['banners'];
      if (rawBanners is List) {
        for (final item in rawBanners) {
          final url = item?.toString().trim() ?? '';
          if (url.isNotEmpty) {
            bannerUrls.add(url);
          }
        }
      }

      final logoUrl = publicInfo['logoUrl']?.toString().trim() ?? '';
      if (logoUrl.isNotEmpty &&
          (hydrated['logo_url'] == null ||
              hydrated['logo_url'].toString().trim().isEmpty)) {
        hydrated['logo_url'] = logoUrl;
      }
      if (bannerUrls.isNotEmpty) {
        hydrated['banners'] = bannerUrls;
        hydrated['banner_url'] = bannerUrls.first;
      }
    } catch (_) {}

    return hydrated;
  }

  void _replaceSelectedStore(Map<String, dynamic> store) {
    final sellerId = store['seller_id']?.toString();
    if (sellerId == null) {
      return;
    }

    final index = _selectedStores.indexWhere(
      (item) => item['seller_id']?.toString() == sellerId,
    );
    if (index != -1) {
      _selectedStores[index] = store;
    }
  }

  List<String> _resolveBannerUrls() {
    if (_adImageController.text.isNotEmpty) {
      return _adImageController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final activeStore = _activeStoreForProducts;
    if (activeStore == null) {
      return const [];
    }

    final urls = <String>[];
    final directBanner = activeStore['banner_url']?.toString().trim() ?? '';
    if (directBanner.isNotEmpty) {
      urls.add(directBanner);
    }

    final rawBanners = activeStore['banners'];
    if (rawBanners is List) {
      for (final item in rawBanners) {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }

    return urls;
  }

  Future<void> _searchStores(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await StoreService().searchStoresByNameOrCategory(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {}
  }

  Future<void> _addStore(Map<String, dynamic> store) async {
    final hydratedStore = await _hydrateStorePreviewData(store);

    // Check if already selected
    if (_selectedStores.any(
      (s) => s['seller_id'] == hydratedStore['seller_id'],
    )) {
      // Just switch to it
      _switchToStore(hydratedStore);
      return;
    }

    setState(() {
      _selectedStores.add(hydratedStore);
      _brandSearchController.clear();
      _searchResults = [];
    });

    await _switchToStore(hydratedStore);
  }

  // Cache for store products list to avoid re-fetching on tab switch
  final Map<String, List<Map<String, dynamic>>> _storeProductsCache = {};

  Future<void> _switchToStore(Map<String, dynamic> store) async {
    final hydratedStore = await _hydrateStorePreviewData(store);
    final sellerId = hydratedStore['seller_id']?.toString();

    // If selecting the already active store, just return unless products are empty
    if (_activeStoreForProducts?['seller_id'] == sellerId &&
        _storeProducts.isNotEmpty) {
      return;
    }

    // Check cache first
    if (sellerId != null) {
      final cachedProducts = _storeProductsCache[sellerId];
      if (cachedProducts != null) {
        if (mounted) {
          setState(() {
            _replaceSelectedStore(hydratedStore);
            _activeStoreForProducts = hydratedStore;
            _storeProducts = cachedProducts;
          });
        }
        return;
      }
    }

    // Only set loading if we actually need to fetch
    setState(() {
      _replaceSelectedStore(hydratedStore);
      _activeStoreForProducts = hydratedStore;
      _isLoading = true;
    });

    try {
      if (sellerId != null) {
        final products = await StoreService().getProductsBySellerId(sellerId);

        // Update cache
        _storeProductsCache[sellerId] = products;
        for (var p in products) {
          _productDetailsCache[p['id'].toString()] = p;
        }

        if (mounted) setState(() => _storeProducts = products);
      } else {
        if (mounted) setState(() => _storeProducts = []);
      }
    } catch (_) {
      if (mounted) setState(() => _storeProducts = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeStore(Map<String, dynamic> store) {
    setState(() {
      _selectedStores.removeWhere((s) => s['seller_id'] == store['seller_id']);
      _selectedProductIdsByStore.remove(store['seller_id']);

      if (_activeStoreForProducts?['seller_id'] == store['seller_id']) {
        if (_selectedStores.isNotEmpty) {
          _switchToStore(_selectedStores.last);
        } else {
          _activeStoreForProducts = null;
          _storeProducts = [];
        }
      }
    });
  }

  void _handleSave() {
    // Birden fazla mağazayı 'brand_name' alanına JSON string olarak kaydediyoruz
    // Metin alanlarında sorun olmaması için encode ediyoruz

    final storesToSave = _selectedStores
        .map(
          (s) => {
            'seller_id': s['seller_id'],
            'business_name': s['business_name'],
            'logo_url': s['logo_url'],
          },
        )
        .toList();

    final jsonString = Uri.encodeComponent(json.encode(storesToSave));
    final displayStoreNames = _selectedStores
        .map((s) => s['business_name'])
        .join(', ');

    final robustData = {
      'id': widget.initialData['id'], // Preserve ID for updates
      'title': _titleController.text.trim(),
      'store_name': displayStoreNames,
      'brand_name': jsonString,
      'ad_image_url': _adImageController.text.trim(),
      'product_ids': _allSelectedProductIds,
      'slot': _slot,
      'target_category': _targetCategory,
    };

    widget.onSave(robustData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE9F6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDD6FF)),
                      ),
                      child: Text(
                        'Kart $_slot',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    if (_targetCategory != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Text(
                          _targetCategory!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Sil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade500,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _handleSave,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Kaydet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF3F0FF)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol taraf: Form
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              label: 'Üst Başlık',
                              controller: _titleController,
                              hint: 'Örn: Teknoloji Fırsatları',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildDropdownField(
                              label: 'Kart Sırası',
                              value: _slot.toString(),
                              items: List.generate(
                                10,
                                (index) => (index + 1).toString(),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _slot = int.parse(val));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildDropdownField(
                              label: 'Kategori (Opsiyonel)',
                              value: _targetCategory ?? '',
                              items: [
                                'Yemek',
                                'Elektronik',
                                'Giyim & Aksesuar',
                                'Spor & Outdoor',
                                'Kozmetik',
                                'Ev & Yaşam',
                              ],
                              onChanged: (val) {
                                setState(
                                  () => _targetCategory =
                                      (val == null || val.isEmpty) ? null : val,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel('Marka Seç', Icons.store_outlined),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          TextField(
                            controller: _brandSearchController,
                            onChanged: _searchStores,
                            decoration: InputDecoration(
                              hintText: 'Marka veya kategori ile ara...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF8B5CF6),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAFAFF),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                          if (_searchResults.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final store = _searchResults[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.store_outlined,
                                      size: 18,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                    title: Text(
                                      store['business_name'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      store['category'] ?? '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onTap: () => _addStore(store),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSectionLabel(
                        'Duyuru Görseli URL',
                        Icons.image_outlined,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Çoklu görsel için virgül ile ayırın',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _adImageController,
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'https://ornek.com/1.jpg, https://ornek.com/2.jpg',
                          prefixIcon: const Icon(
                            Icons.link_rounded,
                            size: 18,
                            color: Color(0xFF9CA3AF),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFF),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildSectionLabel(
                            'Seçilen Ürünler',
                            Icons.shopping_bag_outlined,
                          ),
                          const Spacer(),
                          if (_activeStoreForProducts != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _activeStoreForProducts!['business_name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Ürünler yükleniyor...',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_activeStoreForProducts == null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ürünlerini görmek için bir marka seçin veya ekleyin.',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_storeProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            'Bu mağazada ürün bulunamadı',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _storeProducts.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFF3F4F6),
                            ),
                            itemBuilder: (context, index) {
                              final product = _storeProducts[index];
                              final pid = product['id'].toString();
                              final sellerId =
                                  _activeStoreForProducts!['seller_id']
                                      .toString();
                              final currentStoreIds =
                                  _selectedProductIdsByStore[sellerId] ?? {};
                              final isSelected = currentStoreIds.contains(pid);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (!_selectedProductIdsByStore.containsKey(
                                      sellerId,
                                    )) {
                                      _selectedProductIdsByStore[sellerId] = {};
                                    }
                                    if (val == true) {
                                      if (_allSelectedProductIds.length < 8) {
                                        _selectedProductIdsByStore[sellerId]!
                                            .add(pid);
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Toplam en fazla 8 ürün seçebilirsiniz',
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      _selectedProductIdsByStore[sellerId]!
                                          .remove(pid);
                                    }
                                  });
                                },
                                title: Text(
                                  product['name'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  '₺${product['price']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                activeColor: const Color(0xFF8B5CF6),
                                checkColor: Colors.white,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Sağ taraf: Önizleme
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(
                        'Ana Sayfa Önizleme',
                        Icons.preview_outlined,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEDE9F6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleController.text.isEmpty
                                  ? 'Başlık'
                                  : _titleController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedStores.isNotEmpty)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _selectedStores.map((store) {
                                    final isActive =
                                        _activeStoreForProducts?['seller_id'] ==
                                        store['seller_id'];
                                    return GestureDetector(
                                      onTap: () => _switchToStore(store),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFF8B5CF6)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF8B5CF6)
                                                : const Color(0xFFE5E7EB),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            if (store['logo_url'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: CircleAvatar(
                                                  backgroundImage: ResizeImage.resizeIfNeeded(
                                                    32,
                                                    32,
                                                    NetworkImage(store['logo_url']),
                                                  ),
                                                  radius: 8,
                                                  backgroundColor:
                                                      Colors.grey.shade100,
                                                ),
                                              )
                                            else
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: Icon(
                                                  Icons.store,
                                                  size: 16,
                                                  color: isActive
                                                      ? Colors.white
                                                      : const Color(0xFF8B5CF6),
                                                ),
                                              ),
                                            Text(
                                              store['business_name'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? Colors.white
                                                    : const Color(0xFF8B5CF6),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _removeStore(store),
                                              child: Icon(
                                                Icons.close,
                                                size: 16,
                                                color: isActive
                                                    ? Colors.white.withValues(
                                                        alpha: 0.8,
                                                      )
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final bannerUrls = _resolveBannerUrls();
                                    if (bannerUrls.isEmpty) {
                                      return Container(
                                        height: 100,
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.campaign_outlined,
                                                color: Color(0xFFD1D5DB),
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _activeStoreForProducts != null
                                                    ? '${_activeStoreForProducts!['business_name']} Duyuru Görseli'
                                                    : 'Duyuru Görseli',
                                                style: const TextStyle(
                                                  color: Color(0xFF9CA3AF),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return SizedBox(
                                      height: 100,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: bannerUrls.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (context, index) {
                                          return Container(
                                            width: 250,
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              image: DecorationImage(
                                                image: ResizeImage.resizeIfNeeded(
                                                  800,
                                                  400,
                                                  NetworkImage(bannerUrls[index]),
                                                ),
                                                fit: BoxFit.cover,
                                                onError:
                                                    (exception, stackTrace) {},
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(
                                  height: 240,
                                  child: Builder(
                                    builder: (context) {
                                      final activeSellerId =
                                          _activeStoreForProducts?['seller_id']
                                              ?.toString();
                                      if (activeSellerId == null) {
                                        return const Center(
                                          child: Text(
                                            'Lütfen bir mağaza seçin',
                                          ),
                                        );
                                      }
                                      final activeStoreProductIds =
                                          _selectedProductIdsByStore[activeSellerId] ??
                                          {};
                                      if (activeStoreProductIds.isEmpty) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_outlined,
                                                  color: Color(0xFFD1D5DB),
                                                  size: 28,
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  'Ürün seçilmedi',
                                                  style: TextStyle(
                                                    color: Color(0xFF9CA3AF),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      final productIdsList =
                                          activeStoreProductIds.toList();
                                      return ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: productIdsList.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(width: 12),
                                        itemBuilder: (context, index) {
                                          final pid = productIdsList[index];
                                          var product =
                                              _productDetailsCache[pid
                                                  .toString()];
                                          if (product == null) {
                                            return Container(
                                              width: 120,
                                              color: Colors.grey.shade100,
                                              child: Center(
                                                child: Text(
                                                  'Ürün $pid\n(Yükleniyor...)',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return Container(
                                            width: 140,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x06000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (_activeStoreForProducts !=
                                                    null)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF9F5FF,
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        if (_activeStoreForProducts!['logo_url'] !=
                                                            null)
                                                          CircleAvatar(
                                                            backgroundImage:
                                                                ResizeImage.resizeIfNeeded(
                                                                  28,
                                                                  28,
                                                                  NetworkImage(
                                                                    _activeStoreForProducts!['logo_url'],
                                                                  ),
                                                                ),
                                                            radius: 7,
                                                          )
                                                        else
                                                          const Icon(
                                                            Icons.store,
                                                            size: 12,
                                                            color: Color(
                                                              0xFF8B5CF6,
                                                            ),
                                                          ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _activeStoreForProducts!['business_name'] ??
                                                                '',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 9,
                                                                  color: Color(
                                                                    0xFF8B5CF6,
                                                                  ),
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF3F4F6,
                                                      ),
                                                      image:
                                                          product['image_url'] !=
                                                              null
                                                          ? DecorationImage(
                                                              image: ResizeImage.resizeIfNeeded(
                                                                200,
                                                                200,
                                                                NetworkImage(
                                                                  product['image_url'],
                                                                ),
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        product['name'] ?? '',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF1F1035,
                                                          ),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '₺${product['price']}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                            0xFF8B5CF6,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return AdminPanelSectionLabel(label: label, icon: icon);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              hint: const Text('Seç'),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
