import 'package:flutter/material.dart';

import '../data/blog_media_service.dart';
import '../models/blog_models.dart';
import '../models/blog_post_draft.dart';
import '../widgets/blog_theme.dart';

class BlogEditorLookups {
  const BlogEditorLookups({
    this.categories = const [],
    this.tags = const [],
    this.authors = const [],
  });

  final List<BlogCategory> categories;
  final List<BlogTag> tags;
  final List<BlogAuthor> authors;
}

class BlogEditorSettingsPanel extends StatefulWidget {
  const BlogEditorSettingsPanel({
    super.key,
    required this.draft,
    required this.lookups,
    required this.access,
    required this.onChanged,
  });

  final BlogPostDraft draft;
  final BlogEditorLookups lookups;
  final BlogAccess access;
  final VoidCallback onChanged;

  @override
  State<BlogEditorSettingsPanel> createState() =>
      _BlogEditorSettingsPanelState();
}

class _BlogEditorSettingsPanelState extends State<BlogEditorSettingsPanel> {
  final Map<String, TextEditingController> _controllers = {};
  double? _coverProgress;
  String? _coverError;

  BlogPostDraft get _d => widget.draft;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  Widget _text(
    String key,
    String initial,
    ValueChanged<String> write,
    String label, {
    String? helper,
    int maxLines = 1,
    int? maxLength,
  }) {
    final controller = _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: (value) {
          write(value);
          _changed();
        },
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _uploadCover() async {
    setState(() {
      _coverProgress = 0;
      _coverError = null;
    });
    try {
      final url = await BlogMediaService.instance.pickAndUpload(
        BlogMediaKind.image,
        onProgress: (value) {
          if (mounted) setState(() => _coverProgress = value);
        },
      );
      if (url != null) {
        _d.coverUrl = url;
        _controllers['cover_url']?.text = url;
        widget.onChanged();
      }
    } catch (error) {
      _coverError = error.toString();
    } finally {
      if (mounted) setState(() => _coverProgress = null);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _d.publishedAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    _d.publishedAt = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );
    _changed();
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: BlogTheme.muted,
        letterSpacing: 0.4,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lookups = widget.lookups;
    final admin = widget.access.isAdmin;
    final categoryIds = lookups.categories.map((c) => c.id).toSet();
    final authorIds = lookups.authors.map((a) => a.id).toSet();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      children: [
        _section('YAZI BİLGİLERİ'),
        _text('slug', _d.slug, (v) => _d.slug = v, 'URL (slug)',
            helper: '/blog/${_d.effectiveSlug.isEmpty ? '…' : _d.effectiveSlug}'
                '${_d.liveSlug != null && _d.liveSlug != _d.effectiveSlug ? '\nYayınlanınca eski adres yeni adrese yönlenir.' : ''}'),
        _text('excerpt', _d.excerpt, (v) => _d.excerpt = v, 'Kısa özet',
            maxLines: 3, maxLength: 600),
        _section('KAPAK GÖRSELİ'),
        if (_d.coverUrl.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: BlogTheme.coverAspect,
                child: BlogImage(url: _d.coverUrl),
              ),
            ),
          ),
        _text('cover_url', _d.coverUrl, (v) => _d.coverUrl = v, 'Kapak görseli adresi'),
        OutlinedButton.icon(
          onPressed: _coverProgress != null ? null : _uploadCover,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Kapak yükle'),
        ),
        if (_coverProgress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: _coverProgress == 0 ? null : _coverProgress,
              color: BlogTheme.accent,
            ),
          ),
        if (_coverError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _coverError!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ),
        const SizedBox(height: 14),
        _text('cover_alt', _d.coverAlt, (v) => _d.coverAlt = v,
            'Kapak alternatif metni'),
        _section('KONU'),
        DropdownButtonFormField<String?>(
          initialValue: categoryIds.contains(_d.categoryId) ? _d.categoryId : null,
          decoration: const InputDecoration(
            labelText: 'Kategori',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Kategorisiz')),
            for (final category in lookups.categories)
              DropdownMenuItem(value: category.id, child: Text(category.name)),
          ],
          onChanged: (value) {
            _d.categoryId = value;
            _changed();
          },
        ),
        const SizedBox(height: 12),
        if (lookups.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in lookups.tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: _d.tagIds.contains(tag.id),
                  selectedColor: BlogTheme.accentSoft,
                  onSelected: (selected) {
                    selected ? _d.tagIds.add(tag.id) : _d.tagIds.remove(tag.id);
                    _changed();
                  },
                ),
            ],
          )
        else
          const Text('Henüz etiket yok.', style: BlogTheme.metaStyle),
        const SizedBox(height: 14),
        _section('YAYIN'),
        if (admin)
          DropdownButtonFormField<String?>(
            initialValue: authorIds.contains(_d.authorId) ? _d.authorId : null,
            decoration: const InputDecoration(
              labelText: 'Yazar',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final author in lookups.authors)
                DropdownMenuItem(
                  value: author.id,
                  child: Text(author.displayName),
                ),
            ],
            onChanged: (value) {
              _d.authorId = value;
              _changed();
            },
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(widget.access.authorName ?? 'Siz'),
            subtitle: const Text('Yazar'),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _d.isFeatured,
          onChanged: admin
              ? (value) {
                  _d.isFeatured = value;
                  _changed();
                }
              : null,
          title: const Text('Öne çıkan yazı'),
          subtitle: admin ? null : const Text('Yönetici belirler'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(
            _d.publishedAt == null
                ? 'Yayın tarihi: yayınlanınca'
                : 'Yayın tarihi: ${BlogTheme.formatDate(_d.publishedAt)}',
          ),
          subtitle: admin
              ? const Text('İleri tarih seçilirse o zamana kadar görünmez.')
              : const Text('Yönetici belirler'),
          onTap: admin ? _pickDate : null,
          trailing: admin && _d.publishedAt != null
              ? IconButton(
                  tooltip: 'Tarihi temizle',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _d.publishedAt = null;
                    _changed();
                  },
                )
              : null,
        ),
        _section('ARAMA MOTORU'),
        _text('seo_title', _d.seoTitle, (v) => _d.seoTitle = v, 'SEO başlığı',
            helper: 'Boş bırakılırsa yazı başlığı kullanılır.', maxLength: 120),
        _text('meta_description', _d.metaDescription,
            (v) => _d.metaDescription = v, 'Meta açıklaması',
            helper: 'Boş bırakılırsa kısa özet kullanılır.',
            maxLines: 3, maxLength: 320),
      ],
    );
  }
}
