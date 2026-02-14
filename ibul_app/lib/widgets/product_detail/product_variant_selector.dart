import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import 'product_bottom_bar.dart';

class ProductVariantSelector extends StatefulWidget {
  const ProductVariantSelector({super.key});

  @override
  State<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends State<ProductVariantSelector> {
  // Mock state for selected options
  String _selectedColor = 'Mavi';
  String _selectedStorage = '256GB';

  @override
  Widget build(BuildContext context) {
    // Ürünün seçenekleri olup olmadığını kontrol et
    final product = Provider.of<ProductDetailViewModel>(context).initialProduct;
    // Basit bir kontrol: iPhone ise seçenekler var, değilse yok varsayalım.
    // Gerçekte API'den gelen veriye göre olacak.
    final hasVariants = true; // product.name.toLowerCase().contains('iphone');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasVariants) ...[
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
      ],
    );
  }

  Widget _buildColorOption(String colorName, String imagePath, bool isPopular) {
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

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6200EA), size: 24), // Reduced from 28
          const SizedBox(width: 12), // Reduced from 16
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13, // Reduced from 14
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2), // Reduced from 4
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12, // Reduced from 13
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20), // Reduced from 24
        ],
      ),
    );
  }

  Widget _buildOptionChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  void _showVariantBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Seçenekler',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Renk Section
                      const Text('Renk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSelectableChip('Mavi', _selectedColor == 'Mavi', (val) {
                            if (val) setState(() => _selectedColor = 'Mavi');
                          }),
                          const SizedBox(width: 12),
                          _buildSelectableChip('Beyaz', _selectedColor == 'Beyaz', (val) {
                            if (val) setState(() => _selectedColor = 'Beyaz');
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Depolama Section
                      const Text('Depolama', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSelectableChip('256GB', _selectedStorage == '256GB', (val) {
                            if (val) setState(() => _selectedStorage = '256GB');
                          }),
                          const SizedBox(width: 12),
                          _buildSelectableChip('512GB', _selectedStorage == '512GB', (val) {
                            if (val) setState(() => _selectedStorage = '512GB');
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                // Footer Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        // Update main state (this is a mock, in real app use provider/callback)
                        this.setState(() {
                          // Values already updated in local state variables _selectedColor/_selectedStorage
                          // which are shared because this is a method of the main state class 
                          // Wait, showModalBottomSheet builder context is different.
                          // Actually, I'm updating _selectedColor in the StatefulBuilder's setState 
                          // BUT _selectedColor is a member of _ProductVariantSelectorState.
                          // So when I call setState inside StatefulBuilder, it updates the UI of the sheet.
                          // To update the parent widget, I need to call the parent's setState when sheet closes or apply is clicked.
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Uygula', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Bottom safe area spacing
              ],
            ),
          );
        }
      ),
    ).then((_) {
      // Refresh parent widget to show new selection
      setState(() {}); 
    });
  }

  Widget _buildSelectableChip(String label, bool isSelected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6200EA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6200EA) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
