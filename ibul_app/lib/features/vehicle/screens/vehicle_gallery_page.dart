import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../services/location_access_service.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/vehicle_listing.dart';
import '../navigation/gallery_store_entry.dart';
import '../navigation/vehicle_routes.dart';
import '../services/vehicle_service.dart';

class VehicleGalleryPage extends StatelessWidget {
  const VehicleGalleryPage({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context) {
    return PublicGalleryStoreView(
      business: PublicGalleryStoreView.businessRecord(sellerId: sellerId),
    );
  }
}

class VehicleMapPage extends StatefulWidget {
  const VehicleMapPage({super.key});

  @override
  State<VehicleMapPage> createState() => _VehicleMapPageState();
}

class _VehicleMapPageState extends State<VehicleMapPage> {
  bool _loading = true;
  String? _error;
  List<VehicleGallerySummary> _galleries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var lat = 41.0082;
      var lng = 28.9784;
      try {
        final pos = await LocationAccessService.instance.getCurrentPosition(
          requestPermissionIfNeeded: true,
        );
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (error) {
        debugPrint('[vehicle] location fallback: $error');
      }
      final galleries = await VehicleService.instance.galleries.nearby(
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      setState(() {
        _galleries = galleries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Galeriler yüklenemedi. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yakınımdaki galeriler'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
      ),
      body: _loading
          ? const IbulPageState.loading()
          : _error != null
          ? IbulPageState.error(title: _error!, onAction: _load)
          : ListView.separated(
              itemCount: _galleries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final g = _galleries[index];
                return ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(g.name),
                  subtitle: Text(
                    'Bu galeride ${g.vehicleCount} araç var'
                    '${g.city == null ? '' : ' · ${g.city}'}',
                  ),
                  onTap: () => VehicleRoutes.openGallery(context, g.sellerId),
                );
              },
            ),
    );
  }
}
