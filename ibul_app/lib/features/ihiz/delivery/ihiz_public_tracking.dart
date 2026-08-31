import 'ihiz_delivery_status.dart';
import 'ihiz_route_paths.dart';

class IhizTrackingEvent {
  const IhizTrackingEvent({
    required this.eventType,
    this.status,
    this.title,
    this.description,
    this.createdAt,
  });

  final String eventType;
  final String? status;
  final String? title;
  final String? description;
  final DateTime? createdAt;

  factory IhizTrackingEvent.fromJson(Map<String, dynamic> json) {
    return IhizTrackingEvent(
      eventType: (json['event_type'] ?? '').toString(),
      status: json['status']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get displayTitle {
    final raw = (title ?? '').trim();
    if (raw.isNotEmpty) return raw;
    return IhizDeliveryStatus.label(status ?? eventType);
  }
}

class IhizLiveLocation {
  const IhizLiveLocation({
    this.courierLat,
    this.courierLng,
    this.courierUpdatedAt,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  final double? courierLat;
  final double? courierLng;
  final DateTime? courierUpdatedAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  bool get hasCourierPoint => courierLat != null && courierLng != null;

  factory IhizLiveLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const IhizLiveLocation();
    }
    return IhizLiveLocation(
      courierLat: _asDouble(json['courier_lat']),
      courierLng: _asDouble(json['courier_lng']),
      courierUpdatedAt: DateTime.tryParse(
        json['courier_location_updated_at']?.toString() ?? '',
      ),
      pickupLat: _asDouble(json['pickup_lat']),
      pickupLng: _asDouble(json['pickup_lng']),
      dropoffLat: _asDouble(json['dropoff_lat']),
      dropoffLng: _asDouble(json['dropoff_lng']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class IhizPublicTracking {
  const IhizPublicTracking({
    required this.found,
    this.error,
    this.trackingCode,
    this.status,
    this.sourceType,
    this.createdAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.packageSize,
    this.packageWeight,
    this.notes,
    this.packageMediaUrl,
    this.senderName,
    this.pickupLabel,
    this.dropoffLabel,
    this.live,
    this.events = const [],
  });

  final bool found;
  final String? error;
  final String? trackingCode;
  final String? status;
  final String? sourceType;
  final DateTime? createdAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? packageSize;
  final double? packageWeight;
  final String? notes;
  final String? packageMediaUrl;
  final String? senderName;
  final String? pickupLabel;
  final String? dropoffLabel;
  final IhizLiveLocation? live;
  final List<IhizTrackingEvent> events;

  bool get isLive =>
      live != null && IhizDeliveryStatus.isLive(status);

  bool get hasVideo {
    final url = (packageMediaUrl ?? '').trim();
    return url.startsWith('http');
  }

  List<IhizTrackingEvent> get orderedEvents {
    final copy = [...events];
    copy.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return copy;
  }

  String get statusLabel => IhizDeliveryStatus.label(status);

  String get friendlyMessage {
    if (!found) {
      if (error == 'rate_limited') {
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      }
      return 'Teslimat bulunamadı.';
    }
    return IhizDeliveryStatus.friendlyMessage(status);
  }

  bool get exposesPii {
    const forbidden = <String>[
      'pickup_phone',
      'dropoff_phone',
      'seller_id',
      'store_id',
      'order_id',
      'assigned_courier_id',
      'created_by_user_id',
      'actor_user_id',
    ];
    return forbidden.any((key) => trackingCode == key);
  }

  factory IhizPublicTracking.notFound([String error = 'not_found']) {
    return IhizPublicTracking(found: false, error: error);
  }

  factory IhizPublicTracking.fromJson(Map<String, dynamic> json) {
    final found = json['found'] == true;
    final liveRaw = json['live'];
    final eventsRaw = json['events'];
    return IhizPublicTracking(
      found: found,
      error: json['error']?.toString(),
      trackingCode: IhizRoutePaths.normalizeTrackingCode(
        json['tracking_code']?.toString(),
      ),
      status: json['status']?.toString(),
      sourceType: json['source_type']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      pickedUpAt: DateTime.tryParse(json['picked_up_at']?.toString() ?? ''),
      deliveredAt: DateTime.tryParse(json['delivered_at']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
      packageSize: json['package_size']?.toString(),
      packageWeight: IhizLiveLocation._asDouble(json['package_weight']),
      notes: json['notes']?.toString(),
      packageMediaUrl: json['package_media_url']?.toString(),
      senderName: json['sender_name']?.toString(),
      pickupLabel: json['pickup_label']?.toString(),
      dropoffLabel: json['dropoff_label']?.toString(),
      live: liveRaw is Map
          ? IhizLiveLocation.fromJson(Map<String, dynamic>.from(liveRaw))
          : null,
      events: eventsRaw is List
          ? eventsRaw
                .whereType<Map>()
                .map(
                  (row) => IhizTrackingEvent.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  static bool jsonExposesForbiddenKeys(Map<String, dynamic> json) {
    const forbidden = <String>{
      'pickup_phone',
      'dropoff_phone',
      'pickup_address',
      'dropoff_address',
      'seller_id',
      'store_id',
      'order_id',
      'assigned_courier_id',
      'created_by_user_id',
      'actor_user_id',
      'user_id',
    };
    return _containsForbidden(json, forbidden);
  }

  static bool _containsForbidden(
    Map<String, dynamic> json,
    Set<String> forbidden,
  ) {
    for (final entry in json.entries) {
      if (forbidden.contains(entry.key)) return true;
      final value = entry.value;
      if (value is Map) {
        if (_containsForbidden(Map<String, dynamic>.from(value), forbidden)) {
          return true;
        }
      }
      if (value is List) {
        for (final item in value) {
          if (item is Map &&
              _containsForbidden(Map<String, dynamic>.from(item), forbidden)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
