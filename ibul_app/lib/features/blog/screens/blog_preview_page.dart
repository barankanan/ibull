import 'package:flutter/material.dart';

import '../../../core/web_seo.dart';
import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../widgets/blog_article_view.dart';
import '../widgets/blog_scaffold.dart';
import '../widgets/blog_theme.dart';

/// `/blog/onizleme/:id` — saved draft/revision through the reader renderer.
/// Access is decided by `blog_get_editable_post` (owner author or blog admin).
class BlogPreviewPage extends StatefulWidget {
  const BlogPreviewPage({super.key, required this.postId, this.repository});

  final String postId;
  final BlogRepository? repository;

  @override
  State<BlogPreviewPage> createState() => _BlogPreviewPageState();
}

class _BlogPreviewPageState extends State<BlogPreviewPage> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  late final Future<BlogPost> _future = _repo.getEditablePost(widget.postId);

  @override
  void initState() {
    super.initState();
    setSeoMeta(
      title: 'Önizleme | İBUL Blog',
      canonicalPath: BlogPaths.preview(widget.postId),
      noIndex: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BlogPost>(
      future: _future,
      builder: (context, snapshot) {
        final Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 120),
            child: Center(child: CircularProgressIndicator(color: BlogTheme.accent)),
          );
        } else if (snapshot.hasError) {
          body = BlogStateMessage(
            icon: Icons.lock_outline,
            title: 'Önizleme açılamadı',
            message: snapshot.error is BlogException
                ? (snapshot.error as BlogException).message
                : 'Bu taslağı görüntüleme yetkiniz yok.',
          );
        } else {
          body = BlogArticleView(
            post: snapshot.data!,
            banner: const BlogPreviewBanner(),
          );
        }
        return BlogScaffold(slivers: [SliverToBoxAdapter(child: body)]);
      },
    );
  }
}
