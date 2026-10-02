import 'package:flutter/material.dart';

import '../../../widgets/common/video_player_widget.dart';
import '../models/blog_content.dart';
import 'blog_inline_text.dart';
import 'blog_theme.dart';

/// Renders one block of the shared document. Used by the reader page and the
/// editor preview so both show the same output.
class BlogBlockView extends StatelessWidget {
  const BlogBlockView({super.key, required this.block, this.headingKey});

  final BlogBlock block;
  final Key? headingKey;

  @override
  Widget build(BuildContext context) {
    final body = BlogTheme.bodyStyle(context);
    switch (block.type) {
      case BlogBlockType.paragraph:
        if (block.text.trim().isEmpty) return const SizedBox.shrink();
        return BlogInlineText(block.text, style: body);
      case BlogBlockType.heading:
        return Padding(
          key: headingKey,
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            header: true,
            child: BlogInlineText(
              block.text,
              style: BlogTheme.headingStyle(context, block.level),
            ),
          ),
        );
      case BlogBlockType.list:
        return _ListBlock(block: block, style: body);
      case BlogBlockType.quote:
        return _QuoteBlock(block: block);
      case BlogBlockType.image:
        return _Figure(
          caption: block.caption,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BlogImage(
              url: block.url,
              semanticLabel: block.alt,
              fit: BoxFit.contain,
            ),
          ),
        );
      case BlogBlockType.video:
        return _Figure(caption: block.caption, child: _VideoBlock(block: block));
      case BlogBlockType.button:
        if (block.label.trim().isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BlogTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => openBlogLink(context, block.url),
            child: Text(block.label),
          ),
        );
      case BlogBlockType.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: BlogTheme.line, thickness: 1),
        );
      case BlogBlockType.columns:
        return BlogColumnsView(block: block);
    }
  }
}

/// Columns side by side when there is room (≥ 200 px each); otherwise stacked
/// in column order so mobile reads first column first.
class BlogColumnsView extends StatelessWidget {
  const BlogColumnsView({super.key, required this.block});

  final BlogBlock block;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = block.columns.length;
        const gap = 28.0;
        final sideBySide =
            constraints.maxWidth >= count * 200 + (count - 1) * gap;
        final columns = [
          for (final column in block.columns)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final inner in column.blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: BlogBlockView(block: inner),
                  ),
              ],
            ),
        ];
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columns,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(child: columns[i]),
            ],
          ],
        );
      },
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({required this.block, required this.style});

  final BlogBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final items = block.items.where((i) => i.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    block.ordered ? '${i + 1}.' : '•',
                    style: style.copyWith(
                      color: BlogTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: BlogInlineText(items[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.block});

  final BlogBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 6, 0, 6),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: BlogTheme.accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlogInlineText(
            block.text,
            style: BlogTheme.bodyStyle(context).copyWith(
              fontSize: BlogTheme.isWide(context) ? 22 : 19,
              fontStyle: FontStyle.italic,
              color: BlogTheme.ink,
            ),
          ),
          if (block.cite.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('— ${block.cite}', style: BlogTheme.metaStyle),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.child, required this.caption});

  final Widget child;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: BlogTheme.coverAspect, child: child),
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          BlogInlineText(
            caption,
            style: BlogTheme.metaStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Uploaded files play inline; YouTube/Vimeo show a thumbnail card that opens
/// the provider page (no third-party iframe).
class _VideoBlock extends StatelessWidget {
  const _VideoBlock({required this.block});

  final BlogBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.url.trim().isEmpty) return const SizedBox.shrink();
    if (block.videoSource == BlogVideoSource.upload) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Colors.black,
          child: VideoPlayerWidget(videoUrl: block.url),
        ),
      );
    }
    final link = BlogVideoLink.parse(block.url);
    if (link == null) return const SizedBox.shrink();
    final provider = link.source == BlogVideoSource.youtube
        ? 'YouTube'
        : 'Vimeo';
    return Semantics(
      button: true,
      label: '$provider videosunu aç',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openBlogLink(context, link.watchUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (link.thumbnailUrl != null)
                BlogImage(url: link.thumbnailUrl)
              else
                const ColoredBox(color: BlogTheme.ink),
              const ColoredBox(color: Color(0x33000000)),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: BlogTheme.accent,
                    size: 44,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Text(
                  '$provider üzerinde izle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
