/// Server-computed setup state (`mall_setup_summary`). Dashboard counts and the
/// checklist read only this, so they always match `mall_floors`/`malls`.
class MallSetupSummary {
  const MallSetupSummary({
    required this.status,
    this.isVerified = false,
    this.floorCount = 0,
    this.unitCount = 0,
    this.vacantUnitCount = 0,
    this.activeStoreCount = 0,
    this.pendingRequestCount = 0,
    this.floorPlanCount = 0,
    this.profileReady = false,
    this.mediaReady = false,
    this.hoursReady = false,
    this.locationReady = false,
    this.missing = const [],
    this.publication,
    this.fromServer = true,
  });

  /// Same counts from the rows the panel already read (`malls`, `mall_floors`,
  /// `mall_units`, `mall_branch_links`) when `mall_setup_summary` is
  /// unavailable. Publishing stays disabled: only the server decides that.
  factory MallSetupSummary.fromRows({
    required String status,
    required bool isVerified,
    required bool profileReady,
    required bool mediaReady,
    required bool hoursReady,
    required bool locationReady,
    required int floorCount,
    required int floorPlanCount,
    required int unitCount,
    required int vacantUnitCount,
    required int activeStoreCount,
    required int pendingRequestCount,
  }) {
    return MallSetupSummary(
      status: status,
      isVerified: isVerified,
      floorCount: floorCount,
      unitCount: unitCount,
      vacantUnitCount: vacantUnitCount,
      activeStoreCount: activeStoreCount,
      pendingRequestCount: pendingRequestCount,
      floorPlanCount: floorPlanCount,
      profileReady: profileReady,
      mediaReady: mediaReady,
      hoursReady: hoursReady,
      locationReady: locationReady,
      missing: [
        if (!profileReady) 'profile',
        if (!mediaReady) 'media',
        if (!hoursReady) 'hours',
        if (!locationReady) 'location',
        if (floorCount == 0) 'floor',
        if (activeStoreCount == 0) 'store',
      ],
      fromServer: false,
    );
  }

  final String status;
  final bool isVerified;
  final int floorCount;
  final int unitCount;
  final int vacantUnitCount;
  final int activeStoreCount;
  final int pendingRequestCount;
  final int floorPlanCount;
  final bool profileReady;
  final bool mediaReady;
  final bool hoursReady;
  final bool locationReady;

  /// Publish blockers from `mall_publication_missing`:
  /// profile, media, hours, location, floor, store.
  final List<String> missing;
  final MallPublication? publication;
  final bool fromServer;

  bool get hasFloor => floorCount > 0;
  bool get hasActiveStore => activeStoreCount > 0;
  bool get hasFloorPlan => floorPlanCount > 0;
  bool get isActive => status == 'active';
  bool get isPendingReview => status == 'pending_review';
  bool get canRequestPublish => fromServer && status == 'draft' && isVerified && missing.isEmpty;

  String get statusLabel => switch (status) {
        'active' => 'Yayında',
        'pending_review' => 'Yayın onayı bekliyor',
        'suspended' => 'Askıda',
        'archived' => 'Arşiv',
        _ => 'Kurulumda',
      };

  /// Why the mall is (not) on the customer map. Public map lists `status = active` only.
  String mapVisibilityText(String mallName) => switch (status) {
        'active' => '$mallName müşteri haritasında AVM pini olarak görünüyor.',
        'pending_review' =>
          '$mallName haritada henüz görünmüyor: yayın talebiniz İBUL ekibi tarafından inceleniyor. '
              'Onaylanınca haritada AVM pini olarak çıkar.',
        'suspended' => '$mallName askıya alındığı için haritada görünmüyor. İBUL ekibiyle iletişime geçin.',
        _ => '$mallName haritada görünmüyor çünkü durumu "Kurulumda" (taslak). Haritada yalnız yayındaki '
            'AVM\'ler gösterilir. Kurulumu tamamlayıp "Yayına Gönder" deyin; İBUL ekibi onaylayınca yayına alınır.',
      };

  static String missingLabel(String key) => switch (key) {
        'profile' => 'AVM bilgileri',
        'media' => 'Logo ve kapak',
        'hours' => 'Çalışma saatleri',
        'location' => 'Harita konumu',
        'floor' => 'En az 1 kat',
        'store' => 'En az 1 onaylı mağaza',
        _ => key,
      };

  factory MallSetupSummary.fromMap(Map<String, dynamic> map) {
    final rawMissing = map['missing'];
    final rawPublication = map['publication'];
    return MallSetupSummary(
      status: map['status']?.toString() ?? 'draft',
      isVerified: map['is_verified'] == true,
      floorCount: _int(map['floor_count']),
      unitCount: _int(map['unit_count']),
      vacantUnitCount: _int(map['vacant_unit_count']),
      activeStoreCount: _int(map['active_store_count']),
      pendingRequestCount: _int(map['pending_request_count']),
      floorPlanCount: _int(map['floor_plan_count']),
      profileReady: map['profile_ready'] == true,
      mediaReady: map['media_ready'] == true,
      hoursReady: map['hours_ready'] == true,
      locationReady: map['location_ready'] == true,
      missing: rawMissing is List ? [for (final item in rawMissing) item.toString()] : const [],
      publication: rawPublication is Map ? MallPublication.fromMap(Map<String, dynamic>.from(rawPublication)) : null,
    );
  }
}

class MallPublication {
  const MallPublication({required this.status, this.requestedAt, this.reviewedAt, this.adminNote});

  final String status;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String? adminNote;

  bool get isRejected => status == 'rejected';

  factory MallPublication.fromMap(Map<String, dynamic> map) {
    final note = map['admin_note']?.toString().trim() ?? '';
    return MallPublication(
      status: map['status']?.toString() ?? 'pending',
      requestedAt: DateTime.tryParse(map['requested_at']?.toString() ?? '')?.toLocal(),
      reviewedAt: DateTime.tryParse(map['reviewed_at']?.toString() ?? '')?.toLocal(),
      adminNote: note.isEmpty ? null : note,
    );
  }
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
