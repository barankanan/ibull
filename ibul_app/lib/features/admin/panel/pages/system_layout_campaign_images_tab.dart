import 'package:flutter/material.dart';

import '../../../../services/admin_service.dart';
import '../../../../widgets/optimized_image.dart';
import '../dialogs/system_layout_dialogs.dart';
import '../widgets/campaign_image_preview_dialog.dart';
import '../widgets/system_layout_section.dart';

/// Ana sayfa hero slider görselleri (`campaign_images`).
class SystemLayoutCampaignImagesTab extends StatefulWidget {
  const SystemLayoutCampaignImagesTab({super.key});

  @override
  State<SystemLayoutCampaignImagesTab> createState() =>
      _SystemLayoutCampaignImagesTabState();
}

class _SystemLayoutCampaignImagesTabState
    extends State<SystemLayoutCampaignImagesTab> {
  final _service = AdminService();
  List<Map<String, dynamic>> _images = const [];
  bool _loading = true;
  String? _error;
  bool _savingOrder = false;
  final Set<Object> _savingIds = <Object>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.getCampaignImages();
      if (!mounted) return;
      setState(() {
        _images = List<Map<String, dynamic>>.from(rows);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$prefix: $error')));
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_savingOrder) return;
    final previous = List<Map<String, dynamic>>.from(_images);
    final next = List<Map<String, dynamic>>.from(_images);
    if (newIndex > oldIndex) newIndex -= 1;
    next.insert(newIndex, next.removeAt(oldIndex));
    setState(() {
      _images = next;
      _savingOrder = true;
    });
    try {
      await _service.updateCampaignImagesOrder(next);
    } catch (error) {
      if (mounted) setState(() => _images = previous);
      _showError('Sıralama kaydedilemedi', error);
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _toggleActive(int index, bool value) async {
    final image = _images[index];
    final id = image['id'] as Object;
    final updated = {...image, 'is_active': value};
    setState(() {
      _images = [..._images]..[index] = updated;
      _savingIds.add(id);
    });
    try {
      await _service.saveCampaignImage(updated);
    } catch (error) {
      if (mounted) {
        setState(() {
          final i = _images.indexWhere((row) => row['id'] == id);
          if (i >= 0) _images = [..._images]..[i] = image;
        });
      }
      _showError('Durum kaydedilemedi', error);
    } finally {
      if (mounted) setState(() => _savingIds.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> image) async {
    try {
      await _service.deleteCampaignImage(image['id'] as int);
      await _load();
    } catch (error) {
      _showError('Görsel silinemedi', error);
    }
  }

  void _openEditor({Map<String, dynamic>? existing}) {
    showCampaignImageDetailsDialog(
      context: context,
      existingImage: existing,
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
          var desktopPath = request.desktopImagePath;
          var mobilePath = request.mobileImagePath;
          final stamp = DateTime.now().millisecondsSinceEpoch;
          if (request.newDesktopBytes != null) {
            desktopPath = await _service.uploadCampaignImage(
              request.newDesktopBytes!,
              'desktop_$stamp.jpg',
            );
          }
          if (request.newMobileBytes != null) {
            mobilePath = await _service.uploadCampaignImage(
              request.newMobileBytes!,
              'mobile_$stamp.jpg',
            );
          }
          if (desktopPath == null || desktopPath.isEmpty) {
            throw Exception('Masaüstü görseli zorunludur');
          }
          await _service.saveCampaignImage({
            'id': request.existingImage?['id'],
            'image_path': desktopPath,
            'mobile_image_path': mobilePath,
            'title': request.title,
            'alt_text': request.altText,
            'link_url': request.linkUrl,
            'is_active': request.isActive,
            if (request.existingImage == null) 'sort_order': _images.length,
          });
          return true;
        } catch (error) {
          _showError('Kaydetme hatası', error);
          return false;
        }
      },
      onSaved: () {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kampanya görseli kaydedildi.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _images.where((i) => i['is_active'] != false).length;
    return ColoredBox(
      color: SystemLayoutColors.background,
      child: Column(
        children: [
          SystemLayoutSectionHeader(
            title: 'Kampanya Görselleri',
            subtitle:
                '${_images.length} görsel • $activeCount aktif • Tutamaçtan sürükleyerek sıralayın',
            liveNote:
                'Kaydedildiği anda ana sayfa slider’ında yayına girer. Masaüstü '
                '996×412, mobil 768×400 kırpılır; mobil görsel yoksa masaüstü kullanılır.',
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
            primaryAction: FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: const Text('Yeni Görsel'),
              style: systemLayoutPrimaryButtonStyle(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _images.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SystemLayoutColors.accent),
      );
    }
    if (_error != null && _images.isEmpty) {
      return SystemLayoutEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Kampanya görselleri yüklenemedi',
        message: _error!,
        action: OutlinedButton(
          onPressed: _load,
          style: systemLayoutSecondaryButtonStyle(),
          child: const Text('Tekrar dene'),
        ),
      );
    }
    if (_images.isEmpty) {
      return const SystemLayoutEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Henüz kampanya görseli yok',
        message: 'Ana sayfa slider’ında görünecek ilk görseli ekleyin.',
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      buildDefaultDragHandles: false,
      itemCount: _images.length,
      onReorder: _reorder,
      itemBuilder: (context, index) {
        final image = _images[index];
        return Padding(
          key: ValueKey(image['id'] ?? index),
          padding: const EdgeInsets.only(bottom: 10),
          child: _CampaignImageRow(
            index: index,
            image: image,
            saving: _savingIds.contains(image['id']),
            reorderEnabled: !_savingOrder,
            onPreview: () =>
                showCampaignImagePreviewDialog(context: context, image: image),
            onToggle: (value) => _toggleActive(index, value),
            onEdit: () => _openEditor(existing: image),
            onDelete: () => showCampaignImageDeleteConfirmDialog(
              context: context,
              onConfirm: () => _delete(image),
            ),
          ),
        );
      },
    );
  }
}

class _CampaignImageRow extends StatelessWidget {
  const _CampaignImageRow({
    required this.index,
    required this.image,
    required this.saving,
    required this.reorderEnabled,
    required this.onPreview,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final Map<String, dynamic> image;
  final bool saving;
  final bool reorderEnabled;
  final VoidCallback onPreview;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = image['is_active'] != false;
    final title = (image['title']?.toString() ?? '').trim();
    final link = (image['link_url']?.toString() ?? '').trim();
    final hasMobile = (image['mobile_image_path']?.toString() ?? '')
        .trim()
        .isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return _buildRow(compact, isActive, title, link, hasMobile);
      },
    );
  }

  Widget _buildRow(
    bool compact,
    bool isActive,
    String title,
    String link,
    bool hasMobile,
  ) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: SystemLayoutColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SystemLayoutColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            enabled: reorderEnabled,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: Color(0xFFB8B5C4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Tam görseli önizle',
            child: InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: compact ? 110 : 174,
                height: compact ? 46 : 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OptimizedImage(
                      imageUrlOrPath: image['image_path']?.toString() ?? '',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                    const Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(
                        Icons.zoom_in_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${title.isEmpty ? 'Başlıksız görsel' : title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: SystemLayoutColors.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  link.isEmpty ? 'Hedef bağlantı yok' : link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: SystemLayoutColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasMobile
                      ? 'Masaüstü + mobil görsel'
                      : 'Yalnızca masaüstü görseli',
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
          const SizedBox(width: 8),
          if (!compact)
            SizedBox(
              width: 64,
              child: Text(
                saving ? 'Kaydediliyor' : (isActive ? 'Aktif' : 'Pasif'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF059669)
                      : SystemLayoutColors.muted,
                ),
              ),
            ),
          Switch(
            value: isActive,
            activeTrackColor: SystemLayoutColors.accent,
            activeThumbColor: Colors.white,
            onChanged: saving ? null : onToggle,
          ),
          IconButton(
            tooltip: 'Düzenle',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: SystemLayoutColors.accent,
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
