import 'package:flutter/material.dart';

import '../blog_paths.dart';
import '../models/blog_models.dart';
import 'blog_inline_text.dart';
import 'blog_theme.dart';

String _metaLine(BlogPostSummary post) => [
  if (post.publishedAt != null) BlogTheme.formatDate(post.publishedAt),
  BlogTheme.readingLabel(post.readingMinutes),
].join(' · ');

class BlogPostCard extends StatelessWidget {
  const BlogPostCard({super.key, required this.post});

  final BlogPostSummary post;

  @override
  Widget build(BuildContext context) {
    void open() => openBlogLink(context, BlogPaths.post(post.slug));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: BlogTheme.cardImageAspect,
              child: BlogImage(
                url: post.coverUrl,
                semanticLabel: post.coverAlt ?? post.title,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (post.categoryName != null)
          Text(post.categoryName!.toUpperCase(), style: BlogTheme.chipStyle),
        const SizedBox(height: 6),
        InkWell(
          onTap: open,
          child: Text(
            post.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: BlogTheme.ink,
            ),
          ),
        ),
        if (post.excerpt != null) ...[
          const SizedBox(height: 8),
          Text(
            post.excerpt!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: BlogTheme.muted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(_metaLine(post), style: BlogTheme.metaStyle.copyWith(fontSize: 13)),
      ],
    );
  }
}

/// Wide hero for the featured post.
class BlogFeaturedCard extends StatelessWidget {
  const BlogFeaturedCard({super.key, required this.post});

  final BlogPostSummary post;

  @override
  Widget build(BuildContext context) {
    void open() => openBlogLink(context, BlogPaths.post(post.slug));
    final image = InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: BlogTheme.coverAspect,
          child: BlogImage(
            url: post.coverUrl,
            semanticLabel: post.coverAlt ?? post.title,
          ),
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          [
            'ÖNE ÇIKAN',
            if (post.categoryName != null) post.categoryName!.toUpperCase(),
          ].join('  ·  '),
          style: BlogTheme.chipStyle,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: open,
          child: Text(
            post.title,
            style: TextStyle(
              fontSize: BlogTheme.isWide(context) ? 34 : 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: BlogTheme.ink,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (post.excerpt != null) ...[
          const SizedBox(height: 12),
          Text(
            post.excerpt!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              height: 1.6,
              color: BlogTheme.muted,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          [
            if (post.authorName != null) post.authorName!,
            _metaLine(post),
          ].join(' · '),
          style: BlogTheme.metaStyle,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [image, const SizedBox(height: 18), text],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 7, child: image),
            const SizedBox(width: 40),
            Expanded(flex: 5, child: text),
          ],
        );
      },
    );
  }
}
