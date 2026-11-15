import 'dart:async';

/// Pure staff-login decisions. Auth and membership stay in [AuthService].
class StaffLoginAccessDecision {
  const StaffLoginAccessDecision({
    this.role,
    this.storeId,
    this.rejectionMessage,
  });

  /// `waiter` or `seller` (sub-admin uses the seller panel).
  final String? role;
  final String? storeId;
  final String? rejectionMessage;

  bool get isActiveStaff =>
      storeId != null && storeId!.isNotEmpty && role != null;
}

StaffLoginAccessDecision resolveStaffLoginAccess({
  required bool managedStaffFlag,
  required Map<String, dynamic>? access,
  required String diagnosticContext,
}) {
  final storeId = access?['store_id']?.toString().trim() ?? '';
  if (storeId.isNotEmpty) {
    final staffRole = access?['staff_role']?.toString();
    return StaffLoginAccessDecision(
      role: staffRole == 'waiter' ? 'waiter' : 'seller',
      storeId: storeId,
    );
  }
  final sellerSurface =
      diagnosticContext == 'seller_login' || diagnosticContext == 'admin_login';
  if (managedStaffFlag && sellerSurface) {
    return const StaffLoginAccessDecision(
      rejectionMessage:
          'Personel üyeliği bulunamadı veya hesap pasif. İşletme sahibi üyeliği kontrol etmeli.',
    );
  }
  return const StaffLoginAccessDecision();
}

/// In-memory lockout. Passwords are never stored.
class StaffLoginThrottle {
  StaffLoginThrottle({
    this.limit = 5,
    this.lockout = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int limit;
  final Duration lockout;
  final DateTime Function() _clock;
  int _failures = 0;
  DateTime? _lockedUntil;

  String? rejection() {
    final until = _lockedUntil;
    if (until == null) return null;
    final now = _clock();
    if (!now.isBefore(until)) {
      _lockedUntil = null;
      return null;
    }
    final seconds = until.difference(now).inSeconds + 1;
    return 'Çok fazla başarısız giriş. $seconds saniye sonra tekrar deneyin.';
  }

  void recordFailure() {
    if (rejection() != null) return;
    _failures += 1;
    if (_failures >= limit) {
      _lockedUntil = _clock().add(lockout);
      _failures = 0;
    }
  }

  void recordSuccess() {
    _failures = 0;
    _lockedUntil = null;
  }
}

class StaffAccountLinkDecision {
  const StaffAccountLinkDecision({
    required this.allowed,
    required this.linkAvailable,
  });

  final bool allowed;
  final bool linkAvailable;
}

/// Email, role, and an empty membership list are not a pairing proof.
StaffAccountLinkDecision decideStaffAccountLink({
  required bool confirmLink,
  required String ownerStoreId,
  required String? provisionedByStoreId,
  required bool managedStaff,
  required bool foreignMembership,
  required bool ownsStore,
}) {
  final storeId = ownerStoreId.trim();
  final proof = managedStaff &&
      storeId.isNotEmpty &&
      provisionedByStoreId != null &&
      provisionedByStoreId.trim().isNotEmpty &&
      provisionedByStoreId.trim() == storeId &&
      !foreignMembership &&
      !ownsStore;
  if (!proof) {
    return const StaffAccountLinkDecision(allowed: false, linkAvailable: false);
  }
  if (!confirmLink) {
    return const StaffAccountLinkDecision(allowed: false, linkAvailable: true);
  }
  return const StaffAccountLinkDecision(allowed: true, linkAvailable: true);
}

class StaffMenuGate {
  const StaffMenuGate.owner()
    : restrict = false,
      revoked = false,
      role = null,
      permissions = const <String>{},
      jobTitle = null,
      visibleModules = null;

  const StaffMenuGate.staff({
    required this.role,
    required this.permissions,
    this.jobTitle,
    this.visibleModules,
  }) : restrict = true,
       revoked = false;

  const StaffMenuGate.revoked()
    : restrict = true,
      revoked = true,
      role = null,
      permissions = const <String>{},
      jobTitle = null,
      visibleModules = null;

  final bool restrict;
  final bool revoked;
  final String? role;
  final Set<String> permissions;

  /// Display label. Null keeps the older permission-derived menu.
  final String? jobTitle;
  final Set<String>? visibleModules;
}

const restaurantStaffPasswordMinLength = 8;

/// `0` means the next launch must drop the persisted Supabase session.
/// Any other value, including a missing flag, keeps that session.
bool shouldDiscardPersistedSellerSession(String? rememberFlag) =>
    rememberFlag == '0';

/// Membership store wins. A managed account without one is not the owner.
/// An owner keeps their own auth id, including before the first store row.
String? resolvedRestaurantOwnerId({
  required String? authUserId,
  required String? membershipStoreId,
  required bool managedStaff,
}) {
  final membership = membershipStoreId?.trim() ?? '';
  if (membership.isNotEmpty) return membership;
  if (managedStaff) return null;
  final auth = authUserId?.trim() ?? '';
  if (auth.isEmpty) return null;
  return auth;
}

/// Store-wide staff see every table. A branch staff member sees that branch
/// and tables that were never assigned to a branch. Another branch stays closed.
bool restaurantStaffBranchCanSeeTable({
  required String? staffBranchId,
  required String? tableBranchId,
}) {
  final staff = staffBranchId?.trim() ?? '';
  final table = tableBranchId?.trim() ?? '';
  if (staff.isEmpty || table.isEmpty) return true;
  return staff == table;
}

/// The server text is kept. Email or phone is only a legacy unbound membership
/// path and is not the explanation for every 42501.
String? restaurantWriteDenialMessage({
  required String? code,
  required String details,
}) {
  final text = details.toLowerCase();
  if (text.contains('bu şubede işlem yetkiniz yok')) {
    return 'Bu masanın şubesinde işlem yetkiniz yok. Şubesiz masalar bu '
        'işletmenin aktif personeline açıktır. Başka şubenin masası kapalıdır.';
  }
  if (text.contains('bu restoran için işlem yetkiniz yok') ||
      text.contains('personel sipariş yetkisi yok')) {
    return 'Bu restoranda sipariş yönetme yetkisi yok. manageOrders izni '
        'kapalı olabilir. E-posta veya telefon eşleşmesi bu hatayı açıklamaz.';
  }
  if (code == '57014' ||
      text.contains('57014') ||
      text.contains('statement timeout') ||
      text.contains('canceling statement')) {
    return 'Aktif adisyon sorgusu zaman aşımına uğradı (57014). '
        'Bu sonuç boş masa olarak gösterilmez.';
  }
  if (code == '42501' ||
      text.contains('permission denied') ||
      text.contains('row-level security')) {
    final detail = details.trim();
    if (detail.isEmpty) {
      return 'Sunucu bu işlem için yetki vermedi.';
    }
    return 'Sunucu bu işlem için yetki vermedi: $detail';
  }
  return null;
}

/// Same confirmation keeps one server key. A new amount or method is a new key.
String stableStaffPaymentRequestId({
  required int tableNumber,
  required String sessionKey,
  required double amount,
  required String method,
  required String attemptToken,
}) {
  final cents = (amount * 100).round();
  return 'pay-$tableNumber-$sessionKey-$cents-$method-$attemptToken';
}

/// A failed close or transfer RPC never continues as a direct `table_orders`
/// write. Permission denial, a missing function, and business-rule errors stop.
bool directTableOrderWriteAllowedAfterRpcFailure({
  String? code,
  String message = '',
}) {
  if (code == '42501') return false;
  if (code == 'PGRST202') return false;
  if (message.trim().isNotEmpty) return false;
  return false;
}

/// Owner keeps every operation. A permission is open only when it is stored
/// on the active membership. manageOrders does not imply payment or transfer.
bool staffOperationAllowed({
  required bool isOwner,
  required bool activeMembership,
  required bool mustChangePassword,
  required Set<String> permissions,
  required String operation,
}) {
  if (mustChangePassword) return false;
  if (isOwner) return true;
  if (!activeMembership) return false;
  return permissions.contains(operation);
}

/// Owners and staff created before the password flag keep working.
/// Only a managed account that still must change its password is blocked.
bool restaurantPermissionAllowed({
  required bool isOwner,
  required bool activeMembership,
  required bool hasPermission,
  required bool managedStaff,
  required bool mustChangePassword,
}) {
  if (managedStaff && mustChangePassword) return false;
  if (isOwner) return true;
  return activeMembership && hasPermission;
}

/// Waiters stay on the floor screens. Finance and store setup stay closed.
bool waiterMayOpenScreen(String screen) {
  switch (screen.trim()) {
    case 'tables':
    case 'orders':
    case 'local_status':
      return true;
    default:
      return false;
  }
}

class LanOrderSubmitDecision {
  const LanOrderSubmitDecision({
    required this.showSuccess,
    this.error,
  });

  final bool showSuccess;
  final String? error;
}

/// A paired waiter may see success only after the host has stored the order.
LanOrderSubmitDecision decideLanOrderSubmit({
  required bool paired,
  required bool hostReachable,
  required bool hostSaved,
}) {
  if (!paired) {
    return const LanOrderSubmitDecision(showSuccess: false);
  }
  if (!hostReachable) {
    return const LanOrderSubmitDecision(
      showSuccess: false,
      error: 'Ana bilgisayar kapalı veya yerel ağa ulaşılamıyor.',
    );
  }
  if (!hostSaved) {
    return const LanOrderSubmitDecision(
      showSuccess: false,
      error: 'Sipariş kalıcı kaydedilmedi.',
    );
  }
  return const LanOrderSubmitDecision(showSuccess: true);
}

/// What the waiter device may say about a ticket. Forwarded is not printed.
String lanTicketStatusText(String? printStatus) {
  switch ((printStatus ?? '').trim()) {
    case 'uncertain':
      return 'Sipariş kaydedildi. Baskı belirsiz; otomatik tekrar yok.';
    case 'failed':
    case 'not_sent':
      return 'Sipariş kaydedildi. Fiş yazıcıya iletilmedi.';
    case 'forwarded':
      return 'Sipariş kaydedildi. Fiş yazıcıya iletildi; basıldığı onaylanmadı.';
    default:
      return 'Sipariş kaydedildi. Fiş bu telefonda basılmaz.';
  }
}

/// Locally printed or uncertain tickets must not be sent to the printer again
/// when the order is replayed to Supabase.
bool localPrintShouldSkipCloudReprint(String printStatus) {
  final status = printStatus.trim();
  return status == 'printed' || status == 'forwarded' || status == 'uncertain';
}

String localPrintStatusFromDispatch({
  required bool physicallyDispatched,
  String? error,
}) {
  if (physicallyDispatched) return 'printed';
  final text = (error ?? '').toLowerCase();
  if (text.contains('timeout') ||
      text.contains('uncertain') ||
      text.contains('belirsiz')) {
    return 'uncertain';
  }
  return 'failed';
}

enum StaffProbeKind { active, rejected, unreachable }

/// A staff check result. Network failure is never represented as rejection.
class StaffProbe {
  const StaffProbe(this.kind, {this.reason = ''});

  final StaffProbeKind kind;
  final String reason;

  bool get isActive => kind == StaffProbeKind.active;
}

bool staffProbeErrorIsUnreachable(Object error) {
  if (error is TimeoutException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('Connection closed') ||
      text.contains('TimeoutException') ||
      text.contains('HandshakeException');
}

/// A paired tablet uses the main computer as the only floor authority, even
/// when the cloud answers. The seller machine keeps the cloud path so the
/// existing kitchen dispatch is not replaced. Neither path is a successful
/// order by itself.
String restaurantOrderRoute({
  required bool supabaseReachable,
  required bool lanReachable,
  required bool lanIdentityVerified,
  bool pairedTablet = false,
}) {
  if (pairedTablet && lanReachable && lanIdentityVerified) return 'lan';
  if (supabaseReachable) return 'cloud';
  if (lanReachable && lanIdentityVerified) return 'lan';
  return 'refuse';
}
