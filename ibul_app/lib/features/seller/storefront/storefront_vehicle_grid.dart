import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../responsive/breakpoints.dart';
import '../../../widgets/ibul_page_state.dart';
import '../../vehicle/models/vehicle_listing.dart';
import '../../vehicle/widgets/vehicle_card.dart';
import 'storefront_copy.dart';

/// Product-grid twin for vehicle listings inside the shared storefront shell.
class StorefrontVehicleGrid extends StatelessWidget {
  const StorefrontVehicleGrid({
    super.key,
    required this.items,
    required this.copy,
    required this.loading,
    required this.catalogEmpty,
    this.aspectRatioOverride,
  });

  final List<VehicleListing> items;
  final StorefrontCopy copy;
  final bool loading;
  final bool catalogEmpty;
  final double? aspectRatioOverride;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: IbulPageState.empty(
          icon: copy.emptyIcon == 'car'
              ? Icons.directions_car_outlined
              : Icons.shopping_bag_outlined,
          title: catalogEmpty ? copy.emptyCatalog : copy.emptyFiltered,
          message: catalogEmpty
              ? 'Yayında araç ilanı eklendiğinde burada görünecek.'
              : 'Farklı bir arama veya kategori deneyin.',
        ),
      );
    }

    final useSearchWebGrid = MediaQuery.of(context).size.width > 900;
    if (useSearchWebGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: aspectRatioOverride ?? 0.82,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => Align(
          alignment: Alignment.topCenter,
          child: VehicleCard(
            listing: items[index],
            storefront: true,
            tight: false,
            margin: EdgeInsets.zero,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final columns = ProductGridSizing.columnCountForWidth(
          outerWidth - 24,
          spacing: 10,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatioOverride ?? 0.70,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => Align(
            alignment: Alignment.topCenter,
            child: VehicleCard(
              listing: items[index],
              storefront: true,
              tight: true,
              margin: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}
