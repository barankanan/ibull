import 'staff_access_policy.dart';

enum SellerPermission {
  manageProducts,
  viewOrders,
  manageOrders,
  manageCampaigns,
  viewFinance,
  manageSupport,
  manageStoreProfile,
  fullAccess,
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
    case SellerPermission.fullAccess:
      return 'Tam Erişim';
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
      return 'Finans Gör';
    case SellerPermission.manageSupport:
      return 'Destek';
    case SellerPermission.manageStoreProfile:
      return 'Mağaza';
    case SellerPermission.fullAccess:
      return 'Tam Erişim';
  }
}

class SubAdmin {
  final String id;
  final String? email;
  final String? phone;
  final List<SellerPermission> permissions;
  final String status;
  final DateTime? createdAt;

  SubAdmin({
    required this.id,
    this.email,
    this.phone,
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
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory SubAdmin.fromMap(Map<String, dynamic> map, String id) {
    DateTime? created;
    if (map['createdAt'] is String) {
      created = DateTime.parse(map['createdAt']);
    } else if (map['createdAt'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(map['createdAt']);
    }

    final permissions = parseStaffPermissionTokens(map['permissions'])
        .map(SellerPermission.values.byName)
        .toList(growable: false);

    return SubAdmin(
      id: id,
      email: map['email'],
      phone: map['phone'],
      permissions: permissions,
      status: map['status'] ?? 'invited',
      createdAt: created,
    );
  }
}
