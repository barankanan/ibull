import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle_listing.dart';
import 'vehicle_detail_spec_table.dart';

/// Product-tab nearby chrome: copy + compact map preview (or placeholder).
class VehicleDetailLocationTab extends StatelessWidget {
  const VehicleDetailLocationTab({
    super.key,
    required this.listing,
    this.onNearby,
  });

  final VehicleListing listing;
  final VoidCallback? onNearby;

  @override
  Widget build(BuildContext context) {
    final location = VehicleDetailSpecBuilder.locationOf(listing);
    final lat = listing.gallery?.lat;
    final lng = listing.gallery?.lng;
    final hasPoint = lat != null && lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          location.isEmpty
              ? 'Yakınınızdaki galerilerde bu ilanı bulabilirsiniz.'
              : 'Yakınınızdaki araçları / galerileri görüntüleyin.\n$location',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasPoint
                ? _MiniMap(lat: lat, lng: lng, onTap: onNearby)
                : _Unavailable(onTap: onNearby),
          ),
        ),
      ],
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.lat, required this.lng, this.onTap});

  final double lat;
  final double lng;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return GestureDetector(
      key: const ValueKey('vehicle-detail-nearby'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: IgnorePointer(
        child: FlutterMap(
          options: MapOptions(initialCenter: point, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ibul.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF673AB7),
                    size: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: const ValueKey('vehicle-detail-nearby'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Konum haritada işaretlenmedi',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
