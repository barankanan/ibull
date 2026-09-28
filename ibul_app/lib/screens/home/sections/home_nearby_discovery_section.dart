import 'package:flutter/material.dart';

import '../../../features/vehicle/navigation/vehicle_routes.dart';
import '../../../features/vehicle/widgets/vehicle_card.dart';
import '../../../models/product_model.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_discovery_resolver.dart';

class HomeNearbyDiscoverySection extends StatefulWidget {
  const HomeNearbyDiscoverySection({
    super.key,
    required this.items,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final List<HomeDiscoveryItem> items;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<HomeNearbyDiscoverySection> createState() =>
      _HomeNearbyDiscoverySectionState();
}

class _HomeNearbyDiscoverySectionState extends State<HomeNearbyDiscoverySection> {
  static const _cardWidth = 220.0;
  static const _cardHeight = 348.0;
  static const _gap = 12.0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.items.isEmpty) {
      return const HomeProductRailSkeleton();
    }
    
    if (widget.errorMessage != null && widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: widget.onRetry, child: const Text('Tekrar dene')),
              ],
            ],
          ),
        ),
      );
    }
    
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final showArrows =
        widget.items.length > 3 && MediaQuery.sizeOf(context).width >= 700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yakın Lokasyon',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _cardHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, index) {
                    return _DiscoveryCard(
                      item: widget.items[index],
                      width: _cardWidth,
                      height: _cardHeight,
                    );
                  },
                ),
                if (showArrows) ...[
                  Positioned(
                    left: 0,
                    child: _Arrow(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollBy(-(_cardWidth + _gap) * 2),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: _Arrow(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollBy((_cardWidth + _gap) * 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.item,
    required this.width,
    required this.height,
  });

  final HomeDiscoveryItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (item.type == HomeDiscoveryContentType.vehicle && item.vehicle != null) {
      return SizedBox(
        width: width,
        height: height,
        child: VehicleCard(
          listing: item.vehicle!,
          width: width,
          storefront: true,
          margin: EdgeInsets.zero,
          onTap: () => VehicleRoutes.openDetail(
            context,
            item.id,
            slug: item.vehicle?.title,
          ),
        ),
      );
    }
    if (item.product == null) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: ProductCard(
        product: Product.fromDBProduct(item.product!),
        width: width,
        margin: EdgeInsets.zero,
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: const Color(0xFF333333)),
        ),
      ),
    );
  }
}
