import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../screens/account_page.dart';
import '../screens/cart_page.dart';
import '../screens/favorites_page.dart';

class WebHeaderMenuItems extends StatelessWidget {
  final String? activeMenu;

  const WebHeaderMenuItems({super.key, this.activeMenu});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Row(
      children: [
        _WebHeaderMenuItem(
          icon: Icons.person_outline,
          label: 'Hesabım',
          isActive: activeMenu == 'account',
          onTap: () => _pushReplacement(context, const AccountPage()),
        ),
        const SizedBox(width: 24),
        _WebHeaderMenuItem(
          icon: Icons.favorite_border,
          label: 'Favorilerim',
          isActive: activeMenu == 'favorites',
          onTap: () => _pushReplacement(context, const FavoritesPage()),
        ),
        const SizedBox(width: 24),
        ValueListenableBuilder<int>(
          valueListenable: appState.cartCountNotifier,
          builder: (context, count, child) {
            return _WebHeaderMenuItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Sepetim',
              isActive: activeMenu == 'cart',
              badgeCount: count > 0 ? count : null,
              onTap: () => _pushReplacement(context, const CartPage()),
            );
          },
        ),
      ],
    );
  }

  void _pushReplacement(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

class _WebHeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool isActive;

  const _WebHeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : Colors.black87;

    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 20),
              if (badgeCount != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
