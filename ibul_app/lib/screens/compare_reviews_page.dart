import 'package:flutter/material.dart';

import '../core/ibul_chrome.dart';
import '../models/product_model.dart';
import '../widgets/compare_page_helpers.dart';

class CompareReviewsPage extends StatefulWidget {
  const CompareReviewsPage({
    super.key,
    required this.products,
    this.loadReviews,
  });

  final List<Map<String, dynamic>> products;

  /// Defaults to the product-detail review repository.
  final Future<List<Map<String, dynamic>>> Function(Product product)? loadReviews;

  @override
  State<CompareReviewsPage> createState() => _CompareReviewsPageState();
}

class _CompareReviewsPageState extends State<CompareReviewsPage> {
  late Future<List<List<Map<String, dynamic>>>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final limit = compareSelectionLimit(context);
    if (_loadedLimit == limit) return;
    _loadedLimit = limit;
    _future = _load(limit);
  }

  int? _loadedLimit;

  Future<List<List<Map<String, dynamic>>>> _load(int limit) {
    final products = compareProductsFromMaps(
      compareDisplayProducts(widget.products, maxCount: limit),
    );
    final loader = widget.loadReviews ?? loadReviewsForProduct;
    return Future.wait(products.map(loader));
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = IbulChrome.isWebOf(context);
    final display = compareDisplayProducts(
      widget.products,
      maxCount: isWeb ? 4 : 2,
    );
    final models = compareProductsFromMaps(display);
    final body = FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Yorumlar yüklenemedi.'),
                TextButton(
                  onPressed: () => setState(() => _future = _load(_loadedLimit ?? 2)),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          );
        }
        final raw = snapshot.data ?? const <List<Map<String, dynamic>>>[];
        final groups = [
          for (var i = 0; i < models.length; i++)
            reviewsForCompareProduct(
              models[i],
              i < raw.length ? raw[i] : const <Map<String, dynamic>>[],
            ),
        ];
        if (models.isEmpty) {
          return const Center(child: Text('Karşılaştırılacak ürün bulunamadı.'));
        }
        return _ReviewColumns(products: models, groups: groups);
      },
    );

    if (!isWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          centerTitle: true,
          title: const Text(
            'Ürün Yorumları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        body: body,
      );
    }

    return CompareWebShell(
      title: 'Ürün Yorumları',
      subtitle: 'Seçilen ürünlerin yorumları',
      child: body,
    );
  }
}

class _ReviewColumns extends StatelessWidget {
  const _ReviewColumns({required this.products, required this.groups});

  final List<Product> products;
  final List<List<Map<String, dynamic>>> groups;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < products.length; i++) ...[
            if (i > 0) Container(width: 1, color: Colors.grey.shade300),
            Expanded(
              child: _ReviewColumn(
                product: products[i],
                reviews: i < groups.length ? groups[i] : const [],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewColumn extends StatelessWidget {
  const _ReviewColumn({required this.product, required this.reviews});

  final Product product;
  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    final rated = reviews
        .map((review) => (review['rating'] as num?)?.toDouble())
        .whereType<double>()
        .where((rating) => rating > 0)
        .toList(growable: false);
    final average = rated.isEmpty
        ? null
        : rated.reduce((a, b) => a + b) / rated.length;
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
          buildCompareProductHeaderImage(
            imagePath: compareProductImageUrl({'product': product}),
            height: 88,
          ),
          const SizedBox(height: 8),
          if (average != null)
            Text(
              '⭐ ${average.toStringAsFixed(1)} · ${reviews.length} yorum',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            )
          else
            const Text(
              'Bu ürün için henüz yorum yok.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          const SizedBox(height: 8),
          for (final review in reviews)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maskReviewUserName(review['userName']?.toString()),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  if ((review['rating'] as num?) != null)
                    Text(
                      '⭐ ${(review['rating'] as num).toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if ((review['comment']?.toString() ?? '').trim().isNotEmpty)
                    Text(
                      review['comment'].toString(),
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
