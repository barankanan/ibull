class AdminModules {
  static const String dashboard = 'dashboard';
  static const String analytics = 'analytics';
  static const String storeManagement = 'store_management';
  static const String productApproval = 'product_approval';
  static const String ordersReturns = 'orders_returns';
  static const String mapSearch = 'map_search';
  static const String finance = 'finance';
  static const String ads = 'ads';
  static const String campaignContent = 'campaign_content';
  static const String systemLayout = 'system_layout';
  static const String support = 'support';
  static const String ihiz = 'ihiz';
  static const String permissionSystem = 'permission_system';
  static const String securityLogs = 'security_logs';

  static const List<String> all = [
    dashboard,
    analytics,
    storeManagement,
    productApproval,
    ordersReturns,
    mapSearch,
    finance,
    ads,
    campaignContent,
    systemLayout,
    support,
    ihiz,
    permissionSystem,
    securityLogs,
  ];

  static const Map<String, String> labels = {
    dashboard: 'Dashboard',
    analytics: 'Veriler',
    storeManagement: 'Magaza Yonetimi',
    productApproval: 'Urun Onay',
    ordersReturns: 'Siparis & Iade',
    mapSearch: 'Harita & Arama',
    finance: 'Finans',
    ads: 'Reklam',
    campaignContent: 'Kampanya & Icerik',
    systemLayout: 'Sistem Duzeni',
    support: 'Destek & Sikayet',
    ihiz: 'Ihiz',
    permissionSystem: 'Yetki Sistemi',
    securityLogs: 'Log & Guvenlik',
  };
}

class AdminRoleCatalogEntry {
  const AdminRoleCatalogEntry({
    required this.roleKey,
    required this.title,
    required this.description,
    required this.colorHex,
    required this.iconName,
    required this.modules,
    required this.scopes,
    required this.isSystem,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String roleKey;
  final String title;
  final String description;
  final String colorHex;
  final String iconName;
  final List<String> modules;
  final List<String> scopes;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminRoleCatalogEntry copyWith({
    String? roleKey,
    String? title,
    String? description,
    String? colorHex,
    String? iconName,
    List<String>? modules,
    List<String>? scopes,
    bool? isSystem,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminRoleCatalogEntry(
      roleKey: roleKey ?? this.roleKey,
      title: title ?? this.title,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      modules: modules ?? this.modules,
      scopes: scopes ?? this.scopes,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role_key': roleKey,
      'title': title,
      'description': description,
      'color_hex': colorHex,
      'icon_name': iconName,
      'modules': modules,
      'scopes': scopes,
      'is_system': isSystem,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AdminRoleCatalogEntry.fromMap(Map<String, dynamic> map) {
    return AdminRoleCatalogEntry(
      roleKey: (map['role_key'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      colorHex: (map['color_hex'] ?? '#2563EB').toString(),
      iconName: (map['icon_name'] ?? 'admin_panel_settings').toString(),
      modules: _readStringList(map['modules']),
      scopes: _readStringList(map['scopes']),
      isSystem: map['is_system'] == true,
      isActive: map['is_active'] != false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 100,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
    );
  }
}

class AdminUserPermissionAssignment {
  const AdminUserPermissionAssignment({
    required this.userId,
    required this.roleKey,
    required this.allowedModules,
    required this.deniedModules,
    required this.isActive,
    this.userEmail,
    this.userDisplayName,
    this.note,
    this.assignedAt,
    this.updatedAt,
  });

  final String userId;
  final String roleKey;
  final List<String> allowedModules;
  final List<String> deniedModules;
  final bool isActive;
  final String? userEmail;
  final String? userDisplayName;
  final String? note;
  final DateTime? assignedAt;
  final DateTime? updatedAt;

  factory AdminUserPermissionAssignment.fromMap(Map<String, dynamic> map) {
    final userMap = map['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['users'] as Map)
        : null;
    return AdminUserPermissionAssignment(
      userId: (map['user_id'] ?? userMap?['id'] ?? '').toString(),
      roleKey: (map['role_key'] ?? '').toString(),
      allowedModules: _readStringList(map['allowed_modules']),
      deniedModules: _readStringList(map['denied_modules']),
      isActive: map['is_active'] != false,
      userEmail: (userMap?['email'] ?? map['email'])?.toString(),
      userDisplayName: (userMap?['display_name'] ?? map['display_name'])
          ?.toString(),
      note: map['note']?.toString(),
      assignedAt: DateTime.tryParse((map['assigned_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
    );
  }
}

class AdminRoleHistoryEntry {
  const AdminRoleHistoryEntry({
    required this.id,
    required this.eventType,
    required this.previousRoleKey,
    required this.newRoleKey,
    required this.previousModules,
    required this.newModules,
    required this.createdAt,
    this.userId,
    this.userEmail,
    this.userDisplayName,
    this.actorId,
    this.actorEmail,
    this.actorDisplayName,
    this.note,
  });

  final String id;
  final String? userId;
  final String eventType;
  final String? previousRoleKey;
  final String? newRoleKey;
  final List<String> previousModules;
  final List<String> newModules;
  final DateTime createdAt;
  final String? userEmail;
  final String? userDisplayName;
  final String? actorId;
  final String? actorEmail;
  final String? actorDisplayName;
  final String? note;

  factory AdminRoleHistoryEntry.fromMap(Map<String, dynamic> map) {
    final userMap = map['users'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['users'] as Map)
        : null;
    final actorMap = map['actor'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['actor'] as Map)
        : null;
    return AdminRoleHistoryEntry(
      id: (map['id'] ?? '').toString(),
      userId: map['user_id']?.toString(),
      eventType: (map['event_type'] ?? 'updated').toString(),
      previousRoleKey: map['previous_role_key']?.toString(),
      newRoleKey: map['new_role_key']?.toString(),
      previousModules: _readStringList(map['previous_modules']),
      newModules: _readStringList(map['new_modules']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userEmail: (userMap?['email'] ?? map['user_email'])?.toString(),
      userDisplayName: (userMap?['display_name'] ?? map['user_display_name'])
          ?.toString(),
      actorId: map['actor_id']?.toString(),
      actorEmail: (actorMap?['email'] ?? map['actor_email'])?.toString(),
      actorDisplayName: (actorMap?['display_name'] ?? map['actor_display_name'])
          ?.toString(),
      note: map['note']?.toString(),
    );
  }
}

class AdminAccessBundle {
  const AdminAccessBundle({
    required this.roleKey,
    required this.roleTitle,
    required this.allowedModules,
    required this.deniedModules,
    this.roleCatalogEntry,
  });

  final String roleKey;
  final String roleTitle;
  final List<String> allowedModules;
  final List<String> deniedModules;
  final AdminRoleCatalogEntry? roleCatalogEntry;

  bool canAccess(String moduleKey) {
    if (roleKey == 'super_admin') return true;
    if (deniedModules.contains(moduleKey)) return false;
    return allowedModules.contains(moduleKey);
  }
}

const List<AdminRoleCatalogEntry> defaultAdminRoleCatalog = [
  AdminRoleCatalogEntry(
    roleKey: 'super_admin',
    title: 'Super Admin',
    description: 'Tum modullere tam erisim ve kritik ayar yonetimi.',
    colorHex: '#7C3AED',
    iconName: 'workspace_premium',
    modules: AdminModules.all,
    scopes: ['Tum sistem', 'Rol atama', 'Kritik ayarlar', 'Guvenlik'],
    isSystem: true,
    isActive: true,
    sortOrder: 0,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin',
    title: 'Genel Operasyon',
    description: 'Genel operasyon akislarini yoneten ana admin rolu.',
    colorHex: '#2563EB',
    iconName: 'admin_panel_settings',
    modules: [
      AdminModules.dashboard,
      AdminModules.analytics,
      AdminModules.storeManagement,
      AdminModules.productApproval,
      AdminModules.ordersReturns,
      AdminModules.mapSearch,
      AdminModules.finance,
      AdminModules.ads,
      AdminModules.campaignContent,
      AdminModules.systemLayout,
      AdminModules.support,
      AdminModules.ihiz,
      AdminModules.permissionSystem,
      AdminModules.securityLogs,
    ],
    scopes: ['Tum operasyon', 'Panel yonetimi', 'Rol atama'],
    isSystem: true,
    isActive: true,
    sortOrder: 10,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_marketing',
    title: 'Reklam Ekibi',
    description: 'Kampanya, vitrin ve icerik akislarini yoneten ekip rolu.',
    colorHex: '#F97316',
    iconName: 'campaign',
    modules: [
      AdminModules.dashboard,
      AdminModules.analytics,
      AdminModules.ads,
      AdminModules.campaignContent,
    ],
    scopes: ['Kampanyalar', 'Vitrin', 'Icerik'],
    isSystem: true,
    isActive: true,
    sortOrder: 20,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_support',
    title: 'Destek Ekibi',
    description: 'Destek, sikayet ve iade akislarina odaklanan ekip rolu.',
    colorHex: '#10B981',
    iconName: 'support_agent',
    modules: [
      AdminModules.dashboard,
      AdminModules.support,
      AdminModules.ordersReturns,
      AdminModules.ihiz,
    ],
    scopes: ['Ticket', 'Iade sorunlari', 'Escalation'],
    isSystem: true,
    isActive: true,
    sortOrder: 30,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_store_ops',
    title: 'Magaza Yonetimi',
    description: 'Magaza ve satici operasyonlarini yoneten ekip rolu.',
    colorHex: '#0891B2',
    iconName: 'storefront',
    modules: [
      AdminModules.dashboard,
      AdminModules.analytics,
      AdminModules.storeManagement,
      AdminModules.productApproval,
      AdminModules.ordersReturns,
      AdminModules.mapSearch,
      AdminModules.ihiz,
    ],
    scopes: ['Basvurular', 'Urun onay', 'Konum degisimi'],
    isSystem: true,
    isActive: true,
    sortOrder: 40,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_investor',
    title: 'Yatirimcilar',
    description: 'Yuksek seviye performans izleme ve raporlama rolu.',
    colorHex: '#6366F1',
    iconName: 'insights',
    modules: [
      AdminModules.dashboard,
      AdminModules.analytics,
      AdminModules.finance,
    ],
    scopes: ['KPI', 'Gelir trendi', 'Yonetici raporu'],
    isSystem: true,
    isActive: true,
    sortOrder: 50,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_finance',
    title: 'Muhasebe',
    description: 'Finans ve odeme akislarina odaklanan ekip rolu.',
    colorHex: '#16A34A',
    iconName: 'account_balance_wallet',
    modules: [
      AdminModules.dashboard,
      AdminModules.analytics,
      AdminModules.finance,
      AdminModules.ordersReturns,
      AdminModules.ihiz,
    ],
    scopes: ['Hakedis', 'Komisyon', 'Odeme takibi'],
    isSystem: true,
    isActive: true,
    sortOrder: 60,
  ),
  AdminRoleCatalogEntry(
    roleKey: 'admin_security',
    title: 'Siberciler',
    description: 'Guvenlik loglari ve erisim takibini yoneten ekip rolu.',
    colorHex: '#DC2626',
    iconName: 'gpp_good',
    modules: [AdminModules.dashboard, AdminModules.securityLogs],
    scopes: ['Oturum takibi', 'Loglar', 'Risk inceleme'],
    isSystem: true,
    isActive: true,
    sortOrder: 70,
  ),
];

List<String> _readStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
