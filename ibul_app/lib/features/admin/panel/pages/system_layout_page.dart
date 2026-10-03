import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../../../core/mobile_category_catalog.dart';
import '../../../../models/db_category.dart';
import '../../../../services/admin_service.dart';
import '../dialogs/category_delete_confirm_dialog.dart';
import '../dialogs/category_edit_dialog.dart';
import '../dialogs/system_layout_dialogs.dart';
import '../widgets/home_card_template_panel.dart';
import '../widgets/home_feature_sorting_panel.dart';
import '../widgets/system_layout_editor_card.dart';
import '../widgets/system_layout_managed_category_widgets.dart';
import '../widgets/system_layout_section.dart';
import 'system_layout_brand_tab.dart';
import 'system_layout_campaign_images_tab.dart';
import 'system_layout_shortcuts_tab.dart';
import '../../../coupon/screens/admin/coupon_admin_hub_page.dart';
import '../../../coupon/screens/admin/reward_wheel_settings_page.dart';

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

  List<MobileCategoryNode> _managedCategories = [];
  final Set<String> _savingManagedCategoryKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _fetchHairCareLayouts();
    _fetchManagedCategories();
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

  Future<void> _confirmDeleteManagedCategory(
    MobileCategoryNode node, {
    MobileCategoryNode? parent,
  }) async {
    int? linkedProducts;
    try {
      linkedProducts = await AdminService().countProductsForCategory(
        name: node.name,
        parentName: parent?.name,
      );
    } catch (e) {
      debugPrint('Category dependency count failed: $e');
    }
    if (!mounted) return;
    await showManagedCategoryDeleteConfirmDialog(
      context: context,
      node: node,
      parent: parent,
      linkedProductCount: linkedProducts,
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
            color: SystemLayoutColors.surface,
            border: Border(
              bottom: BorderSide(color: SystemLayoutColors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SystemLayoutColors.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_outlined,
                        color: SystemLayoutColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem Düzeni',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: SystemLayoutColors.title,
                            ),
                          ),
                          Text(
                            'Ana sayfa içerikleri, kategoriler, kuponlar ve hediye çarkı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: SystemLayoutColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: SystemLayoutColors.accent,
                unselectedLabelColor: SystemLayoutColors.muted,
                indicatorColor: SystemLayoutColors.accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: const [
                  Tab(text: 'Genel Görünüm ve Logolar'),
                  Tab(text: 'Kampanya Görselleri'),
                  Tab(text: 'Kategoriler ve Alt Kategoriler'),
                  Tab(text: 'Ana Sayfa Kısayolları'),
                  Tab(text: 'Kart Şablonları ve Bölüm Başlıkları'),
                  Tab(text: 'Ana Sayfa ve Reklam Sıralaması'),
                  Tab(text: 'Kuponlar'),
                  Tab(text: 'Hediye Çarkı'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: SystemLayoutColors.background,
            child: TabBarView(
              controller: _tabController,
              children: [
                const SystemLayoutBrandTab(),
                const SystemLayoutCampaignImagesTab(),
                _buildManagedCategoriesTab(),
                const SystemLayoutShortcutsTab(),
                const HomeCardTemplatePanel(),
                const HomeFeatureSortingPanel(),
                const CouponAdminHubPage(),
                const RewardWheelSettingsPage(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Legacy manual kart yönetimi — yeni akış Kart Şablonları sekmesinde.
  // ignore: unused_element
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
        SystemLayoutSectionHeader(
          title: 'Kategoriler ve Alt Kategoriler',
          subtitle:
              '${_managedCategories.length} ana kategori • Ürünler kategoriye adıyla bağlıdır • 512×512 görsel',
          liveNote:
              'Kaydedildiği anda müşteri kategori menüsüne yansır. Pasif kategori menüden kalkar, ürün kayıtları değişmez.',
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: _isLoadingManagedCategories
                  ? null
                  : _fetchManagedCategories,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Yenile'),
              style: systemLayoutSecondaryButtonStyle(),
            ),
          ],
          primaryAction: FilledButton.icon(
            onPressed: () => _showManagedCategoryDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Yeni Kategori'),
            style: systemLayoutPrimaryButtonStyle(),
          ),
        ),
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
