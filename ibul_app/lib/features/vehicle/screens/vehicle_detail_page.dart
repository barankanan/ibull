import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/marketplace_paths.dart';
import '../../../core/app_state.dart';
import '../../../core/auth/customer_login_gate.dart';
import '../../../core/constants.dart';
import '../../../core/home_navigation.dart';
import '../../../models/product_model.dart';
import '../../../screens/home_lazy_routes.dart';
import '../../../screens/search_results_page.dart';
import '../../../viewmodels/product_detail_viewmodel.dart';
import '../../../widgets/ibul_page_state.dart';
import '../../../widgets/product_detail/add_to_list_modal.dart';
import '../../../widgets/web_header.dart';
import '../domain/vehicle_compare_feedback.dart';
import '../domain/vehicle_detail_adapter.dart';
import '../domain/vehicle_listing_validation.dart';
import '../domain/vehicle_nearby_query.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../navigation/vehicle_routes.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_detail_gallery.dart';
import '../widgets/vehicle_detail_sections.dart';
import '../widgets/vehicle_listing_detail_view.dart';
import 'vehicle_appointment_sheet.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({
    super.key,
    required this.listingId,
    this.previewMode = false,
  });

  final String listingId;
  final bool previewMode;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  VehicleListing? _listing;
  List<VehicleListing> _related = const [];
  bool _loading = true;
  String? _error;
  bool _favorite = false;

  Map<String, dynamic> _storeMap(VehicleListing listing) => {
    'id': listing.sellerId,
    'seller_id': listing.sellerId,
    'name': listing.gallery?.name ?? '',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final listing = widget.previewMode
          ? await VehicleService.instance.listings.getForSellerPreview(
              widget.listingId,
            )
          : await VehicleService.instance.listings.getPublished(
              widget.listingId,
            );
      if (!mounted) return;
      if (listing == null ||
          (!widget.previewMode && !listing.status.isPubliclyVisible)) {
        setState(() {
          _error = 'İlan bulunamadı';
          _loading = false;
        });
        return;
      }
      var fav = false;
      if (!widget.previewMode) {
        fav = await VehicleService.instance.favorites.isFavorite(listing.id);
      }
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _favorite = fav;
        _loading = false;
      });
      if (widget.previewMode) return;
      await VehicleService.instance.listings.recordEvent(
        listing,
        'listing_view',
      );
      final related = await _loadRelated(listing);
      if (!mounted) return;
      setState(() => _related = related);
    } catch (error) {
      debugPrint(
        '[vehicle] detail load failed listingId=${widget.listingId}: $error',
      );
      if (!mounted) return;
      setState(() {
        _error = VehiclePublishErrorMapper.loadFailure(error);
        _loading = false;
      });
    }
  }

  Future<List<VehicleListing>> _loadRelated(VehicleListing listing) async {
    final seen = <String>{listing.id};
    final out = <VehicleListing>[];

    Future<void> addFrom(List<VehicleListing> items) async {
      for (final item in items) {
        if (!item.status.isPubliclyVisible) continue;
        if (!seen.add(item.id)) continue;
        out.add(item);
        if (out.length >= 6) return;
      }
    }

    try {
      final brand = listing.specs.brand.trim();
      final model = listing.specs.model.trim();
      if (brand.isNotEmpty && model.isNotEmpty) {
        await addFrom(
          await VehicleService.instance.listings.search(
            VehicleSearchQuery(brand: brand, model: model, limit: 8),
          ),
        );
      }
      if (out.length < 6 && brand.isNotEmpty) {
        await addFrom(
          await VehicleService.instance.listings.search(
            VehicleSearchQuery(brand: brand, limit: 8),
          ),
        );
      }
      if (out.length < 6 && listing.sellerId.trim().isNotEmpty) {
        await addFrom(
          await VehicleService.instance.listings.listBySeller(
            listing.sellerId,
            status: VehicleListingStatus.active.wire,
          ),
        );
      }
    } catch (error) {
      debugPrint('[vehicle] related listings skipped: $error');
    }
    return out;
  }

  Future<bool> _requireAuth() async {
    if (context.read<AppState>().isLoggedIn) return true;
    final loggedIn = await CustomerLoginGate.open(context);
    if (!mounted) return false;
    return loggedIn && context.read<AppState>().isLoggedIn;
  }

  Future<void> _favoriteListing(VehicleListing listing) async {
    final wasLoggedIn = context.read<AppState>().isLoggedIn;
    if (!await _requireAuth()) return;
    if (!mounted) return;
    final next = wasLoggedIn
        ? await VehicleService.instance.favorites.toggle(listing)
        : await VehicleService.instance.favorites.ensureFavorite(listing);
    await VehicleService.instance.listings.recordEvent(listing, 'favorite');
    if (mounted) setState(() => _favorite = next);
  }

  Future<void> _openVideo(VehicleListing listing) async {
    VehicleMedia? video;
    for (final item in listing.media) {
      if (item.isVideo && item.url.trim().isNotEmpty) {
        video = item;
        break;
      }
    }
    if (video == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bu ilanda video yok')));
      return;
    }
    final uri = Uri.tryParse(video.url.trim());
    if (uri == null ||
        !(await launchUrl(uri, mode: LaunchMode.externalApplication))) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video açılamadı')));
    }
  }

  Future<void> _openNearby(VehicleListing listing) async {
    if (!mounted) return;
    await HomeLazyRoutes.openMap(
      context,
      query: VehicleNearbyQuery.fromListing(listing),
      contentType: 'vehicle',
      brand: listing.specs.brand.trim(),
      model: listing.specs.model.trim(),
    );
  }

  Future<void> _shareListing(VehicleListing listing) async {
    final url = MarketplacePaths.shareUrl(
      MarketplacePaths.vehicle(listing.id, slug: listing.title),
    );
    await Clipboard.setData(ClipboardData(text: '${listing.title} — $url'));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İlan bağlantısı kopyalandı')));
  }

  Future<void> _toggleFollow(VehicleListing listing) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    final app = context.read<AppState>();
    if (!app.isLoggedIn) return;
    await app.toggleFollowStore(_storeMap(listing));
    if (mounted) setState(() {});
  }

  Product _productFromListing(VehicleListing listing) {
    String? video;
    for (final item in listing.media) {
      if (item.isVideo && item.url.trim().isNotEmpty) {
        video = item.url.trim();
        break;
      }
    }
    return Product(
      productId: 'vehicle:${listing.id}',
      name: listing.title,
      brand: listing.specs.brand,
      price: VehicleDetailSpecBuilder.priceOf(listing),
      rating: listing.gallery?.rating ?? 0,
      reviewCount: 0,
      tags: const ['Araç'],
      images: VehicleDetailGallery.urlsOf(listing),
      store: listing.gallery?.name,
      sellerId: listing.sellerId,
      category: 'Araç',
      videoUrl: video,
    );
  }

  Future<void> _saveListing(VehicleListing listing) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    final app = context.read<AppState>();
    final product = _productFromListing(listing);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToListModal(
        product: product,
        userLists: app.productLists,
        onAddToList: (listId) => app.addToProductList(listId, product),
        onCreateNewList: (name, visibility) {
          final listId = app.createProductList(name, visibility: visibility);
          return app.addToProductList(listId, product);
        },
      ),
    );
  }

  Widget _webBackButton(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Tooltip(
        message: 'Geri',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
                return;
              }
              HomeNavigation.openHome(context);
            },
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileBackButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
                return;
              }
              HomeNavigation.openHome(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back, color: Color(0xFF673AB7)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _askSeller(VehicleListing listing) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    await VehicleService.instance.listings.recordEvent(
      listing,
      'message_click',
    );
    if (!mounted) return;
    await VehicleRoutes.openChat(
      context,
      listingId: listing.id,
      sellerId: listing.sellerId,
      sellerName: listing.gallery?.name ?? 'Galeri',
    );
  }

  Future<void> _runCta(
    VehicleListing listing,
    VehicleDetailCtaAction action,
  ) async {
    switch (action) {
      case VehicleDetailCtaAction.selectRentalDates:
      case VehicleDetailCtaAction.rentNow:
        if (!await _requireAuth()) return;
        if (!mounted) return;
        await VehicleRoutes.openRental(context, listingId: listing.id);
      case VehicleDetailCtaAction.bookAppointment:
        if (!await _requireAuth()) return;
        if (!mounted) return;
        await showVehicleAppointmentSheet(context, listing);
      case VehicleDetailCtaAction.askSeller:
        await _askSeller(listing);
    }
  }

  Widget _webHeader(BuildContext context) {
    return WebHeader(
      onSearch: (query) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultsPage(query: query),
          ),
        );
      },
      onCategorySelected: (_) => HomeNavigation.openHome(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 1100;
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            if (isWide) _webHeader(context),
            const Expanded(child: IbulPageState.loading()),
          ],
        ),
      );
    }
    if (_error != null || _listing == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            if (isWide) _webHeader(context),
            Expanded(
              child: IbulPageState.error(
                title: _error ?? 'Hata',
                onAction: _load,
              ),
            ),
          ],
        ),
      );
    }
    final listing = _listing!;
    final following = context.select<AppState, bool>(
      (app) => app.isFollowingStore(_storeMap(listing)),
    );
    final ctas = VehicleDetailAdapter.ctas(listing);
    return ChangeNotifierProvider(
      key: ValueKey(listing.id),
      create: (context) => ProductDetailViewModel(
        initialProduct: _productFromListing(listing),
        appState: context.read<AppState>(),
        catalogMode: true,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                if (isWide) _webHeader(context),
                Expanded(
                  child: VehicleListingDetailView(
                    listing: listing,
                    previewMode: widget.previewMode,
                    favorite: _favorite,
                    following: following,
                    related: _related,
                    onFavorite: () => _favoriteListing(listing),
                    onShare: () => _shareListing(listing),
                    onSave: () => _saveListing(listing),
                    onCompare: () => VehicleCompareFeedback.open(
                      context,
                      listing,
                      similar: _related,
                    ),
                    topLeftOverlay: isWide ? _webBackButton(context) : null,
                    onMessage: () => _askSeller(listing),
                    onFollow: () => _toggleFollow(listing),
                    onOpenGallery: () async {
                      await VehicleService.instance.listings.recordEvent(
                        listing,
                        'seller_profile_open',
                      );
                      if (!context.mounted) return;
                      await VehicleRoutes.openGallery(context, listing.sellerId);
                    },
                    onOpenRelated: (item) =>
                        VehicleRoutes.openDetail(context, item.id),
                    onVideo: () => _openVideo(listing),
                    onNearby: () => _openNearby(listing),
                    onCall: () => VehicleService.instance.callGallery(listing),
                    onPrimary: () => _runCta(listing, ctas.primaryAction),
                    onSecondary: () => _runCta(listing, ctas.secondaryAction),
                  ),
                ),
              ],
            ),
            if (!isWide) _mobileBackButton(context),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : VehicleDetailStickyBar(
                listing: listing,
                previewMode: widget.previewMode,
                onPrimary: () => _runCta(listing, ctas.primaryAction),
                onSecondary: () => _runCta(listing, ctas.secondaryAction),
              ),
      ),
    );
  }
}
