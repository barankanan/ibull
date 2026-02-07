import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_detail_page.dart';
import '../../screens/courier_info_page.dart';

class ProductVariantSelector extends StatelessWidget {
  const ProductVariantSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final hasVariants = viewModel.variantOptions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ürün Seçenekleri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: hasVariants ? () => _showProductVariantsBottomSheet(context, viewModel) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (viewModel.selectedVariants.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: viewModel.selectedVariants.entries.map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${e.key}: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(
                                        text: e.value,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          const Text(
                            'Standart Ürün',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasVariants) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Değiştir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.local_shipping_outlined,
            title: 'KURYE TESLİMATI',
            subtitle: 'Tahmini 4 Saate adresinde',
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CourierInfoPage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.credit_card,
            title: 'Ayda 325 TL den başlayan taksitle',
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildInfoTile(
            icon: Icons.refresh,
            title: 'İptal ve iade Koşulları',
            iconColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = Colors.grey,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getSelectedVariantsText(ProductDetailViewModel viewModel) {
    if (viewModel.selectedVariants.isEmpty) return '';
    return viewModel.selectedVariants.entries.map((e) => '${e.key}: ${e.value}').join(' / ');
  }

  void _showProductVariantsBottomSheet(BuildContext context, ProductDetailViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ChangeNotifierProvider.value(
              value: viewModel,
              child: Consumer<ProductDetailViewModel>(
                builder: (context, vm, child) {
                  return DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.5,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) {
                      if (vm.loadingVariants) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      return Column(
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Seçenekler',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: vm.allAvailableOptions.entries.map((entry) {
                                final optionKey = entry.key;
                                final options = entry.value.toList();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      optionKey,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: options.map((optionValue) {
                                        final isSelected = vm.selectedVariants[optionKey] == optionValue;
                                        
                                        // Stok kontrolü için geçici seçim oluştur
                                        final tempSelection = Map<String, String>.from(vm.selectedVariants);
                                        tempSelection[optionKey] = optionValue;
                                        
                                        final bool isAvailable = vm.hasInStockVariantForSelection(tempSelection);

                                        return ChoiceChip(
                                          label: Text(
                                            optionValue,
                                            style: TextStyle(
                                              color: isAvailable 
                                                  ? (isSelected ? Colors.white : Colors.black87)
                                                  : Colors.grey[400],
                                              decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: AppColors.primary,
                                          backgroundColor: Colors.white,
                                          disabledColor: Colors.grey[100],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                            ),
                                          ),
                                          onSelected: isAvailable ? (selected) {
                                            if (selected) {
                                              vm.updateSelectedVariant(optionKey, optionValue);
                                              // Modalı yenilemek gerekebilir ama Provider/Consumer bunu halleder
                                            }
                                          } : null,
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              onPressed: () {
                                final targetProduct = vm.getMatchingVariant();
                                
                                if (targetProduct != null) {
                                  Navigator.pop(context); // Close sheet
                                  
                                  if (targetProduct.name != vm.initialProduct.name || 
                                      targetProduct.variantOptions != vm.initialProduct.variantOptions) {
                                    // Navigate to new product
                                    // We need to import ProductDetailPage to navigate to it.
                                    // However, this creates a circular dependency if ProductDetailPage imports this widget.
                                    // We can use Navigator.pushReplacementNamed or pass a callback.
                                    // Or simply use the class if we handle imports carefully.
                                    // Ideally, navigation should be handled by a coordinator or callback.
                                    // For now, let's assume we can navigate.
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailPage(product: targetProduct),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bu kombinasyonda ürün bulunamadı.')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Uygula',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
