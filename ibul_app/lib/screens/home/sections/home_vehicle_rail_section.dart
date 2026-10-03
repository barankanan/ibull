import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../features/vehicle/models/vehicle_listing.dart';
import '../../../features/vehicle/navigation/vehicle_routes.dart';
import '../../../features/vehicle/widgets/vehicle_card.dart';
import '../../../widgets/skeleton_loading.dart';

class HomeVehicleRailSection extends StatefulWidget {
  const HomeVehicleRailSection({
    super.key,
    required this.listings,
    this.isLoading = false,
    this.title = 'Araç İlanları',
    this.errorMessage,
    this.onRetry,
  });

  final List<VehicleListing> listings;
  final bool isLoading;
  final String title;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<HomeVehicleRailSection> createState() => _HomeVehicleRailSectionState();
}

class _HomeVehicleRailSectionState extends State<HomeVehicleRailSection> {
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
    if (widget.isLoading && widget.listings.isEmpty) {
      return const HomeProductRailSkeleton();
    }
    if (widget.errorMessage != null && widget.listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Araç ilanları yüklenemedi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }
    if (widget.listings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Şu anda yayında araç ilanı bulunmuyor.'),
      );
    }
    final showArrows =
        widget.listings.length > 3 && MediaQuery.sizeOf(context).width >= 700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => VehicleRoutes.openHub(context),
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
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
                  itemCount: widget.listings.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, index) {
                    final listing = widget.listings[index];
                    return SizedBox(
                      width: _cardWidth,
                      height: _cardHeight,
                      child: VehicleCard(
                        listing: listing,
                        width: _cardWidth,
                        storefront: true,
                        margin: EdgeInsets.zero,
                        onTap: () => VehicleRoutes.openDetail(
                          context,
                          listing.id,
                          slug: listing.title,
                        ),
                      ),
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
