import 'package:flutter/material.dart';

import '../../../features/vehicle/models/vehicle_listing.dart';
import '../home_discovery_loader.dart';
import '../sections/home_vehicle_rail_section.dart';

class HomeVehicleBlock extends StatefulWidget {
  const HomeVehicleBlock({super.key});

  @override
  State<HomeVehicleBlock> createState() => _HomeVehicleBlockState();
}

class _HomeVehicleBlockState extends State<HomeVehicleBlock> {
  var _listings = const <VehicleListing>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await HomeDiscoveryLoader.loadVehicles();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Araçlar yüklenemedi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeVehicleRailSection(
      listings: _listings,
      isLoading: _loading,
      errorMessage: _error,
      onRetry: _load,
    );
  }
}
