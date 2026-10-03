import '../models/blog_content.dart';

/// Text blocks that can be converted without dropping the writing.
const convertibleBlockTypes = {
  BlogBlockType.paragraph,
  BlogBlockType.heading,
  BlogBlockType.list,
  BlogBlockType.quote,
};

/// Keeps the block id, inline markup and line order.
BlogBlock convertBlock(BlogBlock block, BlogBlockType next) {
  final source = block.type == BlogBlockType.list
      ? block.items.join('\n')
      : block.text;
  final lines = source.isEmpty ? <String>[''] : source.split('\n');
  return BlogBlock(
    id: block.id,
    type: next,
    text: next == BlogBlockType.list ? '' : source,
    items: next == BlogBlockType.list ? lines : const [],
    level: block.level == 3 ? 3 : 2,
    ordered: block.ordered,
    cite: next == BlogBlockType.quote ? block.cite : '',
    url: block.url,
    alt: block.alt,
    caption: block.caption,
    label: block.label,
    videoSource: block.videoSource,
    frame: block.frame,
  );
}
