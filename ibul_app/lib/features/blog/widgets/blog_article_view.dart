import 'package:flutter/material.dart';

import '../blog_paths.dart';
import '../models/blog_content.dart';
import '../models/blog_image_frame.dart';
import '../models/blog_models.dart';
import 'blog_framed_image.dart';
import 'blog_block_view.dart';
import 'blog_inline_text.dart';
import 'blog_theme.dart';

/// Article header + table of contents + body. The reader page and the editor
/// preview both render through this widget.
class BlogArticleView extends StatefulWidget {
  const BlogArticleView({super.key, required this.post, this.banner});

  final BlogPost post;

  /// Optional notice above the header (e.g. "Önizleme").
  final Widget? banner;

  static const int tocMinHeadings = 3;

  @override
  State<BlogArticleView> createState() => _BlogArticleViewState();
}

class _BlogArticleViewState extends State<BlogArticleView> {
  final Map<String, GlobalKey> _headingKeys = {};

  GlobalKey _keyFor(String blockId) =>
      _headingKeys.putIfAbsent(blockId, GlobalKey.new);

  void _jumpTo(String blockId) {
    final target = _headingKeys[blockId]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final headings = post.document.headings;
    final gutter = BlogTheme.gutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.banner != null) widget.banner!,
        _Reading(
          gutter: gutter,
          child: _ArticleHeader(post: post),
        ),
        if (post.coverUrl != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BlogFramedImage(
                    url: post.coverUrl!,
                    frame: post.document.coverFrame ?? const BlogImageFrame(),
                    semanticLabel: post.coverAlt ?? post.title,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 36),
        if (headings.length >= BlogArticleView.tocMinHeadings)
          _Reading(
            gutter: gutter,
            child: _TableOfContents(headings: headings, onTap: _jumpTo),
          ),
        for (final block in post.document.blocks)
          _Reading(
            gutter: gutter,
            wide: block.type == BlogBlockType.columns,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: BlogBlockView(
                block: block,
                headingKey: block.type == BlogBlockType.heading
                    ? _keyFor(block.id)
                    : null,
              ),
            ),
          ),
        if (post.tags.isNotEmpty)
          _Reading(
            gutter: gutter,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in post.tags)
                  Chip(
                    label: Text('#${tag.name}'),
                    backgroundColor: BlogTheme.accentSoft,
                    side: BorderSide.none,
                    labelStyle: BlogTheme.chipStyle,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Centers content at reading width; column sections may use the wider page.
class _Reading extends StatelessWidget {
  const _Reading({required this.child, required this.gutter, this.wide = false});

  final Widget child;
  final double gutter;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (wide ? 1040 : BlogTheme.readingWidth) + gutter * 2,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  const _ArticleHeader({required this.post});

  final BlogPost post;

  @override
  Widget build(BuildContext context) {
    final category = post.category;
    final updated = post.updatedAt;
    final published = post.publishedAt;
    final showUpdated =
        updated != null &&
        published != null &&
        updated.difference(published).inHours >= 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Semantics(
          label: 'Konum',
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              _Crumb(label: 'Blog', path: BlogPaths.root),
              if (category != null) ...[
                const Icon(Icons.chevron_right, size: 16, color: BlogTheme.muted),
                _Crumb(
                  label: category.name,
                  path: BlogPaths.home(categorySlug: category.slug),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: SelectableText(post.title, style: BlogTheme.titleStyle(context)),
        ),
        if (post.subtitle != null) ...[
          const SizedBox(height: 14),
          SelectableText(
            post.subtitle!,
            style: BlogTheme.subtitleStyle(context),
          ),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (post.author != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: BlogTheme.accentSoft,
                    backgroundImage: post.author!.avatarUrl != null
                        ? NetworkImage(post.author!.avatarUrl!)
                        : null,
                    child: post.author!.avatarUrl == null
                        ? Text(
                            post.author!.displayName.characters.first,
                            style: const TextStyle(color: BlogTheme.accent),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.author!.displayName,
                    style: BlogTheme.metaStyle.copyWith(
                      color: BlogTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            if (published != null)
              Text(BlogTheme.formatDate(published), style: BlogTheme.metaStyle),
            if (showUpdated)
              Text(
                'Güncellendi: ${BlogTheme.formatDate(updated)}',
                style: BlogTheme.metaStyle,
              ),
            Text(
              BlogTheme.readingLabel(post.readingMinutes),
              style: BlogTheme.metaStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openBlogLink(context, path),
      child: Text(
        label,
        style: BlogTheme.chipStyle.copyWith(fontSize: 14),
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({required this.headings, required this.onTap});

  final List<BlogHeadingEntry> headings;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFE),
        border: Border.all(color: BlogTheme.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İçindekiler',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: BlogTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final heading in headings)
            InkWell(
              onTap: () => onTap(heading.blockId),
              child: Padding(
                padding: EdgeInsets.only(
                  left: heading.level == 3 ? 18 : 0,
                  top: 6,
                  bottom: 6,
                ),
                child: Text(
                  heading.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: heading.level == 2 ? BlogTheme.body : BlogTheme.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BlogPreviewBanner extends StatelessWidget {
  const BlogPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlogTheme.accentSoft,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: const Text(
        'Önizleme — bu görünüm herkese açık değildir.',
        textAlign: TextAlign.center,
        style: TextStyle(color: BlogTheme.accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}
