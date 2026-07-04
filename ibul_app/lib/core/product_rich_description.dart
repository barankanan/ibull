import 'dart:convert';

/// Ürün zengin açıklama bloğu: paragraf, görsel veya başlık.
class ProductRichDescriptionBlock {
  const ProductRichDescriptionBlock({
    required this.type,
    this.id,
    this.text,
    this.url,
    this.alt,
    this.caption,
  });

  final String type;
  final String? id;
  final String? text;
  final String? url;
  final String? alt;
  final String? caption;

  bool get isParagraph => type == 'paragraph' || type == 'text';
  bool get isImage => type == 'image';
  bool get isHeading => type == 'heading';
  bool get isText => type == 'text' || type == 'paragraph' || type == 'heading';

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{'type': type};
    if (id != null && id!.trim().isNotEmpty) {
      json['id'] = id;
    }
    if (text != null && text!.trim().isNotEmpty) {
      json['text'] = text;
    }
    if (url != null && url!.trim().isNotEmpty) {
      json['url'] = url;
    }
    if (alt != null && alt!.trim().isNotEmpty) {
      json['alt'] = alt;
    }
    if (caption != null && caption!.trim().isNotEmpty) {
      json['caption'] = caption;
    }
    return json;
  }

  factory ProductRichDescriptionBlock.fromJson(Map<String, dynamic> json) {
    return ProductRichDescriptionBlock(
      type: json['type']?.toString() ?? 'paragraph',
      id: json['id']?.toString(),
      text: json['text']?.toString(),
      url: json['url']?.toString(),
      alt: json['alt']?.toString(),
      caption: json['caption']?.toString(),
    );
  }

  ProductRichDescriptionBlock copyWith({
    String? type,
    String? id,
    String? text,
    String? url,
    String? alt,
    String? caption,
  }) {
    return ProductRichDescriptionBlock(
      type: type ?? this.type,
      id: id ?? this.id,
      text: text ?? this.text,
      url: url ?? this.url,
      alt: alt ?? this.alt,
      caption: caption ?? this.caption,
    );
  }
}

bool isPendingStoryImageUrl(String? url) =>
    (url ?? '').trim().startsWith('pending_');

bool isPersistableStoryImageUrl(String? url) {
  final String value = (url ?? '').trim();
  return value.isNotEmpty && !isPendingStoryImageUrl(value);
}

String normalizeProductDescriptionText(String? raw) {
  if (raw == null) {
    return '';
  }
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll(r'\n', '\n');
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  return text.trim();
}

List<String> splitDescriptionParagraphs(String text) {
  final String normalized = normalizeProductDescriptionText(text);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  final List<String> byBlankLine = normalized
      .split(RegExp(r'\n\s*\n'))
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (byBlankLine.length > 1) {
    return byBlankLine;
  }
  return normalized
      .split('\n')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}

List<ProductRichDescriptionBlock> parseProductRichDescriptionJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <ProductRichDescriptionBlock>[];
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    return parseProductRichDescriptionValue(decoded);
  } catch (_) {
    return const <ProductRichDescriptionBlock>[];
  }
}

List<ProductRichDescriptionBlock> parseProductRichDescriptionValue(dynamic raw) {
  if (raw is! List) {
    return const <ProductRichDescriptionBlock>[];
  }
  final List<ProductRichDescriptionBlock> blocks = <ProductRichDescriptionBlock>[];
  for (final dynamic item in raw) {
    if (item is! Map) {
      continue;
    }
    final ProductRichDescriptionBlock block =
        ProductRichDescriptionBlock.fromJson(Map<String, dynamic>.from(item));
    if (block.isImage) {
      final String url = block.url?.trim() ?? '';
      if (url.isEmpty) {
        continue;
      }
      blocks.add(block);
      continue;
    }
    if (block.isText) {
      final String text = block.text?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      blocks.add(block);
    }
  }
  return blocks;
}

List<ProductRichDescriptionBlock> normalizeStoryBlocks(
  List<ProductRichDescriptionBlock> blocks,
) {
  return blocks
      .map((ProductRichDescriptionBlock block) {
        if (block.isImage) {
          return block;
        }
        if (block.isHeading) {
          return ProductRichDescriptionBlock(
            type: 'text',
            text: block.text,
          );
        }
        if (block.isParagraph && block.type != 'text') {
          return ProductRichDescriptionBlock(
            type: 'text',
            text: block.text,
          );
        }
        return block;
      })
      .toList(growable: false);
}

List<ProductRichDescriptionBlock> storyBlocksFromPlainDescription(String? raw) {
  final String text = normalizeProductDescriptionText(raw);
  if (text.isEmpty) {
    return const <ProductRichDescriptionBlock>[];
  }
  return <ProductRichDescriptionBlock>[
    ProductRichDescriptionBlock(type: 'text', text: text),
  ];
}

List<ProductRichDescriptionBlock> extractDescriptionStoryFromSpecifications(
  String? specificationsRaw,
) {
  if (specificationsRaw == null || specificationsRaw.trim().isEmpty) {
    return const <ProductRichDescriptionBlock>[];
  }
  try {
    final dynamic decoded = jsonDecode(specificationsRaw);
    if (decoded is! Map) {
      return const <ProductRichDescriptionBlock>[];
    }
    final dynamic storyRaw = decoded['description_story_json'];
    if (storyRaw is List) {
      return normalizeStoryBlocks(parseProductRichDescriptionValue(storyRaw));
    }
    if (storyRaw is String && storyRaw.trim().isNotEmpty) {
      return normalizeStoryBlocks(parseProductRichDescriptionJson(storyRaw));
    }
    return normalizeStoryBlocks(extractRichDescriptionFromSpecifications(
      specificationsRaw,
    ));
  } catch (_) {}
  return const <ProductRichDescriptionBlock>[];
}

List<ProductRichDescriptionBlock> extractRichDescriptionFromSpecifications(
  String? specificationsRaw,
) {
  if (specificationsRaw == null || specificationsRaw.trim().isEmpty) {
    return const <ProductRichDescriptionBlock>[];
  }
  try {
    final dynamic decoded = jsonDecode(specificationsRaw);
    if (decoded is! Map) {
      return const <ProductRichDescriptionBlock>[];
    }
    final dynamic raw = decoded['rich_description_json'];
    if (raw is List) {
      return parseProductRichDescriptionValue(raw);
    }
    if (raw is String) {
      return parseProductRichDescriptionJson(raw);
    }
  } catch (_) {}
  return const <ProductRichDescriptionBlock>[];
}

String encodeRichDescriptionJson(List<ProductRichDescriptionBlock> blocks) {
  return jsonEncode(blocks.map((ProductRichDescriptionBlock b) => b.toJson()).toList());
}

String richDescriptionPlainText(List<ProductRichDescriptionBlock> blocks) {
  final List<String> parts = <String>[];
  for (final ProductRichDescriptionBlock block in blocks) {
    if (block.isImage) {
      continue;
    }
    final String text = block.text?.trim() ?? '';
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }
  return parts.join('\n\n');
}

String storyDescriptionPlainText(List<ProductRichDescriptionBlock> blocks) =>
    richDescriptionPlainText(normalizeStoryBlocks(blocks));

List<Map<String, dynamic>> encodeDescriptionStoryJson(
  List<ProductRichDescriptionBlock> blocks,
) {
  return normalizeStoryBlocks(blocks)
      .map((ProductRichDescriptionBlock block) {
        if (block.isImage) {
          final String url = block.url?.trim() ?? '';
          if (!isPersistableStoryImageUrl(url)) {
            return null;
          }
          return <String, dynamic>{
            'type': 'image',
            if ((block.id ?? '').trim().isNotEmpty) 'id': block.id!.trim(),
            'url': url,
            if ((block.caption ?? '').trim().isNotEmpty)
              'caption': block.caption!.trim(),
          };
        }
        return <String, dynamic>{
          'type': 'text',
          if ((block.id ?? '').trim().isNotEmpty) 'id': block.id!.trim(),
          'text': block.text ?? '',
        };
      })
      .whereType<Map<String, dynamic>>()
      .where((Map<String, dynamic> item) {
        if (item['type'] == 'image') {
          return (item['url']?.toString().trim().isNotEmpty ?? false);
        }
        return (item['text']?.toString().trim().isNotEmpty ?? false);
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> encodeLegacyRichDescriptionJson(
  List<ProductRichDescriptionBlock> blocks,
) {
  return normalizeStoryBlocks(blocks)
      .map((ProductRichDescriptionBlock block) {
        if (block.isImage) {
          return block.toJson();
        }
        return ProductRichDescriptionBlock(
          type: 'paragraph',
          text: block.text,
        ).toJson();
      })
      .toList(growable: false);
}

void applyDescriptionStoryToSpecifications(
  Map<String, dynamic> specs,
  List<ProductRichDescriptionBlock> blocks,
) {
  final List<ProductRichDescriptionBlock> normalized =
      normalizeStoryBlocks(blocks);
  if (normalized.isEmpty) {
    specs.remove('description_story_json');
    specs.remove('rich_description_json');
    return;
  }
  specs['description_story_json'] = encodeDescriptionStoryJson(normalized);
  specs['rich_description_json'] = encodeLegacyRichDescriptionJson(normalized);
}

List<ProductRichDescriptionBlock> buildRichDescriptionFromLongDescriptionAndImages({
  required String longDescription,
  required List<String> imageUrls,
  List<String> captions = const <String>[],
}) {
  final List<String> paragraphs = splitDescriptionParagraphs(longDescription);
  final List<ProductRichDescriptionBlock> blocks = <ProductRichDescriptionBlock>[];

  if (paragraphs.isEmpty && imageUrls.isEmpty) {
    return blocks;
  }

  if (paragraphs.isEmpty) {
    for (int index = 0; index < imageUrls.length; index++) {
      blocks.add(
        ProductRichDescriptionBlock(
          type: 'image',
          url: imageUrls[index],
          alt: index < captions.length ? captions[index] : null,
          caption: index < captions.length ? captions[index] : null,
        ),
      );
    }
    return blocks;
  }

  if (imageUrls.isEmpty) {
    for (final String paragraph in paragraphs) {
      blocks.add(ProductRichDescriptionBlock(type: 'paragraph', text: paragraph));
    }
    return blocks;
  }

  final int insertEvery = (paragraphs.length / (imageUrls.length + 1))
      .ceil()
      .clamp(1, paragraphs.length);
  int imageIndex = 0;
  for (int paragraphIndex = 0; paragraphIndex < paragraphs.length; paragraphIndex++) {
    blocks.add(
      ProductRichDescriptionBlock(
        type: 'paragraph',
        text: paragraphs[paragraphIndex],
      ),
    );
    final bool shouldInsertImage =
        imageIndex < imageUrls.length &&
        ((paragraphIndex + 1) % insertEvery == 0 ||
            paragraphIndex == paragraphs.length - 1);
    if (shouldInsertImage) {
      blocks.add(
        ProductRichDescriptionBlock(
          type: 'image',
          url: imageUrls[imageIndex],
          alt: imageIndex < captions.length ? captions[imageIndex] : null,
          caption: imageIndex < captions.length ? captions[imageIndex] : null,
        ),
      );
      imageIndex++;
    }
  }

  while (imageIndex < imageUrls.length) {
    blocks.add(
      ProductRichDescriptionBlock(
        type: 'image',
        url: imageUrls[imageIndex],
        alt: imageIndex < captions.length ? captions[imageIndex] : null,
        caption: imageIndex < captions.length ? captions[imageIndex] : null,
      ),
    );
    imageIndex++;
  }

  return blocks;
}

class BulkImportDescriptionResolution {
  const BulkImportDescriptionResolution({
    required this.description,
    required this.richBlocks,
  });

  final String description;
  final List<ProductRichDescriptionBlock> richBlocks;
}

BulkImportDescriptionResolution resolveBulkImportDescriptionFields(
  Map<String, String> values, {
  required String Function(String? raw) normalizeDescription,
  required String Function(Map<String, String> values, String key) readField,
  required List<String> Function(String? value) parsePipeSeparated,
}) {
  final String richJson = readField(values, 'rich_description_json');
  final String longDescription =
      normalizeDescription(readField(values, 'long_description'));
  final String plainDescription =
      normalizeDescription(readField(values, 'description'));
  final List<String> imageUrls =
      parsePipeSeparated(readField(values, 'description_image_urls'));
  final List<String> captions =
      parsePipeSeparated(readField(values, 'description_image_captions'));

  List<ProductRichDescriptionBlock> richBlocks =
      parseProductRichDescriptionJson(richJson);
  richBlocks = normalizeStoryBlocks(richBlocks);
  if (richBlocks.isEmpty &&
      (longDescription.isNotEmpty || imageUrls.isNotEmpty)) {
    richBlocks = normalizeStoryBlocks(
      buildRichDescriptionFromLongDescriptionAndImages(
        longDescription: longDescription.isNotEmpty
            ? longDescription
            : plainDescription,
        imageUrls: imageUrls,
        captions: captions,
      ),
    );
  }

  String description = plainDescription;
  if (description.isEmpty && longDescription.isNotEmpty) {
    description = longDescription;
  }
  if (description.isEmpty && richBlocks.isNotEmpty) {
    description = richDescriptionPlainText(richBlocks);
  }

  return BulkImportDescriptionResolution(
    description: description,
    richBlocks: richBlocks,
  );
}
