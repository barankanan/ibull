import 'dart:math' as math;

/// Versioned block document shared by the editor, the reader and the preview.
///
/// Must stay in sync with `blog_content_is_safe` (SQL) and
/// `scripts/prerender_blog.py` (static HTML).
enum BlogBlockType {
  paragraph,
  heading,
  list,
  quote,
  image,
  video,
  button,
  divider,
  columns;

  static BlogBlockType? fromName(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

enum BlogVideoSource { upload, youtube, vimeo }

class BlogBlock {
  BlogBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.level = 2,
    this.ordered = false,
    List<String>? items,
    this.url = '',
    this.alt = '',
    this.caption = '',
    this.cite = '',
    this.label = '',
    this.videoSource = BlogVideoSource.upload,
    List<BlogColumn>? columns,
  }) : items = items ?? <String>[],
       columns = columns ?? <BlogColumn>[];

  final String id;
  final BlogBlockType type;
  String text;
  int level;
  bool ordered;
  List<String> items;
  String url;
  String alt;
  String caption;
  String cite;
  String label;
  BlogVideoSource videoSource;
  List<BlogColumn> columns;

  static const int minColumns = 2;
  static const int maxColumns = 4;

  factory BlogBlock.create(BlogBlockType type, {int columnCount = 2}) {
    final id = newBlockId();
    switch (type) {
      case BlogBlockType.list:
        return BlogBlock(id: id, type: type, items: ['']);
      case BlogBlockType.columns:
        return BlogBlock(
          id: id,
          type: type,
          columns: List.generate(
            columnCount.clamp(minColumns, maxColumns),
            (_) => BlogColumn(
              blocks: [BlogBlock.create(BlogBlockType.paragraph)],
            ),
          ),
        );
      default:
        return BlogBlock(id: id, type: type);
    }
  }

  static BlogBlock? fromJson(Object? raw, {bool allowColumns = true}) {
    if (raw is! Map) return null;
    final type = BlogBlockType.fromName(raw['type']?.toString());
    if (type == null) return null;
    if (type == BlogBlockType.columns && !allowColumns) return null;
    final rawColumns = raw['columns'];
    return BlogBlock(
      id: (raw['id']?.toString().trim().isNotEmpty ?? false)
          ? raw['id'].toString()
          : newBlockId(),
      type: type,
      text: raw['text']?.toString() ?? '',
      level: raw['level'] == 3 || raw['level'] == '3' ? 3 : 2,
      ordered: raw['ordered'] == true,
      items: raw['items'] is List
          ? (raw['items'] as List).map((e) => e?.toString() ?? '').toList()
          : null,
      url: raw['url']?.toString() ?? '',
      alt: raw['alt']?.toString() ?? '',
      caption: raw['caption']?.toString() ?? '',
      cite: raw['cite']?.toString() ?? '',
      label: raw['label']?.toString() ?? '',
      videoSource: BlogVideoSource.values.firstWhere(
        (s) => s.name == raw['source']?.toString(),
        orElse: () => BlogVideoSource.upload,
      ),
      columns: type == BlogBlockType.columns && rawColumns is List
          ? rawColumns
                .take(maxColumns)
                .map(BlogColumn.fromJson)
                .toList(growable: true)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id, 'type': type.name};
    switch (type) {
      case BlogBlockType.paragraph:
        json['text'] = text;
      case BlogBlockType.heading:
        json['level'] = level;
        json['text'] = text;
      case BlogBlockType.list:
        json['ordered'] = ordered;
        json['items'] = items;
      case BlogBlockType.quote:
        json['text'] = text;
        if (cite.trim().isNotEmpty) json['cite'] = cite;
      case BlogBlockType.image:
        json['url'] = url;
        json['alt'] = alt;
        if (caption.trim().isNotEmpty) json['caption'] = caption;
      case BlogBlockType.video:
        json['source'] = videoSource.name;
        json['url'] = url;
        if (caption.trim().isNotEmpty) json['caption'] = caption;
      case BlogBlockType.button:
        json['label'] = label;
        json['url'] = url;
      case BlogBlockType.divider:
        break;
      case BlogBlockType.columns:
        json['columns'] = columns.map((c) => c.toJson()).toList();
    }
    return json;
  }

  BlogBlock duplicate() {
    final json = toJson()..['id'] = newBlockId();
    if (type == BlogBlockType.columns) {
      json['columns'] = [
        for (final column in columns)
          {
            'blocks': [
              for (final block in column.blocks)
                {...block.toJson(), 'id': newBlockId()},
            ],
          },
      ];
    }
    return BlogBlock.fromJson(json)!;
  }

  static final math.Random _random = math.Random();

  static String newBlockId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(0x7fffffff).toRadixString(36);
    return 'b$stamp$salt';
  }
}

class BlogColumn {
  BlogColumn({List<BlogBlock>? blocks}) : blocks = blocks ?? <BlogBlock>[];

  final List<BlogBlock> blocks;

  static BlogColumn fromJson(Object? raw) {
    final rawBlocks = raw is Map ? raw['blocks'] : null;
    return BlogColumn(
      blocks: rawBlocks is List
          ? rawBlocks
                .map((b) => BlogBlock.fromJson(b, allowColumns: false))
                .whereType<BlogBlock>()
                .toList(growable: true)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
}

class BlogDocument {
  BlogDocument({List<BlogBlock>? blocks}) : blocks = blocks ?? <BlogBlock>[];

  static const int version = 1;

  final List<BlogBlock> blocks;

  factory BlogDocument.fromJson(Object? raw) {
    final rawBlocks = raw is Map ? raw['blocks'] : null;
    return BlogDocument(
      blocks: rawBlocks is List
          ? rawBlocks
                .map(BlogBlock.fromJson)
                .whereType<BlogBlock>()
                .toList(growable: true)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  /// All blocks including those inside column sections, in reading order.
  Iterable<BlogBlock> get flattened sync* {
    for (final block in blocks) {
      yield block;
      if (block.type == BlogBlockType.columns) {
        for (final column in block.columns) {
          yield* column.blocks;
        }
      }
    }
  }

  List<BlogHeadingEntry> get headings => [
    for (final block in blocks)
      if (block.type == BlogBlockType.heading && block.text.trim().isNotEmpty)
        BlogHeadingEntry(
          blockId: block.id,
          level: block.level,
          text: BlogInlineMarkup.plain(block.text),
        ),
  ];

  String get plainText {
    final parts = <String>[];
    for (final block in flattened) {
      for (final value in [
        block.text,
        block.caption,
        block.cite,
        block.label,
        ...block.items,
      ]) {
        final plain = BlogInlineMarkup.plain(value).trim();
        if (plain.isNotEmpty) parts.add(plain);
      }
    }
    return parts.join(' ');
  }

  static int readingMinutes(String title, String plainText) {
    final words = '$title $plainText'
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return math.max(1, (words / 200).ceil());
  }

  /// First validation problem in Turkish, or null when the document is safe.
  String? validate() {
    var count = 0;
    for (final block in flattened) {
      count++;
      if (count > 600) return 'Yazı en fazla 600 blok içerebilir.';
      final urlProblem = BlogUrlPolicy.problem(block.url);
      if (urlProblem != null) return urlProblem;
      for (final value in [block.text, block.caption, ...block.items]) {
        for (final link in BlogInlineMarkup.linkTargets(value)) {
          if (!BlogUrlPolicy.isSafe(link) || link.trim().isEmpty) {
            return 'Güvenli olmayan bağlantı: $link';
          }
        }
      }
      switch (block.type) {
        case BlogBlockType.image:
          if (block.url.trim().isEmpty) return 'Görsel bloğunda görsel yok.';
          if (block.alt.trim().isEmpty) {
            return 'Her görsel için alternatif metin girin.';
          }
        case BlogBlockType.video:
          if (block.url.trim().isEmpty) return 'Video bloğunda video yok.';
          if (block.videoSource != BlogVideoSource.upload &&
              BlogVideoLink.parse(block.url) == null) {
            return 'Video bağlantısı YouTube veya Vimeo adresi olmalı.';
          }
        case BlogBlockType.button:
          if (block.label.trim().isEmpty || block.url.trim().isEmpty) {
            return 'Buton için metin ve hedef bağlantı girin.';
          }
        case BlogBlockType.columns:
          if (block.columns.length < BlogBlock.minColumns ||
              block.columns.length > BlogBlock.maxColumns) {
            return 'Sütun bölümü 2–4 sütun içermeli.';
          }
        default:
          break;
      }
    }
    return null;
  }
}

class BlogHeadingEntry {
  const BlogHeadingEntry({
    required this.blockId,
    required this.level,
    required this.text,
  });

  final String blockId;
  final int level;
  final String text;
}

abstract final class BlogUrlPolicy {
  static final RegExp _allowed = RegExp(
    r'^(https?://[^\s/]+|mailto:\S+|/([^/\s]|$))',
    caseSensitive: false,
  );

  static bool isSafe(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return true;
    return _allowed.hasMatch(value) && !value.startsWith('//');
  }

  static String? problem(String raw) => isSafe(raw)
      ? null
      : 'Bağlantı https://, mailto: veya / ile başlamalı: ${raw.trim()}';
}

class BlogVideoLink {
  const BlogVideoLink(this.source, this.videoId);

  final BlogVideoSource source;
  final String videoId;

  static final RegExp _youtube = RegExp(
    r'^https://(?:www\.|m\.)?(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  );
  static final RegExp _vimeo = RegExp(
    r'^https://(?:www\.|player\.)?vimeo\.com/(?:video/)?(\d{6,12})',
  );

  static BlogVideoLink? parse(String raw) {
    final value = raw.trim();
    final yt = _youtube.firstMatch(value);
    if (yt != null) return BlogVideoLink(BlogVideoSource.youtube, yt[1]!);
    final vm = _vimeo.firstMatch(value);
    if (vm != null) return BlogVideoLink(BlogVideoSource.vimeo, vm[1]!);
    return null;
  }

  String get watchUrl => source == BlogVideoSource.youtube
      ? 'https://www.youtube.com/watch?v=$videoId'
      : 'https://vimeo.com/$videoId';

  String? get thumbnailUrl => source == BlogVideoSource.youtube
      ? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg'
      : null;
}

class BlogInlineSegment {
  const BlogInlineSegment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final String? link;
}

/// Minimal inline markup: `**kalın**`, `*italik*`, `[metin](https://...)`.
abstract final class BlogInlineMarkup {
  static final RegExp _token = RegExp(
    r'\*\*(.+?)\*\*|\*(.+?)\*|\[([^\]]+)\]\(([^)\s]+)\)',
  );
  static final RegExp _linkTarget = RegExp(r'\]\(([^)]*)\)');

  static List<BlogInlineSegment> parse(
    String source, {
    bool bold = false,
    bool italic = false,
    String? link,
  }) {
    final out = <BlogInlineSegment>[];
    var cursor = 0;
    for (final match in _token.allMatches(source)) {
      if (match.start > cursor) {
        out.add(
          BlogInlineSegment(
            source.substring(cursor, match.start),
            bold: bold,
            italic: italic,
            link: link,
          ),
        );
      }
      if (match[1] != null) {
        out.addAll(parse(match[1]!, bold: true, italic: italic, link: link));
      } else if (match[2] != null) {
        out.addAll(parse(match[2]!, bold: bold, italic: true, link: link));
      } else {
        final target = match[4]!;
        out.addAll(
          parse(
            match[3]!,
            bold: bold,
            italic: italic,
            link: link ?? (BlogUrlPolicy.isSafe(target) ? target : null),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      out.add(
        BlogInlineSegment(
          source.substring(cursor),
          bold: bold,
          italic: italic,
          link: link,
        ),
      );
    }
    return out;
  }

  static String plain(String source) =>
      parse(source).map((s) => s.text).join();

  static Iterable<String> linkTargets(String source) =>
      _linkTarget.allMatches(source).map((m) => m[1] ?? '');
}
