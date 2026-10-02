import 'dart:async';

import 'package:flutter/material.dart';

import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../editor/blog_editor_page.dart';
import '../models/blog_models.dart';
import '../widgets/blog_inline_text.dart';
import '../widgets/blog_theme.dart';

/// Post list for admins (all posts) and authors (own posts). The server scopes
/// rows and actions; the UI only hides what the role cannot do.
class BlogPostsManager extends StatefulWidget {
  const BlogPostsManager({super.key, required this.access, this.repository});

  final BlogAccess access;
  final BlogRepository? repository;

  @override
  State<BlogPostsManager> createState() => _BlogPostsManagerState();
}

class _BlogPostsManagerState extends State<BlogPostsManager> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  final _search = TextEditingController();
  Timer? _debounce;
  BlogPostStatus? _status;
  List<BlogAdminPostRow> _rows = const [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.listManagedPosts(
        search: _search.text,
        status: _status,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _rows = page.items;
        _total = page.total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BlogException ? error.message : 'Yazılar yüklenemedi.';
      });
    }
  }

  Future<void> _openEditor([String? id]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlogEditorPage(access: widget.access, postId: id),
      ),
    );
    if (saved == true || mounted) _reload();
  }

  Future<void> _run(String id, Future<BlogPost> Function(String) action, String done) async {
    setState(() => _busyId = id);
    try {
      await action(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text(error is BlogException ? error.message : 'İşlem başarısız.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _statusText(BlogAdminPostRow row) => [
    row.status.label,
    if (row.revisionStatus == BlogPostStatus.draft) 'değişiklik taslağı',
    if (row.revisionStatus == BlogPostStatus.inReview) 'değişiklik incelemede',
  ].join(' · ');

  Color _statusColor(BlogAdminPostRow row) {
    if (row.status == BlogPostStatus.inReview ||
        row.revisionStatus == BlogPostStatus.inReview) {
      return const Color(0xFFB45309);
    }
    return row.status == BlogPostStatus.published
        ? const Color(0xFF15803D)
        : BlogTheme.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _reload);
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Başlık veya adres ara',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            DropdownButton<BlogPostStatus?>(
              value: _status,
              hint: const Text('Tüm durumlar'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tüm durumlar')),
                for (final status in BlogPostStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) {
                _status = value;
                _reload();
              },
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Yeni yazı'),
            ),
            if (!_loading) Text('$_total yazı', style: BlogTheme.metaStyle),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                TextButton(onPressed: _reload, child: const Text('Tekrar dene')),
              ],
            ),
          )
        else if (_rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: Text('Bu filtreye uyan yazı yok.')),
          )
        else
          for (final row in _rows) _row(row),
      ],
    );
  }

  Widget _row(BlogAdminPostRow row) {
    final admin = widget.access.isAdmin;
    final busy = _busyId == row.id;
    final pending = row.status == BlogPostStatus.inReview ||
        row.revisionStatus != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlogTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title.isEmpty ? 'Başlıksız' : row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      _statusText(row),
                      style: TextStyle(
                        color: _statusColor(row),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(row.authorName ?? 'Yazar yok', style: BlogTheme.metaStyle),
                    Text(row.categoryName ?? 'Kategorisiz', style: BlogTheme.metaStyle),
                    if (row.updatedAt != null)
                      Text(
                        'Güncelleme: ${BlogTheme.formatDate(row.updatedAt)}',
                        style: BlogTheme.metaStyle,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Düzenle',
              onPressed: () => _openEditor(row.id),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Önizle',
              onPressed: () => openBlogLink(
                context,
                BlogPaths.preview(row.id),
                newTab: true,
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
            if (admin && (row.status != BlogPostStatus.published || pending))
              IconButton(
                tooltip: 'Yayınla',
                onPressed: () => _run(row.id, _repo.publish, 'Yayınlandı.'),
                icon: const Icon(Icons.publish_outlined, color: BlogTheme.accent),
              ),
            if (admin && row.status != BlogPostStatus.draft)
              IconButton(
                tooltip: row.status == BlogPostStatus.published
                    ? 'Yayından kaldır'
                    : 'Taslağa döndür',
                onPressed: () => _run(
                  row.id,
                  _repo.unpublish,
                  row.status == BlogPostStatus.published
                      ? 'Yayından kaldırıldı.'
                      : 'Taslağa döndürüldü.',
                ),
                icon: const Icon(Icons.unpublished_outlined),
              ),
          ],
        ],
      ),
    );
  }
}
