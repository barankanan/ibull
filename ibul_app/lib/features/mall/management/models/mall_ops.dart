class MallCampaign {
  const MallCampaign({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.targetType,
    this.description,
    this.imageUrl,
    this.targetCategory,
    this.targetBranchIds = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String targetType;
  final String? targetCategory;
  final List<String> targetBranchIds;

  /// Taslak, Planlandı, Aktif, Bitti. Stored status is only draft/published.
  String displayStatus([DateTime? now]) {
    if (status != 'published') return 'draft';
    final at = now ?? DateTime.now();
    if (at.isBefore(startsAt)) return 'scheduled';
    if (at.isAfter(endsAt)) return 'ended';
    return 'active';
  }

  static String statusLabel(String display) => switch (display) {
        'scheduled' => 'Planlandı',
        'active' => 'Aktif',
        'ended' => 'Bitti',
        _ => 'Taslak',
      };

  String get targetLabel => switch (targetType) {
        'stores' => 'Seçili mağazalar (${targetBranchIds.length})',
        'category' => 'Kategori: ${targetCategory ?? '-'}',
        _ => 'Tüm AVM',
      };

  factory MallCampaign.fromMap(Map<String, dynamic> map) {
    final branches = map['target_branch_ids'];
    return MallCampaign(
      id: map['id'].toString(),
      title: map['title']?.toString() ?? '',
      description: _text(map['description']),
      imageUrl: _text(map['image_url']),
      startsAt: DateTime.tryParse(map['starts_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      endsAt: DateTime.tryParse(map['ends_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      status: map['status']?.toString() ?? 'draft',
      targetType: map['target_type']?.toString() ?? 'mall',
      targetCategory: _text(map['target_category']),
      targetBranchIds: branches is List ? branches.map((item) => item.toString()).toList() : const [],
    );
  }
}

class MallCampaignDraft {
  const MallCampaignDraft({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.targetType,
    required this.publish,
    this.id,
    this.description,
    this.imageUrl,
    this.targetCategory,
    this.targetBranchIds = const [],
  });

  final String? id;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final String targetType;
  final String? targetCategory;
  final List<String> targetBranchIds;
  final bool publish;
}

/// Placements a mall ad can request. Rows live in the shared `campaigns` table.
class MallAdPlacement {
  const MallAdPlacement._();

  static const values = <String>[
    'mall_home_banner',
    'mall_map_featured',
    'mall_detail_banner',
    'mall_campaign_featured',
  ];

  static String label(String value) => switch (value) {
        'mall_home_banner' => 'Ana sayfa AVM banner',
        'mall_map_featured' => 'Harita öne çıkarma',
        'mall_detail_banner' => 'AVM detay banner',
        'mall_campaign_featured' => 'Kampanya öne çıkarma',
        _ => value,
      };
}

class MallAd {
  const MallAd({
    required this.id,
    required this.name,
    required this.status,
    required this.placement,
    this.startsAt,
    this.endsAt,
    this.totalBudget = 0,
    this.reviewNotes,
  });

  final String id;
  final String name;
  final String status;
  final String placement;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double totalBudget;
  final String? reviewNotes;

  /// Groups for the Reklam tabs: active, draft, review, done.
  String get group => switch (status) {
        'draft' => 'draft',
        'pending_review' => 'review',
        'approved' || 'active' || 'scheduled' || 'paused' => 'active',
        _ => 'done',
      };

  String get statusLabel => switch (status) {
        'draft' => 'Taslak',
        'pending_review' => 'Onay bekliyor',
        'approved' => 'Onaylandı',
        'active' => 'Yayında',
        'scheduled' => 'Planlandı',
        'paused' => 'Duraklatıldı',
        'rejected' => 'Reddedildi',
        _ => 'Tamamlandı',
      };

  factory MallAd.fromMap(Map<String, dynamic> map) {
    return MallAd(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'draft',
      placement: map['placement']?.toString() ?? '',
      startsAt: DateTime.tryParse(map['starts_at']?.toString() ?? '')?.toLocal(),
      endsAt: DateTime.tryParse(map['ends_at']?.toString() ?? '')?.toLocal(),
      totalBudget: double.tryParse(map['total_budget']?.toString() ?? '') ?? 0,
      reviewNotes: _text(map['review_notes']),
    );
  }
}

class MallMember {
  const MallMember({
    required this.userId,
    required this.role,
    required this.status,
    required this.displayName,
    this.email,
    this.isSelf = false,
  });

  final String userId;
  final String role;
  final String status;
  final String displayName;
  final String? email;
  final bool isSelf;

  String get statusLabel => switch (status) {
        'active' => 'Aktif',
        'invited' => 'Davet edildi',
        'suspended' => 'Askıda',
        _ => status,
      };

  factory MallMember.fromMap(Map<String, dynamic> map) {
    return MallMember(
      userId: map['user_id'].toString(),
      role: map['role']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'İBUL kullanıcısı',
      email: _text(map['email']),
      isSelf: map['is_self'] == true,
    );
  }
}

class MallInvitation {
  const MallInvitation({required this.email, required this.role});

  final String email;
  final String role;

  factory MallInvitation.fromMap(Map<String, dynamic> map) =>
      MallInvitation(email: map['email']?.toString() ?? '', role: map['role']?.toString() ?? '');
}

class MallActivity {
  const MallActivity({required this.kind, required this.subject, required this.at, this.detail});

  final String kind;
  final String subject;
  final String? detail;
  final DateTime at;

  String get text => switch (kind) {
        'floor_created' => '$subject oluşturuldu',
        'unit_created' => 'Mağaza $subject alanı eklendi${detail == null ? '' : ' ($detail)'}',
        'link_pending' => '$subject mağaza bağlantısı istendi${detail == null ? '' : ' • Mağaza $detail'}',
        'link_approved' => '$subject bağlantıyı onayladı${detail == null ? '' : ' • Mağaza $detail'}',
        'link_rejected' => '$subject bağlantıyı reddetti',
        'link_cancelled' => '$subject bağlantı talebi geri çekildi',
        'link_removed' => '$subject bağlantısı kaldırıldı',
        'campaign_published' => '"$subject" kampanyası yayınlandı',
        'campaign_draft' => '"$subject" kampanya taslağı kaydedildi',
        _ => subject,
      };

  factory MallActivity.fromMap(Map<String, dynamic> map) {
    return MallActivity(
      kind: map['kind']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      detail: _text(map['detail']),
      at: DateTime.tryParse(map['at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class MallStats {
  const MallStats({required this.totals, required this.daily});

  final Map<String, int> totals;
  final List<({DateTime day, int count})> daily;

  static const events = <String, String>{
    'mall_view': 'AVM görüntülenme',
    'map_open': 'Haritadan açılma',
    'store_profile_click': 'Mağaza profil tıklaması',
    'directions_click': 'Yol tarifi tıklaması',
    'campaign_view': 'Kampanya görüntülenme',
  };

  int get total => totals.values.fold(0, (sum, value) => sum + value);
  bool get isEmpty => total == 0;

  factory MallStats.fromMap(Map<String, dynamic> map) {
    final rawTotals = map['totals'];
    final rawDaily = map['daily'];
    return MallStats(
      totals: rawTotals is Map
          ? rawTotals.map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0))
          : const {},
      daily: rawDaily is List
          ? [
              for (final item in rawDaily)
                if (item is Map)
                  (
                    day: DateTime.tryParse(item['day']?.toString() ?? '') ?? DateTime.now(),
                    count: int.tryParse(item['count']?.toString() ?? '') ?? 0,
                  ),
            ]
          : const [],
    );
  }
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
