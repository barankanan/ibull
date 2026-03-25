import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'dart:typed_data';

import '../../../../core/mobile_category_catalog.dart';
import '../../../../models/db_category.dart';
import '../../../../services/admin_service.dart';
import '../dialogs/category_delete_confirm_dialog.dart';
import '../dialogs/category_edit_dialog.dart';
import '../dialogs/system_layout_dialogs.dart';
import '../widgets/system_layout_editor_card.dart';
import '../widgets/system_layout_managed_category_widgets.dart';

class SystemLayoutPage extends StatefulWidget {
  const SystemLayoutPage({super.key});

  @override
  State<SystemLayoutPage> createState() => _SystemLayoutPageState();
}

class _SystemLayoutPageState extends State<SystemLayoutPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isLoadingManagedCategories = false;

  // Hair Care Layouts (Kart Yapısı)
  List<Map<String, dynamic>> _hairCareLayouts = [];

  // Campaign Images
  List<Map<String, dynamic>> _campaignImages = [];
  List<Map<String, dynamic>> _appCategories = [];
  List<MobileCategoryNode> _managedCategories = [];
  final Set<String> _savingCategoryKeys = <String>{};
  final Set<String> _savingManagedCategoryKeys = <String>{};
  static const int _categoryNameMaxLength = 24;

  static const List<Map<String, String>> _defaultAppCategories = [
    {'category_key': 'yakin_lokasyon', 'display_name': 'Yakın Lokasyon'},
    {'category_key': 'urun_listele', 'display_name': 'Ürün Listele'},
    {'category_key': 'gorsel_zeka', 'display_name': 'Görsel Zeka'},
    {'category_key': 'urun_parcala', 'display_name': 'Ürün Parçala'},
    {'category_key': 'ibul_premium', 'display_name': 'İBUL Premium'},
    {'category_key': 'bana_ozel', 'display_name': 'Bana Özel'},
    {'category_key': 'hizli_yemek', 'display_name': 'Hızlı Yemek'},
    {'category_key': 'yapay_zeka', 'display_name': 'Yapay Zeka'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchHairCareLayouts();
    _fetchCampaignImages();
    _fetchAppCategories();
    _fetchManagedCategories();
  }

  Future<void> _fetchCampaignImages() async {
    try {
      final images = await AdminService().getCampaignImages();
      if (mounted) {
        setState(() {
          _campaignImages = List<Map<String, dynamic>>.from(images);
        });
      }
    } catch (e) {
      debugPrint('Error fetching campaign images: $e');
    }
  }

  Future<void> _fetchAppCategories() async {
    try {
      final categories = await AdminService().getAppCategories();
      if (!mounted) return;

      final byKey = <String, Map<String, dynamic>>{};
      for (final category in categories) {
        final key = category['category_key']?.toString();
        if (key != null && key.isNotEmpty) {
          byKey[key] = Map<String, dynamic>.from(category);
        }
      }

      final merged = _defaultAppCategories.map((seed) {
        final key = seed['category_key']!;
        final existing = byKey[key];
        if (existing != null) return existing;
        return {
          'id': null,
          'category_key': key,
          'display_name': seed['display_name'],
          'image_url': null,
          'is_active': true,
        };
      }).toList();

      setState(() {
        _appCategories = merged;
      });
    } catch (e) {
      debugPrint('Error fetching app categories: $e');
    }
  }

  String _managedCategoryKey(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
  }) {
    final parentPart = parent?.name ?? node.parentId?.toString() ?? 'root';
    return '${node.id ?? 'draft'}::$parentPart::${node.name}';
  }

  String _slugifyCategoryPath(String value) {
    return normalizeCategoryNameForLookup(value)
        .replaceAll('&', 've')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  MobileCategoryNode _nodeFromDbCategory(
    DBCategory category, {
    String? fallbackAssetPath,
    List<MobileCategoryNode>? subCategories,
  }) {
    return MobileCategoryNode(
      id: category.id,
      parentId: category.parentId,
      name: category.name,
      imageUrl: category.imageUrl,
      iconName: category.iconName,
      fallbackAssetPath: fallbackAssetPath,
      orderIndex: category.orderIndex,
      isActive: category.isActive,
      subCategories: subCategories ?? const [],
    );
  }

  Future<MobileCategoryNode> _ensureManagedCategoryExists(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
  }) async {
    MobileCategoryNode? resolvedParent = parent;
    if (parent != null && parent.id == null) {
      resolvedParent = await _ensureManagedCategoryExists(parent);
    }

    if (node.id != null) {
      return node.copyWith(parentId: resolvedParent?.id ?? node.parentId);
    }

    final saved = await AdminService().saveManagedCategory(
      node
          .copyWith(parentId: resolvedParent?.id ?? node.parentId)
          .toDbCategory(),
    );

    return _nodeFromDbCategory(
      saved,
      fallbackAssetPath: node.fallbackAssetPath,
      subCategories: node.subCategories,
    );
  }

  Future<void> _fetchManagedCategories() async {
    if (mounted) {
      setState(() {
        _isLoadingManagedCategories = true;
      });
    }

    try {
      final categories = await AdminService().getManagedCategoriesWithSubs();
      if (!mounted) return;
      setState(() {
        _managedCategories = buildMobileCategoryTree(
          categories,
          includeMissingDefaultCategories: true,
        );
      });
    } catch (e) {
      debugPrint('Error fetching managed categories: $e');
      if (!mounted) return;
      setState(() {
        _managedCategories = buildMobileCategoryTree(const []);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingManagedCategories = false;
        });
      }
    }
  }

  Future<bool> _saveManagedCategory({
    required MobileCategoryNode draft,
    MobileCategoryNode? parent,
    Uint8List? newImageBytes,
  }) async {
    final key = _managedCategoryKey(draft, parent: parent);

    setState(() {
      _savingManagedCategoryKeys.add(key);
    });

    try {
      final resolvedParent = parent == null
          ? null
          : await _ensureManagedCategoryExists(parent);
      var imageUrl = draft.imageUrl;
      if (newImageBytes != null) {
        final pathParts = <String>[
          'mobile_categories',
          if (resolvedParent != null) _slugifyCategoryPath(resolvedParent.name),
          _slugifyCategoryPath(draft.name),
        ];
        final categoryKey = pathParts
            .where((part) => part.isNotEmpty)
            .join('/');
        final fileName =
            'cat_${DateTime.now().millisecondsSinceEpoch}_${_slugifyCategoryPath(draft.name)}.jpg';
        imageUrl = await AdminService().uploadCategoryImage(
          newImageBytes,
          fileName,
          categoryKey: categoryKey,
        );
      }

      final saved = await AdminService().saveManagedCategory(
        draft
            .copyWith(
              parentId: resolvedParent?.id ?? draft.parentId,
              imageUrl: imageUrl,
            )
            .toDbCategory(),
      );

      await _fetchManagedCategories();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${saved.name} ${saved.parentId == null ? 'kategorisi' : 'alt kategorisi'} kaydedildi.',
          ),
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kategori kaydetme hatası: $e')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingManagedCategoryKeys.remove(key);
        });
      }
    }
  }

  Future<void> _toggleManagedCategoryActive(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
    required bool value,
  }) async {
    await _saveManagedCategory(
      draft: node.copyWith(isActive: value),
      parent: parent,
    );
  }

  Future<void> _deleteManagedCategory(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
  }) async {
    final key = _managedCategoryKey(node, parent: parent);
    setState(() {
      _savingManagedCategoryKeys.add(key);
    });

    try {
      final resolvedParent = parent == null
          ? null
          : await _ensureManagedCategoryExists(parent);
      final resolvedNode = await _ensureManagedCategoryExists(
        node,
        parent: resolvedParent,
      );
      await AdminService().deleteManagedCategory(
        category: resolvedNode
            .copyWith(parentId: resolvedParent?.id ?? resolvedNode.parentId)
            .toDbCategory(),
        deleteChildren: parent == null && node.subCategories.isNotEmpty,
      );
      await _fetchManagedCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${node.name} silindi.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kategori silme hatası: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _savingManagedCategoryKeys.remove(key);
        });
      }
    }
  }

  void _confirmDeleteManagedCategory(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
  }) {
    showManagedCategoryDeleteConfirmDialog(
      context: context,
      node: node,
      parent: parent,
      onConfirm: () => _deleteManagedCategory(node, parent: parent),
    );
  }

  void _showManagedCategoryDialog({
    MobileCategoryNode? existing,
    MobileCategoryNode? parent,
  }) {
    showManagedCategoryEditDialog(
      context: context,
      existing: existing,
      parent: parent,
      initialOrderIndex:
          (parent?.subCategories.length ?? _managedCategories.length) + 1,
      onPickAndCropImage:
          ({required ratioX, required ratioY, required suggestedWidth}) =>
              pickAndCropSystemLayoutImageBytes(
                context: context,
                ratioX: ratioX,
                ratioY: ratioY,
                suggestedWidth: suggestedWidth,
              ),
      onSave: ({required draft, parent, newImageBytes}) => _saveManagedCategory(
        draft: draft,
        parent: parent,
        newImageBytes: newImageBytes,
      ),
    );
  }

  Future<void> _saveCategoryItem(
    Map<String, dynamic> category, {
    Uint8List? newImageBytes,
    String? newDisplayName,
  }) async {
    final categoryKey = category['category_key']?.toString();
    if (categoryKey == null || categoryKey.isEmpty) return;

    setState(() {
      _savingCategoryKeys.add(categoryKey);
    });

    try {
      final service = AdminService();
      String? imageUrl = category['image_url']?.toString();
      if (newImageBytes != null) {
        final fileName =
            'cat_${categoryKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await service.uploadCategoryImage(
          newImageBytes,
          fileName,
          categoryKey: categoryKey,
        );
      }

      final displayName =
          (newDisplayName ?? category['display_name']?.toString() ?? '').trim();
      final safeDisplayName = displayName.length > _categoryNameMaxLength
          ? displayName.substring(0, _categoryNameMaxLength)
          : displayName;

      await service.saveAppCategory({
        'id': category['id'],
        'category_key': categoryKey,
        'display_name': safeDisplayName,
        'image_url': imageUrl,
        'is_active': category['is_active'] ?? true,
      });

      if (!mounted) return;
      await _fetchAppCategories();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$safeDisplayName kaydedildi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kategori kaydetme hatası: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingCategoryKeys.remove(categoryKey);
        });
      }
    }
  }

  void _showCategoryEditDialog(Map<String, dynamic> category) {
    showAppCategoryEditDialog(
      context: context,
      category: category,
      categoryNameMaxLength: _categoryNameMaxLength,
      onPickAndCropImage:
          ({required ratioX, required ratioY, required suggestedWidth}) =>
              pickAndCropSystemLayoutImageBytes(
                context: context,
                ratioX: ratioX,
                ratioY: ratioY,
                suggestedWidth: suggestedWidth,
              ),
      onSave: ({newImageBytes, newDisplayName}) => _saveCategoryItem(
        category,
        newImageBytes: newImageBytes,
        newDisplayName: newDisplayName,
      ),
    );
  }

  void _showImageDetailsDialog({Map<String, dynamic>? existingImage}) {
    showCampaignImageDetailsDialog(
      context: context,
      existingImage: existingImage,
      onPickAndCropImage:
          ({required ratioX, required ratioY, required suggestedWidth}) =>
              pickAndCropSystemLayoutImageBytes(
                context: context,
                ratioX: ratioX,
                ratioY: ratioY,
                suggestedWidth: suggestedWidth,
              ),
      onSave: (request) async {
        try {
          final service = AdminService();
          var desktopImagePath = request.desktopImagePath;
          var mobileImagePath = request.mobileImagePath;

          if (request.newDesktopBytes != null) {
            final fileName =
                'desktop_${DateTime.now().millisecondsSinceEpoch}.jpg';
            desktopImagePath = await service.uploadCampaignImage(
              request.newDesktopBytes!,
              fileName,
            );
          }

          if (request.newMobileBytes != null) {
            final fileName =
                'mobile_${DateTime.now().millisecondsSinceEpoch}.jpg';
            mobileImagePath = await service.uploadCampaignImage(
              request.newMobileBytes!,
              fileName,
            );
          }

          if (desktopImagePath == null || desktopImagePath.isEmpty) {
            throw Exception('Görsel yüklenemedi');
          }

          final imageData = {
            'id': request.existingImage?['id'],
            'image_path': desktopImagePath,
            'mobile_image_path': mobileImagePath,
            'title': request.title,
            'alt_text': request.altText,
            'link_url': request.linkUrl,
            'is_active': request.isActive,
          };

          await service.saveCampaignImage(imageData);
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e')));
          }
          return false;
        }
      },
      onSaved: () {
        _fetchCampaignImages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kampanya görseli başarıyla kaydedildi.'),
          ),
        );
      },
    );
  }

  Future<void> _deleteCampaignImage(int id) async {
    await AdminService().deleteCampaignImage(id);
    _fetchCampaignImages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHairCareLayouts() async {
    // Prevent fetching if already loading to avoid loops, UNLESS forced (e.g. after save)
    if (_isLoading) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      final layouts = await AdminService().getHairCareLayouts();

      // Deduplicate by slot and Limit to 2
      final Map<int, Map<String, dynamic>> uniqueMap = {};
      for (var layout in layouts) {
        // Ensure slot is an int
        int? slot = int.tryParse(layout['slot'].toString());
        if (slot == null) continue;

        // If we already have this slot, we might want to keep the one with more data?
        // For now, simply keeping the first one encountered or last one.
        // Let's keep the one that looks valid (has title/store_name) if possible.
        if (!uniqueMap.containsKey(slot)) {
          uniqueMap[slot] = layout;
        }
      }

      var cleaned = uniqueMap.values.toList();
      cleaned.sort(
        (a, b) => int.parse(
          a['slot'].toString(),
        ).compareTo(int.parse(b['slot'].toString())),
      );

      // Strictly limit to 2 cards
      // if (cleaned.length > 2) {
      //   cleaned = cleaned.take(2).toList();
      // }

      if (mounted) {
        setState(() {
          _hairCareLayouts = cleaned;
        });
      }
    } catch (e) {
      debugPrint('Error fetching layouts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveHairCareLayouts({bool silent = false}) async {
    setState(() => _isLoading = true);
    try {
      // Pass only the current list. The service will handle upsert vs insert based on ID.
      await AdminService().saveHairCareLayouts(_hairCareLayouts);

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değişiklikler kaydedildi')),
        );
      }

      // Force fetch to ensure we get back the new IDs for inserted items
      // This is CRITICAL to prevent creating duplicates on next save
      setState(() => _isLoading = false);
      await _fetchHairCareLayouts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createNewHairCareLayout() {
    // Limit removed as requested
    /*
    if (_hairCareLayouts.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En fazla 2 kart oluşturabilirsiniz.')));
      return;
    }
    */

    // Determine next available slot
    int nextSlot = 1;
    final existingSlots = _hairCareLayouts
        .map((e) => int.tryParse(e['slot'].toString()) ?? 0)
        .toSet();
    while (existingSlots.contains(nextSlot)) {
      nextSlot++;
    }

    setState(() {
      _hairCareLayouts.add({
        'title': '',
        'store_name': '',
        'brand_name': '',
        'product_ids': [],
        'slot': nextSlot,
        'id': null, // Explicitly set ID to null for new items
      });
    });
    // Do NOT save immediately. Wait for user to enter data and click Save.
    // This prevents creating empty/duplicate records.
    // _saveHairCareLayouts();
  }

  void _deleteLayout(int index) {
    showSystemLayoutDeleteConfirmDialog(
      context: context,
      onConfirm: () async {
        final itemToDelete = _hairCareLayouts[index];
        final idToDelete = itemToDelete['id'];

        if (idToDelete == null) {
          setState(() => _hairCareLayouts.removeAt(index));
          return;
        }

        if (mounted) setState(() => _isLoading = true);

        try {
          await AdminService().deleteSystemLayout(idToDelete);
          if (mounted) {
            setState(() {
              _hairCareLayouts.removeWhere((item) => item['id'] == idToDelete);
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kart tasarımı silindi')),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Silme işlemi başarısız: $e')),
            );
          }
        }
      },
    );
  }

  void _updateLayout(int index, Map<String, dynamic> newData) {
    // Validation: Check if slot is already taken for the same category
    final newSlot = newData['slot'];
    final newCategory = newData['target_category'];

    // Check other layouts
    final isDuplicate = _hairCareLayouts.asMap().entries.any((entry) {
      final i = entry.key;
      final layout = entry.value;

      // Skip current item
      if (i == index) return false;

      final slot = layout['slot'];
      final category = layout['target_category'];

      // If both category and slot match, it's a duplicate
      // Note: If category is null (Global), it might conflict with other globals or specific ones depending on rule.
      // Assumption: Uniqueness is per (Category, Slot) pair.
      return slot == newSlot && category == newCategory;
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hata: "${newCategory ?? "Genel"}" kategorisinde $newSlot. sıra zaten dolu!',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (newData['id'] == null && _hairCareLayouts[index]['id'] != null) {
        newData['id'] = _hairCareLayouts[index]['id'];
      }
      _hairCareLayouts[index] = newData;
    });
    _saveHairCareLayouts();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFEDE9F6), width: 1.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sistem Düzeni',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1035),
                          ),
                        ),
                        Text(
                          'Ana sayfa kartları, görseller ve kategori yönetimi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8B5CF6),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                indicatorColor: const Color(0xFF8B5CF6),
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Kart Yapısı'),
                  Tab(text: 'Görseller'),
                  Tab(text: 'Kategoriler'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHairCareTab(),
              _buildImagesTab(),
              _buildManagedCategoriesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHairCareTab() {
    if (_isLoading && _hairCareLayouts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
            SizedBox(height: 16),
            Text(
              'Kart yapıları yükleniyor...',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFFFAF9FF),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ana Sayfa Kartları',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1035),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_hairCareLayouts.length} kart tanımlı',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _createNewHairCareLayout,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Kart'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEDE9F6)),
        Expanded(
          child: _hairCareLayouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Icon(
                          Icons.view_carousel_outlined,
                          size: 40,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz kart oluşturulmamış',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ana sayfada görünecek içerik kartlarını buradan yönetebilirsiniz.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  itemCount: _hairCareLayouts.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return SystemLayoutEditorCard(
                      key: ValueKey(_hairCareLayouts[index]),
                      index: index,
                      initialData: _hairCareLayouts[index],
                      onSave: (data) => _updateLayout(index, data),
                      onDelete: () => _deleteLayout(index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImagesTab() {
    final bool isDesktop = MediaQuery.of(context).size.width > 1100;
    final int categoryGridCount = isDesktop ? 4 : 2;

    return Column(
      children: [
        Container(
          color: const Color(0xFFFAF9FF),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kampanya Görselleri',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1035),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_campaignImages.length} görsel • Sürükleyerek sırala',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showImageDetailsDialog(),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: const Text('Yeni Görsel'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEDE9F6)),
        Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: _campaignImages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0FF),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                size: 40,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Henüz kampanya görseli eklenmemiş',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ana sayfada görünecek kampanya bannerlarını buradan yönetebilirsiniz.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _campaignImages.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _campaignImages.removeAt(oldIndex);
                            _campaignImages.insert(newIndex, item);
                          });
                          await AdminService().updateCampaignImagesOrder(
                            _campaignImages,
                          );
                        },
                        itemBuilder: (context, index) {
                          final image = _campaignImages[index];
                          final isActive = image['is_active'] ?? true;
                          return Container(
                            key: ValueKey(image['id'] ?? index),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFDDD6FF)
                                    : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_handle_rounded,
                                    color: Colors.grey.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 100,
                                      height: 56,
                                      color: Colors.grey.shade100,
                                      child: OptimizedImage(imageUrlOrPath: 
                                        image['image_path'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.grey,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          image['title'] ?? 'Başlıksız',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFF1F1035),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          image['link_url'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFFEEFDF6)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              isActive ? 'Aktif' : 'Pasif',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? const Color(0xFF059669)
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Switch(
                                              value: isActive,
                                              activeTrackColor: const Color(
                                                0xFF8B5CF6,
                                              ),
                                              activeThumbColor: Colors.white,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              onChanged: (val) async {
                                                final updatedImage = {
                                                  ...image,
                                                  'is_active': val,
                                                };
                                                setState(() {
                                                  _campaignImages[index] =
                                                      updatedImage;
                                                });
                                                await AdminService()
                                                    .saveCampaignImage(
                                                      updatedImage,
                                                    );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                        onPressed: () =>
                                            _showImageDetailsDialog(
                                              existingImage: image,
                                            ),
                                        tooltip: 'Düzenle',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Colors.red.shade400,
                                        ),
                                        onPressed: () {
                                          showCampaignImageDeleteConfirmDialog(
                                            context: context,
                                            onConfirm: () =>
                                                _deleteCampaignImage(
                                                  image['id'],
                                                ),
                                          );
                                        },
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9CCFF)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        color: Color(0xFF8B5CF6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kategori Görselleri',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Önerilen görsel: 512×512 px (1:1), JPG/PNG, maksimum 1 MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: categoryGridCount,
                    childAspectRatio: categoryGridCount == 4 ? 3.6 : 4.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _appCategories.length,
                  itemBuilder: (context, index) {
                    final category = _appCategories[index];
                    final categoryKey =
                        category['category_key']?.toString() ?? '';
                    final isSaving = _savingCategoryKeys.contains(categoryKey);
                    final imageUrl = category['image_url']?.toString();
                    final isActive = category['is_active'] ?? true;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFDDD6FF)
                              : const Color(0xFFE5E7EB),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFFF3F0FF),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      (imageUrl != null && imageUrl.isNotEmpty)
                                      ? OptimizedImage(imageUrlOrPath: 
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.image_outlined,
                                          color: Color(0xFF8B5CF6),
                                          size: 22,
                                        ),
                                ),
                                if (!isActive)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category['display_name']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isActive
                                          ? const Color(0xFF1F1035)
                                          : Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  OutlinedButton.icon(
                                    onPressed: isSaving
                                        ? null
                                        : () =>
                                              _showCategoryEditDialog(category),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 13,
                                    ),
                                    label: Text(
                                      isSaving ? 'Kaydediliyor...' : 'Düzenle',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF8B5CF6),
                                      side: const BorderSide(
                                        color: Color(0xFF8B5CF6),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Switch(
                                  value: isActive,
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  activeThumbColor: Colors.white,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: isSaving
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _appCategories[index] = {
                                              ...category,
                                              'is_active': val,
                                            };
                                          });
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagedCategoriesTab() {
    if (_isLoadingManagedCategories && _managedCategories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
            SizedBox(height: 16),
            Text(
              'Kategoriler yükleniyor...',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFFFAF9FF),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mobil Kategoriler',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1035),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_managedCategories.length} ana kategori • 512×512 px görsel önerilir',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _fetchManagedCategories,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _showManagedCategoryDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Kategori'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEDE9F6)),
        Expanded(
          child: _managedCategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Icon(
                          Icons.category_outlined,
                          size: 40,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz kategori bulunamadı',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Yeni kategori ekleyerek başlayın.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  itemCount: _managedCategories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final category = _managedCategories[index];
                    return _buildManagedCategoryCard(category);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildManagedCategoryCard(MobileCategoryNode category) {
    final cardKey = _managedCategoryKey(category);
    final isSaving = _savingManagedCategoryKeys.contains(cardKey);

    return ManagedCategoryCard(
      category: category,
      isSaving: isSaving,
      onToggleActive: isSaving
          ? null
          : (value) => _toggleManagedCategoryActive(category, value: value),
      onEditTap: isSaving
          ? null
          : () => _showManagedCategoryDialog(existing: category),
      onAddSubCategoryTap: () => _showManagedCategoryDialog(parent: category),
      onDeleteTap: isSaving
          ? null
          : () => _confirmDeleteManagedCategory(category),
      subCategoryCards: category.subCategories
          .map(
            (subCategory) => _buildManagedSubCategoryCard(
              parent: category,
              subCategory: subCategory,
            ),
          )
          .toList(),
    );
  }

  Widget _buildManagedSubCategoryCard({
    required MobileCategoryNode parent,
    required MobileCategoryNode subCategory,
  }) {
    final cardKey = _managedCategoryKey(subCategory, parent: parent);
    final isSaving = _savingManagedCategoryKeys.contains(cardKey);

    return ManagedSubCategoryCard(
      subCategory: subCategory,
      isSaving: isSaving,
      onEditTap: isSaving
          ? null
          : () => _showManagedCategoryDialog(
              existing: subCategory,
              parent: parent,
            ),
      onDeleteTap: isSaving
          ? null
          : () => _confirmDeleteManagedCategory(subCategory, parent: parent),
    );
  }
}
