import 'dart:async';

import 'package:flutter/material.dart';

import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../models/blog_post_draft.dart';
import '../widgets/blog_article_view.dart';
import '../widgets/blog_inline_text.dart';
import '../widgets/blog_theme.dart';
import 'blog_block_editor.dart';
import 'blog_editor_settings_panel.dart';
import 'blog_unload_guard.dart';

/// Full-screen writing surface. Returns `true` when something was saved.
class BlogEditorPage extends StatefulWidget {
  const BlogEditorPage({
    super.key,
    required this.access,
    this.postId,
    this.repository,
  });

  final BlogAccess access;
  final String? postId;
  final BlogRepository? repository;

  @override
  State<BlogEditorPage> createState() => _BlogEditorPageState();
}

class _BlogEditorPageState extends State<BlogEditorPage> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  BlogPostDraft? _draft;
  BlogEditorLookups _lookups = const BlogEditorLookups();
  String _savedFingerprint = '';
  String? _loadError;
  bool _busy = false;
  bool _preview = false;
  bool _settingsOpen = true;
  bool _savedSomething = false;
  // Bumped when the whole draft is replaced so field controllers re-seed.
  int _generation = 0;
  Timer? _backupTimer;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _dirty => _draft != null && _draft!.fingerprint != _savedFingerprint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    setBlogUnloadGuard(false);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.access.isAdmin ? _repo.listAllCategories() : _repo.listCategories(),
        _repo.listTags(),
        widget.access.isAdmin
            ? _repo.listAuthors()
            : Future.value(<BlogAuthor>[
                if (widget.access.authorId != null)
                  BlogAuthor(
                    id: widget.access.authorId!,
                    displayName: widget.access.authorName ?? 'Yazar',
                    slug: '',
                  ),
              ]),
      ]);
      final lookups = BlogEditorLookups(
        categories: results[0] as List<BlogCategory>,
        tags: results[1] as List<BlogTag>,
        authors: (results[2] as List<BlogAuthor>).where((a) => a.isActive).toList(),
      );
      BlogPostDraft draft;
      DateTime? serverUpdatedAt;
      if (widget.postId != null) {
        final post = await _repo.getEditablePost(widget.postId!);
        draft = BlogPostDraft.fromPost(post);
        serverUpdatedAt = post.updatedAt;
      } else {
        draft = BlogPostDraft(
          authorId: widget.access.authorId ??
              (lookups.authors.length == 1 ? lookups.authors.first.id : null),
        );
      }
      if (!mounted) return;
      setState(() {
        _lookups = lookups;
        _draft = draft;
        _savedFingerprint = draft.fingerprint;
      });
      await _offerBackupRestore(serverUpdatedAt);
    } catch (error) {
      if (mounted) setState(() => _loadError = _message(error));
    }
  }

  Future<void> _offerBackupRestore(DateTime? serverUpdatedAt) async {
    final backup = await BlogPostDraft.readBackup(widget.postId);
    if (backup == null || !mounted) return;
    final newer =
        serverUpdatedAt == null || backup.savedAt.isAfter(serverUpdatedAt);
    if (!newer || backup.draft.fingerprint == _draft!.fingerprint) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş içerik bulundu'),
        content: Text(
          '${BlogTheme.formatDate(backup.savedAt)} tarihli, bu cihazda '
          'saklanan kaydedilmemiş bir sürüm var. Geri yüklensin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yoksay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (restore == true && mounted) {
      final current = _draft!;
      setState(() {
        _generation++;
        _draft = backup.draft
          ..id = current.id
          ..status = current.status
          ..revisionStatus = current.revisionStatus
          ..liveSlug = current.liveSlug;
      });
      _onChanged();
    } else {
      await BlogPostDraft.clearBackup(widget.postId);
    }
  }

  void _onChanged() {
    setState(() {});
    setBlogUnloadGuard(_dirty);
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(milliseconds: 800), () {
      if (_dirty) _draft?.writeBackup();
    });
  }

  String _message(Object error) => error is BlogException
      ? error.message
      : 'İşlem tamamlanamadı. İçeriğiniz bu cihazda saklandı; tekrar deneyin.';

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFC62828) : null,
      ),
    );
  }

  /// Saves when needed. Returns false (content kept) on validation/network error.
  Future<bool> _save({bool quiet = false}) async {
    final draft = _draft!;
    final problem = draft.validate();
    if (problem != null) {
      _toast(problem, error: true);
      return false;
    }
    if (!_dirty && draft.id != null) return true;
    setState(() => _busy = true);
    try {
      await draft.writeBackup();
      final previousId = draft.id;
      final saved = await _repo.savePost(draft.id, draft.toPayload());
      _apply(saved);
      await BlogPostDraft.clearBackup(previousId);
      await BlogPostDraft.clearBackup(saved.id);
      _savedSomething = true;
      if (!quiet) {
        _toast(saved.hasRevision
            ? 'Değişiklikler taslak olarak kaydedildi. Yayındaki yazı onaylanana kadar değişmez.'
            : 'Taslak kaydedildi.');
      }
      return true;
    } catch (error) {
      _toast(_message(error), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(BlogPost saved) {
    final draft = _draft!;
    draft
      ..id = saved.id
      ..slug = saved.slug
      ..status = saved.status ?? draft.status
      ..revisionStatus = saved.revisionStatus
      ..liveSlug = saved.liveSlug
      ..publishedAt = saved.publishedAt;
    _savedFingerprint = draft.fingerprint;
    setBlogUnloadGuard(false);
  }

  Future<void> _workflow(Future<BlogPost> Function(String id) action, String done) async {
    if (!await _save(quiet: true)) return;
    setState(() => _busy = true);
    try {
      final result = await action(_draft!.id!);
      _apply(result);
      _savedSomething = true;
      _toast(done);
    } catch (error) {
      _toast(_message(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text(
          'Değişiklikleriniz kaydedilmedi. Bu cihazda bir yedek tutuluyor; '
          'yine de çıkmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Düzenlemeye dön'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazı editörü')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator(color: BlogTheme.accent)
              : Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final settings = BlogEditorSettingsPanel(
      key: ValueKey('settings$_generation'),
      draft: draft,
      lookups: _lookups,
      access: widget.access,
      onChanged: _onChanged,
    );
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setBlogUnloadGuard(false);
          _savedFingerprint = draft.fingerprint;
          Navigator.of(context).pop(_savedSomething);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFFAF9FC),
        endDrawer: wide ? null : Drawer(width: 380, child: SafeArea(child: settings)),
        appBar: _appBar(draft, wide),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _preview ? _previewBody(draft) : _canvas(draft)),
            if (wide && _settingsOpen && !_preview)
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: BlogTheme.line)),
                ),
                child: settings,
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BlogPostDraft draft, bool wide) {
    final admin = widget.access.isAdmin;
    final status = draft.status;
    final revision = draft.revisionStatus;
    final statusText = [
      status.label,
      if (revision == BlogPostStatus.draft) 'kaydedilmiş değişiklik var',
      if (revision == BlogPostStatus.inReview) 'değişiklik incelemede',
      if (_dirty) 'kaydedilmedi',
    ].join(' · ');
    final canSubmit = !admin &&
        ((status != BlogPostStatus.published && status != BlogPostStatus.inReview) ||
            (status == BlogPostStatus.published && revision == BlogPostStatus.draft) ||
            _dirty);
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.id == null ? 'Yeni yazı' : 'Yazıyı düzenle',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(statusText, style: BlogTheme.metaStyle.copyWith(fontSize: 12)),
        ],
      ),
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _preview = !_preview),
          icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
          label: Text(_preview ? 'Düzenle' : 'Önizle'),
        ),
        if (draft.id != null && wide)
          TextButton(
            onPressed: () => openBlogLink(
              context,
              BlogPaths.preview(draft.id!),
              newTab: true,
            ),
            child: const Text('Önizleme sayfası'),
          ),
        TextButton(
          onPressed: _busy ? null : () => _save(),
          child: const Text('Taslağı kaydet'),
        ),
        if (canSubmit)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _workflow(_repo.submitForReview, 'İncelemeye gönderildi.'),
            child: const Text('İncelemeye gönder'),
          ),
        if (admin)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
            onPressed: _busy ? null : () => _workflow(_repo.publish, 'Yayınlandı.'),
            child: Text(status == BlogPostStatus.published ? 'Değişiklikleri yayınla' : 'Yayınla'),
          ),
        if (admin && status == BlogPostStatus.published)
          IconButton(
            tooltip: 'Yayından kaldır',
            onPressed: _busy
                ? null
                : () => _workflow(_repo.unpublish, 'Yayından kaldırıldı.'),
            icon: const Icon(Icons.unpublished_outlined),
          ),
        IconButton(
          tooltip: 'Yazı ayarları',
          onPressed: () => wide
              ? setState(() => _settingsOpen = !_settingsOpen)
              : _scaffoldKey.currentState?.openEndDrawer(),
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _canvas(BlogPostDraft draft) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            key: ValueKey('canvas$_generation'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlainField(
                initial: draft.title,
                hint: 'Başlık',
                style: BlogTheme.titleStyle(context),
                onChanged: (v) {
                  draft.title = v;
                  _onChanged();
                },
              ),
              _PlainField(
                initial: draft.subtitle,
                hint: 'Alt başlık (isteğe bağlı)',
                style: BlogTheme.subtitleStyle(context),
                onChanged: (v) {
                  draft.subtitle = v;
                  _onChanged();
                },
              ),
              const SizedBox(height: 24),
              BlogBlockListEditor(
                blocks: draft.document.blocks,
                onChanged: _onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewBody(BlogPostDraft draft) {
    final category =
        _lookups.categories.where((c) => c.id == draft.categoryId).firstOrNull;
    final author =
        _lookups.authors.where((a) => a.id == draft.authorId).firstOrNull;
    final tags = _lookups.tags.where((t) => draft.tagIds.contains(t.id)).toList();
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 64),
        child: BlogArticleView(
          post: draft.toPreviewPost(category: category, author: author, tags: tags),
          banner: const BlogPreviewBanner(),
        ),
      ),
    );
  }
}

class _PlainField extends StatefulWidget {
  const _PlainField({
    required this.initial,
    required this.hint,
    required this.style,
    required this.onChanged,
  });

  final String initial;
  final String hint;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  @override
  State<_PlainField> createState() => _PlainFieldState();
}

class _PlainFieldState extends State<_PlainField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: null,
      style: widget.style,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
        hintStyle: widget.style.copyWith(color: BlogTheme.line),
      ),
    );
  }
}
