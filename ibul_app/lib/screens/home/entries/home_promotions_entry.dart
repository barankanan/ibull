import 'package:flutter/material.dart';

import '../../../ads/models/home_card_template.dart';
import '../../../ads/services/home_feature_ad_service.dart';
import '../../../models/product_model.dart';
import '../../../widgets/home_category_card_section.dart';
import '../deferred/deferred_home_sponsored_section.dart';

class HomePromotionsBlock extends StatefulWidget {
  const HomePromotionsBlock({super.key});

  @override
  State<HomePromotionsBlock> createState() => _HomePromotionsBlockState();
}

class _HomePromotionsBlockState extends State<HomePromotionsBlock> {
  var _groups = const <HomeCategoryCardGroup>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await HomeFeatureAdService().loadHomePageGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_groups.isNotEmpty)
          HomeCategoryCardSections(
            groups: _groups,
            convertToProduct: Product.fromDBProduct,
          ),
        const DeferredHomeSponsoredSection(suppressSkeleton: true),
      ],
    );
  }
}
