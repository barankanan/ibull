import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data'; // Added for Uint8List
import 'package:image_picker/image_picker.dart';
import '../../core/mobile_category_catalog.dart';
import '../../models/admin_permissions.dart';
import '../../models/db_category.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/store_service.dart';
import '../seller_login_page.dart';
import '../../features/admin/panel/helpers/admin_panel_access_helpers.dart';
import '../../features/admin/panel/models/admin_panel_definitions.dart';
import '../../features/admin/panel/widgets/admin_panel_shell.dart';
import '../../features/admin/panel/widgets/admin_panel_content_router.dart';
import '../../features/admin/panel/widgets/admin_login_required_state.dart';
import '../../features/admin/panel/widgets/admin_panel_loading_state.dart';
import '../../features/admin/panel/widgets/admin_panel_section_label.dart';
import '../../widgets/image_cropper_widget.dart'; // Added for ImageCropperWidget

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  String _selectedMenu = 'Genel Bakış';
  String _selectedIhizMenu = 'Genel Bakış';
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;
  String _adminName = 'Admin';
  String _adminEmail = '';
  String _adminRoleLabel = 'Admin';
  Set<String> _allowedModules = <String>{};
  AdminPanelOperationMode _selectedOperationMode = AdminPanelOperationMode.ibul;
  bool _isOperationSelectorExpanded = false;

  List<AdminPanelMenuDefinition> get _visibleMenuEntries =>
      visibleAdminPanelMenus(_allowedModules);

  AdminPanelLayoutDefinition get _activeLayoutDefinition {
    switch (_selectedOperationMode) {
      case AdminPanelOperationMode.ihiz:
        return ihizAdminPanelLayoutDefinition;
      case AdminPanelOperationMode.defaultPanel:
      case AdminPanelOperationMode.ibul:
        return ibulAdminPanelLayoutDefinition;
    }
  }

  String get _activeSelectedMenu {
    switch (_selectedOperationMode) {
      case AdminPanelOperationMode.ihiz:
        return _selectedIhizMenu;
      case AdminPanelOperationMode.defaultPanel:
      case AdminPanelOperationMode.ibul:
        return _selectedMenu;
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveAdminAccess();
  }

  Future<void> _resolveAdminAccess() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _hasAdminAccess = false;
          _allowedModules = <String>{};
          _adminEmail = '';
          _adminName = 'Admin';
          _adminRoleLabel = 'Admin';
        });
        return;
      }

      final roleFuture = _authService.getUserDataField('role');
      final profileFuture = _authService.getUserProfile();
      final role = await roleFuture;
      final profile = await profileFuture;
      final accessBundle = AuthService.isAdminRole(role?.toString())
          ? await _adminService.getCurrentAdminAccessBundle()
          : const AdminAccessBundle(
              roleKey: 'user',
              roleTitle: 'Kullanici',
              allowedModules: [],
              deniedModules: [],
            );
      if (!mounted) return;

      final visibleMenus = ibulAdminMenuDefinitions
          .where((entry) => accessBundle.canAccess(entry.moduleKey ?? ''))
          .toList(growable: false);
      final nextSelectedMenu = resolveAdminSelectedMenu(
        currentSelectedMenu: _selectedMenu,
        visibleMenus: visibleMenus,
      );

      setState(() {
        _hasAdminAccess = AuthService.isAdminRole(role?.toString());
        _allowedModules = accessBundle.allowedModules.toSet();
        _adminRoleLabel = accessBundle.roleTitle;
        _selectedMenu = nextSelectedMenu;
        _adminName =
            (profile?['display_name']?.toString().trim().isNotEmpty ?? false)
            ? profile!['display_name'].toString()
            : (user.email?.split('@').first ?? 'Admin');
        _adminEmail = user.email ?? '';
      });
    } catch (error, stackTrace) {
      debugPrint('AdminPanelPage _resolveAdminAccess failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasAdminAccess = false;
        _allowedModules = <String>{};
        _selectedMenu = 'Genel Bakış';
        _selectedIhizMenu = 'Genel Bakış';
        _adminRoleLabel = 'Admin';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
        });
      }
    }
  }

  Future<void> _exitAdminPanel() async {
    try {
      final restored = await _authService.restoreUserSessionAfterSellerExit();
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const AdminPanelLoadingState();
    }

    if (!_hasAdminAccess) {
      return AdminLoginRequiredState(
        onLoginTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SellerLoginPage(adminMode: true),
            ),
          );
        },
      );
    }

    if (_selectedOperationMode == AdminPanelOperationMode.ihiz) {
      return _buildAdminLayout();
    }

    if (_selectedOperationMode == AdminPanelOperationMode.ibul) {
      return _buildAdminLayout();
    }

    return _buildAdminLayout();
  }

  Widget _buildAdminLayout() {
    final layoutDefinition = _activeLayoutDefinition;
    final menuDefinitions =
        _selectedOperationMode == AdminPanelOperationMode.ihiz
        ? layoutDefinition.menuDefinitions
        : _visibleMenuEntries;

    return AdminPanelShell(
      panelTitle: layoutDefinition.panelTitle,
      menuSections: _buildMenuSections(menuDefinitions),
      adminName: _adminName,
      adminEmail: _adminEmail,
      onLogoutTap: _exitAdminPanel,
      headerTitle: _activeSelectedMenu,
      content: _selectedOperationMode == AdminPanelOperationMode.ihiz
          ? _buildIhizContent()
          : _buildContent(),
      operationSelector: _buildOperationSelector(),
      showSearch: layoutDefinition.showSearch,
      showOverviewBadge:
          _selectedOperationMode != AdminPanelOperationMode.ihiz &&
          _selectedMenu == 'Genel Bakış',
    );
  }

  String get _selectedOperationLabel {
    return adminOperationModeLabel(_selectedOperationMode, _adminRoleLabel);
  }

  Widget _buildOperationSelector() {
    return AdminOperationSelectorCard(
      selectedLabel: _selectedOperationLabel,
      isExpanded: _isOperationSelectorExpanded,
      onToggle: () {
        setState(() {
          _isOperationSelectorExpanded = !_isOperationSelectorExpanded;
        });
      },
      options: [
        _buildOperationOptionEntry('İbul', AdminPanelOperationMode.ibul),
        _buildOperationOptionEntry('İhız', AdminPanelOperationMode.ihiz),
      ],
    );
  }

  AdminOperationOptionEntry _buildOperationOptionEntry(
    String label,
    AdminPanelOperationMode mode,
  ) {
    return AdminOperationOptionEntry(
      label: label,
      isActive: _selectedOperationMode == mode,
      onTap: () {
        setState(() {
          _selectedOperationMode = mode;
          _isOperationSelectorExpanded = false;
          if (mode == AdminPanelOperationMode.ihiz) {
            _selectedIhizMenu = ihizAdminMenuDefinitions.first.title;
          }
        });
      },
    );
  }

  List<AdminPanelMenuSectionEntry> _buildMenuSections(
    List<AdminPanelMenuDefinition> definitions,
  ) {
    return buildAdminPanelMenuSectionEntries(
      definitions: definitions,
      selectedTitle: _activeSelectedMenu,
      onSelect: (title) {
        setState(() {
          if (_selectedOperationMode == AdminPanelOperationMode.ihiz) {
            _selectedIhizMenu = title;
            return;
          }
          _selectedMenu = title;
        });
      },
    );
  }

  Widget _buildContent() {
    final hasSelectedMenuAccess = _visibleMenuEntries.any(
      (entry) => entry.title == _selectedMenu,
    );
    return buildAdminPanelContent(
      selectedMenu: _selectedMenu,
      hasSelectedMenuAccess: hasSelectedMenuAccess,
      systemLayoutPage: const SystemLayoutPage(),
    );
  }

  Widget _buildIhizContent() {
    return buildIhizAdminPanelContent(selectedMenu: _selectedIhizMenu);
  }
}

// ==========================================
// SYSTEM LAYOUT PAGE (Re-integrated)
// ==========================================

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
    final isMainCategory = parent == null;
    final childCount = node.subCategories.length;
    final description = isMainCategory && childCount > 0
        ? '"${node.name}" kategorisi ve bağlı $childCount alt kategori silinecek.'
        : '"${node.name}" kaydını silmek istediğinize emin misiniz?';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kategoriyi Sil'),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteManagedCategory(node, parent: parent);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showManagedCategoryDialog({
    MobileCategoryNode? existing,
    MobileCategoryNode? parent,
  }) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final orderController = TextEditingController(
      text:
          (existing?.orderIndex ??
                  ((parent?.subCategories.length ?? _managedCategories.length) +
                      1))
              .toString(),
    );
    var isActive = existing?.isActive ?? true;
    Uint8List? selectedImage;
    var isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? (parent == null ? 'Yeni Kategori' : 'Yeni Alt Kategori')
                  : (parent == null
                        ? 'Kategori Düzenle'
                        : 'Alt Kategori Düzenle'),
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: isSaving
                        ? null
                        : () async {
                            final bytes = await _pickAndCropImageBytes(
                              ratioX: 1,
                              ratioY: 1,
                              suggestedWidth: 512,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                selectedImage = bytes;
                              });
                            }
                          },
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD8C8FF)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImage != null
                          ? Image.memory(selectedImage!, fit: BoxFit.cover)
                          : _buildManagedCategoryImage(
                              imageUrl: existing?.imageUrl,
                              fallbackAssetPath: existing?.fallbackAssetPath,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '512x512 kare görsel önerilir. Görsel seçtiğinizde aynı oranda kırpma alanı açılır.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: parent == null
                          ? 'Kategori Adı'
                          : 'Alt Kategori Adı',
                      border: const OutlineInputBorder(),
                      hintText: parent == null
                          ? 'Kategori adını yazın'
                          : 'Alt kategori adını yazın',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sıra',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isActive,
                    activeThumbColor: const Color(0xFF8B5CF6),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                  ),
                  if (parent != null)
                    Text(
                      'Üst kategori: ${parent.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final orderIndex =
                            int.tryParse(orderController.text.trim()) ??
                            existing?.orderIndex ??
                            1;
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kategori adı boş bırakılamaz.'),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        try {
                          final saved = await _saveManagedCategory(
                            draft: MobileCategoryNode(
                              id: existing?.id,
                              parentId: existing?.parentId ?? parent?.id,
                              name: name,
                              imageUrl: existing?.imageUrl,
                              iconName: existing?.iconName ?? parent?.iconName,
                              fallbackAssetPath: existing?.fallbackAssetPath,
                              orderIndex: orderIndex,
                              isActive: isActive,
                              subCategories:
                                  existing?.subCategories ?? const [],
                            ),
                            parent: parent,
                            newImageBytes: selectedImage,
                          );
                          if (!mounted || !saved || !dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
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
    final currentName = category['display_name']?.toString() ?? '';
    final nameController = TextEditingController(text: currentName);
    Uint8List? selectedImage;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final remaining = _categoryNameMaxLength - nameController.text.length;
          final imageUrl = category['image_url']?.toString();

          return AlertDialog(
            title: const Text('Kategori Düzenle'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: isSaving
                        ? null
                        : () async {
                            final bytes = await _pickAndCropImageBytes(
                              ratioX: 1,
                              ratioY: 1,
                              suggestedWidth: 512,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                selectedImage = bytes;
                              });
                            }
                          },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8C8FF)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImage != null
                          ? Image.memory(selectedImage!, fit: BoxFit.cover)
                          : (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    maxLength: _categoryNameMaxLength,
                    decoration: const InputDecoration(
                      labelText: 'Kart Adı',
                      hintText: 'Kategori adı girin',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  Text(
                    '$remaining karakter kaldı',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kategori adı boş olamaz.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                        });
                        await _saveCategoryItem(
                          category,
                          newImageBytes: selectedImage,
                          newDisplayName: newName,
                        );
                        if (!mounted || !context.mounted) return;
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Uint8List?> _pickAndCropImageBytes({
    required double ratioX,
    required double ratioY,
    required double suggestedWidth,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (image == null) return null;

      Uint8List? imageBytes = await image.readAsBytes();
      Uint8List? croppedBytes;

      if (!mounted) return null;

      await showDialog(
        context: context,
        builder: (_) => ImageCropperWidget(
          imageData: imageBytes,
          aspectRatio: ratioX / ratioY,
          suggestedWidth: suggestedWidth,
          onCropped: (croppedData) {
            croppedBytes = croppedData;
          },
        ),
      );

      return croppedBytes;
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Görsel yükleme hatası: $e')));
      }
      return null;
    }
  }

  void _showImageDetailsDialog({Map<String, dynamic>? existingImage}) {
    final titleController = TextEditingController(
      text: existingImage?['title'],
    );
    final altTextController = TextEditingController(
      text: existingImage?['alt_text'],
    );
    final linkUrlController = TextEditingController(
      text: existingImage?['link_url'],
    );
    bool isActive = existingImage?['is_active'] ?? true;

    // Local state for new uploads in this session
    Uint8List? newDesktopBytes;
    Uint8List? newMobileBytes;
    String? desktopImagePath = existingImage?['image_path'];
    String? mobileImagePath = existingImage?['mobile_image_path'];

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isWebOrLargeScreen = MediaQuery.of(context).size.width > 900;

          return AlertDialog(
            title: Text(
              existingImage == null
                  ? 'Yeni Kampanya Görseli'
                  : 'Görseli Düzenle',
            ),
            // Increase max width for better horizontal layout
            insetPadding: const EdgeInsets.all(24),
            contentPadding: const EdgeInsets.all(24),
            scrollable: true,
            content: SizedBox(
              width: isWebOrLargeScreen ? 900 : 400,
              child: isWebOrLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Side: Images
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Masaüstü Görseli (996x412)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: isSaving
                                    ? null
                                    : () async {
                                        final bytes =
                                            await _pickAndCropImageBytes(
                                              ratioX: 996,
                                              ratioY: 412,
                                              suggestedWidth: 996,
                                            );
                                        if (bytes != null) {
                                          setState(
                                            () => newDesktopBytes = bytes,
                                          );
                                        }
                                      },
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade100,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: newDesktopBytes != null
                                      ? Image.memory(
                                          newDesktopBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : (desktopImagePath != null &&
                                            desktopImagePath!.isNotEmpty)
                                      ? Image.network(
                                          desktopImagePath!,
                                          fit: BoxFit.cover,
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.add_a_photo,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Masaüstü Görseli Yükle',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Mobil Görseli (768x400)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: isSaving
                                    ? null
                                    : () async {
                                        final bytes =
                                            await _pickAndCropImageBytes(
                                              ratioX: 768,
                                              ratioY: 400,
                                              suggestedWidth: 800,
                                            );
                                        if (bytes != null) {
                                          setState(
                                            () => newMobileBytes = bytes,
                                          );
                                        }
                                      },
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade100,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: newMobileBytes != null
                                      ? Image.memory(
                                          newMobileBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : (mobileImagePath != null &&
                                            mobileImagePath!.isNotEmpty)
                                      ? Image.network(
                                          mobileImagePath!,
                                          fit: BoxFit.cover,
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.add_a_photo,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Mobil Görseli Yükle',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Side: Form Fields
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Başlık',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !isSaving,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: altTextController,
                                decoration: const InputDecoration(
                                  labelText: 'Alt Metin',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !isSaving,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: linkUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Yönlendirme Linki',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !isSaving,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SwitchListTile(
                                  title: const Text('Aktif'),
                                  value: isActive,
                                  onChanged: isSaving
                                      ? null
                                      : (val) {
                                          setState(() => isActive = val);
                                        },
                                ),
                              ),
                              if (isSaving)
                                const Padding(
                                  padding: EdgeInsets.only(top: 24.0),
                                  child: Column(
                                    children: [
                                      LinearProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text(
                                        'Kaydediliyor...',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  // Mobile Layout (Vertical)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Desktop Image
                        const Text(
                          'Masaüstü Görseli (996x412)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: isSaving
                              ? null
                              : () async {
                                  final bytes = await _pickAndCropImageBytes(
                                    ratioX: 996,
                                    ratioY: 412,
                                    suggestedWidth: 996,
                                  );
                                  if (bytes != null)
                                    setState(() => newDesktopBytes = bytes);
                                },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: newDesktopBytes != null
                                ? Image.memory(
                                    newDesktopBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (desktopImagePath != null &&
                                      desktopImagePath!.isNotEmpty)
                                ? Image.network(
                                    desktopImagePath!,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Mobile Image
                        const Text(
                          'Mobil Görseli (768x400)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: isSaving
                              ? null
                              : () async {
                                  final bytes = await _pickAndCropImageBytes(
                                    ratioX: 768,
                                    ratioY: 400,
                                    suggestedWidth: 800,
                                  );
                                  if (bytes != null)
                                    setState(() => newMobileBytes = bytes);
                                },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: newMobileBytes != null
                                ? Image.memory(
                                    newMobileBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (mobileImagePath != null &&
                                      mobileImagePath!.isNotEmpty)
                                ? Image.network(
                                    mobileImagePath!,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Başlık',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isSaving,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: altTextController,
                          decoration: const InputDecoration(
                            labelText: 'Alt Metin',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isSaving,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: linkUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Yönlendirme Linki',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isSaving,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Aktif'),
                          value: isActive,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isSaving
                              ? null
                              : (val) {
                                  setState(() => isActive = val);
                                },
                        ),
                        if (isSaving)
                          const Padding(
                            padding: EdgeInsets.only(top: 16.0),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        // Validation
                        if ((existingImage == null &&
                                newDesktopBytes == null) &&
                            (desktopImagePath == null ||
                                desktopImagePath!.isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen en az bir masaüstü görseli yükleyin.',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          isSaving = true;
                        });

                        try {
                          // Upload logic
                          final service = AdminService();

                          if (newDesktopBytes != null) {
                            final fileName =
                                'desktop_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            desktopImagePath = await service
                                .uploadCampaignImage(
                                  newDesktopBytes!,
                                  fileName,
                                );
                          }

                          if (newMobileBytes != null) {
                            final fileName =
                                'mobile_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            mobileImagePath = await service.uploadCampaignImage(
                              newMobileBytes!,
                              fileName,
                            );
                          }

                          if (desktopImagePath == null ||
                              desktopImagePath!.isEmpty) {
                            throw Exception('Görsel yüklenemedi');
                          }

                          final imageData = {
                            'id': existingImage?['id'],
                            'image_path': desktopImagePath,
                            'mobile_image_path': mobileImagePath,
                            'title': titleController.text,
                            'alt_text': altTextController.text,
                            'link_url': linkUrlController.text,
                            'is_active': isActive,
                          };

                          await service.saveCampaignImage(imageData);

                          if (context.mounted) {
                            Navigator.pop(context);
                            _fetchCampaignImages();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Kampanya görseli başarıyla kaydedildi.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            isSaving = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kaydetme hatası: $e')),
                            );
                          }
                        }
                      },
                child: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
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

      if (mounted && !silent)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değişiklikler kaydedildi')),
        );

      // Force fetch to ensure we get back the new IDs for inserted items
      // This is CRITICAL to prevent creating duplicates on next save
      setState(() => _isLoading = false);
      await _fetchHairCareLayouts();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text(
          'Bu kart tasarımını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              // ... existing delete logic ...
              // We need to implement this part, but wait, the provided code snippet has the implementation.
              // I will just paste the implementation again because I'm inside SearchReplace but I need to modify _updateLayout to include validation.

              Navigator.of(ctx).pop();
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
                    _hairCareLayouts.removeWhere(
                      (item) => item['id'] == idToDelete,
                    );
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
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
                                      child: Image.network(
                                        image['image_path'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
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
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Görseli Sil'),
                                              content: const Text(
                                                'Bu görseli silmek istediğinizden emin misiniz?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('İptal'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red.shade600,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    _deleteCampaignImage(
                                                      image['id'],
                                                    );
                                                  },
                                                  child: const Text('Sil'),
                                                ),
                                              ],
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
                                      ? Image.network(
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
                                        color: Colors.white.withOpacity(0.6),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildManagedCategoryImage(
              imageUrl: category.imageUrl,
              fallbackAssetPath: category.fallbackAssetPath,
            ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${category.subCategories.length} alt kategori • Sıra ${category.orderIndex}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aktif', style: TextStyle(fontSize: 12)),
            Switch(
              value: category.isActive,
              activeThumbColor: const Color(0xFF8B5CF6),
              onChanged: isSaving
                  ? null
                  : (value) =>
                        _toggleManagedCategoryActive(category, value: value),
            ),
          ],
        ),
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: isSaving
                    ? null
                    : () => _showManagedCategoryDialog(existing: category),
                icon: const Icon(Icons.edit_outlined),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Düzenle'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _showManagedCategoryDialog(parent: category),
                icon: const Icon(Icons.add),
                label: const Text('Alt Kategori Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: isSaving
                    ? null
                    : () => _confirmDeleteManagedCategory(category),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Sil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (category.subCategories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Bu kategori icin henuz alt kategori tanimlanmadi.',
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: category.subCategories
                  .map(
                    (subCategory) => _buildManagedSubCategoryCard(
                      parent: category,
                      subCategory: subCategory,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildManagedSubCategoryCard({
    required MobileCategoryNode parent,
    required MobileCategoryNode subCategory,
  }) {
    final cardKey = _managedCategoryKey(subCategory, parent: parent);
    final isSaving = _savingManagedCategoryKeys.contains(cardKey);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCCEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: _buildManagedCategoryImage(
                    imageUrl: subCategory.imageUrl,
                    fallbackAssetPath: subCategory.fallbackAssetPath,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subCategory.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sıra ${subCategory.orderIndex}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => _showManagedCategoryDialog(
                          existing: subCategory,
                          parent: parent,
                        ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(
                    isSaving ? '...' : 'Düzenle',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => _confirmDeleteManagedCategory(
                          subCategory,
                          parent: parent,
                        ),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Sil', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagedCategoryImage({
    String? imageUrl,
    String? fallbackAssetPath,
  }) {
    final fallback = Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildManagedCategoryAsset(fallbackAssetPath, fallback),
      );
    }

    return _buildManagedCategoryAsset(fallbackAssetPath, fallback);
  }

  Widget _buildManagedCategoryAsset(
    String? fallbackAssetPath,
    Widget fallback,
  ) {
    if (fallbackAssetPath == null || fallbackAssetPath.isEmpty) {
      return fallback;
    }

    return Image.asset(
      fallbackAssetPath,
      package: 'ibul_app',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAssetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

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

  // Use a ValueKey for the image widget to prevent unnecessary rebuilds if URL is same
  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Helper to get all selected product IDs flattened
  List<String> get _allSelectedProductIds {
    return _selectedProductIdsByStore.values.expand((e) => e).toList();
  }

  bool _isLoading = false;
  bool _isSearching = false;

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
    setState(() => _isSearching = true);
    try {
      final results = await StoreService().searchStoresByNameOrCategory(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
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
        _storeProducts.isNotEmpty)
      return;

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
                                if (val != null)
                                  setState(() => _slot = int.parse(val));
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
                                              color: Colors.black.withOpacity(
                                                0.05,
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
                                                  backgroundImage: NetworkImage(
                                                    store['logo_url'],
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
                                                    ? Colors.white.withOpacity(
                                                        0.8,
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
                                        separatorBuilder: (_, __) =>
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
                                                image: NetworkImage(
                                                  bannerUrls[index],
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
                                                                NetworkImage(
                                                                  _activeStoreForProducts!['logo_url'],
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
                                                              image: NetworkImage(
                                                                product['image_url'],
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
