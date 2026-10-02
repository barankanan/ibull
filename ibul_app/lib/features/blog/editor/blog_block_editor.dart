import 'package:flutter/material.dart';

import '../data/blog_media_service.dart';
import '../models/blog_content.dart';
import '../widgets/blog_theme.dart';
import 'blog_columns_editor.dart';
import 'blog_editor_controls.dart';

/// Ordered list of block editors with move / duplicate / delete actions.
class BlogBlockListEditor extends StatelessWidget {
  const BlogBlockListEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
    this.allowColumns = true,
  });

  final List<BlogBlock> blocks;
  final VoidCallback onChanged;
  final bool allowColumns;

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= blocks.length) return;
    final block = blocks.removeAt(index);
    blocks.insert(target, block);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++)
          _BlockFrame(
            key: ValueKey(blocks[i].id),
            block: blocks[i],
            nested: !allowColumns,
            canMoveUp: i > 0,
            canMoveDown: i < blocks.length - 1,
            onMoveUp: () => _move(i, -1),
            onMoveDown: () => _move(i, 1),
            onDuplicate: () {
              blocks.insert(i + 1, blocks[i].duplicate());
              onChanged();
            },
            onDelete: () {
              blocks.removeAt(i);
              onChanged();
            },
            onChanged: onChanged,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: BlogAddBlockButton(
            allowColumns: allowColumns,
            compact: !allowColumns,
            onAdd: (block) {
              blocks.add(block);
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _BlockFrame extends StatelessWidget {
  const _BlockFrame({
    super.key,
    required this.block,
    required this.nested,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
    required this.onChanged,
  });

  final BlogBlock block;
  final bool nested;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final meta = blogBlockMeta[block.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BlogTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(meta.$2, size: 16, color: BlogTheme.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block.type == BlogBlockType.columns
                      ? '${block.columns.length} sütunlu bölüm'
                      : meta.$1,
                  overflow: TextOverflow.ellipsis,
                  style: BlogTheme.metaStyle.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _tool(Icons.arrow_upward, 'Yukarı taşı', canMoveUp ? onMoveUp : null),
              _tool(Icons.arrow_downward, 'Aşağı taşı', canMoveDown ? onMoveDown : null),
              _tool(Icons.copy_outlined, 'Çoğalt', onDuplicate),
              _tool(Icons.delete_outline, 'Sil', onDelete),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BlogBlockFields(block: block, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon),
      );
}

/// Field editors per block type. Writes straight into [block].
class BlogBlockFields extends StatefulWidget {
  const BlogBlockFields({super.key, required this.block, required this.onChanged});

  final BlogBlock block;
  final VoidCallback onChanged;

  @override
  State<BlogBlockFields> createState() => _BlogBlockFieldsState();
}

class _BlogBlockFieldsState extends State<BlogBlockFields> {
  final Map<String, TextEditingController> _controllers = {};
  double? _uploadProgress;
  String? _uploadError;

  BlogBlock get _b => widget.block;

  TextEditingController _c(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String initial,
    ValueChanged<String> write, {
    String? label,
    String? hint,
    int? maxLines = 1,
    TextStyle? style,
    bool inlineTools = false,
  }) {
    final controller = _c(key, initial);
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines == null ? 2 : null,
      style: style,
      onChanged: (value) {
        write(value);
        widget.onChanged();
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: label == null ? InputBorder.none : const OutlineInputBorder(),
      ),
    );
    if (!inlineTools) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlogInlineToolbar(
          controller: controller,
          onChanged: (value) {
            write(value);
            widget.onChanged();
          },
        ),
        field,
      ],
    );
  }

  Future<void> _upload(BlogMediaKind kind) async {
    setState(() {
      _uploadProgress = 0;
      _uploadError = null;
    });
    try {
      final url = await BlogMediaService.instance.pickAndUpload(
        kind,
        onProgress: (value) {
          if (mounted) setState(() => _uploadProgress = value);
        },
      );
      if (url != null) {
        _b.url = url;
        _c('url', '').text = url;
        if (kind == BlogMediaKind.video) _b.videoSource = BlogVideoSource.upload;
        widget.onChanged();
      }
    } catch (error) {
      _uploadError = error.toString();
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Widget _uploadRow(BlogMediaKind kind, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _uploadProgress != null ? null : () => _upload(kind),
            icon: const Icon(Icons.upload_outlined),
            label: Text(label),
          ),
          if (_uploadProgress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress == 0 ? null : _uploadProgress,
              color: BlogTheme.accent,
            ),
            const SizedBox(height: 4),
            Text(
              'Yükleniyor… %${((_uploadProgress ?? 0) * 100).round()}',
              style: BlogTheme.metaStyle,
            ),
          ],
          if (_uploadError != null) ...[
            const SizedBox(height: 6),
            Text(
              _uploadError!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = BlogTheme.bodyStyle(context).copyWith(fontSize: 17);
    switch (_b.type) {
      case BlogBlockType.paragraph:
        return _field('text', _b.text, (v) => _b.text = v,
            hint: 'Yazmaya başlayın…', maxLines: null, style: body, inlineTools: true);
      case BlogBlockType.heading:
        return Row(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('H2')),
                ButtonSegment(value: 3, label: Text('H3')),
              ],
              selected: {_b.level},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _b.level = value.first);
                widget.onChanged();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field('text', _b.text, (v) => _b.text = v,
                  hint: 'Alt başlık',
                  style: BlogTheme.headingStyle(context, _b.level)),
            ),
          ],
        );
      case BlogBlockType.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Maddeli')),
                ButtonSegment(value: true, label: Text('Numaralı')),
              ],
              selected: {_b.ordered},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _b.ordered = value.first);
                widget.onChanged();
              },
            ),
            const SizedBox(height: 8),
            _field('items', _b.items.join('\n'),
                (v) => _b.items = v.split('\n'),
                hint: 'Her satır bir madde', maxLines: null, style: body, inlineTools: true),
          ],
        );
      case BlogBlockType.quote:
        return Column(
          children: [
            _field('text', _b.text, (v) => _b.text = v,
                hint: 'Alıntı metni', maxLines: null,
                style: body.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            _field('cite', _b.cite, (v) => _b.cite = v, label: 'Kaynak (isteğe bağlı)'),
          ],
        );
      case BlogBlockType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_b.url.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 180,
                    child: BlogImage(url: _b.url, fit: BoxFit.contain),
                  ),
                ),
              ),
            _field('url', _b.url, (v) => _b.url = v, label: 'Görsel adresi'),
            _uploadRow(BlogMediaKind.image, 'Görsel yükle (en fazla 10 MB)'),
            const SizedBox(height: 10),
            _field('alt', _b.alt, (v) => _b.alt = v, label: 'Alternatif metin (zorunlu)'),
            const SizedBox(height: 10),
            _field('caption', _b.caption, (v) => _b.caption = v, label: 'Açıklama'),
          ],
        );
      case BlogBlockType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Dosya')),
                ButtonSegment(value: false, label: Text('YouTube / Vimeo')),
              ],
              selected: {_b.videoSource == BlogVideoSource.upload},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() {
                  _b.videoSource = value.first
                      ? BlogVideoSource.upload
                      : (BlogVideoLink.parse(_b.url)?.source ??
                            BlogVideoSource.youtube);
                });
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),
            _field('url', _b.url, (v) {
              _b.url = v;
              final link = BlogVideoLink.parse(v);
              if (link != null) _b.videoSource = link.source;
            },
                label: _b.videoSource == BlogVideoSource.upload
                    ? 'Video adresi'
                    : 'YouTube veya Vimeo bağlantısı'),
            if (_b.videoSource == BlogVideoSource.upload)
              _uploadRow(BlogMediaKind.video, 'Video yükle (mp4/webm, en fazla 30 MB)'),
            const SizedBox(height: 10),
            _field('caption', _b.caption, (v) => _b.caption = v, label: 'Açıklama'),
          ],
        );
      case BlogBlockType.button:
        return Column(
          children: [
            _field('label', _b.label, (v) => _b.label = v, label: 'Buton metni'),
            const SizedBox(height: 10),
            _field('url', _b.url, (v) => _b.url = v,
                label: 'Hedef bağlantı', hint: 'https://… veya /kategori/…'),
          ],
        );
      case BlogBlockType.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: BlogTheme.line),
        );
      case BlogBlockType.columns:
        return BlogColumnsEditor(block: _b, onChanged: () {
          setState(() {});
          widget.onChanged();
        });
    }
  }
}
