import 'package:flutter/material.dart';

import '../widgets/compare_page_helpers.dart';

class CompareFeaturesPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const CompareFeaturesPage({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    final content = _buildContent(isWeb);

    if (isWeb) {
      return CompareWebShell(
        title: 'Ürün Özellikleri',
        subtitle: 'Detaylı özellik karşılaştırması',
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürün özellikleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildContent(bool isWeb) {
    final displayProducts = compareDisplayProducts(products);
    final productModels = compareProductsFromMaps(displayProducts);

    if (productModels.isEmpty) {
      return const Center(child: Text('Karşılaştırılacak ürün bulunamadı.'));
    }

    final categoryMismatch =
        compareMainCategoryMismatchForProducts(productModels);
    if (categoryMismatch != null) {
      return buildCompareCategoryBlockedState(message: categoryMismatch);
    }

    final categoryLabel = compareCategoryLabel(displayProducts);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWeb)
            CompareInfoBanner(
              message:
                  'Seçtiğin $categoryLabel ürünlerinin özellik karşılaştırması',
            ),
          CompareFeaturesPanel(
            productMaps: displayProducts,
            sections: buildCompareFeatureSections(productModels),
          ),
        ],
      ),
    );
  }
}
