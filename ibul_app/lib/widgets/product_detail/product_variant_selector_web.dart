import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import 'product_bottom_bar.dart';

class ProductVariantSelectorWeb extends StatefulWidget {
  const ProductVariantSelectorWeb({super.key});

  @override
  State<ProductVariantSelectorWeb> createState() => _ProductVariantSelectorWebState();
}

class _ProductVariantSelectorWebState extends State<ProductVariantSelectorWeb> {
  // Mock state for selected options
  String _selectedColor = 'Mavi';
  String _selectedStorage = '256GB';

  @override
  Widget build(BuildContext context) {
    // Ürünün seçenekleri olup olmadığını kontrol et
    final product = Provider.of<ProductDetailViewModel>(context).initialProduct;
    // Sadece Telefon kategorisindeki ürünlerde varyant seçimi göster
    // Kategori veya Alt Kategori kontrolü ekledik.
    final hasVariants = (product.category?.toLowerCase().contains('telefon') ?? false) || 
                        (product.subCategory?.toLowerCase().contains('telefon') ?? false);

    if (!hasVariants) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Renk Seçimi (Mevcut kod)
          Row(
            children: [
              const Text(
                'Renk:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedColor,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildColorOption('Beyaz', 'assets/products/iphone15_mavi_256gb.png', true),
                const SizedBox(width: 12),
                _buildColorOption('Mor', 'assets/products/iphone15_mavi_256gb.png', false),
                const SizedBox(width: 12),
                _buildColorOption('Siyah', 'assets/products/iphone15_mavi_256gb.png', false),
                const SizedBox(width: 12),
                _buildColorOption('Pembe', 'assets/products/iphone15_mavi_256gb.png', false),
                const SizedBox(width: 12),
                _buildColorOption('Yeşil', 'assets/products/iphone15_mavi_256gb.png', false),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Dahili Hafıza Seçimi
          Row(
            children: [
              const Text(
                'Dahili Hafıza:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedStorage,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStorageOption('128 GB', true),
              const SizedBox(width: 12),
              _buildStorageOption('256 GB', false),
              const SizedBox(width: 12),
              _buildStorageOption('512 GB', false),
            ],
          ),
        const SizedBox(height: 24),
        ],
      );
  }Widget _buildColorOption(String colorName, String imagePath, bool isPopular) {
    final isSelected = _selectedColor == colorName || (colorName == 'Mor' && _selectedColor == 'Mavi'); // Mock logic
    final selectedColor = const Color(0xFF673AB7); // Deep Purple
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = colorName;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 80,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? selectedColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: imagePath.contains('assets') 
              ? Image.asset(imagePath, fit: BoxFit.contain)
              : const Icon(Icons.phone_iphone, color: Colors.grey),
          ),
          if (isPopular)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'Popüler',
                    style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStorageOption(String label, bool isSelected) {
    // Override isSelected based on state for demo
    final selected = _selectedStorage == label.replaceAll(' ', '');
    final selectedColor = const Color(0xFF673AB7); // Deep Purple
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStorage = label.replaceAll(' ', '');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: selected ? selectedColor : Colors.black87,
          ),
        ),
      ),
    );
  }
}
