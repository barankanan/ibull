import 'package:flutter/material.dart';
import '../core/constants.dart';

class WebHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;

  const WebHeader({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst Bar (Logo, Arama, Menüler)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
        
        // Alt Çizgi
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        
        // Kategori Menüsü (Alt Bar)
        _buildCategoryBar(),
        
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  Widget _buildLogo() {
    return Text(
      'iBul',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: -1.0,
        fontFamily: 'Montserrat', // Varsa, yoksa default bold
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onSubmitted: onSearch,
              decoration: const InputDecoration(
                hintText: 'Aradığınız ürün, kategori veya markayı yazınız',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 12), // Hizalama düzeltmesi
              ),
              style: const TextStyle(fontSize: 14),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
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
                  'İstanbul, Kadıköy',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return Row(
      children: [
        _MenuItem(icon: Icons.person_outline, label: 'Hesabım', onTap: () {}),
        const SizedBox(width: 24),
        _MenuItem(icon: Icons.favorite_border, label: 'Favorilerim', onTap: () {}),
        const SizedBox(width: 24),
        _MenuItem(icon: Icons.shopping_cart_outlined, label: 'Sepetim', badgeCount: 3, onTap: () {}),
      ],
    );
  }

  Widget _buildCategoryBar() {
    final categories = [
      'Elektronik', 'Moda', 'Ev & Yaşam', 'Kırtasiye & Ofis', 
      'Oto, Bahçe, Yapı Market', 'Anne, Bebek, Oyuncak', 
      'Spor, Outdoor', 'Kozmetik, Kişisel Bakım', 
      'Süpermarket, Pet Shop', 'Kitap, Müzik, Film, Hobi'
    ];

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: categories.map((category) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }).toList(),
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
