import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/ibul_chrome.dart';
import '../../../widgets/catalog_detail/catalog_detail_breadcrumb.dart';
import '../../../widgets/catalog_detail/catalog_detail_scope.dart';
import '../../../widgets/catalog_detail/catalog_detail_tabs.dart';
import '../../../widgets/catalog_detail/catalog_sidebar_cards.dart';
import '../../../widgets/product_detail/product_qa_card.dart';
import '../../../widgets/product_detail/product_reviews_section.dart';
import '../domain/vehicle_detail_adapter.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_detail_center_card.dart';
import 'vehicle_detail_gallery.dart';
import 'vehicle_detail_location_tab.dart';
import 'vehicle_detail_sections.dart';
import 'vehicle_rental_info_panel.dart';

class VehicleListingDetailView extends StatefulWidget {
  const VehicleListingDetailView({
    super.key,
    required this.listing,
    this.previewMode = false,
    this.favorite = false,
    this.following = false,
    this.related = const [],
    this.onFavorite,
    this.onShare,
    this.onSave,
    this.onMessage,
    this.onFollow,
    this.onOpenGallery,
    this.onOpenRelated,
    this.onVideo,
    this.onNearby,
    this.onCompare,
    this.onPrimary,
    this.onSecondary,
    this.onCall,
    this.compared = false,
    this.topLeftOverlay,
  });

  final VehicleListing listing;
  final bool previewMode;
  final bool favorite;
  final bool following;
  final List<VehicleListing> related;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onMessage;
  final VoidCallback? onFollow;
  final VoidCallback? onOpenGallery;
  final ValueChanged<VehicleListing>? onOpenRelated;
  final VoidCallback? onVideo;
  final VoidCallback? onNearby;
  final VoidCallback? onCompare;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback? onCall;
  final bool compared;
  final Widget? topLeftOverlay;

  @override
  State<VehicleListingDetailView> createState() =>
      _VehicleListingDetailViewState();
}

class _VehicleListingDetailViewState extends State<VehicleListingDetailView> {
  final _descriptionKey = GlobalKey();
  final _specsKey = GlobalKey();
  final _rentalKey = GlobalKey();
  bool _descExpanded = false;
  int _tabIndex = 0;

  VehicleListing get listing => widget.listing;

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  bool get _hasVideo => listing.media.any((item) => item.isVideo);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 1100;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (isWide) _breadcrumb(),
            if (isWide)
              _buildWideLayout(context)
            else
              _buildNarrowLayout(context),
            if (isWide)
              Center(
                child: ConstrainedBox(
                  constraints: IbulChrome.contentConstraints,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _lowerSections(),
                        VehicleDetailRelatedRail(
                          related: widget.related,
                          onOpenRelated: widget.onOpenRelated,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 80 + safeBottom),
                child: Column(
                  children: [
                    _lowerSections(),
                    VehicleDetailRelatedRail(
                      related: widget.related,
                      onOpenRelated: widget.onOpenRelated,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _breadcrumb() {
    Widget? leading;
    if (widget.previewMode) {
      leading = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primary),
        ),
        child: const Text(
          'Önizleme',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return CatalogDetailBreadcrumb(
      parts: VehicleDetailAdapter.breadcrumbParts(listing),
      leading: leading,
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('vehicle-detail-hero-row'),
      child: Center(
        child: ConstrainedBox(
          constraints: IbulChrome.contentConstraints,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _gallery(isMobile: false, showAllFeatures: false),
                      const SizedBox(height: 14),
                      SizedBox(height: 360, child: _tabs()),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: VehicleDetailCenterCard(
                    listing: listing,
                    isMobile: false,
                    previewMode: widget.previewMode,
                    onPrimary: widget.onPrimary,
                    onSecondary: widget.onSecondary,
                    onScrollSpecs: () {
                      setState(() => _tabIndex = 2);
                      _scrollTo(_specsKey);
                    },
                  ),
                ),
                const SizedBox(width: 32),
                SizedBox(width: 280, child: _sidebar()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('vehicle-detail-mobile-stack'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _gallery(isMobile: true, showAllFeatures: true),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    VehicleDetailCenterCard(
                      listing: listing,
                      isMobile: true,
                      previewMode: widget.previewMode,
                      showCta: false,
                      onPrimary: widget.onPrimary,
                      onSecondary: widget.onSecondary,
                      onScrollSpecs: () {
                        setState(() => _tabIndex = 2);
                        _scrollTo(_specsKey);
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 280, child: _tabs()),
                    const SizedBox(height: 16),
                    _sellerCard(compact: true),
                    const SizedBox(height: 16),
                    _reviewsBody(),
                    const SizedBox(height: 16),
                    _qaBody(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery({required bool isMobile, required bool showAllFeatures}) {
    return VehicleDetailGallery(
      listing: listing,
      isMobile: isMobile,
      favorite: widget.favorite,
      previewMode: widget.previewMode,
      showActions: true,
      onFavorite: widget.onFavorite,
      onShare: widget.onShare,
      onSave: widget.onSave,
      onCompare: widget.onCompare,
      onVideo: widget.onVideo,
      onAllFeatures: () => _scrollTo(_specsKey),
      hasVideo: _hasVideo,
      showAllFeatures: showAllFeatures,
      compared: widget.compared,
      topLeftOverlay: isMobile ? null : widget.topLeftOverlay,
    );
  }

  Widget _tabs() {
    final tabs = VehicleDetailAdapter.tabs(listing);
    final index = _tabIndex.clamp(0, tabs.length - 1);
    return CatalogDetailTabs(
      tabs: tabs,
      selectedIndex: index,
      onSelected: (value) => setState(() => _tabIndex = value),
      actionLabel: VehicleDetailAdapter.tabActionLabel(index),
      onAction: () {
        if (index == 1) {
          widget.onNearby?.call();
          return;
        }
        if (index == 2) {
          _scrollTo(_specsKey);
          return;
        }
        if (index == 3) {
          _scrollTo(_rentalKey);
          return;
        }
        _scrollTo(_descriptionKey);
      },
      content: _tabContent(index),
    );
  }

  Widget _tabContent(int index) {
    if (index == 1) {
      return VehicleDetailLocationTab(
        listing: listing,
        onNearby: widget.onNearby,
      );
    }
    if (index == 2) {
      return SingleChildScrollView(
        child: VehicleDetailSpecTable(listing: listing),
      );
    }
    if (index == 3) {
      return SingleChildScrollView(
        child: VehicleRentalInfoPanel(
          listing: listing,
          compact: true,
          onSelectDelivery: widget.previewMode ? null : widget.onPrimary,
        ),
      );
    }
    final text = (listing.description ?? '').trim();
    return SingleChildScrollView(
      child: Text(
        text.isEmpty ? 'Bilgi eklenmedi.' : text,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black54,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _sidebar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _sellerCard(compact: false),
          const SizedBox(height: 16),
          CatalogSidebarReviewsCard(child: _reviewsBody()),
          const SizedBox(height: 16),
          CatalogSidebarQaCard(child: _qaBody()),
        ],
      ),
    );
  }

  Widget _sellerCard({required bool compact}) {
    if (listing.gallery == null) return const SizedBox.shrink();
    return VehicleDetailSellerCard(
      listing: listing,
      compact: compact,
      previewMode: widget.previewMode,
      following: widget.following,
      onFollow: widget.onFollow,
      onMessage: widget.onMessage,
      onOpenGallery: widget.onOpenGallery,
      onCall: widget.onCall,
    );
  }

  Widget _reviewsBody() {
    if (catalogDetailViewModelOf(context) != null) {
      return const ProductReviewsSection();
    }
    return const CatalogReviewsEmpty(
      message:
          'Bu ilanı kiralayan veya satın alan kullanıcılar değerlendirme yapabilir.',
    );
  }

  Widget _qaBody() {
    if (catalogDetailViewModelOf(context) != null) {
      return const ProductQaCard();
    }
    return const CatalogQaEmpty();
  }

  Widget _lowerSections() {
    final description = (listing.description ?? '').trim();
    return Column(
      children: [
        KeyedSubtree(
          key: _descriptionKey,
          child: VehicleDetailSectionCard(
            title: 'Araç Açıklaması',
            icon: Icons.description_outlined,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: VehicleDetailDescription(
                    text: description,
                    expanded: _descExpanded,
                    showToggle: false,
                    onToggle: () =>
                        setState(() => _descExpanded = !_descExpanded),
                  ),
                ),
                if (description.length > 360 ||
                    description.split('\n').length > 10) ...[
                  const SizedBox(height: 14),
                  CatalogExpandMoreButton(
                    expanded: _descExpanded,
                    onPressed: () =>
                        setState(() => _descExpanded = !_descExpanded),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        KeyedSubtree(
          key: _specsKey,
          child: VehicleDetailSectionCard(
            title: 'Araç Özellikleri',
            icon: Icons.tune_outlined,
            child: VehicleDetailSpecTable(listing: listing),
          ),
        ),
        if (VehicleDetailAdapter.rentalGroups(listing).isNotEmpty) ...[
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _rentalKey,
            child: VehicleDetailSectionCard(
              title: 'Teslimat / Kiralama',
              icon: Icons.event_available_outlined,
              child: VehicleRentalInfoPanel(
                listing: listing,
                onSelectDelivery: widget.previewMode ? null : widget.onPrimary,
              ),
            ),
          ),
        ],
        if (VehicleDetailDamageSection.visible(listing)) ...[
          const SizedBox(height: 24),
          VehicleDetailSectionCard(
            title: 'Boya / Değişen / Tramer',
            icon: Icons.car_crash_outlined,
            child: VehicleDetailDamageSection(listing: listing),
          ),
        ],
        const SizedBox(height: 24),
        VehicleDetailSectionCard(
          title: 'Donanım',
          icon: Icons.tune_outlined,
          child: VehicleDetailFeatureSection(listing: listing),
        ),
      ],
    );
  }
}
