import 'package:flutter/material.dart';

import '../data/blog_media_service.dart';
import '../models/blog_content.dart';
import '../models/blog_image_frame.dart';
import '../widgets/blog_framed_image.dart';
import '../widgets/blog_theme.dart';
import 'blog_columns_editor.dart';
import 'blog_editor_controls.dart';
import 'blog_image_adjust_dialog.dart';

class BlogBlockFields extends StatefulWidget {
  const BlogBlockFields({
    super.key,
    required this.block,
    required this.onChanged,
    this.autofocus = false,
    this.onUndo,
  });

  final BlogBlock block;
  final VoidCallback onChanged;
  final bool autofocus;
  final void Function(VoidCallback undo)? onUndo;

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
    bool autofocus = false,
  }) {
    final controller = _c(key, initial);
    final field = TextField(
      controller: controller,
      autofocus: autofocus,
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

  Future<void> _editImage() async {
    final next = await showBlogImageAdjustDialog(
      context: context,
      url: _b.url,
      initial: _b.frame,
    );
    if (next == null || !mounted) return;
    setState(() => _b.frame = next);
    widget.onChanged();
  }

  Widget _imagePlacement() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'start', label: Text('Sol')),
            ButtonSegment(value: 'center', label: Text('Orta')),
            ButtonSegment(value: 'end', label: Text('Sağ')),
          ],
          selected: {_b.frame.align},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => _b.frame = _b.frame.copyWith(align: value.first));
            widget.onChanged();
          },
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'narrow', label: Text('Dar')),
            ButtonSegment(value: 'medium', label: Text('Orta genişlik')),
            ButtonSegment(value: 'content', label: Text('Tam')),
          ],
          selected: {_b.frame.width},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => _b.frame = _b.frame.copyWith(width: value.first));
            widget.onChanged();
          },
        ),
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
        if (kind == BlogMediaKind.image) {
          _b.frame = BlogImageFrame(originalUrl: url);
        }
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
            hint: 'Yazmaya başlayın…', maxLines: null, style: body,
            inlineTools: true, autofocus: widget.autofocus);
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
                child: InkWell(
                  onTap: _editImage,
                  child: BlogFramedImage(url: _b.url, frame: _b.frame, semanticLabel: _b.alt),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _uploadRow(BlogMediaKind.image, 'Görsel seç'),
                if (_b.url.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _editImage,
                    icon: const Icon(Icons.crop),
                    label: const Text('Görseli düzenle'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _imagePlacement(),
            _field('url', _b.url, (v) {
              _b.url = v;
              if (_b.frame.originalUrl.isEmpty) {
                _b.frame = _b.frame.copyWith(originalUrl: v.trim());
              }
            }, label: 'Görsel adresi'),
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
        return BlogColumnsEditor(
          block: _b,
          onUndo: widget.onUndo,
          onChanged: () {
            setState(() {});
            widget.onChanged();
          },
        );
    }
  }
}
