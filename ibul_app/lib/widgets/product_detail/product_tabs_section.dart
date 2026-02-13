import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/map_page.dart';

class ProductTabsSection extends StatefulWidget {
  final VoidCallback? onScrollToDescription;
  final VoidCallback? onScrollToSpecs;
  final bool isMobile;

  const ProductTabsSection({
    super.key, 
    this.onScrollToDescription, 
    this.onScrollToSpecs,
    this.isMobile = false,
  });

  @override
  State<ProductTabsSection> createState() => _ProductTabsSectionState();
}

class _ProductTabsSectionState extends State<ProductTabsSection> {
  int _lastTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    // Reset state when switching tabs if needed (though not really needed for this new layout)
    if (viewModel.selectedTabIndex != _lastTabIndex) {
      _lastTabIndex = viewModel.selectedTabIndex;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = viewModel.selectedTabIndex == index;
              return GestureDetector(
                onTap: () {
                  viewModel.updateTabIndex(index);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF673AB7) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    viewModel.tabs[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        
        // Expanded Content Area
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Content
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Bottom padding for button
                    child: _buildTabContent(context, viewModel),
                  ),
                ),
                
                // Bottom Button / Gradient Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFF5F5F5).withOpacity(0.0),
                          const Color(0xFFF5F5F5).withOpacity(0.9),
                          const Color(0xFFF5F5F5),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          if (viewModel.selectedTabIndex == 2) {
                            widget.onScrollToSpecs?.call();
                          } else {
                            widget.onScrollToDescription?.call();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF673AB7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: const Text(
                          'İncele',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  Widget _buildTabContent(BuildContext context, ProductDetailViewModel viewModel) {
    // Yakın Lokasyon tab'ı
    if (viewModel.selectedTabIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Yakınınızdaki mağazalarda bu ürünü bulabilirsiniz.', 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          // Map preview image placeholder or icon could go here
          Expanded(
            child: Center(
              child: Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
            ),
          ),
        ],
      );
    }

    // Ürün Açıklaması & Ürün Özellikleri tab'ları
    final fullText = viewModel.getTabContentText();
    
    return Text(
      fullText,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black54, 
        height: 1.5,
      ),
      // Let it overflow naturally, it will be clipped by the parent Stack
    );
  }
}
