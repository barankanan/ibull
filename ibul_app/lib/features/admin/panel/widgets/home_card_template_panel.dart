import 'package:flutter/material.dart';

import '../../../../core/mobile_category_catalog.dart';
import '../../../../ads/models/home_card_template.dart';
import '../../../../ads/services/home_card_template_service.dart';
import '../../../../models/db_category.dart';
import '../../../../services/database_helper.dart';

class HomeCardTemplatePanel extends StatefulWidget {
  const HomeCardTemplatePanel({super.key});

  @override
  State<HomeCardTemplatePanel> createState() => _HomeCardTemplatePanelState();
}

class _HomeCardTemplatePanelState extends State<HomeCardTemplatePanel> {
  final _service = HomeCardTemplateService();
  List<HomeCardTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getAllTemplates();
    if (mounted) {
      setState(() {
        _templates = items;
        _loading = false;
      });
    }
  }

  Future<void> _showEditor([HomeCardTemplate? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _HomeCardTemplateEditorDialog(existing: existing),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(HomeCardTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kart şablonunu sil?'),
        content: Text('"${t.title}" silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteTemplate(t.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Kart Şablonları',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Şablon'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _templates.isEmpty
              ? const Center(child: Text('Henüz kart şablonu yok.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    return Card(
                      child: ListTile(
                        title: Text(t.displayLabel),
                        subtitle: Text(
                          'Sıra: ${t.sortOrder} • ${t.isActive ? 'Aktif' : 'Pasif'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditor(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(t),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategorySelection {
  const _CategorySelection({this.main, this.sub});

  final DBCategory? main;
  final DBCategory? sub;

  bool get hasMain => main?.id != null;

  String get displayCategoryName {
    final mainName = main?.name.trim() ?? '';
    final subName = sub?.name.trim() ?? '';
    if (mainName.isNotEmpty && subName.isNotEmpty) {
      return '$mainName > $subName';
    }
    return mainName;
  }

  int? get resolvedCategoryId => sub?.id ?? main?.id;
}

_CategorySelection? _resolveInitialSelection(
  HomeCardTemplate? existing,
  List<CategoryWithSubcategories> groups,
) {
  if (existing == null) return null;

  final parsedId = int.tryParse(existing.categoryId ?? '');
  if (parsedId != null) {
    for (final group in groups) {
      if (group.mainCategory.id == parsedId) {
        return _CategorySelection(main: group.mainCategory);
      }
      for (final sub in group.subCategories) {
        if (sub.id == parsedId) {
          return _CategorySelection(main: group.mainCategory, sub: sub);
        }
      }
    }
  }

  final savedName = existing.categoryName?.trim();
  if (savedName != null && savedName.isNotEmpty) {
    if (savedName.contains('>')) {
      final parts = savedName.split('>').map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        final mainName = parts.first;
        final subName = parts.sublist(1).join('>').trim();
        for (final group in groups) {
          if (normalizeCategoryNameForLookup(group.mainCategory.name) ==
              normalizeCategoryNameForLookup(mainName)) {
            for (final sub in group.subCategories) {
              if (normalizeCategoryNameForLookup(sub.name) ==
                  normalizeCategoryNameForLookup(subName)) {
                return _CategorySelection(main: group.mainCategory, sub: sub);
              }
            }
            return _CategorySelection(main: group.mainCategory);
          }
        }
      }
    }

    final normalized = normalizeCategoryNameForLookup(savedName);
    for (final group in groups) {
      if (normalizeCategoryNameForLookup(group.mainCategory.name) ==
          normalized) {
        return _CategorySelection(main: group.mainCategory);
      }
      for (final sub in group.subCategories) {
        if (normalizeCategoryNameForLookup(sub.name) == normalized) {
          return _CategorySelection(main: group.mainCategory, sub: sub);
        }
      }
    }
  }

  return null;
}

class _HomeCardTemplateEditorDialog extends StatefulWidget {
  const _HomeCardTemplateEditorDialog({this.existing});

  final HomeCardTemplate? existing;

  @override
  State<_HomeCardTemplateEditorDialog> createState() =>
      _HomeCardTemplateEditorDialogState();
}

class _HomeCardTemplateEditorDialogState
    extends State<_HomeCardTemplateEditorDialog> {
  final _service = HomeCardTemplateService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _sortCtrl;

  List<CategoryWithSubcategories> _categoryGroups = [];
  DBCategory? _selectedMain;
  DBCategory? _selectedSub;
  String? _legacyCategoryLabel;
  bool _loadingCategories = true;
  String? _categoryLoadError;
  bool _isSaving = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _slugCtrl = TextEditingController(text: existing?.slug ?? '');
    _sortCtrl = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    _isActive = existing?.isActive ?? true;
    _loadCategories(existing);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _slugCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  List<DBCategory> get _mainCategories => _categoryGroups
      .map((group) => group.mainCategory)
      .toList(growable: false);

  List<DBCategory> get _subCategoriesForSelectedMain {
    final mainName = _selectedMain?.name;
    if (mainName == null || mainName.trim().isEmpty) return const [];

    final mainKey = normalizeCategoryNameForLookup(mainName);
    for (final group in _categoryGroups) {
      if (normalizeCategoryNameForLookup(group.mainCategory.name) == mainKey) {
        return group.subCategories;
      }
    }
    return const [];
  }

  Future<void> _loadCategories(HomeCardTemplate? existing) async {
    setState(() {
      _loadingCategories = true;
      _categoryLoadError = null;
      _legacyCategoryLabel = null;
    });

    try {
      final remoteDb = await DatabaseHelper.instance.getCategoriesWithSubs();
      final groups = buildSellerProductCategoryGroups(remoteDb);
      final subCount = groups.fold<int>(
        0,
        (sum, group) => sum + group.subCategories.length,
      );
      debugPrint(
        'HomeCardTemplatePanel categories '
        'roots=${groups.length} subs=$subCount '
        'roots=${groups.map((g) => g.mainCategory.name).join(', ')}',
      );

      final initial = _resolveInitialSelection(existing, groups);

      if (initial != null) {
        _selectedMain = initial.main;
        _selectedSub = initial.sub;
      } else if (existing?.categoryName?.trim().isNotEmpty == true) {
        _legacyCategoryLabel = existing!.categoryName!.trim();
      }

      if (!mounted) return;
      setState(() {
        _categoryGroups = groups;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryLoadError = 'Kategoriler yüklenemedi.';
        _loadingCategories = false;
      });
    }
  }

  void _onMainCategoryChanged(String? mainName) {
    if (mainName == null) {
      setState(() {
        _selectedMain = null;
        _selectedSub = null;
        _legacyCategoryLabel = null;
      });
      return;
    }

    final mainKey = normalizeCategoryNameForLookup(mainName);
    DBCategory? main;
    for (final group in _categoryGroups) {
      if (normalizeCategoryNameForLookup(group.mainCategory.name) == mainKey) {
        main = group.mainCategory;
        break;
      }
    }

    setState(() {
      _selectedMain = main;
      _selectedSub = null;
      _legacyCategoryLabel = null;
    });
  }

  void _onSubCategoryChanged(String? subName) {
    if (subName == null) {
      setState(() => _selectedSub = null);
      return;
    }

    final subKey = normalizeCategoryNameForLookup(subName);
    DBCategory? sub;
    for (final candidate in _subCategoriesForSelectedMain) {
      if (normalizeCategoryNameForLookup(candidate.name) == subKey) {
        sub = candidate;
        break;
      }
    }

    setState(() => _selectedSub = sub);
  }

  String _resolvedCategoryName() {
    final mainName = _selectedMain?.name.trim() ?? '';
    final subName = _selectedSub?.name.trim() ?? '';
    if (mainName.isNotEmpty && subName.isNotEmpty) {
      return '$mainName > $subName';
    }
    return mainName;
  }

  Future<void> _save() async {
    if (_loadingCategories) return;

    if (_categoryLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_categoryLoadError!)),
      );
      return;
    }

    if (_mainCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce kategori oluşturmalısınız.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final categoryName = _resolvedCategoryName();
    final categoryId = (_selectedSub?.id ?? _selectedMain?.id)?.toString();

    final slug = _slugCtrl.text.trim().isNotEmpty
        ? _slugCtrl.text.trim()
        : _slugify('$categoryName-${_titleCtrl.text.trim()}');

    final template = (widget.existing ??
            HomeCardTemplate(
              id: '',
              title: '',
              slug: '',
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      categoryId: categoryId,
      categoryName: categoryName,
      slug: slug,
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 0,
      isActive: _isActive,
    );

    try {
      await _service.saveTemplate(template);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _slugify(String value) {
    const trMap = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };
    var text = value;
    trMap.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Widget _buildCategoryFields() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_categoryLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _categoryLoadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => _loadCategories(widget.existing),
            child: const Text('Tekrar dene'),
          ),
        ],
      );
    }

    if (_mainCategories.isEmpty) {
      return Text(
        'Önce kategori oluşturmalısınız.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final subs = _subCategoriesForSelectedMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_legacyCategoryLabel != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Kayıtlı kategori: $_legacyCategoryLabel\n'
              'Lütfen geçerli bir ana kategori seçin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey('main-${_selectedMain?.name ?? 'none'}'),
          isExpanded: true,
          initialValue: _selectedMain?.name,
          decoration: const InputDecoration(
            labelText: 'Ana Kategori',
            hintText: 'Kategori seçin',
          ),
          menuMaxHeight: 280,
          items: _mainCategories
              .map(
                (cat) => DropdownMenuItem<String>(
                  value: cat.name,
                  child: Text(
                    cat.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _onMainCategoryChanged,
          validator: (_) {
            if (_selectedMain == null) {
              return 'Ana kategori seçmelisiniz.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'sub-${_selectedMain?.name ?? 'none'}-${_selectedSub?.name ?? 'none'}',
          ),
          isExpanded: true,
          initialValue: _selectedSub?.name,
          decoration: InputDecoration(
            labelText: 'Alt Kategori',
            hintText: _selectedMain == null
                ? 'Önce ana kategori seçin'
                : 'Alt kategori seçin (opsiyonel)',
          ),
          menuMaxHeight: 280,
          items: subs
              .map(
                (cat) => DropdownMenuItem<String>(
                  value: cat.name,
                  child: Text(
                    cat.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _selectedMain == null ? null : _onSubCategoryChanged,
        ),
        if (_selectedMain != null && subs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Bu kategoriye bağlı alt kategori yok.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Yeni Kart Şablonu' : 'Kart Düzenle',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Kart adı'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kart adı gerekli.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildCategoryFields(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugCtrl,
                  decoration: const InputDecoration(labelText: 'Slug (benzersiz)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortCtrl,
                  decoration: const InputDecoration(labelText: 'Sıralama önceliği'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _isSaving || _loadingCategories ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
