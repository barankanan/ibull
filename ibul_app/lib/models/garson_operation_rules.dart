/// Garson Operasyon Kural Seti
///
/// Bu dosya, restoran garson akışındaki her kritik işlem için
/// hangi sipariş statüsünde ne yapılabileceğini tek yerden tanımlar.
///
/// Kural hiyerarşisi:
///   status → UndoPolicy, EditPolicy, TransferPolicy
///
/// Kullanım:
///   final rules = GarsonOperationRules.forStatus('sent');
///   if (rules.canUndo) { ... }
library;

/// Normalised set of statuses used throughout the garson flow.
///
/// The DB may store values like 'done', 'kitchen' etc. — those are mapped
/// to one of the canonical values below before any rule lookup.
abstract final class GarsonOrderStatus {
  static const draft = 'draft';
  static const waiting = 'waiting';
  static const sent = 'sent';
  static const preparing = 'preparing';
  static const ready = 'ready';
  static const served = 'served';
  static const closed = 'closed';
  static const completed = 'completed';

  /// Normalise a raw DB value to one of the canonical status keys.
  static String normalise(String? raw) {
    final v = (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s\-]+'), '_');
    switch (v) {
      case 'done':
      case 'kitchen':
        return sent;
      case 'new':
        return waiting;
      default:
        return v.isEmpty ? sent : v;
    }
  }
}

/// Full operation permission set for a given order status.
class GarsonOperationRules {
  const GarsonOperationRules._({
    required this.status,
    required this.canUndo,
    required this.canEdit,
    required this.canResend,
    required this.canTransfer,
    required this.showUndoWarning,
    required this.showEditWarning,
    required this.editNote,
  });

  /// The canonical status these rules apply to.
  final String status;

  // ── UNDO ────────────────────────────────────────────────────────────────
  /// Undo is allowed within the 30-second window after submit.
  ///
  /// Rule: undo is always allowed immediately after *any* submit action,
  /// regardless of status — the 30-second TTL in [GarsonUndoController]
  /// is the only gate. Once the TTL expires undo is impossible.
  ///
  /// Exceptions (canUndo = false at rule level, TTL aside):
  ///   - 'closed'    — table already paid and archived; undo has no target.
  ///   - 'completed' — same as closed.
  ///   - 'served'    — order delivered; undo would re-open a served item.
  final bool canUndo;

  /// When true the undo banner should show a yellow "⚠ Mutfakta" warning
  /// because the order may already have been seen by kitchen staff.
  final bool showUndoWarning;

  // ── EDIT ────────────────────────────────────────────────────────────────
  /// The waiter may load this order into the draft editor.
  final bool canEdit;

  /// When true the edit form shows a yellow banner explaining the order is
  /// already in progress (preparing / ready).
  final bool showEditWarning;

  /// Human-readable note shown in the edit form header and stored as
  /// `last_edit_note` on the revised order row.
  final String editNote;

  /// When true the updated order is re-dispatched to the kitchen.
  final bool canResend;

  // ── TRANSFER ────────────────────────────────────────────────────────────
  /// The order may be moved to another table via [transferTableOrders].
  ///
  /// Rule:
  ///   - 'draft' / 'waiting' / 'sent' / 'preparing' / 'ready' → allowed.
  ///   - 'served' / 'closed' / 'completed' → blocked (order is finalised).
  final bool canTransfer;

  // ── FACTORY ─────────────────────────────────────────────────────────────
  /// Returns the rule set for [rawStatus], normalising it first.
  factory GarsonOperationRules.forStatus(String? rawStatus) {
    return _byStatus[GarsonOrderStatus.normalise(rawStatus)] ?? _default;
  }

  // ── INTERNAL REGISTRY ───────────────────────────────────────────────────
  static const _draft = GarsonOperationRules._(
    status: GarsonOrderStatus.draft,
    canUndo: true,
    showUndoWarning: false,
    canEdit: true,
    showEditWarning: false,
    canResend: false,
    canTransfer: true,
    editNote: 'Bu sipariş mutfağa iletilmeden önce tamamen düzenlenebilir.',
  );

  static const _waiting = GarsonOperationRules._(
    status: GarsonOrderStatus.waiting,
    canUndo: true,
    showUndoWarning: false,
    canEdit: true,
    showEditWarning: false,
    canResend: false,
    canTransfer: true,
    editNote: 'Bu sipariş henüz mutfağa iletilmedi. Serbestçe düzenlenebilir.',
  );

  static const _sent = GarsonOperationRules._(
    status: GarsonOrderStatus.sent,
    canUndo: true,
    showUndoWarning: true,
    canEdit: true,
    showEditWarning: false,
    canResend: true,
    canTransfer: true,
    editNote:
        'Bu sipariş düzenlenebilir. Değişiklikler aynı siparişe işlenir ve mutfağa tekrar iletilir.',
  );

  static const _preparing = GarsonOperationRules._(
    status: GarsonOrderStatus.preparing,
    canUndo: true,
    showUndoWarning: true,
    canEdit: true,
    showEditWarning: true,
    canResend: true,
    canTransfer: true,
    editNote:
        'Bu sipariş hazırlanıyor. Değişiklikler mutfağa tekrar iletilecek — '
        'mutfak ekibini haberdar edin.',
  );

  static const _ready = GarsonOperationRules._(
    status: GarsonOrderStatus.ready,
    canUndo: false,
    showUndoWarning: false,
    canEdit: true,
    showEditWarning: true,
    canResend: true,
    canTransfer: true,
    editNote:
        'Bu sipariş hazır bekliyor. Değişiklik yapılırsa mutfağa tekrar bildirim gönderilir.',
  );

  static const _served = GarsonOperationRules._(
    status: GarsonOrderStatus.served,
    canUndo: false,
    showUndoWarning: false,
    canEdit: false,
    showEditWarning: false,
    canResend: false,
    canTransfer: false,
    editNote: 'Bu sipariş servis edildi ve artık düzenlenemez.',
  );

  static const _closed = GarsonOperationRules._(
    status: GarsonOrderStatus.closed,
    canUndo: false,
    showUndoWarning: false,
    canEdit: false,
    showEditWarning: false,
    canResend: false,
    canTransfer: false,
    editNote: 'Bu sipariş kapatıldı ve arşivlendi. Düzenlenemez.',
  );

  static const _default = GarsonOperationRules._(
    status: 'unknown',
    canUndo: true,
    showUndoWarning: true,
    canEdit: true,
    showEditWarning: true,
    canResend: true,
    canTransfer: true,
    editNote:
        'Bu sipariş özel bir durumda. Değişiklikler mutfağa tekrar iletilecek.',
  );

  static const Map<String, GarsonOperationRules> _byStatus = {
    GarsonOrderStatus.draft: _draft,
    GarsonOrderStatus.waiting: _waiting,
    GarsonOrderStatus.sent: _sent,
    GarsonOrderStatus.preparing: _preparing,
    GarsonOrderStatus.ready: _ready,
    GarsonOrderStatus.served: _served,
    GarsonOrderStatus.closed: _closed,
    GarsonOrderStatus.completed: _closed, // same rules as closed
  };
}

// ────────────────────────────────────────────────────────────────────────────
// Kitchen / Printer dispatch policy
// ────────────────────────────────────────────────────────────────────────────

/// Governs **how** print jobs are dispatched when a garson submits or revises
/// an order.
///
/// ### Relationship with [GarsonOperationRules]
///
/// | Concern | Class |
/// |---|---|
/// | **Whether** an action is allowed (canEdit, canResend, canTransfer …) | `GarsonOperationRules` |
/// | **How** the kitchen print is performed (full / diff / reprint) | `KitchenPrintPolicy` |
///
/// ### Complete dispatch behavior matrix
///
/// | Scenario | Gate | Dispatch type | Note constant |
/// |---|---|---|---|
/// | New order (draft/waiting) | `canResend == false` → first submit always prints | `_dispatchKitchenPrintJobs` (full ticket) | — |
/// | Edit: unprinted (draft/waiting) | `shouldDispatchFullTicket == true` | `_dispatchKitchenPrintJobs` (full ticket) | — |
/// | Edit: additions only (sent/preparing/ready) | `canResend == true` | `_dispatchKitchenAdditions` | `addItemsNote` |
/// | Edit: removals only (sent/preparing/ready) | `canResend == true` | `_dispatchKitchenRemovals` | `removeItemsNote` |
/// | Edit: no net diff (sent/preparing/ready) | `canResend == true` | `_dispatchKitchenReprintJobs` | `reprintNote` |
/// | Manual reprint from ops sheet | `canReprint == true` | `_dispatchKitchenReprintJobs` | `reprintNote` |
/// | Edit: served/closed/completed | `canResend == false` → blocked by [GarsonOperationRules] | — | — |
///
/// ### Decision tree (edit path)
/// ```
/// GarsonOperationRules.forStatus(status).canResend?
///   ├─ NO  → no print dispatch at all
///   └─ YES → shouldDispatchFullTicket(status)?
///               ├─ YES (draft/waiting) → full ticket
///               └─ NO  (sent/preparing/ready)
///                     ├─ additions? → addItemsNote diff
///                     ├─ removals?  → removeItemsNote diff
///                     └─ no change? → reprintNote full
/// ```
///
/// The note constants are stored as `last_edit_note` on the revised row and
/// shown in [TableHistoryScreen] to label revision intent.
abstract final class KitchenPrintPolicy {
  /// Returns `true` when the full ticket must be dispatched (order has NOT
  /// yet been seen by the kitchen — `draft` or `waiting` status).
  static bool shouldDispatchFullTicket(String? previousStatus) {
    final s = GarsonOrderStatus.normalise(previousStatus);
    return s == GarsonOrderStatus.draft || s == GarsonOrderStatus.waiting;
  }

  /// Returns `true` when the order can be manually reprinted from the ops
  /// sheet (i.e., it has already been sent to the kitchen and can be
  /// re-dispatched without a diff).
  ///
  /// Equivalent to [GarsonOperationRules.canResend] for a single order.
  static bool canReprint(String? status) =>
      GarsonOperationRules.forStatus(status).canResend;

  // ── Print note constants ──────────────────────────────────────────────────
  /// Note appended to "add items" diff print jobs.
  static const String addItemsNote = 'Sipariş revizyonu • eklenen kalemler';

  /// Note appended to "remove items" diff print jobs.
  static const String removeItemsNote = 'Sipariş revizyonu • çıkarılan kalemler';

  /// Note used when nothing changed in the diff but a reprint is forced.
  static const String reprintNote = 'Sipariş tekrar iletimi';
}

// ────────────────────────────────────────────────────────────────────────────
// Table-level policy (aggregate across all orders on a table)
// ────────────────────────────────────────────────────────────────────────────

/// Computes table-level action permissions by aggregating the per-order
/// [GarsonOperationRules] across all orders on a table.
///
/// Used in `_MobileGarsonTableFlowPageState._showOperationsSheet` so the
/// action-sheet buttons are gated by the same rules as per-order UI.
abstract final class TableLevelPolicy {
  /// A table can be **transferred** if at least one order has
  /// [GarsonOperationRules.canTransfer] == `true`.
  ///
  /// Typically false only when every order is already `served`, `closed`, or
  /// `completed` — which should not occur on an active table.
  static bool canTransfer(Iterable<String?> orderStatuses) =>
      orderStatuses.any(
        (s) => GarsonOperationRules.forStatus(s).canTransfer,
      );

  /// A table can be **paid** if at least one order is not in a terminal state
  /// (`closed` / `completed`).
  static bool canPay(Iterable<String?> orderStatuses) => orderStatuses.any((s) {
        final n = GarsonOrderStatus.normalise(s);
        return n != GarsonOrderStatus.closed &&
            n != GarsonOrderStatus.completed;
      });

  /// A table can be **reprinted to the kitchen** if at least one order is
  /// in a status that [KitchenPrintPolicy.canReprint] allows (i.e.,
  /// `sent`, `preparing`, or `ready`).
  static bool canReprint(Iterable<String?> orderStatuses) =>
      orderStatuses.any(KitchenPrintPolicy.canReprint);

  // ── Action tile subtitles ─────────────────────────────────────────────────
  static const String transferEnabled =
      'Siparişleri başka bir masaya taşı.';
  static const String transferBlocked =
      'Masada aktarılabilir sipariş yok (servis edilmiş/kapalı).';

  static const String payEnabled =
      'Kısmi ödeme kaydet veya masayı kapat.';
  static const String payBlocked =
      'Aktif sipariş olmadan ödeme alınamaz.';

  static const String splitEnabled =
      'Kişi sayısına göre hesap özetini göster.';
  static const String splitBlocked =
      'Aktif sipariş olmadan hesap bölünemez.';

  static const String closeEnabled =
      'Ödemeyi al ve masayı kapat.';
  static const String closeBlocked =
      'Aktif sipariş olmadan hesap kesilemez.';

  static const String reprintEnabled =
      'Aktif siparişleri mutfak kuyruğuna yeniden yolla.';
  static const String reprintBlocked =
      'Yeniden yazdırmak için aktif mutfak siparişi gerekli.';

  static const String adisyonEnabled =
      'Masa adisyonunu yazıcıya gönder.';
  static const String adisyonBlocked =
      'Yazdırmak için en az bir aktif sipariş gerekli.';
}

// ────────────────────────────────────────────────────────────────────────────
// Payload validation helpers (used by service layer / tests)
// ────────────────────────────────────────────────────────────────────────────

/// Validates a `table_orders` insert/update payload and returns a list of
/// human-readable error strings (empty = valid).
///
/// Only applies structural rules that can be checked without DB access.
/// Does NOT check RLS, uniqueness or foreign key constraints.
List<String> validateTableOrderPayload(Map<String, dynamic> payload) {
  final errors = <String>[];

  final sellerId = payload['seller_id']?.toString().trim() ?? '';
  if (sellerId.isEmpty) errors.add('seller_id boş olamaz');

  final tableNumber = payload['table_number'];
  final parsedTable = tableNumber is int
      ? tableNumber
      : int.tryParse(tableNumber?.toString() ?? '');
  if (parsedTable == null || parsedTable <= 0) {
    errors.add('table_number geçerli bir pozitif tam sayı olmalı');
  }

  final rawItems = payload['items'];
  if (rawItems is! List || rawItems.isEmpty) {
    errors.add('items en az bir kalem içermeli');
  } else {
    for (var i = 0; i < rawItems.length; i++) {
      final item = rawItems[i];
      if (item is! Map) {
        errors.add('items[$i]: harita değil');
        continue;
      }
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) errors.add('items[$i]: name boş olamaz');
      final price = item['price'];
      if (price is! num || price < 0) {
        errors.add('items[$i]: price ≥ 0 olmalı');
      }
      final qty = item['quantity'];
      final parsedQty = qty is int ? qty : int.tryParse(qty?.toString() ?? '');
      if (parsedQty == null || parsedQty <= 0) {
        errors.add('items[$i]: quantity ≥ 1 olmalı');
      }
    }
  }

  return errors;
}

/// Validates a `table_payments` insert payload.
List<String> validateTablePaymentPayload(Map<String, dynamic> payload) {
  final errors = <String>[];

  final sellerId = payload['seller_id']?.toString().trim() ?? '';
  if (sellerId.isEmpty) errors.add('seller_id boş olamaz');

  final tableNumber = payload['table_number'];
  final parsedTable = tableNumber is int
      ? tableNumber
      : int.tryParse(tableNumber?.toString() ?? '');
  if (parsedTable == null || parsedTable <= 0) {
    errors.add('table_number geçerli bir pozitif tam sayı olmalı');
  }

  final sessionKey = payload['session_key']?.toString().trim() ?? '';
  if (sessionKey.isEmpty) errors.add('session_key boş olamaz');

  final amount = payload['amount'];
  if (amount is! num || amount <= 0) {
    errors.add('amount > 0 olmalı');
  }

  final method = payload['method']?.toString().trim() ?? '';
  const validMethods = {'cash', 'card', 'online', 'mixed', 'complimentary', 'other'};
  if (!validMethods.contains(method)) {
    errors.add('method geçersiz: "$method". Geçerli: ${validMethods.join(", ")}');
  }

  return errors;
}
