import 'package:flutter/material.dart';
import 'package:ibul_app/core/product_rich_description.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

class ProductRichDescriptionView extends StatelessWidget {
  const ProductRichDescriptionView({
    super.key,
    required this.blocks,
    this.textStyle,
    this.headingStyle,
    this.maxWidth = 760,
  });

  final List<ProductRichDescriptionBlock> blocks;
  final TextStyle? textStyle;
  final TextStyle? headingStyle;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextStyle bodyStyle = textStyle ??
        const TextStyle(
          fontSize: 13,
          color: Colors.black54,
          height: 1.7,
        );
    final TextStyle titleStyle = headingStyle ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          height: 1.4,
        );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blocks.map((ProductRichDescriptionBlock block) {
            if (block.isImage) {
              return _ImageBlock(
                block: block,
                bodyStyle: bodyStyle,
              );
            }
            if (block.isText) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  block.text ?? '',
                  style: block.isHeading ? titleStyle : bodyStyle,
                ),
              );
            }
            return const SizedBox.shrink();
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
    required this.block,
    required this.bodyStyle,
  });

  final ProductRichDescriptionBlock block;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final String url = block.url?.trim() ?? '';
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: OptimizedImage(
                imageUrlOrPath: url,
                fit: BoxFit.contain,
                errorWidget: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          if ((block.caption ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                block.caption!.trim(),
                style: bodyStyle.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else if ((block.alt ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                block.alt!.trim(),
                style: bodyStyle.copyWith(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
