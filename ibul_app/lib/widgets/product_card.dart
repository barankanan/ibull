import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_image_cdn.dart';
import '../models/product_model.dart';
import '../screens/home_lazy_routes.dart';
import '../core/home_navigation.dart';
import '../core/app_state.dart';
import '../core/cart_state.dart';
import '../core/favorite_state.dart';
import '../core/compare_state.dart';
import '../core/review_state.dart';
import '../core/app_motion.dart';
import '../core/interaction_feedback.dart';
import '../core/build_profile.dart';
import '../core/constants.dart';
import '../models/product_pricing.dart';
import '../services/supabase_service.dart';
import 'optimized_image.dart';
import 'premium_interactions.dart';
import 'ecommerce_product_quick_info_sheet.dart';
import 'staggered_reveal.dart';

class _CampaignBadgeData {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _CampaignBadgeData({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });
}

/// Shared vertical rhythm for every product card.
/// Discount and plain products reserve the same slots, so rails stay aligned.
class _ProductCardMetrics {
  const _ProductCardMetrics({
    required this.padding,
    required this.imageGap,
    required this.badgeInFlow,
    required this.badgeHeight,
    required this.badgeGap,
    required this.titleBlockHeight,
    required this.titleFontSize,
    required this.titleLineHeight,
    required this.metaGap,
    required this.ratingBlockHeight,
    required this.priceGap,
    required this.priceBlockHeight,
    required this.priceFontSize,
    required this.oldPriceFontSize,
    required this.ctaGap,
    required this.ctaHeight,
    required this.ctaFontSize,
  });

  final double padding;
  final double imageGap;
  final bool badgeInFlow;
  final double badgeHeight;
  final double badgeGap;
  final double titleBlockHeight;
  final double titleFontSize;
  final double titleLineHeight;
  final double metaGap;
  final double ratingBlockHeight;
  final double priceGap;
  final double priceBlockHeight;
  final double priceFontSize;
  final double oldPriceFontSize;
  final double ctaGap;
  final double ctaHeight;
  final double ctaFontSize;

  double get ctaRadius => ctaHeight / 2;

  /// Content under the image, excluding the card's vertical padding.
  double get contentBelowImage {
    final badgeSlot = badgeInFlow ? badgeHeight + badgeGap : 0;
    return imageGap +
        badgeSlot +
        titleBlockHeight +
        metaGap +
        ratingBlockHeight +
        priceGap +
        priceBlockHeight +
        ctaGap +
        ctaHeight;
  }
}

class ProductCard extends StatefulWidget {
  final Product product;
  final double? width;
  final bool compact;
  final EdgeInsetsGeometry? margin;
  final bool tight;
  final bool forceFoodOrderButton;
  final bool pinActionsBottom;
  final bool isCatalogMode;

  /// Mobile home rail. Desktop cards leave this false.
  final bool homeRail;
  final OptimizedImagePriority imagePriority;

  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.compact = false,
    this.margin,
    this.tight = false,
    this.forceFoodOrderButton = false,
    this.pinActionsBottom = false,
    this.isCatalogMode = false,
    this.homeRail = false,
    this.imagePriority = OptimizedImagePriority.lazy,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final String _heroTag;
  late _CampaignBadgeData _campaignBadgeData;
  String? _primaryImageUrlOrPath;

  AppState get _appState => context.read<AppState>();

  _ProductCardMetrics _metrics(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;
    final homeRail = widget.homeRail;
    final tight = widget.tight;
    final compact = widget.compact;

    final titleFontSize = compact
        ? (isSmallScreen ? 9.0 : 10.0)
        : (tight ? 10.0 : 10.8);
    final titleLineHeight = compact ? 1.2 : 1.25;
    final oldPriceFontSize = compact ? (isSmallScreen ? 8.5 : 9.0) : 12.0;
    final priceFontSize = compact
        ? (isSmallScreen ? 11.5 : 12.5)
        : (homeRail ? 16.0 : 14.0);
    final chipHeight = compact ? 16.0 : 18.0;
    final oldLine = scaler.scale(oldPriceFontSize) * 1.1;
    final currentLine = math.max(
      scaler.scale(priceFontSize) * 1.15,
      chipHeight,
    );

    return _ProductCardMetrics(
      padding: homeRail ? 6 : (compact ? 8 : (tight ? 4 : 8)),
      imageGap: homeRail ? 4 : (compact ? 6 : (tight ? 3 : 5)),
      badgeInFlow: !homeRail,
      badgeHeight: compact ? 22 : 24,
      badgeGap: compact ? 5 : (tight ? 3 : 5),
      titleBlockHeight: scaler.scale(titleFontSize) * titleLineHeight * 2 + 1,
      titleFontSize: titleFontSize,
      titleLineHeight: titleLineHeight,
      metaGap: 2,
      ratingBlockHeight: scaler.scale(compact ? 14.0 : 16.0),
      priceGap: homeRail ? 4 : (compact ? 5 : (tight ? 3 : 5)),
      priceBlockHeight: oldLine + currentLine + 2,
      priceFontSize: priceFontSize,
      oldPriceFontSize: oldPriceFontSize,
      ctaGap: homeRail ? 6 : (compact ? 6 : (tight ? 4 : 6)),
      ctaHeight: homeRail ? 35 : (compact ? 32 : (tight ? 34 : 40)),
      ctaFontSize: compact ? 10 : (homeRail ? 13.5 : (tight ? 11 : 12)),
    );
  }

  _CampaignBadgeData _resolveCampaignBadgeData() {
    if (widget.product.tags.contains('Ücretsiz Kargo')) {
      return const _CampaignBadgeData(
        text: 'Ücretsiz Kargo',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    if (widget.product.tags.contains('Hızlı Kargo')) {
      return const _CampaignBadgeData(
        text: 'Hızlı Kargo',
        backgroundColor: Color(0xFF2196F3),
        textColor: Colors.white,
      );
    }

    final currentPrice = ProductPriceCalculator.parsePriceValue(
      widget.product.price,
    );
    final oldPrice = ProductPriceCalculator.parsePriceValue(
      widget.product.oldPrice ?? '',
    );
    final hasRealDiscount = oldPrice > currentPrice && currentPrice > 0;

    if (hasRealDiscount) {
      return _CampaignBadgeData(
        text: widget.homeRail ? 'Fırsat Ürünü' : 'İndirimli',
        backgroundColor: const Color(0xFFFFD54F),
        textColor: widget.homeRail ? const Color(0xFF2F2A16) : Colors.black87,
      );
    }

    if (widget.homeRail) {
      return const _CampaignBadgeData(
        text: '',
        backgroundColor: Colors.transparent,
        textColor: Colors.transparent,
      );
    }

    return const _CampaignBadgeData(
      text: 'Fırsat Ürünü',
      backgroundColor: Color(0xFFF4CF4A),
      textColor: Color(0xFF2F2A16),
    );
  }

  String? _resolvePrimaryImageUrlOrPath() {
    // Use CDN card variant — 420×420 @ q75 — instead of raw original URL.
    final url = widget.product.imageFor(AppImageVariant.card);
    return url.isEmpty ? null : url;
  }

  void _primeDerivedState() {
    _campaignBadgeData = _resolveCampaignBadgeData();
    _primaryImageUrlOrPath = _resolvePrimaryImageUrlOrPath();
  }

  @override
  void initState() {
    super.initState();
    _heroTag =
        'product-image-${widget.product.productId ?? widget.product.name}-${identityHashCode(this)}';
    _primeDerivedState();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.product, widget.product)) {
      _primeDerivedState();
    }
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giriş Yap'),
        content: const Text('Bu işlemi yapmak için giriş yapmanız gerekiyor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HomeLazyRoutes.openLogin(context);
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('ProductCard', () {
      final isAddedToCart = context.select<CartState, bool>(
        (cartState) => cartState.isInCart(widget.product),
      );
      final isFavorite = context.select<FavoriteState, bool>(
        (favoriteState) => favoriteState.isFavorite(widget.product),
      );
      final ratingData = context.select<ReviewState, ProductRatingSummary>(
        (reviewState) => reviewState.getProductRatingSummary(
          productName: widget.product.name,
          storeName: widget.product.store,
          fallbackRating: widget.product.rating,
          fallbackReviewCount: widget.product.reviewCount,
        ),
      );
      final isCompared = context.select<CompareState, bool>(
        (compareState) => compareState.isCompared(widget.product),
      );

      return RepaintBoundary(
        child: widget.compact
            ? _buildCompactCard(
                isAddedToCart: isAddedToCart,
                isFavorite: isFavorite,
                isCompared: isCompared,
                ratingData: ratingData,
              )
            : _buildNormalCard(
                isAddedToCart: isAddedToCart,
                isFavorite: isFavorite,
                isCompared: isCompared,
                ratingData: ratingData,
              ),
      );
    });
  }

  void _onCardTap() {
    InteractionFeedback.lightImpact(channel: 'product_card_open');
    // Wrap navigation in Future.delayed to avoid MouseTracker crash on Web
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      HomeLazyRoutes.openProductDetail(
        context,
        widget.product,
        heroTag: _heroTag,
      );
    });
  }

  /// Liste projeksiyonları description/specifications içermeyebilir;
  /// quick view açılınca tam satır arka planda çekilip birleştirilir.
  Future<Product?> _enrichQuickViewProduct() async {
    final id = widget.product.productId?.trim() ?? '';
    if (id.isEmpty) return null;
    final row = await SupabaseService.instance.getProductByIdString(id);
    return row == null ? null : Product.fromDBProduct(row);
  }

  void _showQuickView() {
    InteractionFeedback.lightImpact(channel: 'product_quick_view');
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      isScrollControlled: true,
      builder: (sheetContext) {
        return EcommerceProductQuickInfoSheet(
          product: widget.product,
          enrich: _enrichQuickViewProduct,
          onAddToCart: () => _handleAddToCartTap(context),
          onViewDetails: _onCardTap,
        );
      },
    );
  }

  Widget _buildOptimizedCardImage({
    double? aspectRatio,
    double? height,
    required BorderRadius borderRadius,
    required double fallbackIconSize,
  }) {
    assert(aspectRatio != null || height != null);

    final imagePath = _primaryImageUrlOrPath;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth =
        widget.width ??
        (widget.compact ? 160.0 : (widget.tight ? 188.0 : 198.0));
    final logicalHeight = height != null && height.isFinite
        ? height
        : (logicalWidth / (aspectRatio ?? 1.0));
    final cacheWidth = (logicalWidth * devicePixelRatio).round().clamp(
      160,
      widget.compact ? 320 : 520,
    );
    final cacheHeight = (logicalHeight * devicePixelRatio).round().clamp(
      160,
      widget.compact ? 320 : 520,
    );

    final imageContent = Container(
      color: const Color(0xFFF7F7F8),
      width: double.infinity,
      alignment: Alignment.center,
      child: Hero(
        tag: _heroTag,
        transitionOnUserGestures: true,
        child: imagePath != null
            ? OptimizedImage(
                imageUrlOrPath: imagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                priority: widget.imagePriority,
                onFirstFrameReady: () {
                  // Fire the StaggeredReveal signal so the slide animation
                  // starts only after this image's GPU texture is ready.
                  final signal = StaggeredRevealSignal.maybeOf(context);
                  if (signal != null && signal.value != true) {
                    signal.value = true;
                  }
                },
                errorWidget: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[400],
                  size: fallbackIconSize,
                ),
              )
            : Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
                size: fallbackIconSize,
              ),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: RepaintBoundary(
        child: height != null
            ? SizedBox(
                height: height,
                width: double.infinity,
                child: imageContent,
              )
            : AspectRatio(aspectRatio: aspectRatio!, child: imageContent),
      ),
    );
  }

  double _resolveFixedBodyHeight() => _metrics(context).contentBelowImage;

  double _resolveImageHeight(BoxConstraints constraints) {
    final fallbackWidth = widget.width ?? (widget.compact ? 180.0 : 198.0);
    final availableWidth =
        constraints.maxWidth.isFinite && constraints.maxWidth > 0
        ? constraints.maxWidth
        : fallbackWidth;
    final horizontalPadding = widget.compact
        ? 16.0
        : (widget.tight ? 8.0 : 16.0);
    final contentWidth = math.max(0.0, availableWidth - horizontalPadding);
    final imageRatio = widget.isCatalogMode
        ? 1.0
        : (widget.compact ? 0.72 : (widget.tight ? 0.70 : 0.72));
    final minHeight = widget.isCatalogMode
        ? 160.0
        : (widget.compact ? 92.0 : (widget.tight ? 72.0 : 100.0));
    final maxHeight = widget.isCatalogMode
        ? 300.0
        : (widget.compact ? 145.0 : 168.0);

    final naturalImageHeight = (contentWidth * imageRatio)
        .clamp(minHeight, maxHeight)
        .toDouble();

    if (!constraints.maxHeight.isFinite) {
      return naturalImageHeight;
    }

    final verticalPadding = widget.compact ? 16.0 : (widget.tight ? 8.0 : 16.0);
    const layoutSlack = 6.0;
    final innerMaxHeight = constraints.maxHeight - verticalPadding;
    final maxImageForCell =
        innerMaxHeight - _resolveFixedBodyHeight() - layoutSlack;

    if (maxImageForCell >= minHeight) {
      return math.min(naturalImageHeight, maxImageForCell);
    }

    return math.max(56.0, maxImageForCell);
  }

  // Normal card for home page (new design like screenshot)
  Widget _buildNormalCard({
    required bool isAddedToCart,
    required bool isFavorite,
    required bool isCompared,
    required ProductRatingSummary ratingData,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final homeRail = widget.homeRail;
        final metrics = _metrics(context);
        final fillCellHeight = !homeRail && constraints.maxHeight.isFinite;
        final imageHeight = homeRail
            ? 156.0
            : (fillCellHeight ? null : _resolveImageHeight(constraints));
        final padding = metrics.padding;

        return SizedBox(
          width: widget.width,
          height: fillCellHeight ? constraints.maxHeight : null,
          child: PremiumPressable(
            hoverLift: 2,
            hoverScale: 1.008,
            pressedScale: 0.982,
            child: Container(
              width: double.infinity,
              height: fillCellHeight ? double.infinity : null,
              margin: widget.margin ?? const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: _onCardTap,
                    onLongPress: _showQuickView,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        padding,
                        padding,
                        padding,
                        padding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: fillCellHeight
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        children: [
                          if (fillCellHeight)
                            Expanded(
                              child: _buildNormalImageSection(
                                isFavorite: isFavorite,
                                isCompared: isCompared,
                                fillAvailable: true,
                              ),
                            )
                          else
                            _buildNormalImageSection(
                              isFavorite: isFavorite,
                              isCompared: isCompared,
                              imageHeight: imageHeight!,
                            ),
                          SizedBox(height: metrics.imageGap),
                          if (metrics.badgeInFlow) ...[
                            _buildCampaignBadge(),
                            SizedBox(height: metrics.badgeGap),
                          ],
                          _buildTitle(),
                          SizedBox(height: metrics.metaGap),
                          _buildRating(ratingData),
                          SizedBox(height: metrics.priceGap),
                          _buildPrice(),
                          SizedBox(height: metrics.ctaGap),
                          _buildButton(context, isAddedToCart),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Compact card for seller page (like Listelerim)
  Widget _buildCompactCard({
    required bool isAddedToCart,
    required bool isFavorite,
    required bool isCompared,
    required ProductRatingSummary ratingData,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _metrics(context);
        final imageHeight = _resolveImageHeight(constraints);
        final boundedHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;

        return SizedBox(
          height: boundedHeight,
          child: PremiumPressable(
            hoverLift: 2,
            hoverScale: 1.008,
            pressedScale: 0.982,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: _onCardTap,
                    onLongPress: _showQuickView,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildImageSection(
                            isFavorite: isFavorite,
                            isCompared: false,
                            imageHeight: imageHeight,
                          ),
                          SizedBox(height: metrics.imageGap),
                          if (metrics.badgeInFlow) ...[
                            _buildCampaignBadge(),
                            SizedBox(height: metrics.badgeGap),
                          ],
                          _buildTitle(),
                          SizedBox(height: metrics.metaGap),
                          _buildRating(ratingData),
                          SizedBox(height: metrics.priceGap),
                          _buildPrice(),
                          SizedBox(height: metrics.ctaGap),
                          _buildButton(context, isAddedToCart),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Normal image section (for home page)
  Widget _buildNormalImageSection({
    required bool isFavorite,
    required bool isCompared,
    double? imageHeight,
    bool fillAvailable = false,
  }) {
    return Stack(
      fit: fillAvailable ? StackFit.expand : StackFit.loose,
      children: [
        // Product Image - Wrapped in GestureDetector to ensure tap is caught
        GestureDetector(
          onTap: _onCardTap,
          behavior: HitTestBehavior.opaque,
          child: _buildOptimizedCardImage(
            height: fillAvailable ? double.infinity : imageHeight!,
            borderRadius: BorderRadius.circular(14),
            fallbackIconSize: 40,
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
        // Heart Icon
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              _handleFavoriteTap(context);
            },
            child: PremiumPressable(
              pressedScale: 0.9,
              hoverScale: 1.04,
              hoverLift: 0.5,
              child: Container(
                width: widget.homeRail ? 22 : 28,
                height: widget.homeRail ? 22 : 28,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey.shade400,
                  size: widget.homeRail ? 13 : 16,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: widget.homeRail ? 28 : 36,
          right: 4,
          child: GestureDetector(
            onTap: () {
              _handleCompareTap(context);
            },
            child: PremiumPressable(
              pressedScale: 0.9,
              hoverScale: 1.04,
              hoverLift: 0.5,
              child: Container(
                width: widget.homeRail ? 22 : 28,
                height: widget.homeRail ? 22 : 28,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.compare_arrows,
                  color: isCompared ? AppColors.primary : Colors.grey.shade400,
                  size: widget.homeRail ? 13 : 16,
                ),
              ),
            ),
          ),
        ),
        if (widget.homeRail && _campaignBadgeData.text.isNotEmpty)
          Positioned(
            left: 6,
            bottom: 6,
            child: _buildCampaignBadge(overlay: true),
          ),
      ],
    );
  }

  // Compact image section with AspectRatio (for seller page)
  //
  // NOT (perf): bu dosyadaki tüm ekran-genişliği okumaları MediaQuery.sizeOf
  // kullanır. MediaQuery.of(context) kartı TÜM MediaQueryData'ya abone eder;
  // klavye açılış/kapanışı (viewInsets), safe-area veya textScale değişiminde
  // grid'deki her ProductCard yeniden build olurdu. sizeOf yalnız `size`
  // aspect'ine abone olur — okunan değer ve görsel çıktı birebir aynıdır.
  Widget _buildImageSection({
    required bool isFavorite,
    required bool isCompared,
    required double imageHeight,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;

    return Stack(
      children: [
        // Product Image - Wrapped in GestureDetector
        GestureDetector(
          onTap: _onCardTap,
          behavior: HitTestBehavior.opaque,
          child: _buildOptimizedCardImage(
            height: imageHeight,
            borderRadius: BorderRadius.circular(12),
            fallbackIconSize: isSmallScreen ? 25 : 30,
          ),
        ),
        Positioned(
          top: isSmallScreen ? 4 : 6,
          left: isSmallScreen ? 4 : 6,
          child: GestureDetector(
            onTap: _showQuickView,
            child: _buildQuickViewButton(compact: true),
          ),
        ),
        // Heart Icon
        Positioned(
          top: isSmallScreen ? 4 : 6,
          right: isSmallScreen ? 4 : 6,
          child: GestureDetector(
            onTap: () {
              _handleFavoriteTap(context);
            },
            child: PremiumPressable(
              pressedScale: 0.9,
              hoverScale: 1.04,
              hoverLift: 0.5,
              child: Container(
                width: 28,
                height: 28,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey.shade400,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 36,
          right: 4,
          child: GestureDetector(
            onTap: () {
              _handleCompareTap(context);
            },
            child: PremiumPressable(
              pressedScale: 0.9,
              hoverScale: 1.04,
              hoverLift: 0.5,
              child: Container(
                width: 28,
                height: 28,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.compare_arrows,
                  color: isCompared ? AppColors.primary : Colors.grey.shade400,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignBadge({bool overlay = false}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final metrics = _metrics(context);
    final verticalPadding = widget.compact
        ? 4.0
        : (widget.tight ? 4.0 : (isMobile ? 5.0 : 5.5));
    final fontSize = widget.compact
        ? 8.5
        : (widget.tight ? 8.2 : (isMobile ? 8.8 : 9.3));

    final badge = Container(
      padding: EdgeInsets.symmetric(
        vertical: overlay ? 3 : verticalPadding,
        horizontal: widget.compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _campaignBadgeData.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _campaignBadgeData.text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _campaignBadgeData.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );

    if (overlay) return badge;

    return SizedBox(
      width: double.infinity,
      height: metrics.badgeHeight,
      child: badge,
    );
  }

  Widget _buildTitle() {
    final metrics = _metrics(context);
    final fontSize = metrics.titleFontSize;

    return SizedBox(
      height: metrics.titleBlockHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.topLeft,
        child: RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black87,
              height: metrics.titleLineHeight,
            ),
            children: [
              TextSpan(
                text: "${widget.product.brand} ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: AppColors.primary,
                ),
              ),
              TextSpan(
                text: widget.product.name,
                style: TextStyle(fontSize: fontSize, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRating(ProductRatingSummary ratingData) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;
    final rating = ratingData.rating;
    final reviewCount = ratingData.reviewCount;
    final metrics = _metrics(context);

    if (widget.compact) {
      // Compact mode: Stars + rating + count
      final starSize = isSmallScreen ? 7.0 : 9.0;
      final fontSize = isSmallScreen ? 8.0 : 9.0;

      return SizedBox(
        height: metrics.ratingBlockHeight,
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              ...List.generate(5, (index) {
                if (index < rating.floor()) {
                  return Icon(Icons.star, color: Colors.amber, size: starSize);
                } else if (index < rating) {
                  return Icon(
                    Icons.star_half,
                    color: Colors.amber,
                    size: starSize,
                  );
                }
                return Icon(
                  Icons.star_border,
                  color: Colors.grey[300],
                  size: starSize,
                );
              }),
              SizedBox(width: isSmallScreen ? 2 : 3),
              Flexible(
                child: Text(
                  '${rating.toStringAsFixed(1)} ($reviewCount)',
                  style: TextStyle(fontSize: fontSize, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal mode: Rating like screenshot - stars, number, (count)
    return SizedBox(
      height: metrics.ratingBlockHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                if (index < rating.floor()) {
                  return const Icon(Icons.star, color: Colors.amber, size: 12);
                } else if (index < rating) {
                  return const Icon(
                    Icons.star_half,
                    color: Colors.amber,
                    size: 12,
                  );
                }
                return Icon(
                  Icons.star_border,
                  color: Colors.grey[300],
                  size: 12,
                );
              }),
            ),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 1),
            Icon(Icons.photo_library, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 1),
            if (!widget.tight)
              Flexible(
                child: Text(
                  '($reviewCount)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrice() {
    final metrics = _metrics(context);
    final priceText = widget.product.price.contains('TL')
        ? widget.product.price
        : '${widget.product.price} TL';

    final currentPrice = ProductPriceCalculator.parsePriceValue(
      widget.product.price,
    );
    final oldPrice = ProductPriceCalculator.parsePriceValue(
      widget.product.oldPrice ?? '',
    );
    final hasDiscount = oldPrice > currentPrice && currentPrice > 0;
    final oldPriceLabel = hasDiscount
        ? (widget.product.oldPrice!.contains('TL')
              ? widget.product.oldPrice!
              : '${widget.product.oldPrice!} TL')
        : null;

    return SizedBox(
      key: const ValueKey('product-card-price-block'),
      height: metrics.priceBlockHeight,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (oldPriceLabel != null)
            Text(
              oldPriceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: metrics.oldPriceFontSize,
                color: const Color(0xFFE53935),
                decoration: TextDecoration.lineThrough,
                decorationColor: const Color(0xFFE53935),
                decorationThickness: widget.compact ? 1.2 : 1.4,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          Row(
            children: [
              Flexible(
                child: Text(
                  priceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: metrics.priceFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                    height: 1.15,
                  ),
                ),
              ),
              if (hasDiscount) ...[
                SizedBox(width: widget.compact ? 4 : 6),
                _buildDiscountChip(compact: widget.compact),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountChip({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 5,
        vertical: compact ? 2 : 2.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(compact ? 4 : 5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_downward,
            size: compact ? 8 : 10,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 2),
          Text(
            'İndirim',
            style: TextStyle(
              fontSize: compact ? 7.5 : 10,
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickViewButton({bool compact = false}) {
    final size = widget.homeRail ? 22.0 : (compact ? 28.0 : 30.0);
    final iconSize = widget.homeRail ? 13.0 : (compact ? 16.0 : 17.0);

    return PremiumPressable(
      pressedScale: 0.9,
      hoverScale: 1.04,
      hoverLift: 0.5,
      child: Container(
        width: size,
        height: size,
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
        child: Icon(
          Icons.remove_red_eye_outlined,
          color: AppColors.primary,
          size: iconSize,
        ),
      ),
    );
  }

  ButtonStyle _pillButtonStyle({
    required Color background,
    required Color foreground,
    required double radius,
    Color? borderColor,
    Color? overlayColor,
    double? fixedHeight,
  }) {
    return premiumButtonInteractionStyle(
      ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: fixedHeight == null ? Size.zero : Size(0, fixedHeight),
        maximumSize: fixedHeight == null
            ? Size.infinite
            : Size(double.infinity, fixedHeight),
        fixedSize: fixedHeight == null ? null : Size.fromHeight(fixedHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        alignment: Alignment.center,
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      overlayColor: overlayColor ?? foreground,
    );
  }

  TextStyle _ctaTextStyle(double fontSize, Color color) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: 0.15,
      color: color,
    );
  }

  Widget _buildButton(BuildContext context, bool isAddedToCart) {
    final metrics = _metrics(context);
    final category = (widget.product.category ?? '').toLowerCase();
    final subCategory = (widget.product.subCategory ?? '').toLowerCase();
    final isFoodCategory =
        widget.forceFoodOrderButton ||
        category.contains('yemek') ||
        subCategory.contains('yemek');

    final buttonHeight = metrics.ctaHeight;
    final fontSize = metrics.ctaFontSize;

    return AnimatedSwitcher(
      duration: AppMotion.normalTransitionDuration,
      reverseDuration: AppMotion.normalTransitionReverseDuration,
      switchInCurve: AppMotion.pageTransitionCurve,
      switchOutCurve: AppMotion.pageTransitionReverseCurve,
      transitionBuilder: (child, animation) =>
          AppMotion.buildFadeScaleTransition(
            animation,
            child,
            beginScale: 0.97,
          ),
      child: isFoodCategory
          ? _buildFoodOrderButton(
              context: context,
              buttonHeight: buttonHeight,
              fontSize: fontSize,
            )
          : isAddedToCart
          ? _buildAddedToCartButton(
              context: context,
              buttonHeight: buttonHeight,
              fontSize: fontSize,
            )
          : _buildAddToCartButton(
              context: context,
              buttonHeight: buttonHeight,
              fontSize: fontSize,
            ),
    );
  }

  Widget _buildFoodOrderButton({
    required BuildContext context,
    required double buttonHeight,
    required double fontSize,
  }) {
    return PremiumPressable(
      key: const ValueKey('product-card-food-button'),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: () {
            InteractionFeedback.forInteraction(InteractionFeedbackType.mainCta);
            _showFoodOrderModePopup(context);
          },
          style: _pillButtonStyle(
            background: AppColors.primary,
            foreground: Colors.white,
            radius: widget.homeRail ? 14 : buttonHeight / 2,
            overlayColor: Colors.white,
            fixedHeight: buttonHeight,
          ),
          child: Text(
            'Sipariş Ver',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ctaTextStyle(
              fontSize,
              Colors.white,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildAddedToCartButton({
    required BuildContext context,
    required double buttonHeight,
    required double fontSize,
  }) {
    return LayoutBuilder(
      key: const ValueKey('product-card-added-button'),
      builder: (context, constraints) {
        final gap = widget.compact ? 6.0 : 8.0;
        final iconButtonWidth = buttonHeight + (widget.compact ? 8 : 10);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width ?? (widget.compact ? 140.0 : 200.0));
        final primaryButtonWidth = math.max(
          0.0,
          maxWidth - iconButtonWidth - gap,
        );

        return Row(
          children: [
            SizedBox(
              width: primaryButtonWidth,
              height: buttonHeight,
              child: PremiumPressable(
                child: ElevatedButton(
                  onPressed: _onCardTap,
                  style: _pillButtonStyle(
                    background: Colors.green,
                    foreground: Colors.white,
                    radius: buttonHeight / 2,
                    overlayColor: Colors.white,
                  ),
                  child: Text(
                    'Sepette',
                    style: _ctaTextStyle(fontSize, Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: iconButtonWidth,
              height: buttonHeight,
              child: PremiumPressable(
                child: ElevatedButton(
                  onPressed: () {
                    InteractionFeedback.forInteraction(
                      InteractionFeedbackType.mainCta,
                      channel: 'product_card_open_cart',
                    );
                    HomeNavigation.openHome(
                      context,
                      initialIndex: 3,
                      replaceStack: true,
                    );
                  },
                  style: _pillButtonStyle(
                    background: Colors.green,
                    foreground: Colors.white,
                    radius: buttonHeight / 2,
                    overlayColor: Colors.white,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: widget.compact ? 16 : 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddToCartButton({
    required BuildContext context,
    required double buttonHeight,
    required double fontSize,
  }) {
    return PremiumPressable(
      key: const ValueKey('product-card-primary-button'),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: () {
            _handleAddToCartTap(context);
          },
          style: _pillButtonStyle(
            background: Colors.white,
            foreground: AppColors.primary,
            borderColor: AppColors.primary,
            radius: 14,
            fixedHeight: buttonHeight,
          ),
          child: Text(
            'Sepete Ekle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ctaTextStyle(
              fontSize,
              AppColors.primary,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
          ),
        ),
      ),
    );
  }

  void _handleFavoriteTap(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    InteractionFeedback.forInteraction(InteractionFeedbackType.favorite);
    _appState.toggleFavorite(widget.product);
  }

  void _handleCompareTap(BuildContext context) {
    InteractionFeedback.lightImpact(channel: 'compare_tap');
    final compareState = Provider.of<CompareState>(context, listen: false);
    final error = compareState.toggleCompare(widget.product);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _handleAddToCartTap(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    InteractionFeedback.forInteraction(InteractionFeedbackType.addToCart);
    _appState.addToCart(widget.product);
  }

  void _showFoodOrderModePopup(BuildContext context) {
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nasıl sipariş vermek istersiniz?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _foodModeButton(
                        icon: Icons.table_restaurant_outlined,
                        label: 'Mekanda',
                        subtitle: 'Masaya sipariş ver',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _navigateToDiningMode(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _foodModeButton(
                        icon: Icons.delivery_dining_outlined,
                        label: 'Online',
                        subtitle: 'Sepetten onayla',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _navigateToOnlineCart(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _foodModeButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        InteractionFeedback.forInteraction(InteractionFeedbackType.mainCta);
        onTap();
      },
      child: PremiumPressable(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: color.withValues(alpha: 0.75),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDiningMode(BuildContext context) {
    final storeName = (widget.product.store ?? widget.product.brand).toString();
    final business = {
      'id': storeName.hashCode,
      'name': storeName,
      'category': 'restoran',
      'logo': storeName.isNotEmpty ? storeName[0] : '',
      'distance': '-',
      'seller_id': widget.product.sellerId ?? '',
    };

    HomeLazyRoutes.openBusinessDetail(
      context,
      business: business,
      forceTableSelection: true,
      storeProducts: [widget.product],
    );
  }

  void _navigateToOnlineCart(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    _appState.addToCart(widget.product);
    HomeNavigation.openHome(context, initialIndex: 3, replaceStack: true);
  }
}
