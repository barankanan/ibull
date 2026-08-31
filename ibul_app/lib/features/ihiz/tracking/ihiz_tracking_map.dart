import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../delivery/ihiz_public_tracking.dart';
import '../theme/ihiz_brand.dart';

class IhizTrackingMap extends StatelessWidget {
  const IhizTrackingMap({
    super.key,
    required this.live,
    this.connectionLost = false,
  });

  final IhizLiveLocation live;
  final bool connectionLost;

  @override
  Widget build(BuildContext context) {
    final points = <Marker>[];
    if (live.pickupLat != null && live.pickupLng != null) {
      points.add(
        Marker(
          point: LatLng(live.pickupLat!, live.pickupLng!),
          width: 42,
          height: 42,
          child: const _MapPin(Icons.storefront_rounded, IhizBrand.navy),
        ),
      );
    }
    if (live.dropoffLat != null && live.dropoffLng != null) {
      points.add(
        Marker(
          point: LatLng(live.dropoffLat!, live.dropoffLng!),
          width: 42,
          height: 42,
          child: const _MapPin(Icons.location_on_rounded, IhizBrand.blue),
        ),
      );
    }
    if (live.hasCourierPoint) {
      points.add(
        Marker(
          point: LatLng(live.courierLat!, live.courierLng!),
          width: 46,
          height: 46,
          child: const _MapPin(Icons.two_wheeler_rounded, IhizBrand.blueBright),
        ),
      );
    }

    final center = live.hasCourierPoint
        ? LatLng(live.courierLat!, live.courierLng!)
        : (live.dropoffLat != null && live.dropoffLng != null)
        ? LatLng(live.dropoffLat!, live.dropoffLng!)
        : const LatLng(39.7767, 30.5206);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ibul.ihiz',
              ),
              MarkerLayer(markers: points),
            ],
          ),
          if (connectionLost)
            const Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _LiveWarning(),
            ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _LiveWarning extends StatelessWidget {
  const _LiveWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Canlı konum geçici olarak güncellenemiyor.',
        style: TextStyle(
          color: IhizBrand.ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
