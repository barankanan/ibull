import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';

class ProductFullDescription extends StatefulWidget {
  const ProductFullDescription({super.key});

  @override
  State<ProductFullDescription> createState() => _ProductFullDescriptionState();
}

class _ProductFullDescriptionState extends State<ProductFullDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final description = product.getDisplayDescription();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    // Additional info bullets
    final additionalInfo = [
      'Bu ürün ${product.store ?? "satıcı"} tarafından gönderilecektir.',
      'Kampanya fiyatından satılmak üzere 5 adetten az stok bulunmaktadır.',
      'Bir ürün, birden fazla satıcı tarafından satılabilir. Birden fazla satıcı tarafından satışa sunulan ürünler için belirledikleri fiyata, satıcı puanlarına, teslimat statülerine, ürünlerdeki promosyonlara ve kargonun bedava olup olmamasına göre sıralanmaktadır.',
      'Bu üründen en fazla 1 adet sipariş verilebilir.',
      '15 gün içinde ücretsiz iade.',
    ];

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
                  child: Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Ürün Bilgileri',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: isWide
                      ? _buildWideContent(product, description, additionalInfo)
                      : _buildNarrowContent(product, description, additionalInfo),
                ),

                // "DAHA FAZLA GÖSTER" button
                const SizedBox(height: 16),
                Center(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(List<String> additionalInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Ek Bilgiler',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        ...additionalInfo.map((info) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info,
                  style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget? _buildImageWidget(dynamic product) {
    if (product.images != null && product.images!.isNotEmpty && product.images!.first.isNotEmpty) {
      return Container(
        width: 140,
        height: 180,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product.images!.first,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 60, color: Colors.grey),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildWideContent(dynamic product, String description, List<String> additionalInfo) {
    final rightColumn = _buildRightColumn(additionalInfo);
    final imageWidget = _buildImageWidget(product);

    if (_isExpanded) {
      // Expanded: show full text, no clipping
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageWidget != null) imageWidget,
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ürün Açıklaması',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: rightColumn),
        ],
      );
    }

    // Collapsed: right column determines height, description fills available space
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageWidget != null) imageWidget,
          Expanded(
            flex: 3,
            child: _ZeroIntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ürün Açıklaması',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.black, Colors.transparent],
                          stops: [0.0, 0.85, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: rightColumn),
        ],
      ),
    );
  }

  Widget _buildNarrowContent(dynamic product, String description, List<String> additionalInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ürün Açıklaması',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        AnimatedCrossFade(
          firstChild: Text(
            description.length > 150 ? '${description.substring(0, 150)}...' : description,
            style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ek Bilgiler',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              ...additionalInfo.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info,
                        style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}

/// Reports 0 intrinsic height so IntrinsicHeight uses sibling columns to determine height.
class _ZeroIntrinsicHeight extends SingleChildRenderObjectWidget {
  const _ZeroIntrinsicHeight({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderZeroIntrinsicHeight();
}

class _RenderZeroIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}
