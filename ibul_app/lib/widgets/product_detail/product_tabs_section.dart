import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/map_page.dart';

class ProductTabsSection extends StatefulWidget {
  final VoidCallback? onScrollToDescription;
  final VoidCallback? onScrollToSpecs;

  const ProductTabsSection({super.key, this.onScrollToDescription, this.onScrollToSpecs});

  @override
  State<ProductTabsSection> createState() => _ProductTabsSectionState();
}

class _ProductTabsSectionState extends State<ProductTabsSection> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact tab chips - yatay
        SizedBox(
          height: 28,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.tabs.length,
            itemBuilder: (context, index) {
              final isSelected = viewModel.selectedTabIndex == index;
              return GestureDetector(
                onTap: () {
                  viewModel.updateTabIndex(index);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      viewModel.tabs[index],
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _ZeroIntrinsicHeight(
            child: _buildTabContent(context, viewModel),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, ProductDetailViewModel viewModel) {
    // Yakın Lokasyon tab'ı
    if (viewModel.selectedTabIndex == 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Yakınızıdaki mağazalarda bu ürünü bulabilirsiniz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const Spacer(),
            SizedBox(
              height: 30,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage(product: viewModel.initialProduct), fullscreenDialog: true));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Haritada Göster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ),
      );
    }

    // Ürün Açıklaması & Ürün Özellikleri tab'ları
    final fullText = viewModel.getTabContentText();
    final isLongText = fullText.length > 50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRect(
              child: Text(fullText, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3), overflow: TextOverflow.fade),
            ),
          ),
          if (isLongText) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (viewModel.selectedTabIndex == 2) {
                    widget.onScrollToSpecs?.call();
                  } else {
                    widget.onScrollToDescription?.call();
                  }
                },
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                ),
                label: Text(
                  viewModel.selectedTabIndex == 2 ? 'Ürün Özelliklerini Göster' : 'Ürün Bilgilerini Göster',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// IntrinsicHeight hesaplamasında 0 yükseklik bildiren widget.
/// Bu sayede IntrinsicHeight, bu widget'ın içindeki metnin yüksekliğini
/// saymaz ve kart boyutu orta/sağ sütuna göre belirlenir.
class _ZeroIntrinsicHeight extends SingleChildRenderObjectWidget {
  const _ZeroIntrinsicHeight({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderZeroIntrinsicHeight();
}

class _RenderZeroIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}
