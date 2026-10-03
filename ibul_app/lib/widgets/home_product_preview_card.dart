import 'package:flutter/material.dart';

import '../core/app_image_cdn.dart';
import '../core/app_motion.dart';
import '../core/constants.dart';
import '../core/interaction_feedback.dart';
import '../core/web_perf_trace.dart';
import '../models/db_product.dart';
import '../models/home_product_preview.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import 'ecommerce_product_quick_info_sheet.dart';
import 'optimized_image.dart';
import 'premium_interactions.dart';
import 'skeleton_loading.dart';

/// Lightweight product tile — fixed rail dimensions, no RenderFlex overflow.
class HomeProductPreviewCard extends StatefulWidget {
  const HomeProductPreviewCard({
    super.key,
    required this.preview,
    this.width = defaultWidth,
    this.height = defaultHeight,
    this.onTap,
    this.onAddTap,
    this.onFirstPaint,
    this.showStore = false,
  });

  static const double defaultWidth = 198;
  static const double defaultHeight = 312;

  final HomeProductPreview preview;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onFirstPaint;
  final bool showStore;

  @override
  State<HomeProductPreviewCard> createState() => _HomeProductPreviewCardState();
}

class _HomeProductPreviewCardState extends State<HomeProductPreviewCard> {
  bool _reportedPaint = false;
  bool _isFavorite = false;

  static const double _buttonHeight = 34;
  static const double _priceBlockHeight = 40;
  static const double _nameHeight = 34;
  static const double _brandHeight = 14;
  static const double _verticalPadding = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportFirstPaint());
  }

  void _reportFirstPaint() {
    if (_reportedPaint || !mounted) return;
    _reportedPaint = true;
    widget.onFirstPaint?.call();
    WebPerfTrace.instance.markFirstProductCardRendered();
  }

  Product _previewAsProduct() {
    return Product.fromDBProduct(
      DBProduct(
        id: widget.preview.id,
        name: widget.preview.name,
        brand: widget.preview.brand ?? '',
        store: widget.preview.storeName,
        price: widget.preview.price.toString(),
        oldPrice: widget.preview.discountPrice?.toString(),
        imageUrl: widget.preview.imageUrl,
        category: '',
        rating: 0,
        reviewCount: 0,
        tags: widget.preview.hasDiscount ? '["İndirimde"]' : '[]',
      ),
    );
  }

  /// Kart üzerindeki ince önizleme verisini tam ürün satırıyla tamamlar.
  /// Popup beklemez: sheet kart verisiyle anında açılır, bu fetch geldiğinde
  /// içerik tazelenir (timeout sheet tarafında uygulanır).
  Future<Product?> _enrichPreviewProduct() async {
    final row = await SupabaseService.instance.getProductByIdString(
      widget.preview.id,
    );
    return row == null ? null : Product.fromDBProduct(row);
  }

  void _showQuickView() {
    InteractionFeedback.lightImpact(channel: 'home_preview_quick_view');
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      isScrollControlled: true,
      builder: (sheetContext) {
        return EcommerceProductQuickInfoSheet(
          product: _previewAsProduct(),
          enrich: _enrichPreviewProduct,
          onAddToCart: widget.onAddTap ?? widget.onTap,
          onViewDetails: widget.onTap,
        );
      },
    );
  }

  Widget _buildQuickViewButton() {
    return PremiumPressable(
      pressedScale: 0.9,
      hoverScale: 1.04,
      hoverLift: 0.5,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.remove_red_eye_outlined,
          color: AppColors.primary,
          size: 16,
        ),
      ),
    );
  }

  double _resolveImageHeight() {
    final hasBrand =
        widget.preview.brand != null && widget.preview.brand!.isNotEmpty;
    final hasStore =
        widget.showStore &&
        widget.preview.storeName != null &&
        widget.preview.storeName!.isNotEmpty;
    var bodyHeight =
        _verticalPadding +
        _nameHeight +
        8 +
        _priceBlockHeight +
        8 +
        _buttonHeight;
    if (hasBrand) bodyHeight += _brandHeight + 4;
    if (hasStore) bodyHeight += 14 + 4;
    final imageHeight = widget.height - bodyHeight;
    return imageHeight.clamp(88, 150);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.preview.imageUrl.isEmpty
        ? null
        : AppImageCdn.buildUrl(widget.preview.imageUrl, AppImageVariant.card);
    final imageHeight = _resolveImageHeight();
    // Decode boyutlama: product_card.dart ile aynı DPR-aware desen. cacheWidth
    // fiziksel pikselden büyük olduğundan görünür kalite kaybı yok; tam
    // çözünürlük decode yerine downsample edilerek image cache RAM'i düşer.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final imageCacheWidth = (widget.width * devicePixelRatio).round().clamp(
      160,
      520,
    );
    final imageCacheHeight = (imageHeight * devicePixelRatio).round().clamp(
      160,
      520,
    );
    final hasBrand =
        widget.preview.brand != null && widget.preview.brand!.isNotEmpty;
    final hasStore =
        widget.showStore &&
        widget.preview.storeName != null &&
        widget.preview.storeName!.isNotEmpty;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl == null)
                      const SkeletonLoading(
                        width: double.infinity,
                        height: double.infinity,
                      )
                    else
                      OptimizedImage(
                        imageUrlOrPath: imageUrl,
                        fit: BoxFit.contain,
                        cacheWidth: imageCacheWidth,
                        cacheHeight: imageCacheHeight,
                        priority: OptimizedImagePriority.high,
                        onFirstFrameReady: () {
                          WebPerfTrace.instance.markImageFirstLoaded();
                        },
                      ),
                    if (widget.preview.hasDiscount)
                      Positioned(
                        top: 36,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'İndirimli',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: _showQuickView,
                        child: _buildQuickViewButton(),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              setState(() => _isFavorite = !_isFavorite),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: _isFavorite
                                  ? Colors.red
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasBrand)
                        SizedBox(
                          height: _brandHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.preview.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (hasBrand) const SizedBox(height: 2),
                      SizedBox(
                        height: _nameHeight,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.preview.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                      if (hasStore) ...[
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 14,
                          child: Text(
                            widget.preview.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        height: _priceBlockHeight,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.preview.hasDiscount)
                                Text(
                                  '₺${widget.preview.price.toStringAsFixed(widget.preview.price == widget.preview.price.roundToDouble() ? 0 : 2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE53935),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFFE53935),
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '₺${widget.preview.displayPrice.toStringAsFixed(widget.preview.displayPrice == widget.preview.displayPrice.roundToDouble() ? 0 : 2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (widget.preview.hasDiscount) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.arrow_downward,
                                            size: 9,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'İndirim',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF2E7D32),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: _buttonHeight,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onAddTap ?? widget.onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                _buttonHeight / 2,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Sepete Ekle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
