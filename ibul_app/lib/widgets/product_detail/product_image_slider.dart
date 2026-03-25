import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/app_motion.dart';
import '../../core/app_image_cdn.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../core/interaction_feedback.dart';
import '../../screens/product_features_page.dart';
import '../../screens/login_page.dart';
import '../common/video_player_widget.dart'; // Added
import 'comparison_modal.dart';
import 'product_360_viewer.dart';
import 'add_to_list_modal.dart';

class ProductImageSlider extends StatefulWidget {
  final bool isMobile;
  final String? heroTag;
  const ProductImageSlider({super.key, this.isMobile = false, this.heroTag});

  @override
  State<ProductImageSlider> createState() => _ProductImageSliderState();
}

class _ProductImageSliderState extends State<ProductImageSlider> {
  late PageController _pageController;
  bool _show360 = false; // final kaldırıldı
  bool _hasSettledHeroLayout = true;

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
  void initState() {
    super.initState();
    _pageController = PageController();
    _hasSettledHeroLayout = widget.heroTag == null;
    if (!_hasSettledHeroLayout) {
      _scheduleHeroLayoutSettle();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheProductImages();
  }

  /// Precaches all product images at the bounded decode resolution so that
  /// swiping between slides is synchronous (no raster spike on first decode).
  void _precacheProductImages() {
    final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
    final images = viewModel.images;
    if (images.isEmpty) return;

    // Main (first) image: detail variant (960×960); rest: card variant (420×420).
    for (var i = 0; i < images.length; i++) {
      final url = images[i];
      if (url.isEmpty) continue;
      final variant = i == 0 ? AppImageVariant.detail : AppImageVariant.card;
      final cdnUrl = AppImageCdn.buildUrl(url, variant);
      final spec = AppImageCdn.cacheSize(variant);
      final provider = OptimizedImage.buildProvider(
        imageUrlOrPath: cdnUrl,
        cacheWidth: spec.width,
        cacheHeight: spec.height,
      );
      if (provider != null) {
        precacheImage(provider, context).ignore();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ProductImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroTag != widget.heroTag && widget.heroTag != null) {
      _hasSettledHeroLayout = false;
      _scheduleHeroLayoutSettle();
    }
  }

  void _scheduleHeroLayoutSettle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        AppMotion.routeDuration + const Duration(milliseconds: 40),
        () {
          if (!mounted) return;
          setState(() {
            _hasSettledHeroLayout = true;
          });
        },
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final images = viewModel.images;

    // Sync controller if the ViewModel index changes externally
    if (_pageController.hasClients &&
        _pageController.page?.round() != viewModel.currentImageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            viewModel.currentImageIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Column(
      children: [
        // Main Image Area
        Container(
          decoration: widget.isMobile
              ? const BoxDecoration(color: Colors.white) // Mobile: Flat
              : BoxDecoration(
                  // Web: Card style
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: widget.isMobile
                    ? 1.3
                    : 1.0, // Reduced height for mobile (was 1.0)
                child:
                    _show360 &&
                        viewModel.initialProduct.threeSixtyImages != null
                    ? Product360Viewer(
                        imageUrls: viewModel.initialProduct.threeSixtyImages!,
                        autoRotate: false,
                      )
                    : PageView.builder(
                        controller: _pageController,
                        onPageChanged: viewModel.updateImageIndex,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imageUrl = images[index];
                          final isHeroImage = index == 0;
                          final imageWidget = isHeroImage
                              ? _buildHeroImage(imageUrl, viewModel)
                              : _buildSettledImage(imageUrl);

                          // Only wrap the first image with Hero to match ProductCard
                          if (isHeroImage) {
                            final fallbackTag = 'product-image-${viewModel.initialProduct.productId ?? viewModel.initialProduct.name}';
                            return Hero(
                              tag: widget.heroTag ?? fallbackTag,
                              transitionOnUserGestures: true,
                              placeholderBuilder: (_, __, child) => child,
                              child: imageWidget,
                            );
                          }
                          return imageWidget;
                        },
                      ),
              ),

              // Navigation Arrows (Web only or if multiple images)
              if (images.length > 1 && !widget.isMobile) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(
                      Icons.chevron_left,
                      onPressed: viewModel.prevImage,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavArrow(
                      Icons.chevron_right,
                      onPressed: viewModel.nextImage,
                    ),
                  ),
                ),
              ],

              // Action Icons (Top Right - Floating Vertical Stack)
              Positioned(
                top: widget.isMobile
                    ? 12 + MediaQuery.of(context).padding.top
                    : 12,
                right: 12,
                child: Column(
                  children: [
                    _buildFloatingActionButton(
                      Icons.share_outlined,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      Icons.bookmark_border,
                      onPressed: () {
                        final appState = Provider.of<AppState>(
                          context,
                          listen: false,
                        );
                        if (!appState.isLoggedIn) {
                          _showLoginRequiredDialog(context);
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddToListModal(
                            product: viewModel.initialProduct,
                            userLists: appState.productLists,
                            onAddToList: (listId) {
                              return appState.addToProductList(
                                listId,
                                viewModel.initialProduct,
                              );
                            },
                            onCreateNewList: (listName, visibility) {
                              final listId = appState.createProductList(
                                listName,
                                visibility: visibility,
                              );
                              return appState.addToProductList(
                                listId,
                                viewModel.initialProduct,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      Icons.compare_arrows,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ComparisonModal(
                            currentProduct: viewModel.initialProduct,
                            similarProducts: viewModel.similarProducts,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingActionButton(
                      viewModel.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: viewModel.isFavorite
                          ? Colors.red
                          : const Color(0xFF673AB7),
                      onPressed: () {
                        InteractionFeedback.forInteraction(
                          InteractionFeedbackType.favorite,
                        );
                        viewModel.toggleFavorite();
                      },
                    ),
                  ],
                ),
              ),

              if (images.length > 1 && widget.isMobile && !_show360)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final isSelected = viewModel.currentImageIndex == index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 8 : 6,
                        height: isSelected ? 8 : 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),

              if (_show360Button(viewModel))
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildPillButton(
                    text: _show360 ? 'Fotoğraflar' : '360° Görünüm',
                    icon: _show360 ? Icons.image_outlined : Icons.threesixty,
                    isIconRight: !_show360,
                    onPressed: () {
                      setState(() {
                        _show360 = !_show360;
                      });
                    },
                  ),
                ),

              if (!widget.isMobile)
                Positioned(
                  left: 16,
                  top: 16,
                  child: _buildVideoPill(context, viewModel),
                ),
              if (widget.isMobile)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Row(
                    children: [
                      _buildVideoPill(context, viewModel, compact: true),
                      const Spacer(),
                      _buildFeaturesPill(context, viewModel),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Thumbnails (Hidden on mobile)
        if (images.length > 1 && !widget.isMobile) ...[
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = viewModel.currentImageIndex == index;
                  final imageUrl = images[index];
                  return GestureDetector(
                    onTap: () {
                      if (_show360) {
                        setState(() => _show360 = false);
                      }
                      viewModel.updateImageIndex(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imageUrl.startsWith('http')
                            ? OptimizedImage(
                                // Thumbnail strip: thumb variant 160×160 @ q70.
                                imageUrlOrPath: AppImageCdn.buildUrl(
                                  imageUrl,
                                  AppImageVariant.thumb,
                                ),
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                cacheHeight: 160,
                                placeholder: Container(color: Colors.grey[100]),
                                errorWidget: const Icon(
                                  Icons.error,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              )
                            : Image.asset(
                                imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 200,
                                cacheHeight: 200,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.error,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _show360Button(ProductDetailViewModel viewModel) {
    return viewModel.initialProduct.threeSixtyImages != null &&
        viewModel.initialProduct.threeSixtyImages!.isNotEmpty;
  }

  Widget _buildHeroImage(
    String imageUrl,
    ProductDetailViewModel viewModel,
  ) {
    final hasSettledLayout =
        _hasSettledHeroLayout && viewModel.currentImageIndex == 0;

    return AnimatedSwitcher(
      duration: AppMotion.normalTransitionDuration,
      reverseDuration: AppMotion.normalTransitionReverseDuration,
      switchInCurve: AppMotion.pageTransitionCurve,
      switchOutCurve: AppMotion.pageTransitionReverseCurve,
      child: hasSettledLayout
          ? KeyedSubtree(
              key: const ValueKey('product-detail-image-settled'),
              child: _buildImageFrame(
                imageUrl,
                fit: BoxFit.contain,
                padding: const EdgeInsets.all(16),
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('product-detail-image-hero'),
              child: _buildImageFrame(
                imageUrl,
                fit: BoxFit.cover,
                padding: EdgeInsets.zero,
              ),
            ),
    );
  }

  Widget _buildSettledImage(String imageUrl) {
    return _buildImageFrame(
      imageUrl,
      fit: BoxFit.contain,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _buildImageFrame(
    String imageUrl, {
    required BoxFit fit,
    required EdgeInsets padding,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: padding,
        child: _buildProductImage(imageUrl, fit: fit),
      ),
    );
  }

  Widget _buildProductImage(String imageUrl, {required BoxFit fit}) {
    if (imageUrl.startsWith('http')) {
      // Apply detail variant (960×960 @ q82) for the main product detail image.
      final cdnUrl = AppImageCdn.buildUrl(imageUrl, AppImageVariant.detail);
      final spec = AppImageCdn.cacheSize(AppImageVariant.detail);
      return OptimizedImage(
        imageUrlOrPath: cdnUrl,
        fit: fit,
        cacheWidth: spec.width,
        cacheHeight: spec.height,
        placeholder: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: _buildPlaceholder(),
      );
    }

    return Image.asset(
      imageUrl,
      fit: fit,
      cacheWidth: 800,
      cacheHeight: 800,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  void _showVideoDialog(
    BuildContext context,
    String videoUrl, {
    String? thumbnailUrl,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              constraints: BoxConstraints(
                maxWidth: size.width - 32,
                maxHeight: size.height * 0.75,
              ),
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: VideoPlayerWidget(
                        videoUrl: videoUrl,
                        thumbnailUrl: thumbnailUrl,
                        initializeOnTap: true,
                        autoPlay: false,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.12),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[50],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildNavArrow(IconData icon, {VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(
    IconData icon, {
    VoidCallback? onPressed,
    Color iconColor = const Color(0xFF673AB7),
  }) {
    return Container(
      width: 36, // Reduced from 40
      height: 36, // Reduced from 40
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: 18, color: iconColor), // Reduced from 20
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isIconRight = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16), // Slightly tighter radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isIconRight) ...[
              Icon(icon, size: 14, color: Colors.black87), // Reduced from 16
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isIconRight) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: Colors.black87), // Reduced from 16
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPill(
    BuildContext context,
    ProductDetailViewModel viewModel, {
    bool compact = false,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final url = viewModel.initialProduct.videoUrl?.trim() ?? '';
          if (url.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu ürün için video yok')),
            );
            return;
          }
          _showVideoDialog(
            context,
            url,
            thumbnailUrl: viewModel.initialProduct.thumbnailPublicUrl,
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: compact ? 15 : 18,
                color: const Color(0xFF6B21A8),
              ),
              const SizedBox(width: 6),
              Text(
                compact ? 'Ürün Videosu' : 'Video',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B21A8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesPill(
    BuildContext context,
    ProductDetailViewModel viewModel,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProductFeaturesPage(product: viewModel.initialProduct),
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tüm Özellikler',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B21A8),
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: Color(0xFF6B21A8)),
            ],
          ),
        ),
      ),
    );
  }
}
