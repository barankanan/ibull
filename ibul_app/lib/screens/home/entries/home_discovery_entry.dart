import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../features/vehicle/models/vehicle_listing.dart';
import '../../../models/db_product.dart';
import '../../../models/home_products_fetch_report.dart';
import '../../../services/supabase_service.dart';
import '../home_discovery_loader.dart';
import '../home_discovery_resolver.dart';
import '../sections/home_nearby_discovery_section.dart';

class HomeDiscoveryBlock extends StatefulWidget {
  const HomeDiscoveryBlock({super.key});

  @override
  State<HomeDiscoveryBlock> createState() => _HomeDiscoveryBlockState();
}

class _HomeDiscoveryBlockState extends State<HomeDiscoveryBlock> {
  var _items = const <HomeDiscoveryItem>[];
  var _loadingProducts = true;
  var _loadingVehicles = true;
  var _loadingLocation = true;
  String? _error;
  
  List<DBProduct> _products = [];
  List<VehicleListing> _vehicles = [];
  Position? _position;
  Map<String, double> _distanceBySeller = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _rebuildItems() {
    if (!mounted) return;
    setState(() {
      _items = HomeDiscoveryResolver.nearby(
        products: _products,
        vehicles: _vehicles,
        distanceBySeller: _distanceBySeller,
      );
      _error = (!_loadingProducts && !_loadingVehicles && _items.isEmpty) 
          ? 'Yakınınızdaki ürünler bulunamadı' 
          : null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loadingProducts = true;
      _loadingVehicles = true;
      _loadingLocation = true;
      _error = null;
      _products = [];
      _vehicles = [];
      _position = null;
      _distanceBySeller = {};
      _items = [];
    });

    final productsFuture = SupabaseService.instance
        .fetchInitialHomeProductsReport()
        .timeout(const Duration(seconds: 5))
        .catchError((_) => HomeProductsFetchReport.configMissing());
        
    final vehiclesFuture = HomeDiscoveryLoader.loadVehicles()
        .catchError((_) => const <VehicleListing>[]);
        
    final locationFuture = HomeDiscoveryLoader.resolvePosition()
        .catchError((_) => null);

    // 1. Fetch Products
    unawaited(productsFuture.then((report) {
      if (!mounted) return;
      _products = report.products;
      _loadingProducts = false;
      _rebuildItems();
    }));

    // 2. Fetch Vehicles
    unawaited(vehiclesFuture.then((vehicles) {
      if (!mounted) return;
      _vehicles = vehicles;
      _loadingVehicles = false;
      _rebuildItems();
    }));

    // 3. Fetch Location and Distances
    unawaited(locationFuture.then((pos) async {
      if (!mounted) return;
      if (pos == null) {
        _loadingLocation = false;
        _rebuildItems();
        return;
      }
      _position = pos;
      
      // Wait for products and vehicles to know all sellers
      await Future.wait([productsFuture, vehiclesFuture]);
      
      final sellerIds = <String>{
        for (final p in _products) if (p.sellerId != null) p.sellerId!,
        for (final v in _vehicles) if (v.sellerId != null) v.sellerId!,
      };
      
      final distances = await HomeDiscoveryLoader.distancesFor(
        sellerIds: sellerIds,
        position: pos,
      ).catchError((_) => const <String, double>{});
      
      if (!mounted) return;
      _distanceBySeller = distances;
      _loadingLocation = false;
      _rebuildItems();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return HomeNearbyDiscoverySection(
      items: _items,
      isLoading: _loadingProducts && _loadingVehicles,
      errorMessage: _error,
      onRetry: _load,
    );
  }
}
