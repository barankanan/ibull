enum SellerPermission {
  manageProducts,
  viewOrders,
  manageOrders,
  manageCampaigns,
  viewFinance,
  manageSupport,
  manageStoreProfile,
  transferTable,
  splitBill,
  takePartialPayment,
  closeBill,
  managePrintSettings,
  manageTables,
  manageStaff,
}

class SellerPermissionGroup {
  const SellerPermissionGroup(this.title, this.permissions);

  final String title;
  final List<SellerPermission> permissions;
}

const defaultStaffPermissions = <SellerPermission>{
  SellerPermission.viewOrders,
  SellerPermission.manageOrders,
};

const sellerPermissionGroups = <SellerPermissionGroup>[
  SellerPermissionGroup('Sipariş ve Masa', <SellerPermission>[
    SellerPermission.viewOrders,
    SellerPermission.manageOrders,
    SellerPermission.transferTable,
    SellerPermission.splitBill,
  ]),
  SellerPermissionGroup('Ödeme ve Kasa', <SellerPermission>[
    SellerPermission.takePartialPayment,
    SellerPermission.closeBill,
  ]),
  SellerPermissionGroup('İşletme Yönetimi', <SellerPermission>[
    SellerPermission.manageProducts,
    SellerPermission.manageCampaigns,
    SellerPermission.viewFinance,
    SellerPermission.managePrintSettings,
    SellerPermission.manageTables,
    SellerPermission.manageSupport,
    SellerPermission.manageStoreProfile,
  ]),
  SellerPermissionGroup('Personel', <SellerPermission>[
    SellerPermission.manageStaff,
  ]),
];

const ownerOnlyGrantPermissions = <SellerPermission>{
  SellerPermission.manageStoreProfile,
};

bool actorCanManageStaff({
  required bool isOwner,
  required Set<String> held,
}) {
  if (isOwner) return true;
  return held.contains(SellerPermission.manageStaff.name);
}

Set<SellerPermission> staffGrantCeiling({
  required bool isOwner,
  required Set<String> held,
}) {
  if (isOwner) return SellerPermission.values.toSet();
  return SellerPermission.values.where((permission) {
    if (ownerOnlyGrantPermissions.contains(permission)) return false;
    return held.contains(permission.name);
  }).toSet();
}

List<SellerPermissionGroup> staffGrantGroups({
  required bool isOwner,
  required Set<String> held,
}) {
  final ceiling = staffGrantCeiling(isOwner: isOwner, held: held);
  return <SellerPermissionGroup>[
    for (final group in sellerPermissionGroups)
      if (group.permissions.any(ceiling.contains))
        SellerPermissionGroup(
          group.title,
          group.permissions.where(ceiling.contains).toList(growable: false),
        ),
  ];
}

bool staffGrantWithinCeiling({
  required bool isOwner,
  required Set<String> held,
  required Iterable<String> requested,
}) {
  final ceiling = staffGrantCeiling(isOwner: isOwner, held: held)
      .map((permission) => permission.name)
      .toSet();
  return requested.every(ceiling.contains);
}

String sellerPermissionLabel(SellerPermission permission) {
  switch (permission) {
    case SellerPermission.manageProducts:
      return 'Ürünleri Yönet';
    case SellerPermission.viewOrders:
      return 'Siparişleri Görüntüle';
    case SellerPermission.manageOrders:
      return 'Siparişleri Yönet';
    case SellerPermission.manageCampaigns:
      return 'Kampanyaları Yönet';
    case SellerPermission.viewFinance:
      return 'Finansı Görüntüle';
    case SellerPermission.manageSupport:
      return 'Destek Yönetimi';
    case SellerPermission.manageStoreProfile:
      return 'Mağaza Profili';
    case SellerPermission.transferTable:
      return 'Masa Aktar';
    case SellerPermission.splitBill:
      return 'Hesabı Böl';
    case SellerPermission.takePartialPayment:
      return 'Ara Ödeme Al';
    case SellerPermission.closeBill:
      return 'Hesabı Kes';
    case SellerPermission.managePrintSettings:
      return 'Yazıcı Ayarları';
    case SellerPermission.manageTables:
      return 'Alan ve Masa Yönetimi';
    case SellerPermission.manageStaff:
      return 'Personel Yönetimi';
  }
}

String sellerPermissionShortLabel(SellerPermission permission) {
  switch (permission) {
    case SellerPermission.manageProducts:
      return 'Ürün';
    case SellerPermission.viewOrders:
      return 'Sipariş Gör';
    case SellerPermission.manageOrders:
      return 'Sipariş Yönet';
    case SellerPermission.manageCampaigns:
      return 'Kampanya';
    case SellerPermission.viewFinance:
      return 'Finans';
    case SellerPermission.manageSupport:
      return 'Destek';
    case SellerPermission.manageStoreProfile:
      return 'Mağaza';
    case SellerPermission.transferTable:
      return 'Masa Aktar';
    case SellerPermission.splitBill:
      return 'Hesap Böl';
    case SellerPermission.takePartialPayment:
      return 'Ara Ödeme';
    case SellerPermission.closeBill:
      return 'Hesap Kes';
    case SellerPermission.managePrintSettings:
      return 'Yazıcı';
    case SellerPermission.manageTables:
      return 'Masa Düzeni';
    case SellerPermission.manageStaff:
      return 'Personel';
  }
}

class SubAdmin {
  final String id;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? staffRole;
  final String? jobTitle;
  final List<String>? visibleModules;
  final String? branchId;
  final List<SellerPermission> permissions;
  final String status;
  final DateTime? createdAt;

  SubAdmin({
    required this.id,
    this.email,
    this.phone,
    this.displayName,
    this.staffRole,
    this.jobTitle,
    this.visibleModules,
    this.branchId,
    required this.permissions,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'permissions': permissions.map((e) => e.name).toList(),
      'status': status,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory SubAdmin.fromMap(Map<String, dynamic> map, String id) {
    final List<dynamic>? perms = map['permissions'];
    
    DateTime? created;
    if (map['createdAt'] is String) {
      created = DateTime.parse(map['createdAt']);
    } else if (map['createdAt'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(map['createdAt']);
    }

    return SubAdmin(
      id: id,
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      displayName: map['display_name']?.toString(),
      staffRole: map['staff_role']?.toString(),
      jobTitle: map['job_title']?.toString(),
      visibleModules: map['visible_modules'] is List
          ? (map['visible_modules'] as List)
              .map((item) => item.toString())
              .toList(growable: false)
          : null,
      branchId: map['branch_id']?.toString(),
      permissions: (perms ?? [])
          .map((entry) {
            for (final permission in SellerPermission.values) {
              if (permission.name == entry) return permission;
            }
            return null;
          })
          .whereType<SellerPermission>()
          .toList(growable: false),
      status: map['status'] ?? 'invited',
      createdAt: created,
    );
  }
}
