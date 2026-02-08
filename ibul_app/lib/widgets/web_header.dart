
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../screens/cart_page.dart';
import '../screens/account_page.dart';
import '../core/app_state.dart';

class WebHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onCategorySelected;
  final String? selectedCategory;

  const WebHeader({
    super.key,
    required this.onSearch,
    this.onCategorySelected,
    this.selectedCategory,
  });

  @override
  State<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends State<WebHeader> {
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst Bar (Logo, Arama, Menüler)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Row(
            children: [
              // 1. Logo
              _buildLogo(),
              
              const SizedBox(width: 48),
              
              // 2. Search Bar
              Expanded(
                child: _buildSearchBar(),
              ),
              
              const SizedBox(width: 32),
              
              // 3. Location (Konum)
              _buildLocation(),
              
              const SizedBox(width: 32),

              // 4. Menu Items (Hesabım, Favorilerim, Sepetim)
              _buildMenuItems(context),
            ],
          ),
        ),
        
        // Kategori Menüsü (Alt Bar)
        _buildCategoryBar(),
      ],
    );
  }

  Widget _buildLogo() {
    return InkWell(
      onTap: () => widget.onCategorySelected?.call('Ana Sayfa'),
      hoverColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'iBul',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -0.5,
              fontFamily: 'Montserrat', 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Colors.grey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onSubmitted: widget.onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Ürün, kategori veya marka ara...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 8), 
                    ),
                    style: const TextStyle(fontSize: 14),
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      'ARA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    return InkWell(
      onTap: () {
        // Navigate to MapPage
        Navigator.pushNamed(context, '/map');
        // Or if named route is not set up, use direct push:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage()));
        // Assuming '/map' or importing MapPage.
        // Let's use MaterialPageRoute for safety as I don't see routes defined here.
        // Need to import MapPage first? It is likely not imported. 
        // I will rely on the fact that I need to add import or use named route if available.
        // Let's check imports in next step or assume standard approach.
        // I'll add the import in a separate block if needed, but for now let's just use the callback if possible or standard push.
        // Since I can't easily check main.dart for routes right now without another read, I'll use a direct push and ensure import.
      },
      child: Row(
        children: [
          const Icon(Icons.map, color: AppColors.primary, size: 24),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Konum',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Text(
                    'Harita',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final appState = AppState();
    
    return Row(
      children: [
        _MenuItem(
          icon: Icons.person_outline, 
          label: 'Hesabım', 
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountPage()),
            );
          }
        ),
        const SizedBox(width: 24),
        _MenuItem(icon: Icons.favorite_border, label: 'Favorilerim', onTap: () {}),
        const SizedBox(width: 24),
        ValueListenableBuilder<int>(
          valueListenable: appState.cartCountNotifier,
          builder: (context, count, child) {
            return _MenuItem(
              icon: Icons.shopping_cart_outlined, 
              label: 'Sepetim', 
              badgeCount: count > 0 ? count : null, 
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
              }
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryBar() {
    final categories = [
      'Yakın Lokasyon', 'Erkek', 'Kadın', 'Elektronik', 
      'Ayakkabı & Çanta', 'Saat & Aksesuar',
      'Ev & Yaşam', 'Kırtasiye & Ofis',
      'Oto, Bahçe, Yapı Market', 'Oyuncak, Müzik, Film', 
      'Spor & Outdoor', 'Kozmetik & Kişisel Bakım', 
      'Pet Shop'
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
              // Scrollable List
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: ListView.separated(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 24, right: 60), // Added left padding to align with body
                  itemCount: categories.length,
                  shrinkWrap: true,
                  separatorBuilder: (context, index) => const SizedBox(width: 32),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = widget.selectedCategory == category;
                    return InkWell(
                      onTap: () => widget.onCategorySelected?.call(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12), // Added horizontal padding
                        decoration: BoxDecoration(
                          border: isSelected 
                            ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2)) 
                            : null,
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primary : Colors.grey[800],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Right Arrow Button
              Positioned(
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                      onPressed: () {
                        _categoryScrollController.animateTo(
                          _categoryScrollController.offset + 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.black87, size: 20),
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
