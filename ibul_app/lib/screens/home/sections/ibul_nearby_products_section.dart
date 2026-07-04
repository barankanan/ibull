import 'package:flutter/material.dart';

import '../../../models/home_product_preview.dart';
import '../../../widgets/home_product_preview_card.dart';
import '../../../widgets/skeleton_loading.dart';

/// Yakın lokasyon mavi rail — legacy 312px kart yüksekliği + oklar.
class IbulNearbyProductsSection extends StatefulWidget {
  const IbulNearbyProductsSection({
    super.key,
    required this.previews,
    required this.isLoading,
    this.onProductTap,
  });

  final List<HomeProductPreview> previews;
  final bool isLoading;
  final void Function(HomeProductPreview preview)? onProductTap;

  static const double railHeight = HomeProductPreviewCard.defaultHeight;

  @override
  State<IbulNearbyProductsSection> createState() =>
      _IbulNearbyProductsSectionState();
}

class _IbulNearbyProductsSectionState extends State<IbulNearbyProductsSection> {
  final _scrollController = ScrollController();

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32, bottom: 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF0FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFB9DFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9E7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.near_me_outlined,
                  color: Color(0xFF2891F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Yakın Lokasyon ile çevrendeki mağazalardan alışveriş yapabilirsin',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A8A99),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2891F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Yakın Lokasyon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (widget.isLoading && widget.previews.isEmpty)
            SkeletonLoading(
              width: double.infinity,
              height: IbulNearbyProductsSection.railHeight,
              borderRadius: 16,
            )
          else if (widget.previews.isEmpty)
            const SizedBox.shrink()
          else
            SizedBox(
              height: IbulNearbyProductsSection.railHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    cacheExtent: 420,
                    itemCount: widget.previews.length.clamp(0, 12),
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final preview = widget.previews[index];
                      return HomeProductPreviewCard(
                        preview: preview,
                        onTap: () => widget.onProductTap?.call(preview),
                        onAddTap: () => widget.onProductTap?.call(preview),
                      );
                    },
                  ),
                  if (widget.previews.length > 3) ...[
                    Positioned(
                      left: 0,
                      child: _RailArrow(
                        icon: Icons.chevron_left,
                        onTap: () => _scrollBy(-220),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: _RailArrow(
                        icon: Icons.chevron_right,
                        onTap: () => _scrollBy(220),
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

class _RailArrow extends StatelessWidget {
  const _RailArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
