import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/map_store_marker.dart';
import '../core/map_loading_helpers.dart';
import '../core/map_store_filter_helpers.dart';
import '../core/runtime_diagnostic_logger.dart';
import '../services/map_store_emergency_pipeline.dart';
import '../core/app_state.dart';
import '../core/store_logo_helper.dart';
import '../models/product_model.dart';
import '../services/location_access_service.dart';
import '../services/push_notification_service.dart';
import '../services/store/store_mapping_helpers.dart';
import '../services/supabase_service.dart';
import '../utils/external_navigation.dart';
import '../widgets/map_filter_bottom_sheet.dart';
import '../utils/text_normalizer.dart';
import '../app/ibul_router.dart';
import '../app/marketplace_paths.dart';
import '../features/mall/public/mall_map_layer.dart';
import '../features/seller/domain/store_vertical.dart';
import '../features/vehicle/domain/vehicle_compare_fields.dart';
import '../features/vehicle/domain/vehicle_map_search.dart';
import '../features/vehicle/models/vehicle_listing.dart';
import '../features/vehicle/navigation/gallery_store_entry.dart';
import '../features/vehicle/navigation/vehicle_routes.dart';
import 'business_detail_page.dart';
import '../models/store_follow_state.dart';
import '../features/seller/achievements/helpers/seller_badge_public_display.dart';
import '../features/seller/achievements/models/seller_badge_models.dart';
import '../features/seller/achievements/widgets/seller_badge_map_popup_row.dart';
import 'ai_chat_page.dart';

class MapPage extends StatefulWidget {
  final Product? product;
  final String? targetStoreName;
  final Map<String, dynamic>? targetBusiness;
  final String? initialSearchQuery;
  final String? initialStoreProductQuery;
  final String? contentType;
  final String? vehicleBrand;
  final String? vehicleModel;

  const MapPage({
    super.key,
    this.product,
    this.targetStoreName,
    this.targetBusiness,
    this.initialSearchQuery,
    this.initialStoreProductQuery,
    this.contentType,
    this.vehicleBrand,
    this.vehicleModel,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final MallMapPins _mallPins = MallMapPins()..load();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedBusinessIndex;
  static const LatLng _initialPosition = LatLng(
    36.2025,
    36.1605,
  ); // Hatay/Antakya
  LatLng? _userLocation;
  List<int> _filteredBusinessIndices = [];
  String _searchQuery = '';
  List<int>? _searchCandidateIndices;
  List<VehicleListing> _vehicleHits = const [];
  String _vehicleMatchLabel = '';
  bool get _vehicleMode =>
      (widget.contentType ?? '').trim().toLowerCase() == 'vehicle';
  List<MapStoreMarker> _mapStores = [];
  List<Map<String, dynamic>> _businesses = [];

  // Animation controller for smooth map movement
  late AnimationController _moveAnimationController;
  VoidCallback? _activeMapMoveListener;

  // Filter state - NOT final so they can be updated
  double _filterDistance = 10.0;
  List<String> _filterCategories = [];
  bool _filterOpenNow = false;
  bool _userAppliedDistanceFilter = false;
  bool _isBusinessSheetOpen = false;

  // Live location tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _notificationsReady = false;
  final Set<String> _storesNotifiedInCurrentProximity = {};
  final Map<String, Future<List<Product>>> _storeProductsCache = {};
  double? _userHeadingDegrees;
  Timer? _searchDebounce;
  int _searchRequestVersion = 0;
  bool _isCenteringOnUserLocation = false;
  bool _isOpeningStoreDirections = false;
  bool _didOpenInitialTargetBusiness = false;
  bool _storesLoadCompleted = false;
  String? _storesLoadEmptyReason;
  String? _storesLoadError;
  int _rawStoreCount = 0;
  int _markerStoreCount = 0;
  String? _locationNotice;
  bool _isMapReady = false;
  bool _isLoadingStores = false;
  bool _storesLoadInFlight = false;
  bool _isLoadingLocation = false;
  Timer? _mapLoadingFailsafeTimer;
  static const Duration _mapLoadingFailsafe = Duration(seconds: 5);
  static const Duration _mapLocationTimeout = Duration(seconds: 3);
  static const Duration _mapStoresQueryTimeout = Duration(seconds: 8);
  static const double _nearStoreThresholdKm = 0.1; // 100 metre
  static const double _locationSyncDistanceMeters = 25;
  static const Duration _locationSyncInterval = Duration(seconds: 15);
  DateTime? _lastLocationSyncAt;
  LatLng? _lastSyncedLocation;
  DateTime? _lastProximityCheckAt;

  double? _distanceKmTo(LatLng storeLocation) {
    if (_userLocation == null) return null;
    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      storeLocation.latitude,
      storeLocation.longitude,
    );
    return meters / 1000.0;
  }

  String _formatDistance(double? km) {
    if (km == null) return '-';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.toStringAsFixed(0)} km';
  }

  void _applyDistanceDataAndSort({bool sortFiltered = true}) {
    for (final business in _businesses) {
      final location = business['location'] as LatLng?;
      final km = location == null ? null : _distanceKmTo(location);
      business['distance_km'] = km;
      business['distance'] = _formatDistance(km);
    }

    if (sortFiltered) {
      _filteredBusinessIndices.sort((a, b) {
        final akm = _businesses[a]['distance_km'] as double?;
        final bkm = _businesses[b]['distance_km'] as double?;
        if (akm == null && bkm == null) return 0;
        if (akm == null) return 1;
        if (bkm == null) return -1;
        return akm.compareTo(bkm);
      });
    }
  }

  void _rebuildFilteredIndices({bool log = false}) {
    if (_businesses.isEmpty) {
      _filteredBusinessIndices = [];
      if (log) {
        RuntimeDiagnosticLogger.map('stores after search/filter count=0');
        RuntimeDiagnosticLogger.map('markers rendered count=0');
      }
      return;
    }

    _filteredBusinessIndices = filterMapStoreIndices(
      businessCount: _businesses.length,
      businessNameAt: (i) => _businesses[i]['name']?.toString(),
      categoryAt: (i) => _businesses[i]['category']?.toString(),
      distanceKmAt: (i) => _businesses[i]['distance_km'] as double?,
      searchQuery: _searchCandidateIndices == null ? _searchQuery : '',
      filterCategories: _filterCategories,
      filterOpenNow: _filterOpenNow,
      filterDistanceKm: _filterDistance,
      hasUserLocation: _userLocation != null,
      userAppliedDistanceFilter: _userAppliedDistanceFilter,
      candidateIndices: _searchCandidateIndices,
    );
    _applyDistanceDataAndSort();

    if (log) {
      RuntimeDiagnosticLogger.map(
        'stores after search/filter count=${_filteredBusinessIndices.length}',
      );
      RuntimeDiagnosticLogger.map(
        'active search query=${_searchQuery.isEmpty ? '(empty)' : _searchQuery}',
      );
      RuntimeDiagnosticLogger.map(
        'active category filter=${_filterCategories.isEmpty ? '(none)' : _filterCategories.join(',')}',
      );
      RuntimeDiagnosticLogger.map(
        'user location available=${_userLocation != null}',
      );
      if (_userLocation != null) {
        RuntimeDiagnosticLogger.map('query radius km=$_filterDistance');
      }
      RuntimeDiagnosticLogger.map(
        'markers rendered count=${_filteredBusinessIndices.length}',
      );
    }
  }

  void _rerunVehicleSearchIfNeeded() {
    if (!_vehicleMode || _searchQuery.trim().isEmpty) return;
    unawaited(_performSearch(_searchQuery));
  }

  String get _mapListEmptyMessage => resolveMapFilteredEmptyMessage(
    rawCount: _rawStoreCount,
    markerCount: _markerStoreCount,
    filteredCount: _filteredBusinessIndices.length,
    searchQuery: _searchQuery,
    filterCategories: _filterCategories,
    hasUserLocation: _userLocation != null,
    filterDistanceKm: _filterDistance,
    userAppliedDistanceFilter: _userAppliedDistanceFilter,
  );

  String _normalize(String s) {
    return TextNormalizer.normalize(s);
  }

  void _addProximityDebugLog(String message) {
    RuntimeDiagnosticLogger.mapProximity(message);
  }

  Future<void> _syncUserLocationToBackend() async {
    if (_userLocation == null) return;
    await PushNotificationService.instance.syncUserLocation(
      latitude: _userLocation!.latitude,
      longitude: _userLocation!.longitude,
    );
  }

  double _bearingBetween(LatLng start, LatLng end) {
    final startLat = start.latitude * math.pi / 180;
    final startLng = start.longitude * math.pi / 180;
    final endLat = end.latitude * math.pi / 180;
    final endLng = end.longitude * math.pi / 180;
    final deltaLng = endLng - startLng;

    final y = math.sin(deltaLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _handleLocationUpdate(LatLng nextLocation, {double? headingDegrees}) {
    final previous = _userLocation;
    final movedMeters = previous == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            nextLocation.latitude,
            nextLocation.longitude,
          );

    if (previous == null || movedMeters >= 5) {
      setState(() {
        _userLocation = nextLocation;
        if (headingDegrees != null && headingDegrees >= 0) {
          _userHeadingDegrees = headingDegrees;
        } else if (previous != null && movedMeters >= 3) {
          _userHeadingDegrees = _bearingBetween(previous, nextLocation);
        }
        _rebuildFilteredIndices();
      });
    } else {
      _userLocation = nextLocation;
      if (headingDegrees != null && headingDegrees >= 0) {
        _userHeadingDegrees = headingDegrees;
      }
    }

    final now = DateTime.now();
    final shouldSync =
        _lastLocationSyncAt == null ||
        now.difference(_lastLocationSyncAt!) >= _locationSyncInterval ||
        _lastSyncedLocation == null ||
        Geolocator.distanceBetween(
              _lastSyncedLocation!.latitude,
              _lastSyncedLocation!.longitude,
              nextLocation.latitude,
              nextLocation.longitude,
            ) >=
            _locationSyncDistanceMeters;
    if (shouldSync) {
      _lastLocationSyncAt = now;
      _lastSyncedLocation = nextLocation;
      unawaited(_syncUserLocationToBackend());
    }

    final shouldCheckProximity =
        _lastProximityCheckAt == null ||
        now.difference(_lastProximityCheckAt!) >= const Duration(seconds: 10) ||
        movedMeters >= _locationSyncDistanceMeters;
    if (shouldCheckProximity && _storesLoadCompleted) {
      _lastProximityCheckAt = now;
      unawaited(_checkAndSendProximityNotifications());
    }
  }

  Future<void> _ensureNotificationsReady() async {
    if (kIsWeb || _notificationsReady) return;

    _notificationsReady = true;
    _addProximityDebugLog('Bildirim sistemi hazir.');
  }

  void _maybeStartProximityAfterStoresLoaded() {
    if (!_storesLoadCompleted || _mapStores.isEmpty) return;
    unawaited(_ensureNotificationsReady());
    if (_userLocation != null) {
      unawaited(_checkAndSendProximityNotifications());
    }
  }

  bool _matchesFavoriteStoreProduct(Product favorite, Product storeProduct) {
    final favoriteName = _normalize(favorite.name);
    final storeProductName = _normalize(storeProduct.name);
    if (favoriteName.isEmpty || storeProductName.isEmpty) return false;

    final nameMatches =
        storeProductName.contains(favoriteName) ||
        favoriteName.contains(storeProductName);
    if (!nameMatches) return false;

    final favoriteBrand = _normalize(favorite.brand);
    final storeProductBrand = _normalize(storeProduct.brand);
    if (favoriteBrand.isEmpty || storeProductBrand.isEmpty) return true;

    return storeProductBrand.contains(favoriteBrand) ||
        favoriteBrand.contains(storeProductBrand);
  }

  bool _matchesInterestTerm(String term, Product storeProduct) {
    final normalizedTerm = _normalize(term);
    if (normalizedTerm.isEmpty) return false;

    final searchableParts = <String>[
      storeProduct.name,
      storeProduct.brand,
      '${storeProduct.brand} ${storeProduct.name}',
      storeProduct.category ?? '',
      storeProduct.subCategory ?? '',
      ...storeProduct.tags,
    ].map(_normalize).where((value) => value.isNotEmpty).toList();

    for (final candidate in searchableParts) {
      if (candidate.contains(normalizedTerm) ||
          normalizedTerm.contains(candidate)) {
        return true;
      }
    }

    final termTokens = normalizedTerm
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toList(growable: false);
    if (termTokens.isEmpty) return false;

    final combined = searchableParts.join(' ');
    return termTokens.every(combined.contains);
  }

  Iterable<String> _savedProductTerms(AppState appState) sync* {
    for (final list in appState.productLists) {
      if (list.products.isNotEmpty) {
        for (final product in list.products) {
          final name = product.name.trim();
          if (name.isNotEmpty) yield name;
        }
        continue;
      }

      for (final productId in list.productIds) {
        final trimmed = productId.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split('|');
        if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
          yield parts[1].trim();
        } else {
          yield trimmed;
        }
      }
    }
  }

  Future<Map<String, String>> _findInterestMatchForStore(
    String storeName,
  ) async {
    if (!mounted) {
      return {
        'matched': 'false',
        'reason': 'Widget mounted degil.',
        'productCount': '0',
      };
    }
    final appState = context.read<AppState>();
    final storeProducts = await _getStoreProducts(storeName);
    if (storeProducts.isEmpty) {
      return {
        'matched': 'false',
        'reason': 'Magazada eslesecek urun yok.',
        'productCount': '0',
      };
    }

    for (final searchTerm in appState.searchHistory.take(25)) {
      final term = searchTerm.trim();
      if (term.isEmpty) continue;
      final searchMatch = storeProducts.where(
        (product) => _matchesInterestTerm(term, product),
      );
      if (searchMatch.isNotEmpty) {
        final matchedProduct = searchMatch.first;
        return {
          'matched': 'true',
          'type': 'searched',
          'term': matchedProduct.name,
          'reason': "Arama eslesti: '$term' -> '${matchedProduct.name}'",
          'productCount': storeProducts.length.toString(),
        };
      }
    }

    for (final fav in appState.favorites.take(25)) {
      final term = fav.name.trim();
      if (term.isEmpty) continue;
      final favoriteMatch = storeProducts.where(
        (product) => _matchesFavoriteStoreProduct(fav, product),
      );
      if (favoriteMatch.isNotEmpty) {
        final matchedProduct = favoriteMatch.first;
        return {
          'matched': 'true',
          'type': 'favorite',
          'term': matchedProduct.name,
          'reason': "Favori urun eslesti: '$term' -> '${matchedProduct.name}'",
          'productCount': storeProducts.length.toString(),
        };
      }
    }

    for (final cartProduct in appState.cart.take(25)) {
      final term = cartProduct.name.trim();
      if (term.isEmpty) continue;
      final cartMatch = storeProducts.where(
        (product) => _matchesFavoriteStoreProduct(cartProduct, product),
      );
      if (cartMatch.isNotEmpty) {
        final matchedProduct = cartMatch.first;
        return {
          'matched': 'true',
          'type': 'cart',
          'term': matchedProduct.name,
          'reason':
              "Sepetteki urun eslesti: '$term' -> '${matchedProduct.name}'",
          'productCount': storeProducts.length.toString(),
        };
      }
    }

    for (final savedTerm in _savedProductTerms(appState).take(40)) {
      final term = savedTerm.trim();
      if (term.isEmpty) continue;
      final savedMatch = storeProducts.where(
        (product) => _matchesInterestTerm(term, product),
      );
      if (savedMatch.isNotEmpty) {
        final matchedProduct = savedMatch.first;
        return {
          'matched': 'true',
          'type': 'saved',
          'term': matchedProduct.name,
          'reason': "Kayitli urun eslesti: '$term' -> '${matchedProduct.name}'",
          'productCount': storeProducts.length.toString(),
        };
      }
    }

    return {
      'matched': 'false',
      'reason': 'Arama, favori veya kayitli urun eslesmesi bulunamadi.',
      'productCount': storeProducts.length.toString(),
    };
  }

  String _buildNotificationBody({
    required String storeName,
    required String type,
    required String term,
  }) {
    String intro = 'Aradığın';
    if (type == 'favorite') {
      intro = 'Beğendiğin';
    } else if (type == 'cart') {
      intro = 'Sepete eklediğin';
    } else if (type == 'saved') {
      intro = 'Kaydettiğin';
    }
    return "$intro ürün '$term', '$storeName' mağazasında mevcut. Görmek ister misin?";
  }

  Future<void> _checkAndSendProximityNotifications() async {
    if (!mounted) return;
    if (!_storesLoadCompleted) return;
    if (!_notificationsReady) return;
    if (_userLocation == null) return;

    RuntimeDiagnosticLogger.mapProximity(
      'input stores count=${_mapStores.length}',
    );

    if (_mapStores.isEmpty) {
      final reason = _storesLoadEmptyReason?.trim();
      if (reason != null && reason.isNotEmpty) {
        _addProximityDebugLog('Magaza listesi bos: $reason');
      }
      return;
    }

    _addProximityDebugLog(
      'Yakinlik taramasi basladi. ${_mapStores.length} magaza kontrol ediliyor.',
    );

    for (final marker in _mapStores) {
      final storeName = marker.name;
      final location = marker.location;
      final km = _distanceKmTo(location);
      if (km == null) {
        _addProximityDebugLog(
          '$storeName atlandi: magaza mesafesi hesaplanamadi.',
        );
        continue;
      }
      if (km > _nearStoreThresholdKm) {
        _addProximityDebugLog(
          '$storeName eslesmedi: mesafe ${(km * 1000).round()} m, esik ${(_nearStoreThresholdKm * 1000).round()} m.',
        );
        continue;
      }

      if (_storesNotifiedInCurrentProximity.contains(storeName)) {
        _addProximityDebugLog(
          '$storeName icin bu oturumda bildirim zaten islendi.',
        );
        continue;
      }

      final match = await _findInterestMatchForStore(storeName);
      if (match['matched'] != 'true') {
        _addProximityDebugLog(
          "$storeName yakin (${(km * 1000).round()} m) ama bildirim yok: ${match['reason']}",
        );
        continue;
      }

      _addProximityDebugLog(
        "$storeName icin bildirim tetiklenecek. Mesafe ${(km * 1000).round()} m. Sebep: ${match['reason']}",
      );

      final body = _buildNotificationBody(
        storeName: storeName,
        type: match['type']!,
        term: match['term']!,
      );
      final notificationShown = await PushNotificationService.instance
          .showNearbyStoreNotification(
            storeName: storeName,
            body: body,
            initialStoreProductQuery: match['term'],
          );
      if (notificationShown) {
        _storesNotifiedInCurrentProximity.add(storeName);
        _addProximityDebugLog(
          "$storeName icin sistem bildirimi gosterildi. Eslesen urun/arama: '${match['term']}'.",
        );
      } else {
        _addProximityDebugLog(
          '$storeName icin bildirim izni olmadigi icin sistem bildirimi gosterilemedi.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    RuntimeDiagnosticLogger.map('opening');
    _moveAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addStatusListener((status) {
          if ((status == AnimationStatus.completed ||
                  status == AnimationStatus.dismissed) &&
              _activeMapMoveListener != null) {
            _moveAnimationController.removeListener(_activeMapMoveListener!);
            _activeMapMoveListener = null;
          }
        });

    // Initialize search with passed query if available
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!;
      _searchController.text = _searchQuery;
    } else if (MapViewportMemory.search.isNotEmpty) {
      _searchQuery = MapViewportMemory.search;
      _searchController.text = _searchQuery;
      _filterDistance = MapViewportMemory.distance;
      _filterCategories = List<String>.from(MapViewportMemory.categories);
      _filterOpenNow = MapViewportMemory.openNow;
    }

    _businesses = [];
    _mapStores = [];
    if (widget.targetBusiness != null) {
      // ... existing code
    }

    _filteredBusinessIndices = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isMapReady = true;
      });
      RuntimeDiagnosticLogger.map('render default center');
      _mapController.move(
        MapViewportMemory.center ?? _initialPosition,
        MapViewportMemory.zoom ?? 14.0,
      );
      _startMapLoadingFailsafe();
    });
    scheduleMicrotask(() {
      RuntimeDiagnosticLogger.map('stores query scheduled');
      unawaited(_loadMapStoresEmergencyPipeline());
    });
    unawaited(_checkLocationPermissionAndStart());
  }

  void _startMapLoadingFailsafe() {
    _mapLoadingFailsafeTimer?.cancel();
    _mapLoadingFailsafeTimer = Timer(_mapLoadingFailsafe, () {
      if (!mounted) return;
      if (_isLoadingStores || _isLoadingLocation) {
        RuntimeDiagnosticLogger.map(
          'loading failsafe fired — forcing loading cleared',
        );
        _clearMapLoadingStates();
      }
    });
  }

  void _clearMapLoadingStates() {
    if (!mounted) return;
    final hadLoading = _isLoadingStores || _isLoadingLocation;
    setState(() {
      _isLoadingStores = false;
      _isLoadingLocation = false;
    });
    if (hadLoading) {
      RuntimeDiagnosticLogger.map('loading cleared');
    }
  }

  @override
  void dispose() {
    _mallPins.dispose();
    _mapLoadingFailsafeTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _searchDebounce?.cancel();
    if (_activeMapMoveListener != null) {
      _moveAnimationController.removeListener(_activeMapMoveListener!);
    }
    _moveAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapStoresEmergencyPipeline() async {
    if (_storesLoadInFlight) {
      RuntimeDiagnosticLogger.map(
        'stores query skipped — load already in flight',
      );
      return;
    }
    _storesLoadInFlight = true;
    await _mallPins.load();
    final queryStartedMs = DateTime.now().millisecondsSinceEpoch;
    if (mounted) {
      setState(() {
        _isLoadingStores = true;
        _storesLoadError = null;
        _storesLoadCompleted = false;
        _storesLoadEmptyReason = null;
      });
    }
    var rawCount = 0;
    try {
      final result = await MapStoreEmergencyPipeline().load().timeout(
        _mapStoresQueryTimeout,
      );
      final list = result.rows;
      rawCount = list.length;
      _rawStoreCount = rawCount;
      RuntimeDiagnosticLogger.map(
        'stores raw count=$rawCount source=${result.primarySource}',
      );
      RuntimeDiagnosticLogger.map(
        'stores query ms=${DateTime.now().millisecondsSinceEpoch - queryStartedMs}',
      );
      if (list.isEmpty) {
        _storesLoadEmptyReason =
            'Mağaza sorgusu boş döndü — terminalde [Map] empty reason satırına bakın.';
      }

      if (!mounted) return;

      final newMarkers = <MapStoreMarker>[];
      var cityFallbackCount = 0;

      for (final row in list) {
        final source =
            row['_map_pipeline_source']?.toString() ?? result.primarySource;
        final marker = MapStoreMarker.fromPipelineRow(
          row,
          disambiguationIndex: newMarkers.length,
          source: source,
          mapCategory: _mapStoreCategoryToMap,
        );
        if (marker == null) continue;
        if (_mallPins.hiddenStoreIds.contains(marker.sellerId)) continue;
        if (marker.fromCityFallback) cityFallbackCount++;
        newMarkers.add(marker);
      }

      RuntimeDiagnosticLogger.map(
        'stores with coordinates count=${newMarkers.length}',
      );
      RuntimeDiagnosticLogger.mapFallback(
        'synthetic markers generated count=$cityFallbackCount',
      );
      if (cityFallbackCount > 0) {
        RuntimeDiagnosticLogger.map(
          'city/district coordinate fallback count=$cityFallbackCount',
        );
      }

      final newBusinesses = newMarkers
          .asMap()
          .entries
          .map((entry) => entry.value.toBusinessRecord(index: entry.key))
          .toList(growable: false);

      _markerStoreCount = newBusinesses.length;

      setState(() {
        _mapStores = newMarkers;
        _businesses = newBusinesses;
        _storesLoadError = newBusinesses.isEmpty
            ? resolveMapStoresEmptyMessage(
                rawCount: rawCount,
                markerCount: newBusinesses.length,
              )
            : null;
        _rebuildFilteredIndices();
      });
      _rebuildFilteredIndices(log: true);
      RuntimeDiagnosticLogger.map(
        'markers rendered count=${_filteredBusinessIndices.length}',
      );
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.isNotEmpty) {
        unawaited(_performSearch(widget.initialSearchQuery!));
      } else if (_searchQuery.isNotEmpty) {
        unawaited(_performSearch(_searchQuery));
      } else {
        _searchCandidateIndices = null;
      }

      if (widget.targetBusiness != null) {
        final index = _businesses.indexWhere(
          (b) =>
              _normalize(b['name'].toString()) ==
              _normalize(widget.targetBusiness!['name'].toString()),
        );

        if (index != -1) {
          _openInitialTargetBusiness(index);
        }
      } else if (widget.targetStoreName != null) {
        final index = _businesses.indexWhere(
          (b) =>
              _normalize(b['name'].toString()) ==
              _normalize(widget.targetStoreName!),
        );

        if (index != -1) {
          _openInitialTargetBusiness(index);
        }
      }
    } on TimeoutException catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        stackTrace,
        context: 'stores_timeout',
      );
      if (!mounted) return;
      setState(() {
        _storesLoadError =
            'Mağazalar şu an yüklenemedi. Harita varsayılan bölgede açık.';
      });
    } catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        stackTrace,
        context: 'stores',
      );
      if (!mounted) return;
      setState(() {
        _storesLoadError =
            'Harita mağazaları yüklenemedi. Bağlantınızı kontrol edin.';
      });
    } finally {
      _storesLoadInFlight = false;
      _storesLoadCompleted = true;
      if (mounted) {
        setState(() => _isLoadingStores = false);
      }
      _clearMapLoadingStates();
      _maybeStartProximityAfterStoresLoaded();
    }
  }

  void _showDefaultMapCenter({String? reason}) {
    if (!mounted) return;
    _mapController.move(_initialPosition, 14.0);
    if (reason != null && reason.isNotEmpty) {
      RuntimeDiagnosticLogger.map(reason);
    }
  }

  Future<Position?> _getFreshCurrentPosition() async {
    try {
      return await LocationAccessService.instance.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _centerMapOnCurrentLocation() async {
    if (_isCenteringOnUserLocation) return;
    if (_userLocation != null) {
      _animatedMapMove(_userLocation!, 16.0);
    }

    setState(() {
      _isCenteringOnUserLocation = true;
    });

    try {
      final position = await _getFreshCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        if (_userLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Konum alınamadı. Tarayıcı site izni, sistem konumu ve HTTPS/localhost ayarını kontrol edin.'
                    : 'Konum alınamadı. Lütfen GPS ve konum izinlerini kontrol edin.',
              ),
            ),
          );
        }
        return;
      }

      final next = LatLng(position.latitude, position.longitude);
      _handleLocationUpdate(next, headingDegrees: position.heading);
      _animatedMapMove(next, 16.5);
    } finally {
      if (mounted) {
        setState(() {
          _isCenteringOnUserLocation = false;
        });
      }
    }
  }

  // _businesses is now an instance variable, initialized in initState

  Future<void> _checkLocationPermissionAndStart() async {
    RuntimeDiagnosticLogger.map('location request start');
    if (mounted) {
      setState(() => _isLoadingLocation = true);
    }
    final locationStartedMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _checkLocationPermissionAndStartImpl().timeout(_mapLocationTimeout);
    } on TimeoutException {
      RuntimeDiagnosticLogger.map(
        'location timeout fallback to default center',
      );
      if (mounted) {
        setState(() {
          _locationNotice = 'Konum alınamadı, varsayılan bölge gösteriliyor.';
        });
      }
      _showDefaultMapCenter(reason: 'location timeout');
    } catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        stackTrace,
        context: 'location',
      );
      if (mounted) {
        setState(() {
          _locationNotice = 'Konum alınamadı, varsayılan bölge gösteriliyor.';
        });
      }
      _showDefaultMapCenter(reason: 'location catch');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
      final elapsed = DateTime.now().millisecondsSinceEpoch - locationStartedMs;
      if (_userLocation != null) {
        RuntimeDiagnosticLogger.map(
          'location loaded lat=${_userLocation!.latitude} '
          'lng=${_userLocation!.longitude} ms=$elapsed',
        );
      }
      _clearMapLoadingStates();
    }
  }

  Future<void> _checkLocationPermissionAndStartImpl() async {
    final locationAccess = LocationAccessService.instance;

    if (kIsWeb) {
      try {
        final serviceEnabled = await locationAccess.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tarayıcı konum servisi kapalı. Tarayıcı ve sistem konumunu açın.',
                ),
              ),
            );
          }
          _mapController.move(_initialPosition, 14.0);
          return;
        }

        Position? position;
        try {
          position = await locationAccess.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 30),
            ),
          );
        } catch (e) {
          debugPrint('Primary location fetch failed: $e');
        }

        if (mounted && position != null) {
          // Hide any existing snackbars
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          setState(() {
            _userLocation = LatLng(position!.latitude, position.longitude);
            _rebuildFilteredIndices();
            // On Web, auto-center immediately when location is found
            _mapController.move(_userLocation!, 15.0);
          });
          _syncUserLocationToBackend();
          _maybeStartProximityAfterStoresLoaded();
          _startLiveLocationUpdates();
          _rerunVehicleSearchIfNeeded();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Web konumu okunamadı. Tarayıcı izin verdi ancak geçerli koordinat dönmedi. Sayfayı yenileyip tekrar deneyin.',
              ),
            ),
          );
          _mapController.move(_initialPosition, 14.0);
        }
      } catch (e) {
        debugPrint('Web Location Error: $e');

        if ((e is PermissionDeniedException ||
                e.toString().toLowerCase().contains('denied')) &&
            mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni verilmedi. Harita varsayılan konumda açılıyor.',
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Web konumu okunamadı. Tarayıcı site izni, macOS konum izni ve HTTPS/localhost kullanımını kontrol edin.',
              ),
            ),
          );
        }

        if (mounted) {
          _mapController.move(_initialPosition, 14.0);
        }
      }
      return;
    }

    try {
      final serviceEnabled = await locationAccess.isLocationServiceEnabled();
      RuntimeDiagnosticLogger.map(
        'location permission status=serviceEnabled:$serviceEnabled',
      );
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Konum servisleri kapalı. Harita varsayılan konumda açılıyor.',
              ),
              action: SnackBarAction(
                label: 'Ayarlar',
                onPressed: () {
                  Geolocator.openLocationSettings();
                },
              ),
            ),
          );
        }
        _showDefaultMapCenter(reason: 'location service disabled');
        return;
      }

      final permission = await locationAccess.ensurePermission();
      RuntimeDiagnosticLogger.map('location permission status=$permission');
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationNotice = 'Konum alınamadı, varsayılan bölge gösteriliyor.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni verilmedi. Harita varsayılan konumda açılıyor.',
              ),
            ),
          );
        }
        _showDefaultMapCenter(reason: 'location permission denied');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Konum İzni Gerekli'),
              content: const Text(
                'Konum izni kalıcı olarak reddedilmiş veya kısıtlanmış. '
                'Harita varsayılan konumda açılacak; izin vermek için ayarlara gidebilirsiniz.',
              ),
              actions: [
                TextButton(
                  child: const Text('Tamam'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Ayarları Aç'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openAppSettings();
                  },
                ),
              ],
            ),
          );
        }
        _showDefaultMapCenter(reason: 'location permission deniedForever');
        return;
      }

      final position = await locationAccess.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
        requestPermissionIfNeeded: false,
      );
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum alınamadı. Harita varsayılan konumda açılıyor.',
              ),
            ),
          );
        }
        _showDefaultMapCenter(reason: 'location position null');
        return;
      }

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _locationNotice = null;
          _rebuildFilteredIndices();
        });
        _syncUserLocationToBackend();
        _maybeStartProximityAfterStoresLoaded();
        _rerunVehicleSearchIfNeeded();

        // Move map to user location on initial load
        if (_userLocation != null) {
          _mapController.move(_userLocation!, 15.0);
        }
      }

      _startLiveLocationUpdates();
    } catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'Map',
        e,
        stackTrace,
        context: 'location',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konum alınamadı. Harita varsayılan konumda açılıyor.',
            ),
          ),
        );
      }
      _showDefaultMapCenter(reason: 'location catch');
    }
  }

  void _startLiveLocationUpdates() {
    if (kIsWeb) {
      Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        try {
          final position = await LocationAccessService.instance
              .getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 8),
                ),
                requestPermissionIfNeeded: false,
              );
          if (position == null) return;

          if (mounted) {
            _handleLocationUpdate(
              LatLng(position.latitude, position.longitude),
              headingDegrees: position.heading,
            );
          }
        } catch (e) {
          // Silent fail on polling error
        }
      });
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 25,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? position) {
            if (position != null && mounted) {
              _handleLocationUpdate(
                LatLng(position.latitude, position.longitude),
                headingDegrees: position.heading,
              );
            }
          },
          onError: (e) {
            debugPrint('Location stream error: $e');
          },
        );
  }

  String _mapStoreCategoryToMap(String? category) {
    if (category == null || category.isEmpty) return 'other';
    final c = category.toLowerCase();
    if (c.contains('elektronik') || c.contains('teknoloji')) return 'teknoloji';
    if (c.contains('giyim') || c.contains('ayakkabı')) return 'giyim';
    if (c.contains('yemek')) return 'restoran';
    if (c.contains('market') || c.contains('süpermarket')) return 'market';
    if (c.contains('kozmetik')) return 'kozmetik';
    if (c.contains('kitap')) return 'kitap';
    if (c.contains('oyuncak')) return 'oyuncak';
    if (c.contains('tamir') || c.contains('otomotiv')) return 'tamir';
    return 'other';
  }

  Future<List<Product>> _getStoreProducts(String storeName) {
    final normalizedStoreName = _normalize(storeName);
    return _storeProductsCache.putIfAbsent(normalizedStoreName, () async {
      final fetched = await SupabaseService.instance
          .getProductsByStoreNamePaged(storeName: storeName, limit: 60);
      return fetched.items
          .map<Product>((item) => Product.fromDBProduct(item))
          .toList(growable: false);
    });
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some latlng tween
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    if (_activeMapMoveListener != null) {
      _moveAnimationController.removeListener(_activeMapMoveListener!);
      _activeMapMoveListener = null;
    }

    // Reset controller
    _moveAnimationController.reset();

    // Listen to animation
    void listener() {
      final lat = latTween.evaluate(_moveAnimationController);
      final lng = lngTween.evaluate(_moveAnimationController);
      final zoom = zoomTween.evaluate(_moveAnimationController);

      _mapController.move(LatLng(lat, lng), zoom);
    }

    _activeMapMoveListener = listener;
    _moveAnimationController.addListener(listener);
    _moveAnimationController.forward();
  }

  void _onBusinessSelected(int index) {
    setState(() {
      _selectedBusinessIndex = index;
    });
    final business = _businesses[index];
    final location = business['location'] as LatLng;
    _animatedMapMove(location, 17.5);
  }

  void _applyMapFilters(Map<String, dynamic> filters) {
    setState(() {
      _filterDistance = filters['distance'];
      _filterCategories = List<String>.from(filters['categories'] as List);
      _filterOpenNow = filters['openNow'] as bool;
      _userAppliedDistanceFilter = true;
      _rebuildFilteredIndices(log: true);

      if (_selectedBusinessIndex != null &&
          !_filteredBusinessIndices.contains(_selectedBusinessIndex)) {
        _selectedBusinessIndex = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filtreler uygulandı: ${_filteredBusinessIndices.length} sonuç',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MapFilterBottomSheet(
        onApply: _applyMapFilters,
        currentDistance: _filterDistance,
        currentCategories: _filterCategories,
        openNow: _filterOpenNow,
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (_vehicleMode) {
      await _performVehicleSearch(query);
      return;
    }
    final trimmedQuery = query.trim();
    final requestVersion = ++_searchRequestVersion;

    setState(() {
      _searchQuery = trimmedQuery;
    });

    if (trimmedQuery.isEmpty) {
      if (!mounted || requestVersion != _searchRequestVersion) return;
      setState(() {
        _searchCandidateIndices = null;
        _rebuildFilteredIndices(log: true);
      });
      return;
    }

    final normalizedQuery = _normalize(trimmedQuery);
    final results = await SupabaseService.instance.searchProductsPaged(
      query: trimmedQuery,
      limit: 80,
    );
    if (!mounted || requestVersion != _searchRequestVersion) return;

    final productStoreNames = results.items
        .map((product) => product.store)
        .whereType<String>()
        .map(_normalize)
        .where((store) => store.isNotEmpty)
        .toSet();

    final combinedIndices = <int>{};
    for (int i = 0; i < _businesses.length; i++) {
      final businessName = _normalize(_businesses[i]['name'].toString());
      if (productStoreNames.contains(businessName) ||
          businessName.contains(normalizedQuery)) {
        combinedIndices.add(i);
      }
    }

    final mall = combinedIndices.isEmpty ? _mallPins.match(trimmedQuery) : null;
    if (mall != null) {
      MapViewportMemory.remember(query: trimmedQuery);
      _animatedMapMove(LatLng(mall.latitude, mall.longitude), 16.0);
      unawaited(showMallMapCard(context, mall));
      return;
    }
    final mallStore = combinedIndices.isEmpty ? _mallPins.matchStore(trimmedQuery) : null;
    if (mallStore != null) {
      MapViewportMemory.remember(query: trimmedQuery);
      _animatedMapMove(LatLng(mallStore.latitude, mallStore.longitude), 16.0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mallStore.storeName}\n${mallStore.placeLabel}'),
          action: SnackBarAction(
            label: 'AVM\'yi Gör',
            onPressed: () => IbulRouter.push(
              context,
              MarketplacePaths.mallProfile(mallStore.mallId, floorId: mallStore.floorId, storeId: mallStore.storeId),
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _searchCandidateIndices = combinedIndices.toList(growable: false);
      _rebuildFilteredIndices(log: true);
    });

    if (_filteredBusinessIndices.isNotEmpty) {
      final business = _businesses[_filteredBusinessIndices.first];
      final location = business['location'] as LatLng;
      _animatedMapMove(location, 17.5);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_filteredBusinessIndices.length} sonuç bulundu.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sonuç bulunamadı. Başka bir ürün veya mağaza deneyin.',
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _performVehicleSearch(String query) async {
    final trimmedQuery = query.trim();
    final requestVersion = ++_searchRequestVersion;
    setState(() => _searchQuery = trimmedQuery);
    if (trimmedQuery.isEmpty) {
      if (!mounted || requestVersion != _searchRequestVersion) return;
      setState(() {
        _vehicleHits = const [];
        _vehicleMatchLabel = '';
        _searchCandidateIndices = null;
        _rebuildFilteredIndices(log: true);
      });
      return;
    }

    VehicleMapSearchHit hit;
    try {
      hit = await VehicleMapSearch.search(
        query: trimmedQuery,
        brand: widget.vehicleBrand,
        model: widget.vehicleModel,
        nearLat: _userLocation?.latitude,
        nearLng: _userLocation?.longitude,
      );
    } catch (error) {
      debugPrint('[Map] vehicle search failed: $error');
      if (!mounted || requestVersion != _searchRequestVersion) return;
      hit = const VehicleMapSearchHit(
        listings: [],
        sellerIds: {},
        matchLabel: 'arama',
      );
    }
    if (!mounted || requestVersion != _searchRequestVersion) return;

    final queryNorm = _normalize(trimmedQuery);
    final combinedIndices = <int>{};
    for (int i = 0; i < _businesses.length; i++) {
      final business = _businesses[i];
      final sellerId = (business['seller_id'] ?? business['id'] ?? '')
          .toString()
          .trim();
      final name = _normalize(business['name']?.toString() ?? '');
      if ((sellerId.isNotEmpty && hit.sellerIds.contains(sellerId)) ||
          (queryNorm.isNotEmpty && name.contains(queryNorm))) {
        combinedIndices.add(i);
      }
    }
    if (combinedIndices.isEmpty) {
      for (int i = 0; i < _businesses.length; i++) {
        if (isGalleryStoreRecord(_businesses[i])) combinedIndices.add(i);
      }
    }

    setState(() {
      _vehicleHits = _sortVehicleHits(hit.listings);
      _vehicleMatchLabel = hit.matchLabel;
      _searchCandidateIndices = combinedIndices.toList(growable: false);
      _rebuildFilteredIndices(log: true);
    });

    if (_filteredBusinessIndices.isNotEmpty) {
      final location =
          _businesses[_filteredBusinessIndices.first]['location'] as LatLng?;
      if (location != null) _animatedMapMove(location, 15.5);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _vehicleHits.isEmpty
              ? 'Yakında eşleşen araç bulunamadı. Galeriler gösteriliyor.'
              : '${_vehicleHits.length} araç • ${hit.matchLabel}',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<VehicleListing> _sortVehicleHits(List<VehicleListing> listings) {
    if (_userLocation == null || listings.length < 2) return listings;
    final ranked = [...listings];
    ranked.sort((a, b) {
      final da = _distanceKmForListing(a);
      final db = _distanceKmForListing(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return ranked;
  }

  double? _distanceKmForListing(VehicleListing listing) {
    if (_userLocation == null) return null;
    LatLng? location;
    if (listing.gallery?.lat != null && listing.gallery?.lng != null) {
      location = LatLng(listing.gallery!.lat!, listing.gallery!.lng!);
    } else {
      final sellerId = listing.sellerId.trim();
      for (final business in _businesses) {
        final id = (business['seller_id'] ?? business['id'] ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty && id == sellerId) {
          location = business['location'] as LatLng?;
          break;
        }
      }
    }
    if (location == null) return null;
    return Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          location.latitude,
          location.longitude,
        ) /
        1000;
  }

  Widget _buildVehicleHitsStrip() {
    return SizedBox(
      height: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              _vehicleMatchLabel.isEmpty
                  ? 'Yakındaki araçlar'
                  : 'Yakındaki araçlar • $_vehicleMatchLabel',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _vehicleHits.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final listing = _vehicleHits[index];
                final km = _distanceKmForListing(listing);
                return InkWell(
                  onTap: () => VehicleRoutes.openDetail(context, listing.id),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child:
                                listing.coverUrl == null ||
                                    listing.coverUrl!.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFFF3F4F6),
                                    child: Icon(Icons.directions_car_outlined),
                                  )
                                : OptimizedImage(
                                    imageUrlOrPath: listing.coverUrl!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                listing.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                [
                                  if (listing.specs.year > 0)
                                    '${listing.specs.year}',
                                  if (listing.specs.mileageKm != null)
                                    '${listing.specs.mileageKm} km',
                                  if ((listing.gallery?.name ?? '').isNotEmpty)
                                    listing.gallery!.name,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                [
                                  VehicleCompareFields.headlinePrice(listing),
                                  if (km != null) '${km.toStringAsFixed(1)} km',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBusinessDetail(Map<String, dynamic> business) {
    if (_isBusinessSheetOpen) return;
    _isBusinessSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBusinessDetailSheet(business),
    ).whenComplete(() {
      _isBusinessSheetOpen = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _openBusinessProductsPage(
    Map<String, dynamic> business, {
    String? initialProductQuery,
  }) async {
    if (isGalleryStoreRecord(business)) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PublicGalleryStoreView(business: business),
        ),
      );
      return;
    }
    final storeProducts = await _getStoreProducts(business['name'].toString());
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessDetailPage(
          business: business,
          storeProducts: storeProducts,
          initialProductQuery: initialProductQuery,
        ),
      ),
    );
  }

  void _openInitialTargetBusiness(int index) {
    if (_didOpenInitialTargetBusiness) return;
    _didOpenInitialTargetBusiness = true;
    _onBusinessSelected(index);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if ((widget.initialStoreProductQuery ?? '').trim().isNotEmpty) {
        unawaited(
          _openBusinessProductsPage(
            _businesses[index],
            initialProductQuery: widget.initialStoreProductQuery,
          ),
        );
        return;
      }
      _showBusinessDetail(_businesses[index]);
    });
  }

  List<String> _getStoreImagePaths(String storeName) {
    // Return empty list as we now use dynamic images from DB
    return [];
  }

  void _showMapNavigationErrorSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Harita açılamadı. Lütfen konum izninizi veya bağlantınızı kontrol edin.',
        ),
      ),
    );
  }

  Future<void> _openStoreDirections(Map<String, dynamic> business) async {
    if (_isOpeningStoreDirections) return;

    final location = business['location'] as LatLng?;
    if (location == null) {
      _showMapNavigationErrorSnackBar();
      return;
    }

    setState(() {
      _isOpeningStoreDirections = true;
    });

    try {
      final lat = location.latitude;
      final lng = location.longitude;
      final hasOrigin = _userLocation != null;
      final candidateUrls = <String>[];

      final prefersAppleMaps =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      if (prefersAppleMaps) {
        candidateUrls.add(
          buildAppleMapsNavigationUrl(
            latitude: lat,
            longitude: lng,
            directions: hasOrigin,
          ),
        );
      }

      candidateUrls.add(
        buildGoogleMapsNavigationUrl(
          latitude: lat,
          longitude: lng,
          originLatitude: _userLocation?.latitude,
          originLongitude: _userLocation?.longitude,
        ),
      );

      var opened = false;
      for (final url in candidateUrls) {
        if (await ExternalNavigation.openUrl(url)) {
          opened = true;
          break;
        }
      }

      if (!mounted) return;

      if (!opened) {
        _showMapNavigationErrorSnackBar();
        return;
      }

      if (!hasOrigin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum izni verilirse rota oluşturulabilir.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningStoreDirections = false;
        });
      }
    }
  }

  Widget _buildMapPopupHeader({
    required Map<String, dynamic> business,
    required String? logoUrl,
    required String followerLabel,
    required double rating,
    required List<SellerBadgeProgress> popupBadges,
    required VoidCallback onClose,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: (logoUrl != null && logoUrl.isNotEmpty)
              ? OptimizedImage(
                  imageUrlOrPath: logoUrl,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildStoreLogoPlaceholder(business),
                )
              : StoreLogoHelper.hasLogo(business['name'])
              ? Image.asset(
                  StoreLogoHelper.getStoreLogo(business['name'])!,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildStoreLogoPlaceholder(business),
                )
              : _buildStoreLogoPlaceholder(business),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      business['name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (rating > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  followerLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        MapStorePopupHeaderTrailing(
          badgeKey: ValueKey<String>(
            business['id']?.toString() ??
                business['seller_id']?.toString() ??
                business['name']?.toString() ??
                'store',
          ),
          badges: popupBadges,
          onClose: onClose,
        ),
      ],
    );
  }

  Widget _buildStoreLogoPlaceholder(Map<String, dynamic> business) {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: Text(
        business['name'].toString().isNotEmpty
            ? business['name'].toString().substring(0, 1).toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBusinessDetailSheet(Map<String, dynamic> business) {
    final assetImagePaths = _getStoreImagePaths(business['name']);
    final galleryUrls =
        (business['gallery_images'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];
    final logoUrl = business['logo_url'] as String?;
    final metrics = SellerBadgePublicDisplay.metricsFromBusinessMap(business);
    final followerLabel = StoreFollowState(
      followerCount: metrics.followerCount,
    ).formattedFollowerCount;
    final rating = metrics.averageRating;
    final popupBadges = SellerBadgePublicDisplay.mapPopupBadges(metrics);
    final description = business['description']?.toString().trim() ?? '';
    final addressLine =
        business['address_line']?.toString().trim() ??
        business['address']?.toString().trim() ??
        '';
    final bioText = description.isNotEmpty ? description : mapStoreBioFallback;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 4, 0),
            child: _buildMapPopupHeader(
              business: business,
              logoUrl: logoUrl,
              followerLabel: followerLabel,
              rating: rating,
              popupBadges: popupBadges,
              onClose: () => Navigator.pop(context),
            ),
          ),
          // Content
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bioText,
                    style: TextStyle(
                      fontSize: 13,
                      color: description.isNotEmpty
                          ? Colors.black87
                          : Colors.black54,
                      fontWeight: description.isNotEmpty
                          ? FontWeight.w500
                          : FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                  if (addressLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              addressLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (galleryUrls.isNotEmpty)
                    Row(
                      children: galleryUrls
                          .take(3)
                          .map(
                            (url) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: OptimizedImage(
                                    imageUrlOrPath: url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 100,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 32,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else if (assetImagePaths.isNotEmpty)
                    Row(
                      children: assetImagePaths
                          .map(
                            (path) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    image: DecorationImage(
                                      image: AssetImage(path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _openBusinessProductsPage(business);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'DÜKKANI ZİYARET ET',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Rota oluştur',
                  child: Semantics(
                    label: 'Rota oluştur',
                    button: true,
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isOpeningStoreDirections
                            ? null
                            : () => unawaited(_openStoreDirections(business)),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: _isOpeningStoreDirections
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.map_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
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

  Widget _buildCustomMarker(Map<String, dynamic> business, bool isSelected) {
    // 1. Prepare data
    final businessName = business['name'] as String? ?? 'Mağaza';
    final truncatedName = businessName.length > 12
        ? '${businessName.substring(0, 10)}..'
        : businessName;

    final logoUrl = business['logo_url'] as String?;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    // 2. Build Stack: Logo/Icon on top, Name below
    return Column(
      mainAxisSize: MainAxisSize.min, // Important: shrink to fit children
      children: [
        // --- LOGO CIRCLE ---
        Container(
          width: isSelected ? 48 : 40, // Reduced size (was 56/48)
          height: isSelected ? 48 : 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: hasLogo
                ? OptimizedImage(
                    imageUrlOrPath: logoUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildMarkerIcon(isSelected),
                  )
                : _buildMarkerIcon(isSelected),
          ),
        ),

        // --- SPACING ---
        const SizedBox(height: 4),

        // --- NAME LABEL ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            truncatedName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primary : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerIcon(bool isSelected) {
    return Center(
      // Center the icon inside the circle
      child: Icon(
        Icons.store_mall_directory_rounded,
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
        size: isSelected ? 28 : 24,
      ),
    );
  }

  bool get _shouldShowBackButton {
    final isWebLayout = MediaQuery.of(context).size.width >= 1100;
    return isWebLayout || Navigator.canPop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowBackButton = _shouldShowBackButton;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (_locationNotice != null)
                  MaterialBanner(
                    content: Text(_locationNotice!),
                    leading: const Icon(Icons.location_off_outlined),
                    actions: [
                      IconButton(
                        onPressed: () {
                          setState(() => _locationNotice = null);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                if (_storesLoadError != null)
                  MaterialBanner(
                    content: Text(_storesLoadError!),
                    leading: const Icon(Icons.info_outline),
                    actions: [
                      TextButton(
                        onPressed: _loadMapStoresEmergencyPipeline,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      if (shouldShowBackButton)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {});
                                    _searchDebounce?.cancel();
                                    _searchDebounce = Timer(
                                      const Duration(milliseconds: 350),
                                      () => unawaited(_performSearch(value)),
                                    );
                                  },
                                  decoration: InputDecoration(
                                    hintText: _vehicleMode
                                        ? 'Araç ara (örn: Renault Clio)'
                                        : 'Ürün veya mağaza ara (örn: Samsung S24)',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _searchDebounce?.cancel();
                                    unawaited(_performSearch(''));
                                    setState(() {});
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _showFilterSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.filter_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Filtrele',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_vehicleHits.isNotEmpty) _buildVehicleHitsStrip(),
                Container(
                  height: 52,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: !_storesLoadCompleted && _mapStores.isEmpty
                      ? const SizedBox.shrink()
                      : _filteredBusinessIndices.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _storesLoadCompleted && _markerStoreCount == 0
                                  ? (_mapListEmptyMessage.isEmpty
                                        ? 'Sonuç bulunamadı'
                                        : _mapListEmptyMessage)
                                  : (_mapListEmptyMessage.isEmpty
                                        ? 'Sonuç bulunamadı'
                                        : _mapListEmptyMessage),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredBusinessIndices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final businessIndex = _filteredBusinessIndices[i];
                              final b = _businesses[businessIndex];
                              final selected =
                                  businessIndex == _selectedBusinessIndex;
                              final name = b['name'] as String;
                              final distance = b['distance'] as String;

                              return GestureDetector(
                                onTap: () => _onBusinessSelected(businessIndex),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selected
                                            ? AppColors.primary.withValues(
                                                alpha: 0.3,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                        blurRadius: selected ? 12 : 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store_mall_directory_rounded,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.white.withValues(
                                                  alpha: 0.25,
                                                )
                                              : AppColors.primary.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          distance,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: MapViewportMemory.center ?? _userLocation ?? _initialPosition,
                            initialZoom: MapViewportMemory.zoom ?? 14.0,
                            onTap: (_, _) {},
                            onMapEvent: (event) {
                              if (event is! MapEventMoveEnd) return;
                              MapViewportMemory.remember(
                                camera: event.camera.center,
                                cameraZoom: event.camera.zoom,
                                query: _searchQuery,
                                filterDistance: _filterDistance,
                                filterCategories: _filterCategories,
                                filterOpenNow: _filterOpenNow,
                              );
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.ibul.app',
                            ),
                            MarkerLayer(
                              markers: _filteredBusinessIndices.map((index) {
                                final business = _businesses[index];
                                final isSelected =
                                    index == _selectedBusinessIndex;
                                final location = business['location'] as LatLng;

                                return Marker(
                                  point: location,
                                  width: 80, // Increased width to fit label
                                  height:
                                      80, // Increased height to prevent overflow
                                  child: GestureDetector(
                                    onTap: () {
                                      _onBusinessSelected(index);
                                      _showBusinessDetail(business);
                                    },
                                    child: _buildCustomMarker(
                                      business,
                                      isSelected,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (!_vehicleMode)
                              MallMapLayer(
                                pins: _mallPins,
                                onTap: (pin) => showMallMapCard(context, pin),
                              ),
                            if (_userLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _userLocation!,
                                    width: 68,
                                    height: 68,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(
                                              0xFF60A5FA,
                                            ).withValues(alpha: 0.18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF60A5FA,
                                                ).withValues(alpha: 0.28),
                                                blurRadius: 18,
                                                spreadRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle:
                                              (_userHeadingDegrees ?? 0) *
                                              math.pi /
                                              180,
                                          child: CustomPaint(
                                            size: const Size(28, 34),
                                            painter: _UserDirectionPainter(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (shouldShowStoreLoadingChip(
                          isMapReady: _isMapReady,
                          isLoadingStores: _isLoadingStores,
                          businessCount: _businesses.length,
                        ))
                          Positioned(
                            top: 12,
                            right: 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Mağazalar yükleniyor…',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
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

          // My Location Button
          Positioned(
            right: 16,
            bottom: 90, // Positioned above AI Chat button
            child: FloatingActionButton(
              heroTag: 'my_location_main',
              onPressed: _isCenteringOnUserLocation
                  ? null
                  : () => _centerMapOnCurrentLocation(),
              backgroundColor: Colors.white,
              child: _isCenteringOnUserLocation
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.blue,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // AI Chat Button (Overlay on top of everything)
          Positioned(
            right: 16,
            bottom: 16,
            child: SizedBox(
              width: 60,
              height: 60,
              child: FloatingActionButton(
                heroTag: 'ai_chat_main',
                onPressed: () {
                  final isWeb = MediaQuery.of(context).size.width >= 1100;
                  if (isWeb) {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (context) => const AIChatPage(),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIChatPage(),
                      ),
                    );
                  }
                },
                backgroundColor: AppColors.primary,
                tooltip: 'Yapay Zekaya Danış',
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDirectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.18), 3, false);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
