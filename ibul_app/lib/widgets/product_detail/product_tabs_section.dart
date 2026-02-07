import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/map_page.dart';

class ProductTabsSection extends StatelessWidget {
  const ProductTabsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    
    return Column(
      children: [
        // Tabs
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.tabs.length,
            itemBuilder: (context, index) {
              final isSelected = viewModel.selectedTabIndex == index;
              return GestureDetector(
                onTap: () => viewModel.updateTabIndex(index),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      viewModel.tabs[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Content
        _buildTabContent(context, viewModel),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, ProductDetailViewModel viewModel) {
    // Yakın Lokasyon
    if (viewModel.selectedTabIndex == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              const Text(
                'Yakınınızdaki mağazalarda bu ürünü bulabilirsiniz',
                style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Harita üzerinden bu ürünü satan en yakın satıcıları görebilir ve mağaza detaylarını inceleyebilirsiniz.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapPage(product: viewModel.initialProduct),
                      fullscreenDialog: true,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Haritada Göster',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text(
          viewModel.getTabContentText(),
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
        ),
      ),
    );
  }
}
