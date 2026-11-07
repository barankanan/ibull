/// Page grants on `store_sub_admins.permissions` and the operations they allow.
///
/// `fullAccess` is the owner's "Tam Erişim" grant: it covers every page
/// operation for that business. It does not include staff administration, so
/// a person cannot invite, edit, or elevate anyone — including themselves.
library;

enum StaffOperation {
  viewOrders,
  manageOrders,
  collectPayment,
  manageProducts,
  viewFinance,
  manageCampaigns,
  manageSupport,
  manageStoreProfile,
  manageStaff,
}

class StaffGrant {
  const StaffGrant({required this.status, required this.permissions});

  final String status;
  final List<String> permissions;

  bool get isActive => status.trim().toLowerCase() == 'active';
}

String? normalizeStaffPermissionToken(Object? raw) {
  if (raw == null) return null;
  final folded = _foldPermissionToken(raw.toString());
  if (folded.isEmpty) return null;
  return _canonicalStaffPermissions[folded];
}

Set<String> parseStaffPermissionTokens(Object? raw) {
  final tokens = <String>{};
  for (final item in _permissionItems(raw)) {
    final canonical = normalizeStaffPermissionToken(item);
    if (canonical != null) tokens.add(canonical);
  }
  return tokens;
}

bool staffMayPerform({
  required bool isOwner,
  required String status,
  required Object? permissions,
  required StaffOperation operation,
}) {
  if (isOwner) return true;
  if (status.trim().toLowerCase() != 'active') return false;
  if (operation == StaffOperation.manageStaff) return false;

  final granted = parseStaffPermissionTokens(permissions);
  if (granted.contains('fullAccess')) return true;

  switch (operation) {
    case StaffOperation.viewOrders:
      return granted.contains('viewOrders') || granted.contains('manageOrders');
    case StaffOperation.manageOrders:
    case StaffOperation.collectPayment:
      return granted.contains('manageOrders');
    case StaffOperation.manageProducts:
      return granted.contains('manageProducts');
    case StaffOperation.viewFinance:
      return granted.contains('viewFinance');
    case StaffOperation.manageCampaigns:
      return granted.contains('manageCampaigns');
    case StaffOperation.manageSupport:
      return granted.contains('manageSupport');
    case StaffOperation.manageStoreProfile:
      return granted.contains('manageStoreProfile');
    case StaffOperation.manageStaff:
      return false;
  }
}

/// Seller-panel module ids (`SellerModule.name`). Team management stays with
/// the owner even when Tam Erişim is granted.
bool staffMayOpenModule({
  required String module,
  required String status,
  required Object? permissions,
}) {
  switch (module) {
    case 'dashboard':
    case 'finance':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.viewFinance,
      );
    case 'products':
    case 'collections':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.manageProducts,
      );
    case 'orders':
    case 'garson':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.viewOrders,
      );
    case 'system':
    case 'store':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.manageStoreProfile,
      );
    case 'campaigns':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.manageCampaigns,
      );
    case 'reviews':
    case 'support':
      return staffMayPerform(
        isOwner: false,
        status: status,
        permissions: permissions,
        operation: StaffOperation.manageSupport,
      );
    case 'team':
      return false;
    default:
      return false;
  }
}

const Map<String, String> _canonicalStaffPermissions = <String, String>{
  'fullaccess': 'fullAccess',
  'tamerisim': 'fullAccess',
  'tam_erisim': 'fullAccess',
  'tam erisim': 'fullAccess',
  'tam erişim': 'fullAccess',
  'manageproducts': 'manageProducts',
  'vieworders': 'viewOrders',
  'manageorders': 'manageOrders',
  'managecampaigns': 'manageCampaigns',
  'viewfinance': 'viewFinance',
  'managesupport': 'manageSupport',
  'managestoreprofile': 'manageStoreProfile',
};

String _foldPermissionToken(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.trim().runes) {
    final char = String.fromCharCode(rune);
    if (char == 'İ' || char == 'I' || char == 'ı') {
      buffer.write('i');
    } else {
      buffer.write(char.toLowerCase());
    }
  }
  return buffer.toString().replaceAll('\u0307', '');
}

Iterable<Object?> _permissionItems(Object? raw) {
  if (raw is List) return raw;
  if (raw is Set) return raw;
  if (raw is String && raw.trim().isNotEmpty) return <Object?>[raw];
  return const <Object?>[];
}
