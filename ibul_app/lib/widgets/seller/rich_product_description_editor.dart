import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ibul_app/core/product_rich_description.dart';
import 'package:ibul_app/utils/pick_image_file.dart';
import 'package:ibul_app/utils/product_image_format_helper.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:ibul_app/widgets/seller/story_editor_file_drop.dart';

typedef DescriptionImageUploadCallback = Future<String?> Function(
  Uint8List bytes,
  String fileName,
);

class _StoryEditorBlockEntry {
  _StoryEditorBlockEntry({
    required this.id,
    required this.block,
  });

  final String id;
  ProductRichDescriptionBlock block;
}

/// Tek akışlı "Açıklama ve Hikaye" editörü — metin ve görseller birlikte.
class ProductDescriptionStoryEditor extends StatefulWidget {
  const ProductDescriptionStoryEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
    this.onUploadImage,
    this.pendingImages = const <String, Uint8List>{},
  });

  final List<ProductRichDescriptionBlock> blocks;
  final ValueChanged<List<ProductRichDescriptionBlock>> onChanged;
  final DescriptionImageUploadCallback? onUploadImage;
  final Map<String, Uint8List> pendingImages;

  @override
  State<ProductDescriptionStoryEditor> createState() =>
      ProductDescriptionStoryEditorState();
}

class ProductDescriptionStoryEditorState
    extends State<ProductDescriptionStoryEditor> {
  static const Duration _emitDebounce = Duration(milliseconds: 300);

  final List<_StoryEditorBlockEntry> _entries = <_StoryEditorBlockEntry>[];
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final Map<String, TextEditingController> _captionControllers =
      <String, TextEditingController>{};

  int _idCounter = 0;
  int? _focusedTextIndex;
  bool _isUploadingImage = false;
  Timer? _emitTimer;
  bool _ignoreNextWidgetSync = false;

  String _nextId() => 'story_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  List<ProductRichDescriptionBlock> _toBlocks() {
    return _entries
        .map(
          (_StoryEditorBlockEntry entry) =>
              entry.block.copyWith(id: entry.id),
        )
        .toList(growable: false);
  }

  void _syncControllerValuesToEntries() {
    for (final _StoryEditorBlockEntry entry in _entries) {
      if (entry.block.isImage) {
        entry.block = entry.block.copyWith(
          id: entry.id,
          caption: _captionControllerFor(entry).text,
        );
      } else {
        entry.block = entry.block.copyWith(
          id: entry.id,
          text: _textControllerFor(entry).text,
        );
      }
    }
  }

  /// Kayıt öncesi debounce beklemeden güncel story bloklarını döndürür.
  List<ProductRichDescriptionBlock> captureBlocksForSave() {
    _emitTimer?.cancel();
    _syncControllerValuesToEntries();
    return normalizeStoryBlocks(_toBlocks());
  }

  void _scheduleEmit({bool immediate = false}) {
    _emitTimer?.cancel();
    if (immediate) {
      _ignoreNextWidgetSync = true;
      widget.onChanged(normalizeStoryBlocks(_toBlocks()));
      return;
    }
    _emitTimer = Timer(_emitDebounce, () {
      if (!mounted) return;
      _ignoreNextWidgetSync = true;
      widget.onChanged(normalizeStoryBlocks(_toBlocks()));
    });
  }

  TextEditingController _textControllerFor(_StoryEditorBlockEntry entry) {
    return _textControllers.putIfAbsent(entry.id, () {
      return TextEditingController(text: entry.block.text ?? '');
    });
  }

  FocusNode _focusNodeFor(_StoryEditorBlockEntry entry) {
    return _focusNodes.putIfAbsent(entry.id, () => FocusNode());
  }

  TextEditingController _captionControllerFor(_StoryEditorBlockEntry entry) {
    return _captionControllers.putIfAbsent(entry.id, () {
      return TextEditingController(text: entry.block.caption ?? '');
    });
  }

  void _disposeRemovedControllers(Set<String> activeIds) {
    for (final String id in _textControllers.keys.toList()) {
      if (!activeIds.contains(id)) {
        _textControllers.remove(id)?.dispose();
        _focusNodes.remove(id)?.dispose();
      }
    }
    for (final String id in _captionControllers.keys.toList()) {
      if (!activeIds.contains(id)) {
        _captionControllers.remove(id)?.dispose();
      }
    }
  }

  void _loadFromExternalBlocks(List<ProductRichDescriptionBlock> blocks) {
    final List<ProductRichDescriptionBlock> normalized =
        normalizeStoryBlocks(blocks);
    final List<ProductRichDescriptionBlock> source = normalized.isEmpty
        ? const <ProductRichDescriptionBlock>[
            ProductRichDescriptionBlock(type: 'text', text: ''),
          ]
        : normalized;

    _entries
      ..clear()
      ..addAll(
        source.map(
          (ProductRichDescriptionBlock block) => _StoryEditorBlockEntry(
            id: block.id?.trim().isNotEmpty == true ? block.id!.trim() : _nextId(),
            block: block,
          ),
        ),
      );

    final Set<String> activeIds = _entries.map((e) => e.id).toSet();
    _disposeRemovedControllers(activeIds);

    for (final _StoryEditorBlockEntry entry in _entries) {
      if (entry.block.isImage) {
        final TextEditingController caption = _captionControllerFor(entry);
        final String nextCaption = entry.block.caption ?? '';
        if (caption.text != nextCaption) {
          caption.text = nextCaption;
        }
        continue;
      }
      final TextEditingController controller = _textControllerFor(entry);
      final String nextText = entry.block.text ?? '';
      if (controller.text != nextText) {
        controller.value = controller.value.copyWith(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
          composing: TextRange.empty,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromExternalBlocks(widget.blocks);
  }

  bool _blocksEquivalent(
    List<ProductRichDescriptionBlock> a,
    List<ProductRichDescriptionBlock> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type) return false;
      if (a[i].isImage) {
        if ((a[i].url ?? '') != (b[i].url ?? '')) return false;
        if ((a[i].caption ?? '') != (b[i].caption ?? '')) return false;
      } else {
        if ((a[i].text ?? '') != (b[i].text ?? '')) return false;
      }
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant ProductDescriptionStoryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ignoreNextWidgetSync) {
      _ignoreNextWidgetSync = false;
      return;
    }
    final List<ProductRichDescriptionBlock> incoming =
        normalizeStoryBlocks(widget.blocks);
    if (_blocksEquivalent(_toBlocks(), incoming)) {
      return;
    }
    _loadFromExternalBlocks(incoming);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emitTimer?.cancel();
    for (final TextEditingController controller in _textControllers.values) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    for (final TextEditingController controller in _captionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateTextBlock(int index, String text) {
    _entries[index].block = _entries[index].block.copyWith(text: text);
    _scheduleEmit();
  }

  void _updateImageBlock(int index, ProductRichDescriptionBlock block) {
    _entries[index].block = block;
    _scheduleEmit();
  }

  void _removeBlock(int index) {
    final _StoryEditorBlockEntry removed = _entries.removeAt(index);
    _textControllers.remove(removed.id)?.dispose();
    _focusNodes.remove(removed.id)?.dispose();
    _captionControllers.remove(removed.id)?.dispose();
    if (_entries.isEmpty) {
      _entries.add(
        _StoryEditorBlockEntry(
          id: _nextId(),
          block: const ProductRichDescriptionBlock(type: 'text', text: ''),
        ),
      );
    }
    setState(() {});
    _scheduleEmit(immediate: true);
  }

  void _moveBlock(int index, int offset) {
    final int target = index + offset;
    if (target < 0 || target >= _entries.length) return;
    final _StoryEditorBlockEntry item = _entries.removeAt(index);
    _entries.insert(target, item);
    setState(() {});
    _scheduleEmit(immediate: true);
  }

  void _insertImageBlockAt(int index, ProductRichDescriptionBlock block) {
    _entries.insert(
      index,
      _StoryEditorBlockEntry(id: _nextId(), block: block),
    );
    setState(() {});
    _scheduleEmit(immediate: true);
  }

  Future<void> _pickAndInsertImage({int? atIndex}) async {
    if (_isUploadingImage) return;
    try {
      final PickedImageFile? picked = await pickImageFile();
      if (picked == null || !mounted) return;

      final ProductImageInputValidation validation = validateProductImageInput(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!validation.isValid) {
        _showMessage(validation.errorMessage ?? 'Görsel seçilemedi.');
        return;
      }
      if (validation.lowResolutionWarning != null) {
        _showMessage(validation.lowResolutionWarning!);
      }

      setState(() => _isUploadingImage = true);

      String? url;
      if (widget.onUploadImage != null) {
        url = await widget.onUploadImage!(picked.bytes, picked.name);
      }
      if (url == null || url.trim().isEmpty) {
        if (mounted) _showMessage('Görsel eklenemedi.');
        return;
      }

      _insertImageBlockAt(
        atIndex ?? _entries.length,
        ProductRichDescriptionBlock(type: 'image', url: url, caption: ''),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        _showMessage('Görsel eklenemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _insertImageAtCursor() {
    final int? focused = _focusedTextIndex;
    if (focused == null || focused < 0 || focused >= _entries.length) {
      _pickAndInsertImage();
      return;
    }
    _pickAndInsertImage(atIndex: focused + 1);
  }

  Future<void> _handleDroppedImage(Uint8List bytes, String name) async {
    final ProductImageInputValidation validation = validateProductImageInput(
      bytes: bytes,
      fileName: name,
    );
    if (!validation.isValid) {
      _showMessage(validation.errorMessage ?? 'Görsel eklenemedi.');
      return;
    }
    if (validation.lowResolutionWarning != null) {
      _showMessage(validation.lowResolutionWarning!);
    }

    setState(() => _isUploadingImage = true);
    try {
      String? url;
      if (widget.onUploadImage != null) {
        url = await widget.onUploadImage!(bytes, name);
      }
      if (url == null || url.trim().isEmpty) return;
      _insertImageBlockAt(
        _entries.length,
        ProductRichDescriptionBlock(type: 'image', url: url, caption: ''),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildTextTile(int index, _StoryEditorBlockEntry entry) {
    final TextEditingController controller = _textControllerFor(entry);
    final FocusNode focusNode = _focusNodeFor(entry);
    return Padding(
      key: ValueKey<String>(entry.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onTap: () => _focusedTextIndex = index,
        onChanged: (String value) => _updateTextBlock(index, value),
        minLines: 4,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: 'Ürün hikayesini buraya yazın...',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(int index, _StoryEditorBlockEntry entry) {
    final ProductRichDescriptionBlock block = entry.block;
    final String? url = block.url?.trim();
    final TextEditingController captionController = _captionControllerFor(entry);
    final bool isPending = isPendingStoryImageUrl(url);
    final Uint8List? pendingBytes =
        isPending ? widget.pendingImages[url] : null;
    final bool hasRenderableImage =
        pendingBytes != null || isPersistableStoryImageUrl(url);

    return Padding(
      key: ValueKey<String>(entry.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasRenderableImage
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFFECACA),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Bu görsel açıklama içinde gösterilir',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (index > 0)
                  IconButton(
                    tooltip: 'Yukarı taşı',
                    onPressed: () => _moveBlock(index, -1),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                if (index < _entries.length - 1)
                  IconButton(
                    tooltip: 'Aşağı taşı',
                    onPressed: () => _moveBlock(index, 1),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: () => _removeBlock(index),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                ),
              ],
            ),
            if (pendingBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  pendingBytes,
                  fit: BoxFit.contain,
                  height: 180,
                  width: double.infinity,
                ),
              )
            else if (isPersistableStoryImageUrl(url))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedImage(
                  imageUrlOrPath: url!,
                  fit: BoxFit.contain,
                  height: 180,
                  width: double.infinity,
                  errorWidget: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Açıklama görseli yüklenemedi. Lütfen tekrar deneyin.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: 'Görsel açıklaması (opsiyonel)',
                isDense: true,
              ),
              onChanged: (String value) => _updateImageBlock(
                index,
                block.copyWith(id: entry.id, caption: value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoryEditorFileDropLayer(
      enabled: !_isUploadingImage,
      onFileDropped: (StoryEditorDroppedFile file) {
        _handleDroppedImage(file.bytes, file.name);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paragraflar arasında görsel kullanarak ürünü daha iyi anlatın.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploadingImage ? null : _insertImageAtCursor,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Görsel Ekle'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List<Widget>.generate(_entries.length, (int index) {
              final _StoryEditorBlockEntry entry = _entries[index];
              if (entry.block.isImage) {
                return _buildImageTile(index, entry);
              }
              return _buildTextTile(index, entry);
            }),
          ],
        ),
      ),
    );
  }
}

/// Geriye dönük import adı.
typedef RichProductDescriptionEditor = ProductDescriptionStoryEditor;
