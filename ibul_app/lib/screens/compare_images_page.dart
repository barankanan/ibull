import 'package:flutter/material.dart';

import '../core/app_image_cdn.dart';
import '../core/ibul_chrome.dart';
import '../models/product_model.dart';
import '../widgets/compare_page_helpers.dart';

class CompareImagesPage extends StatelessWidget {
  const CompareImagesPage({super.key, required this.products});

  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    final isWeb = IbulChrome.isWebOf(context);
    final display = compareDisplayProducts(products, maxCount: isWeb ? 4 : 2);
    final models = compareProductsFromMaps(display);

    final body = models.isEmpty
        ? const Center(child: Text('Karşılaştırılacak ürün bulunamadı.'))
        : _ImageColumns(products: models);

    if (!isWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          centerTitle: true,
          title: const Text(
            'Ürün Görselleri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        body: body,
      );
    }

    return CompareWebShell(
      title: 'Ürün Görselleri',
      subtitle: 'Seçilen ürünlerin görselleri',
      child: body,
    );
  }
}

class _ImageColumns extends StatelessWidget {
  const _ImageColumns({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0)
              Container(width: 1, color: Colors.grey.shade300),
            Expanded(child: _ProductGallery(product: products[i])),
          ],
        ],
      ),
    );
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final images = <String>[
      for (final url in product.images)
        if (url.trim().isNotEmpty) url.trim(),
    ];
    if (images.isEmpty) {
      final primary = product.imageFor(AppImageVariant.card).trim();
      if (primary.isNotEmpty) images.add(primary);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          if (images.isEmpty)
            buildCompareProductHeaderImage(imagePath: null, height: 140)
          else
            for (var index = 0; index < images.length; index++) ...[
              KeyedSubtree(
                key: ValueKey('compare-image-${product.productId}-$index'),
                child: buildCompareProductHeaderImage(
                  imagePath: images[index],
                  height: 140,
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
