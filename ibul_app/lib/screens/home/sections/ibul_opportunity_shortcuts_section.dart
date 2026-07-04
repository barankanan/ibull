import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/home_quick_action.dart';

/// Kategori / fırsat kısayol şeridi — legacy ana sayfa chip tasarımı.
class IbulOpportunityShortcutsSection extends StatefulWidget {
  const IbulOpportunityShortcutsSection({
    super.key,
    required this.selectedCategory,
    this.onShortcutTap,
  });

  final String selectedCategory;
  final ValueChanged<String>? onShortcutTap;

  @override
  State<IbulOpportunityShortcutsSection> createState() =>
      _IbulOpportunityShortcutsSectionState();
}

class _IbulOpportunityShortcutsSectionState
    extends State<IbulOpportunityShortcutsSection> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<({IconData icon, String title})> _itemsForCategory() {
    switch (widget.selectedCategory) {
      case 'Elektronik':
        return const [
          (icon: Icons.phone_iphone, title: 'Telefonlar'),
          (icon: Icons.laptop, title: 'Laptop & Tablet'),
          (icon: Icons.tv, title: 'Televizyon'),
          (icon: Icons.headphones_battery, title: 'Aksesuar'),
        ];
      case 'Erkek':
      case 'Kadın':
        return const [
          (icon: Icons.checkroom, title: 'Giyim'),
          (icon: Icons.hiking, title: 'Ayakkabı & Çanta'),
          (icon: Icons.watch, title: 'Saat & Aksesuar'),
        ];
      case 'Yakın Lokasyon':
        return const [
          (icon: Icons.restaurant_menu, title: 'Yemek'),
          (icon: Icons.shopping_cart, title: 'Market'),
          (icon: Icons.explore, title: 'Keşfet'),
        ];
      default:
        return const [
          (icon: Icons.flash_on, title: 'Süper Fırsat'),
          (icon: Icons.local_offer, title: 'İndirimler'),
          (icon: Icons.trending_up, title: 'Çok Satanlar'),
          (icon: Icons.new_releases, title: 'Yeniler'),
          (icon: Icons.diamond, title: 'Özel Ürünler'),
          (icon: Icons.card_giftcard, title: 'Hediye'),
          (icon: Icons.computer, title: 'Elektronik'),
          (icon: Icons.chair, title: 'Ev & Yaşam'),
          (icon: Icons.checkroom, title: 'Moda'),
          (icon: Icons.sports_soccer, title: 'Spor'),
          (icon: Icons.auto_stories, title: 'Kitap'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForCategory();
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                return HomeQuickActionChip(
                  icon: item.icon,
                  title: item.title,
                  onTap: () => widget.onShortcutTap?.call(item.title),
                );
              },
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (!_scrollController.hasClients) return;
                    _scrollController.animateTo(
                      _scrollController.offset + 200,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
