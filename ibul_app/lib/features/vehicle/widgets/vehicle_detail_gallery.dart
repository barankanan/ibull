import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../widgets/optimized_image.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_actions.dart';

class VehicleDetailGallery extends StatefulWidget {
  const VehicleDetailGallery({
    super.key,
    required this.listing,
    this.isMobile = false,
    this.favorite = false,
    this.previewMode = false,
    this.showActions = true,
    this.onFavorite,
    this.onShare,
    this.onSave,
    this.onCompare,
    this.onVideo,
    this.onAllFeatures,
    this.hasVideo = false,
    this.showAllFeatures = false,
    this.compared = false,
    this.topLeftOverlay,
  });

  static const Color surface = Color(0xFFF5F5F5);

  final VehicleListing listing;
  final bool isMobile;
  final bool favorite;
  final bool previewMode;
  final bool showActions;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onCompare;
  final VoidCallback? onVideo;
  final VoidCallback? onAllFeatures;
  final bool hasVideo;
  final bool showAllFeatures;
  final bool compared;
  final Widget? topLeftOverlay;

  static List<String> urlsOf(VehicleListing listing) {
    return [
      if ((listing.coverUrl ?? '').trim().isNotEmpty) listing.coverUrl!.trim(),
      ...listing.media.where((item) => !item.isVideo).map((m) => m.url.trim()),
    ].where((url) => url.isNotEmpty).toSet().toList(growable: false);
  }

  @override
  State<VehicleDetailGallery> createState() => _VehicleDetailGalleryState();
}

class _VehicleDetailGalleryState extends State<VehicleDetailGallery> {
  late final PageController _pages;
  int _index = 0;

  List<String> get _urls => VehicleDetailGallery.urlsOf(widget.listing);

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: [
            Container(
              key: const ValueKey('vehicle-detail-hero-image'),
              decoration: widget.isMobile
                  ? const BoxDecoration(color: Colors.white)
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  AspectRatio(
                    aspectRatio: widget.isMobile ? 1.3 : 1.0,
                    child: urls.isEmpty ? _placeholder() : _viewer(urls),
                  ),
                  if (urls.length > 1 && !widget.isMobile) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _nav(Icons.chevron_left, -1)),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _nav(Icons.chevron_right, 1)),
                    ),
                  ],
                  if (widget.showActions)
                    Positioned(
                      top: widget.isMobile
                          ? 12 + MediaQuery.paddingOf(context).top
                          : 12,
                      right: 12,
                      child: VehicleDetailActionRail(
                        favorite: widget.favorite,
                        compared: widget.compared,
                        previewMode: widget.previewMode,
                        onShare: widget.onShare,
                        onSave: widget.onSave,
                        onCompare: widget.onCompare,
                        onFavorite: widget.onFavorite,
                      ),
                    ),
                  if (urls.length > 1 && widget.isMobile)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(urls.length, (index) {
                          final selected = _index == index;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: selected ? 8 : 6,
                            height: selected ? 8 : 6,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                  if (widget.isMobile)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Row(
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: VehicleDetailVideoPill(
                                  hasVideo: widget.hasVideo,
                                  compact: true,
                                  onTap: widget.previewMode
                                      ? null
                                      : widget.onVideo,
                                ),
                              ),
                            ),
                          ),
                          if (widget.showAllFeatures) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: VehicleDetailFeaturesPill(
                                    onTap: widget.onAllFeatures,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!widget.isMobile)
              Positioned(
                left: 10,
                top: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.topLeftOverlay != null) ...[
                      widget.topLeftOverlay!,
                      const SizedBox(width: 8),
                    ],
                    VehicleDetailVideoPill(
                      hasVideo: widget.hasVideo,
                      onTap: widget.previewMode ? null : widget.onVideo,
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (urls.length > 1 && !widget.isMobile) ...[
          const SizedBox(height: 12),
          _thumbnailStrip(urls),
        ],
      ],
    );
  }

  Widget _thumbnailStrip(List<String> urls) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('vehicle-detail-thumbnail-strip'),
            width: width.isFinite ? width : 0,
            height: 60,
            child: ClipRect(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: urls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = _index == index;
                  return GestureDetector(
                    onTap: () => _go(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: OptimizedImage(
                          imageUrlOrPath: urls[index],
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 160,
                          priority: OptimizedImagePriority.lazy,
                          errorWidget: const ColoredBox(
                            color: AppColors.surfaceMuted,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 16,
                              color: AppColors.iconMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: VehicleDetailGallery.surface,
      child: Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 48,
          color: AppColors.iconMuted,
        ),
      ),
    );
  }

  Widget _viewer(List<String> urls) {
    return ColoredBox(
      color: Colors.white,
      child: PageView.builder(
        controller: _pages,
        itemCount: urls.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _lightbox(index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OptimizedImage(
                imageUrlOrPath: urls[index],
                fit: BoxFit.contain,
                cacheWidth: 960,
                errorWidget: _placeholder(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nav(IconData icon, int delta) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _go(_index + delta),
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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

  void _go(int index) {
    final urls = _urls;
    if (urls.isEmpty) return;
    final next = index.clamp(0, urls.length - 1);
    setState(() => _index = next);
    if (_pages.hasClients) {
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _lightbox(int index) {
    final urls = _urls;
    if (urls.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (context) => _VehicleLightbox(urls: urls, initialIndex: index),
    );
  }
}

class _VehicleLightbox extends StatefulWidget {
  const _VehicleLightbox({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_VehicleLightbox> createState() => _VehicleLightboxState();
}

class _VehicleLightboxState extends State<_VehicleLightbox> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.urls.length - 1);
    if (next == _index) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: AppColors.ink,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pages,
                  itemCount: widget.urls.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, i) => InteractiveViewer(
                    child: OptimizedImage(
                      imageUrlOrPath: widget.urls[i],
                      fit: BoxFit.contain,
                      errorWidget: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: _close,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ),
                if (widget.urls.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => _go(-1),
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => _go(1),
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                ],
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
