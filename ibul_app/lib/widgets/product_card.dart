import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/product_model.dart';
import '../screens/product_detail_page.dart';
import '../screens/home_screen.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../screens/business_detail_page.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final double? width;
  final bool compact;
  final EdgeInsetsGeometry? margin;

  const ProductCard({
    super.key, 
    required this.product, 
    this.width, 
    this.compact = false,
    this.margin,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isAddedToCart = false;
  final AppState _appState = AppState();

  // Purple color from the screenshot
  static const Color _brandPurple = Color(0xFF7C3AED);

  bool _hasDiscount() {
    return widget.product.name.hashCode % 2 == 0;
  }

  @override
  Widget build(BuildContext context) {
    // Check if product is in cart to update state
    _isAddedToCart = _appState.isInCart(widget.product);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProductDetailPage(product: widget.product),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 250),
          ),
        ).then((_) {
          // Refresh state when returning from detail page
          if (mounted) {
             setState(() {
               _isAddedToCart = _appState.isInCart(widget.product);
             });
          }
        });
      },
      child: widget.compact ? _buildCompactCard() : _buildNormalCard(),
    );
  }

  // Normal card for home page (new design like screenshot)
  Widget _buildNormalCard() {
    return Container(
      width: widget.width,
      margin: widget.margin ?? const EdgeInsets.only(right: 12, bottom: 8, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNormalImageSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCampaignBadge(),
                  const SizedBox(height: 8),
                  _buildTitle(),
                  const SizedBox(height: 6),
                  _buildRating(),
                  const Spacer(),
                  _buildPrice(),
                  const SizedBox(height: 10),
                  _buildButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact card for seller page (like Listelerim)
  Widget _buildCompactCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCampaignBadge(),
                  const SizedBox(height: 2),
                  _buildTitle(),
                  const SizedBox(height: 2),
                  _buildRating(),
                  const SizedBox(height: 8), // Spacer yerine sabit boşluk
                  _buildPrice(),
                  const Spacer(), // Butonu en alta itmek için
                  _buildButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Normal image section with AspectRatio (for home page)
  Widget _buildNormalImageSection() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1.25, // Görsel yüksekliği azaltıldı (1.0 -> 1.25)
            child: Container(
              color: Colors.grey[100],
              child: widget.product.images.isNotEmpty && widget.product.images.first.isNotEmpty
                  ? (widget.product.images.first.startsWith('http')
                      ? Image.network(
                          widget.product.images.first,
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        )
                      : Image.asset(
                          widget.product.images.first,
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ))
                  : Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: 40,
                    ),
            ),
          ),
        ),
        // Heart Icon
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _appState.toggleFavorite(widget.product);
              });
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
                _appState.isFavorite(widget.product) ? Icons.favorite : Icons.favorite_border,
                color: _appState.isFavorite(widget.product) ? Colors.red : Colors.grey.shade400,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Compact image section with AspectRatio (for seller page)
  Widget _buildImageSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    
    return Stack(
      children: [
        // Product Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              color: Colors.grey[100],
              child: widget.product.images.isNotEmpty && widget.product.images.first.isNotEmpty
                  ? (widget.product.images.first.startsWith('http')
                      ? Image.network(
                          widget.product.images.first,
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                        )
                      : Image.asset(
                          widget.product.images.first,
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                        ))
                  : Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: isSmallScreen ? 25 : 30,
                    ),
            ),
          ),
        ),
        // Heart Icon
        Positioned(
          top: isSmallScreen ? 4 : 6,
          right: isSmallScreen ? 4 : 6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _appState.toggleFavorite(widget.product);
              });
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
                _appState.isFavorite(widget.product) ? Icons.favorite : Icons.favorite_border,
                color: _appState.isFavorite(widget.product) ? Colors.red : Colors.grey.shade400,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignBadge() {
    // Dynamic badge based on product tags
    String badgeText = 'Fırsat Ürünü'; // Changed default text
    Color badgeColor = const Color(0xFFFFD54F); // Default Yellow
    Color textColor = Colors.black87;

    if (widget.product.tags.contains('Ücretsiz Kargo')) {
      badgeText = 'Ücretsiz Kargo';
      badgeColor = const Color(0xFF6200EE); // Purple
      textColor = Colors.white;
    } else if (widget.product.tags.contains('Hızlı Kargo')) {
      badgeText = 'Hızlı Kargo';
      badgeColor = const Color(0xFF2196F3); // Blue
      textColor = Colors.white;
    } else if (widget.product.tags.any((t) => t.contains('indirim'))) {
      badgeText = widget.product.tags.firstWhere((t) => t.contains('indirim'));
      badgeColor = Colors.red; // Red for discount
      textColor = Colors.white;
    }

    // Returning container with fixed size constraints/structure as requested
    // to match the visual "bar" style exactly.
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: widget.compact ? 2 : 4, horizontal: widget.compact ? 6 : 8),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
        ),
        child: Text(
          badgeText,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: widget.compact ? 8 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final fontSize = widget.compact ? (isSmallScreen ? 10.0 : 11.0) : 13.0;
    
    // Brand bold, name regular - Brand tıklanabilir
    return Row(
      children: [
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: "${widget.product.brand} ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      // Mock business data for the brand
                      final businessData = {
                        'id': widget.product.brand.hashCode,
                        'name': widget.product.brand,
                        'logo': widget.product.brand[0],
                        'rating': widget.product.rating.toString(),
                        'followers': '${(widget.product.reviewCount * 15).toString()}K',
                        'icon': Icons.store,
                        'distance': '500m',
                        'images': widget.product.images,
                      };
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessDetailPage(business: businessData),
                        ),
                      );
                    },
                ),
                TextSpan(
                  text: widget.product.name,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRating() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    if (widget.compact) {
      // Compact mode: Stars + rating + count
      final starSize = isSmallScreen ? 8.0 : 10.0;
      final fontSize = isSmallScreen ? 9.0 : 10.0;
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(5, (index) {
            if (index < widget.product.rating.floor()) {
               return Icon(Icons.star, color: Colors.amber, size: starSize);
            } else if (index < widget.product.rating) {
               return Icon(Icons.star_half, color: Colors.amber, size: starSize);
            }
            return Icon(Icons.star_border, color: Colors.grey[300], size: starSize);
          }),
          SizedBox(width: isSmallScreen ? 2 : 3),
          Flexible(
            child: Text(
              '${widget.product.rating} (${widget.product.reviewCount})',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black87,
              ),
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
            if (index < widget.product.rating.floor()) {
               return const Icon(Icons.star, color: Colors.amber, size: 12);
            } else if (index < widget.product.rating) {
               return const Icon(Icons.star_half, color: Colors.amber, size: 12);
            }
            return Icon(Icons.star_border, color: Colors.grey[300], size: 12);
          }),
        ),
        const SizedBox(width: 4),
        Text(
          '${widget.product.rating}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 3),
        Icon(Icons.photo_library, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 2),
        Text(
          '(${widget.product.reviewCount})',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Discount badge between rating and price
  Widget _buildDiscountBadge() {
    if (widget.compact || !_hasDiscount()) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text(
              "İndirimde",
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrice() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    if (widget.compact) {
      // Compact mode - bold price
      return Text(
        widget.product.price,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    // Normal mode - with old price from JSON
    final hasDiscount = widget.product.oldPrice != null && widget.product.oldPrice!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDiscount)
          Text(
            widget.product.oldPrice!.contains('TL') 
                ? widget.product.oldPrice! 
                : '${widget.product.oldPrice!} TL',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.red,
              decorationThickness: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (hasDiscount) const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.product.price.contains('TL') 
                      ? widget.product.price 
                      : '${widget.product.price} TL',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (hasDiscount) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_downward, size: 8, color: Color(0xFF2E7D32)),
                    SizedBox(width: 1),
                    Text(
                      'İndirim',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final buttonHeight = widget.compact ? 26.0 : 34.0;
    final fontSize = widget.compact ? 10.0 : 13.0;
    
    // Eğer sepete eklendiyse, yeni tasarım (Sepete Eklendi | Sepet İkonu)
    if (_isAddedToCart) {
      return Row(
        children: [
          // Sepete Eklendi Butonu (Gri)
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () {
                  // Sepetten çıkar
                  setState(() {
                    _appState.removeFromCart(widget.product);
                    _isAddedToCart = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.compact ? 6 : 12),
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
          ),
          const SizedBox(width: 8),
          // Sepet İkonu Butonu (Yeşil)
          SizedBox(
            width: buttonHeight + 10, // Biraz daha geniş olsun
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                // Sepete git - HomeScreen'e index 3 ile git (bottom bar korunsun)
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
                  borderRadius: BorderRadius.circular(widget.compact ? 6 : 12),
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
    }

    // Normal Sepete Ekle Butonu
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: () {
          // Sepete ekle
          setState(() {
            _appState.addToCart(widget.product);
            _isAddedToCart = true;
          });
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.compact ? 6 : 12),
          ),
          side: const BorderSide(
            color: _brandPurple,
            width: 2,
          ),
          backgroundColor: Colors.white,
          foregroundColor: _brandPurple,
        ),
        child: Text(
           'Sepete Ekle',
           style: TextStyle(
             fontSize: fontSize,
             fontWeight: FontWeight.w600,
           ),
        ),
      ),
    );
  }
}
