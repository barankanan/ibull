import 'package:flutter/material.dart';

import '../../../../services/admin_service.dart';
import '../../../../services/home_shortcuts_fetch.dart';
import '../../../../widgets/feature_menu.dart';
import '../../../../widgets/optimized_image.dart';
import '../dialogs/home_shortcut_edit_dialog.dart';
import '../dialogs/system_layout_dialogs.dart';
import '../widgets/system_layout_section.dart';

/// Mobil ana sayfa kısayolları (`app_categories`). Bunlar ürün kategorisi
/// değildir; hedefleri uygulamadaki sabit kısayol eylemleridir.
class SystemLayoutShortcutsTab extends StatefulWidget {
  const SystemLayoutShortcutsTab({super.key});

  @override
  State<SystemLayoutShortcutsTab> createState() =>
      _SystemLayoutShortcutsTabState();
}

class _SystemLayoutShortcutsTabState extends State<SystemLayoutShortcutsTab> {
  static const int _titleMaxLength = 24;
  static const Map<String, String> _descriptions = {
    'yakin_lokasyon': 'Harita / yakındaki mağazalar',
    'urun_listele': 'Alışveriş listeleri',
    'gorsel_zeka': 'Görsel arama',
    'urun_parcala': 'Görsel arama (parça)',
    'bana_ozel': 'Kişisel öneriler bölümü',
    'hizli_yemek': 'Yemek kategorisi',
    'yapay_zeka': 'Yapay zeka asistanı',
    'yakinda': 'Yakında rafı',
    'ibul_premium': 'Yakında rafı (Premium)',
  };

  final _service = AdminService();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _savingOrder = false;
  String? _error;

  static List<HomeShortcutTarget> get _allTargets => [
    for (final c in [
      ...FeatureMenu.featureConfigs,
      ...FeatureMenu.optionalConfigs,
    ])
      HomeShortcutTarget(
        key: c.key,
        defaultLabel: c.label,
        description: _descriptions[c.key] ?? c.key,
        assetPath: c.assetPath,
      ),
  ];

  static bool _isOptional(String key) =>
      FeatureMenu.optionalConfigs.any((c) => c.key == key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Mobil menüdeki sırayla birebir aynı listeyi üretir.
  List<Map<String, dynamic>> _visibleRows(List<Map<String, dynamic>> remote) {
    final byKey = {
      for (final row in remote) row['category_key']?.toString() ?? '': row,
    };
    return [
      for (final config in FeatureMenu.resolveConfigs(remote))
        byKey[config.key] ??
            {
              'id': null,
              'category_key': config.key,
              'display_name': config.label,
              'image_url': null,
              'is_active': true,
            },
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.getAppCategories();
      final sorted = HomeShortcutsFetch.sortShortcutRows(
        rows.map(Map<String, dynamic>.from),
      );
      if (!mounted) return;
      setState(() {
        _rows = _visibleRows(sorted);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _showError(String prefix, Object error) {
    if (!mounted) return;
    final text = '$error'.contains('sort_order')
        ? '$prefix: sıra kolonu yok. 20261001_system_layout_content_hub.sql uygulanmalı.'
        : '$prefix: $error';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Map<String, dynamic> _payload(Map<String, dynamic> row, {int? sortOrder}) => {
    'id': row['id'],
    'category_key': row['category_key'],
    'display_name': row['display_name'],
    'image_url': row['image_url'],
    'is_active': row['is_active'] ?? true,
    'sort_order': ?sortOrder,
  };

  Future<void> _persistOrder(List<Map<String, dynamic>> rows) async {
    for (var i = 0; i < rows.length; i++) {
      await _service.saveAppCategory(_payload(rows[i], sortOrder: i + 1));
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_savingOrder) return;
    final previous = _rows;
    final next = [..._rows];
    if (newIndex > oldIndex) newIndex -= 1;
    next.insert(newIndex, next.removeAt(oldIndex));
    setState(() {
      _rows = next;
      _savingOrder = true;
    });
    try {
      await _persistOrder(next);
      HomeShortcutsFetch.invalidate();
    } catch (error) {
      if (mounted) setState(() => _rows = previous);
      _showError('Sıralama kaydedilemedi', error);
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<bool> _save(HomeShortcutDraft draft, {required bool isNew}) async {
    try {
      final existing = _rows.firstWhere(
        (row) => row['category_key'] == draft.targetKey,
        orElse: () => {'id': null, 'category_key': draft.targetKey},
      );
      var imageUrl = existing['image_url']?.toString();
      if (draft.newImageBytes != null) {
        imageUrl = await _service.uploadCategoryImage(
          draft.newImageBytes!,
          'cat_${draft.targetKey}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          categoryKey: draft.targetKey,
        );
      }
      final updated = {
        ...existing,
        'display_name': draft.title,
        'image_url': imageUrl,
        'is_active': draft.isActive,
      };
      if (isNew) {
        await _persistOrder([..._rows, updated]);
      } else {
        await _service.saveAppCategory(_payload(updated));
      }
      HomeShortcutsFetch.invalidate();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${draft.title} kaydedildi.')));
      }
      return true;
    } catch (error) {
      _showError('Kısayol kaydedilemedi', error);
      return false;
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool value) async {
    final key = row['category_key'];
    final updated = {...row, 'is_active': value};
    setState(() {
      _rows = [for (final r in _rows) r['category_key'] == key ? updated : r];
    });
    try {
      await _service.saveAppCategory(_payload(updated));
      HomeShortcutsFetch.invalidate();
    } catch (error) {
      if (mounted) {
        setState(() {
          _rows = [for (final r in _rows) r['category_key'] == key ? row : r];
        });
      }
      _showError('Durum kaydedilemedi', error);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? row}) async {
    final targets = _allTargets;
    final usedKeys = _rows.map((r) => r['category_key']).toSet();
    final available = row == null
        ? targets.where((t) => !usedKeys.contains(t.key)).toList()
        : targets.where((t) => t.key == row['category_key']).toList();
    if (available.isEmpty) return;
    await showHomeShortcutEditDialog(
      context: context,
      targets: available,
      initialTarget: available.first,
      initialTitle: row?['display_name']?.toString(),
      imageUrl: row?['image_url']?.toString(),
      initialActive: row?['is_active'] != false,
      isNew: row == null,
      titleMaxLength: _titleMaxLength,
      onPickAndCropImage:
          ({required ratioX, required ratioY, required suggestedWidth}) =>
              pickAndCropSystemLayoutImageBytes(
                context: context,
                ratioX: ratioX,
                ratioY: ratioY,
                suggestedWidth: suggestedWidth,
              ),
      onSave: (draft) => _save(draft, isNew: row == null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usedKeys = _rows.map((r) => r['category_key']).toSet();
    final canAdd = _allTargets.any((t) => !usedKeys.contains(t.key));
    return ColoredBox(
      color: SystemLayoutColors.background,
      child: Column(
        children: [
          SystemLayoutSectionHeader(
            title: 'Ana Sayfa Kısayolları',
            subtitle:
                '${_rows.length} kısayol • Yalnızca mobil ana sayfada görünür • Ürün kategorisi değildir',
            liveNote:
                'Kaydedildiği anda yayına girer; müşteriler ana sayfayı yeniden '
                'açtığında yeni başlık, görsel ve sıra görünür.',
            secondaryActions: [
              if (_savingOrder)
                const SizedBox(
                  height: kSystemLayoutButtonHeight,
                  child: Center(
                    child: Text(
                      'Sıra kaydediliyor…',
                      style: TextStyle(
                        fontSize: 12,
                        color: SystemLayoutColors.muted,
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Yenile'),
                style: systemLayoutSecondaryButtonStyle(),
              ),
            ],
            primaryAction: Tooltip(
              message: canAdd
                  ? 'Kullanılmayan geçerli bir hedefle kısayol ekle'
                  : 'Tüm geçerli hedefler kullanımda. Yeni hedef türü uygulama güncellemesi gerektirir.',
              child: FilledButton.icon(
                onPressed: canAdd && !_loading ? () => _openEditor() : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Kısayol'),
                style: systemLayoutPrimaryButtonStyle(),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SystemLayoutColors.accent),
      );
    }
    if (_error != null && _rows.isEmpty) {
      return SystemLayoutEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Kısayollar yüklenemedi',
        message: _error!,
        action: OutlinedButton(
          onPressed: _load,
          style: systemLayoutSecondaryButtonStyle(),
          child: const Text('Tekrar dene'),
        ),
      );
    }
    final assets = {for (final t in _allTargets) t.key: t};
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      buildDefaultDragHandles: false,
      itemCount: _rows.length,
      onReorder: _reorder,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final key = row['category_key']?.toString() ?? '';
        final target = assets[key];
        final isActive = row['is_active'] != false;
        final imageUrl = row['image_url']?.toString() ?? '';
        return Container(
          key: ValueKey(key),
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SystemLayoutColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SystemLayoutColors.border),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                enabled: !_savingOrder,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: Color(0xFFB8B5C4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: imageUrl.isNotEmpty
                      ? OptimizedImage(
                          imageUrlOrPath: imageUrl,
                          fit: BoxFit.cover,
                        )
                      : target == null
                      ? const ColoredBox(color: SystemLayoutColors.accentSoft)
                      : Image.asset(target.assetPath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['display_name']?.toString() ?? key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: SystemLayoutColors.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hedef: ${target?.description ?? key}'
                      '${_isOptional(key) ? ' • isteğe bağlı' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: SystemLayoutColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeTrackColor: SystemLayoutColors.accent,
                activeThumbColor: Colors.white,
                onChanged: (value) => _toggle(row, value),
              ),
              IconButton(
                tooltip: 'Düzenle',
                onPressed: () => _openEditor(row: row),
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: SystemLayoutColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
