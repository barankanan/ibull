import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'home_screen.dart';
import 'categories_page.dart';
import 'map_page.dart';
import 'cart_page.dart';
import 'account_page.dart';
import 'visual_intelligence_page.dart';
import 'product_search_page.dart';
import 'visual_search_selection_page.dart';
import '../core/app_state.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              title: 'Görsel Zeka',
              icon: 'assets/images/visual_intelligence.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VisualSearchSelectionPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'Ürünü Arat',
              icon: 'assets/images/product_search.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductSearchPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              title: 'Geçmiş',
              icon: 'assets/images/history.png',
              onTap: () {
                // Geçmiş sayfasına git
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              // Ana Sayfa
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              // Kategori
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesPage()),
                (route) => false,
              );
            } else if (index == 2) {
              // Harita
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            } else if (index == 3) {
              // Sepet
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              );
            } else if (index == 4) {
              // Hesap
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 4)),
                (route) => false,
              );
            }
          },
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.segment),
              label: 'Kategori',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Harita',
            ),
            BottomNavigationBarItem(
              icon: _buildCartIcon(isActive: false),
              activeIcon: _buildCartIcon(isActive: true),
              label: 'Sepet',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hesap',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required String title,
    required String icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _getIconData(title),
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            // Arrow
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String title) {
    switch (title) {
      case 'Görsel Zeka':
        return Icons.psychology_outlined;
      case 'Ürünü Arat':
        return Icons.search;
      case 'Geçmiş':
        return Icons.history;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildCartIcon({required bool isActive}) {
    final cartItemCount = _appState.cart.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined,
        ),
        if (cartItemCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                cartItemCount > 9 ? '9+' : cartItemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
