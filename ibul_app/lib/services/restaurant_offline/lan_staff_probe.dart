import '../staff_login_policy.dart';

/// One membership row as the seller machine reads it from `store_sub_admins`.
typedef LanStaffMembership = Map<String, dynamic>;

/// Reads the membership of [staffId] in this restaurant, or null when the
/// person is not a member. Throws on a network failure.
typedef LanStaffMembershipReader = Future<LanStaffMembership?> Function(
  String staffId,
);

/// Real staff check for the LAN host. It never accepts anybody by default.
/// Each answer rests only on the stored membership, never on a role or job
/// title: the membership must be active, belong to this restaurant, hold the
/// `manageOrders` permission, and (when limited to a branch) be limited to the
/// branch of this center. A network failure is [StaffProbeKind.unreachable]
/// so the host can apply its limited offline grant instead of treating a
/// dropped cloud link as a revocation.
Future<StaffProbe> Function(String staffId) lanStaffProbe(
  LanStaffMembershipReader read, {
  String restaurantId = '',
  String? Function()? centerBranchId,
}) {
  return (String staffId) async {
    final id = staffId.trim();
    if (id.isEmpty) {
      return const StaffProbe(
        StaffProbeKind.rejected,
        reason: 'Personel kimliği yok.',
      );
    }
    final LanStaffMembership? row;
    try {
      row = await read(id);
    } catch (error) {
      if (staffProbeErrorIsUnreachable(error)) {
        return const StaffProbe(
          StaffProbeKind.unreachable,
          reason: 'Personel sunucusuna ulaşılamadı.',
        );
      }
      return const StaffProbe(
        StaffProbeKind.rejected,
        reason: 'Personel yetkisi doğrulanamadı.',
      );
    }
    return lanStaffDecision(
      row,
      restaurantId: restaurantId,
      centerBranchId: centerBranchId?.call(),
    );
  };
}

/// Reads one staff member's authority through the owner-only RPC
/// `lan_staff_authority`, which also reports the temporary-password flag the
/// owner's client cannot read from the table. Returns null when the person is
/// not a member of [restaurantId]. Any other failure (including an RPC that
/// does not exist yet) throws, so the caller never treats it as an approval.
LanStaffMembershipReader lanStaffAuthorityReader(
  Future<dynamic> Function(String function, Map<String, dynamic> params) rpc,
  String restaurantId,
) {
  return (String staffId) async {
    final result = await rpc('lan_staff_authority', <String, dynamic>{
      'p_restaurant_id': restaurantId,
      'p_staff_id': staffId,
    });
    if (result is! Map) {
      throw StateError('Personel yetki yanıtı geçersiz.');
    }
    final map = Map<String, dynamic>.from(result);
    if (map['found'] != true) return null;
    return map;
  };
}

/// Operation a LAN device needs: placing a table order.
const String lanOrderPermission = 'manageOrders';

/// Pure decision over a membership row. Kept separate so it is tested without
/// a database. Mirrors the server rules (`restaurant_has_permission`,
/// `restaurant_table_access`): status, store, permission and branch.
StaffProbe lanStaffDecision(
  LanStaffMembership? row, {
  String restaurantId = '',
  String? centerBranchId,
}) {
  if (row == null) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Bu kişi bu işletmenin personeli değil.',
    );
  }
  final store = row['store_id']?.toString().trim() ?? '';
  if (restaurantId.isNotEmpty && store != restaurantId) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Bu kişi bu işletmenin personeli değil.',
    );
  }
  final status = row['status']?.toString().trim().toLowerCase() ?? '';
  if (status != 'active') {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Personel hesabı aktif değil.',
    );
  }
  // A staff account that still holds its temporary password takes no orders.
  // The flag must be present and exactly false: a missing or odd answer (an
  // old server without the RPC, a hand-made row) is refused, never assumed.
  final mustChange = row['must_change_password'];
  if (mustChange is! bool) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Personelin şifre durumu doğrulanamadı.',
    );
  }
  if (mustChange) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Personel geçici şifresini değiştirmeden sipariş alamaz.',
    );
  }
  // The server always sends the epoch; a missing or odd value is refused.
  final epoch = row['credential_epoch'];
  if (epoch is! int) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Personelin hesap sürümü doğrulanamadı.',
    );
  }
  final permissions = row['permissions'] is List
      ? (row['permissions'] as List).map((item) => item.toString()).toSet()
      : const <String>{};
  // Role and job title grant nothing; only the stored permission does.
  if (!permissions.contains(lanOrderPermission)) {
    return const StaffProbe(
      StaffProbeKind.rejected,
      reason: 'Bu personelin sipariş alma yetkisi yok.',
    );
  }
  final staffBranch = row['branch_id']?.toString().trim() ?? '';
  if (staffBranch.isNotEmpty) {
    final center = centerBranchId?.trim() ?? '';
    if (center.isEmpty || center != staffBranch) {
      return const StaffProbe(
        StaffProbeKind.rejected,
        reason: 'Bu personelin şubesi bu merkezin şubesi değil.',
      );
    }
  }
  return StaffProbe(
    StaffProbeKind.active,
    branchId: staffBranch.isEmpty ? null : staffBranch,
    permissions: permissions,
    credentialEpoch: epoch,
  );
}
