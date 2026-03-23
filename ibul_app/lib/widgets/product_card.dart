import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../screens/product_detail_page.dart';
import '../screens/home_screen.dart';
import '../core/app_state.dart';
import '../core/cart_state.dart';
import '../core/favorite_state.dart';
import '../core/review_state.dart';
import '../core/constants.dart';
import '../screens/login_page.dart';
import '../screens/business_detail_page.dart';
import 'optimized_image.dart';

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

class ProductCard extends StatefulWidget {
  final Product product;
  final double? width;
  final bool compact;
  final EdgeInsetsGeometry? margin;
  final bool tight;
  final bool forceFoodOrderButton;
  final bool pinActionsBottom;

  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.compact = false,
    this.margin,
    this.tight = false,
    this.forceFoodOrderButton = false,
    this.pinActionsBottom = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final String _heroTag;

  // Purple color from the screenshot
  static const Color _brandPurple = Color(0xFF7C3AED);

  AppState get _appState => context.read<AppState>();

  _CampaignBadgeData? get _campaignBadgeData {
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

    final discountTag = widget.product.tags.cast<String?>().firstWhere(
      (tag) => tag != null && tag.contains('indirim'),
      orElse: () => null,
    );
    if (discountTag != null) {
      return const _CampaignBadgeData(
        text: 'İndirimli',
        backgroundColor: Color(0xFFFFD54F),
        textColor: Colors.black87,
      );
    }

    return const _CampaignBadgeData(
      text: 'Fırsat Ürünü',
      backgroundColor: Color(0xFFF4CF4A),
      textColor: Color(0xFF2F2A16),
    );
  }

  String? get _primaryImageUrlOrPath {
    if (widget.product.images.isNotEmpty &&
        widget.product.images.first.trim().isNotEmpty) {
      return widget.product.images.first.trim();
    }
    final thumb = widget.product.thumbnailPublicUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _heroTag =
        'product-image-${widget.product.productId ?? widget.product.name}-${identityHashCode(this)}';
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return widget.compact
        ? _buildCompactCard(
            isAddedToCart: isAddedToCart,
            isFavorite: isFavorite,
            ratingData: ratingData,
          )
        : _buildNormalCard(
            isAddedToCart: isAddedToCart,
            isFavorite: isFavorite,
            ratingData: ratingData,
          );
  }

  void _onCardTap() {
    // Wrap navigation in Future.delayed to avoid MouseTracker crash on Web
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProductDetailPage(product: widget.product, heroTag: _heroTag),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 160),
        ),
      );
    });
  }

  Widget _buildOptimizedCardImage({
    double? aspectRatio,
    double? height,
    required BorderRadius borderRadius,
    required double fallbackIconSize,
  }) {
    assert(aspectRatio != null || height != null);

    final imageContent = Container(
      color: Colors.grey[100],
      width: double.infinity,
      alignment: Alignment.center,
      child: Hero(
        tag: _heroTag,
        child: _primaryImageUrlOrPath != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final mediaQuery = MediaQuery.of(context);
                  final logicalWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : (widget.width ?? (widget.compact ? 160 : 220));
                  final logicalHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : (height ?? (logicalWidth / aspectRatio!));
                  final devicePixelRatio = mediaQuery.devicePixelRatio;
                  final cacheWidth = (logicalWidth * devicePixelRatio)
                      .round()
                      .clamp(160, widget.compact ? 320 : 520);
                  final cacheHeight = (logicalHeight * devicePixelRatio)
                      .round()
                      .clamp(160, widget.compact ? 320 : 520);

                  return OptimizedImage(
                    imageUrlOrPath: _primaryImageUrlOrPath!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    errorWidget: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: fallbackIconSize,
                    ),
                  );
                },
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
      child: height != null
          ? SizedBox(
              height: height,
              width: double.infinity,
              child: imageContent,
            )
          : AspectRatio(aspectRatio: aspectRatio!, child: imageContent),
    );
  }

  double _resolveCardHeight(BoxConstraints constraints) {
    final preferredHeight = widget.compact
        ? 276.0
        : (widget.tight ? 300.0 : 312.0);

    if (constraints.maxHeight.isFinite) {
      return math.min(constraints.maxHeight, preferredHeight);
    }

    return preferredHeight;
  }

  double _resolveImageHeight(BoxConstraints constraints, double cardHeight) {
    final fallbackWidth = widget.width ?? (widget.compact ? 180.0 : 198.0);
    final availableWidth =
        constraints.maxWidth.isFinite && constraints.maxWidth > 0
        ? constraints.maxWidth
        : fallbackWidth;
    final verticalPadding = widget.compact ? 16.0 : (widget.tight ? 8.0 : 16.0);
    final innerHeight = math.max(0.0, cardHeight - verticalPadding);
    final idealImageHeight = widget.compact
        ? availableWidth * 0.72
        : availableWidth * 0.74;
    final reservedHeight = widget.compact
        ? 112.0
        : (widget.tight ? 146.0 : 150.0);
    final maxImageHeight = math.max(
      widget.compact ? 92.0 : (widget.tight ? 72.0 : 118.0),
      innerHeight - reservedHeight,
    );

    return math.min(
      widget.compact ? 145.0 : 155.0,
      math.max(
        widget.compact ? 92.0 : (widget.tight ? 72.0 : 118.0),
        math.min(idealImageHeight, maxImageHeight),
      ),
    );
  }

  // Normal card for home page (new design like screenshot)
  Widget _buildNormalCard({
    required bool isAddedToCart,
    required bool isFavorite,
    required ProductRatingSummary ratingData,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = widget.tight;
        final cardHeight = _resolveCardHeight(constraints);
        final imageHeight = _resolveImageHeight(constraints, cardHeight);
        final padding = isTight ? 4.0 : 8.0;

        return SizedBox(
          width: widget.width,
          height: cardHeight,
          child: Container(
            margin: widget.margin ?? EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
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
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      padding,
                      padding,
                      padding,
                      padding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNormalImageSection(
                          isFavorite: isFavorite,
                          imageHeight: imageHeight,
                        ),
                        SizedBox(height: isTight ? 3 : 5),
                        _buildCampaignBadge(),
                        SizedBox(height: isTight ? 3 : 5),
                        _buildTitle(),
                        const SizedBox(height: 2),
                        _buildRating(ratingData),
                        SizedBox(height: isTight ? 3 : 5),
                        _buildPrice(),
                        SizedBox(height: isTight ? 4 : 6),
                        _buildButton(context, isAddedToCart),
                      ],
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
    required ProductRatingSummary ratingData,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = _resolveCardHeight(constraints);
        final imageHeight = _resolveImageHeight(constraints, cardHeight);

        return SizedBox(
          height: cardHeight,
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildImageSection(
                          isFavorite: isFavorite,
                          imageHeight: imageHeight,
                        ),
                        const SizedBox(height: 6),
                        _buildCampaignBadge(),
                        const SizedBox(height: 5),
                        _buildTitle(),
                        const SizedBox(height: 2),
                        _buildRating(ratingData),
                        const SizedBox(height: 5),
                        _buildPrice(),
                        const SizedBox(height: 6),
                        _buildButton(context, isAddedToCart),
                      ],
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

  // Normal image section with AspectRatio (for home page)
  Widget _buildNormalImageSection({
    required bool isFavorite,
    required double imageHeight,
  }) {
    return Stack(
      children: [
        // Product Image - Wrapped in GestureDetector to ensure tap is caught
        GestureDetector(
          onTap: _onCardTap,
          behavior: HitTestBehavior.opaque,
          child: _buildOptimizedCardImage(
            height: imageHeight,
            borderRadius: BorderRadius.circular(14),
            fallbackIconSize: 40,
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
      ],
    );
  }

  // Compact image section with AspectRatio (for seller page)
  Widget _buildImageSection({
    required bool isFavorite,
    required double imageHeight,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
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
        // Heart Icon
        Positioned(
          top: isSmallScreen ? 4 : 6,
          right: isSmallScreen ? 4 : 6,
          child: GestureDetector(
            onTap: () {
              _handleFavoriteTap(context);
            },
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
      ],
    );
  }

  Widget _buildCampaignBadge() {
    final badgeData = _campaignBadgeData;
    if (badgeData == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final verticalPadding = widget.compact
        ? 4.0
        : (widget.tight ? 4.0 : (isMobile ? 5.0 : 5.5));
    final fontSize = widget.compact
        ? 8.5
        : (widget.tight ? 8.2 : (isMobile ? 8.8 : 9.3));

    return SizedBox(
      width: double.infinity,
      height: widget.compact ? 22 : 24,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: widget.compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: badgeData.backgroundColor,
          borderRadius: BorderRadius.circular(widget.compact ? 10 : 999),
        ),
        child: Text(
          badgeData.text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: badgeData.textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = widget.compact
        ? (isSmallScreen ? 9.0 : 10.0)
        : (widget.tight ? 10.0 : 10.8);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black87,
          height: widget.compact ? 1.2 : 1.25,
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
    );
  }

  Widget _buildRating(ProductRatingSummary ratingData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final rating = ratingData.rating;
    final reviewCount = ratingData.reviewCount;

    if (widget.compact) {
      // Compact mode: Stars + rating + count
      final starSize = isSmallScreen ? 7.0 : 9.0;
      final fontSize = isSmallScreen ? 8.0 : 9.0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (index) {
            if (index < rating.floor()) {
              return Icon(Icons.star, color: Colors.amber, size: starSize);
            } else if (index < rating) {
              return Icon(Icons.star_half, color: Colors.amber, size: starSize);
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
      );
    }

    // Normal mode: Rating like screenshot - stars, number, (count)
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            if (index < rating.floor()) {
              return const Icon(Icons.star, color: Colors.amber, size: 12);
            } else if (index < rating) {
              return const Icon(Icons.star_half, color: Colors.amber, size: 12);
            }
            return Icon(Icons.star_border, color: Colors.grey[300], size: 12);
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
    );
  }

  Widget _buildPrice() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final priceText = widget.product.price.contains('TL')
        ? widget.product.price
        : '${widget.product.price} TL';
    final hasDiscount =
        widget.product.oldPrice != null && widget.product.oldPrice!.isNotEmpty;

    if (widget.compact) {
      final oldPriceSlotHeight = isSmallScreen ? 10.0 : 11.0;

      return SizedBox(
        key: const ValueKey('product-card-price-block'),
        height: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: oldPriceSlotHeight,
              child: hasDiscount
                  ? Text(
                      widget.product.oldPrice!.contains('TL')
                          ? widget.product.oldPrice!
                          : '${widget.product.oldPrice!} TL',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 8.5 : 9.0,
                        color: Colors.red,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.red,
                        decorationThickness: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      priceText,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11.5 : 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 4),
                  _buildDiscountChip(compact: true),
                ],
              ],
            ),
          ],
        ),
      );
    }

    const oldPriceSlotHeight = 12.0;

    return SizedBox(
      key: const ValueKey('product-card-price-block'),
      height: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: oldPriceSlotHeight,
            child: hasDiscount
                ? Text(
                    widget.product.oldPrice!.contains('TL')
                        ? widget.product.oldPrice!
                        : '${widget.product.oldPrice!} TL',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red,
                      decorationThickness: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 4),
                _buildDiscountChip(),
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
            size: compact ? 8 : 9,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 2),
          Text(
            'İndirim',
            style: TextStyle(
              fontSize: compact ? 7.5 : 8.0,
              color: const Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool isAddedToCart) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final category = (widget.product.category ?? '').toLowerCase();
    final subCategory = (widget.product.subCategory ?? '').toLowerCase();
    final isFoodCategory =
        widget.forceFoodOrderButton ||
        category.contains('yemek') ||
        subCategory.contains('yemek');

    // Mobil için daha küçük buton
    final buttonHeight = widget.compact ? 28.0 : (widget.tight ? 30.0 : 34.0);
    final fontSize = widget.compact ? 9.0 : (isMobile ? 11.0 : 12.0);

    // Eğer yemek kategorisi ise özel "Sipariş Ver" butonu göster
    if (isFoodCategory) {
      return SizedBox(
        key: const ValueKey('product-card-primary-button'),
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: () => _showFoodOrderModePopup(context),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.compact ? 6 : 12),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Sipariş Ver',
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    // Eğer sepete eklendiyse, yeni tasarım (Sepete Eklendi | Sepet İkonu)
    if (isAddedToCart) {
      return LayoutBuilder(
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
                child: ElevatedButton(
                  onPressed: _onCardTap,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.compact ? 6 : 12,
                      ),
                    ),
                  ),
                  child: Text(
                    'Sepette',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: iconButtonWidth,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(initialIndex: 3),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.compact ? 6 : 12,
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: widget.compact ? 16 : 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Normal Sepete Ekle Butonu
    return SizedBox(
      key: const ValueKey('product-card-primary-button'),
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: () {
          _handleAddToCartTap(context);
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 0,
          ), // padding ekle
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.compact ? 6 : 12),
          ),
          side: const BorderSide(color: _brandPurple, width: 2),
          backgroundColor: Colors.white,
          foregroundColor: _brandPurple,
        ),
        child: Text(
          'Sepete Ekle',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _handleFavoriteTap(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    setState(() {
      _appState.toggleFavorite(widget.product);
    });
  }

  void _handleAddToCartTap(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    setState(() {
      _appState.addToCart(widget.product);
    });
  }

  void _showFoodOrderModePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isDismissible: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                const SizedBox(height: 20),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Nasıl sipariş vermek istersiniz?',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _foodModeButton(
                        context: context,
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: _foodModeButton(
                        context: context,
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BusinessDetailPage(
          business: business,
          storeProducts: [widget.product],
          forceTableSelection: true,
        ),
      ),
    );
  }

  void _navigateToOnlineCart(BuildContext context) {
    if (!_appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    _appState.addToCart(widget.product);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(initialIndex: 3),
      ),
      (route) => false,
    );
  }
}
