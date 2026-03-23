enum SellerPermission {
  manageProducts,
  viewOrders,
  manageOrders,
  manageCampaigns,
  viewFinance,
  manageSupport,
  manageStoreProfile,
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
      email: map['email'],
      phone: map['phone'],
      permissions: (perms ?? [])
          .map((e) => SellerPermission.values.firstWhere(
                (v) => v.name == e,
                orElse: () => SellerPermission.manageProducts,
              ))
          .toList(),
      status: map['status'] ?? 'invited',
      createdAt: created,
    );
  }
}
