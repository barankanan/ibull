import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';

class ProductFullSpecs extends StatefulWidget {
  const ProductFullSpecs({super.key});

  @override
  State<ProductFullSpecs> createState() => _ProductFullSpecsState();
}

class _ProductFullSpecsState extends State<ProductFullSpecs> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final specsText = product.getDisplaySpecs();
    final specs = _parseSpecs(specsText, product);

    if (specs.isEmpty) return const SizedBox.shrink();

    // Show 9 specs initially (3 rows x 3 columns), all when expanded
    final visibleSpecs = _isExpanded ? specs : specs.take(9).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final crossAxisCount = isWide ? 4 : 2;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Ürün Özellikleri',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${specs.length} özellik',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Specs grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: isWide ? 4.5 : 3.5,
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                  ),
                  itemCount: visibleSpecs.length,
                  itemBuilder: (context, index) {
                    final spec = visibleSpecs[index];
                    final isEvenRow = (index ~/ crossAxisCount) % 2 == 0;
                    final isLastInRow = (index + 1) % crossAxisCount == 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isEvenRow ? AppColors.primary.withValues(alpha: 0.03) : Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                          right: isLastInRow ? BorderSide.none : BorderSide(color: Colors.grey[200]!, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              spec['key']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              spec['value']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // "DAHA FAZLA GÖSTER" button
          if (specs.length > 9) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              child: Center(
                child: SizedBox(
                  width: 280,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? 'DAHA AZ GÖSTER' : 'DAHA FAZLA GÖSTER',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, String>> _parseSpecs(String specsText, dynamic product) {
    final specs = <Map<String, String>>[];
    final brand = product.brand ?? '';
    final name = product.name ?? '';

    // Parse from specs text (format: "Key: Value\nKey: Value")
    final lines = specsText.split('\n');
    for (var line in lines) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        specs.add({
          'key': parts[0].trim(),
          'value': parts.sublist(1).join(':').trim(),
        });
      }
    }

    // Add common specs based on category
    if (brand.contains('Apple') || name.contains('iPhone')) {
      _addIfMissing(specs, 'Garanti Tipi', 'Apple Türkiye Garantili');
      _addIfMissing(specs, 'Kamera Çözünürlüğü', '12 MP + 12 MP');
      _addIfMissing(specs, 'Dahili Hafıza', '128 GB');
      _addIfMissing(specs, 'Ekran Boyutu', '6,1 inç');
      _addIfMissing(specs, 'Pil Gücü (mAh)', '3095');
      _addIfMissing(specs, 'Mobil Bağlantı Hızı', '5G');
      _addIfMissing(specs, 'CPU Aralık', '2.5-3.2 GHz');
      _addIfMissing(specs, 'Ekran Çözünürlüğü', 'FHD+');
      _addIfMissing(specs, 'Ana Kamera Çözünürlük', '10 - 15 MP');
      _addIfMissing(specs, 'Parmak İzi Okuyucu', 'Yok');
      _addIfMissing(specs, 'Suya/Toza Dayanıklılık', 'Var');
      _addIfMissing(specs, 'RAM Kapasitesi', '4 GB');
    } else if (brand.contains('Samsung')) {
      _addIfMissing(specs, 'Garanti Tipi', 'Samsung Türkiye Garantili');
      _addIfMissing(specs, 'Kamera Çözünürlüğü', '200 MP');
      _addIfMissing(specs, 'Dahili Hafıza', '256 GB');
      _addIfMissing(specs, 'Ekran Boyutu', '6,8 inç');
      _addIfMissing(specs, 'Pil Gücü (mAh)', '5000');
      _addIfMissing(specs, 'Mobil Bağlantı Hızı', '5G');
      _addIfMissing(specs, 'CPU Aralık', '3.36 GHz');
      _addIfMissing(specs, 'Ekran Çözünürlüğü', 'QHD+');
      _addIfMissing(specs, 'S Pen Desteği', 'Var');
      _addIfMissing(specs, 'Parmak İzi Okuyucu', 'Ekran Altı');
      _addIfMissing(specs, 'Suya/Toza Dayanıklılık', 'IP68');
      _addIfMissing(specs, 'RAM Kapasitesi', '12 GB');
    } else {
      // Generic specs
      _addIfMissing(specs, 'Marka', brand);
      _addIfMissing(specs, 'Garanti', '2 Yıl');
      _addIfMissing(specs, 'Menşei', 'Türkiye');
    }

    return specs;
  }

  void _addIfMissing(List<Map<String, String>> specs, String key, String value) {
    if (!specs.any((s) => s['key'] == key)) {
      specs.add({'key': key, 'value': value});
    }
  }
}
