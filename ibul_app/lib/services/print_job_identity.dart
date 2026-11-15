/// Shared print identity. The SQL trigger uses the same field order:
/// restaurant | order key | revision | station | job type.
/// Order key is local_order_id when the order was born offline, otherwise
/// the cloud order id. Revision 1 and revision 2 are different jobs.
String buildPrintJobIdentity({
  required String restaurantId,
  required String orderKey,
  String revision = '1',
  String stationId = '',
  String jobType = 'new_order',
}) {
  final safeRevision = revision.trim().isEmpty ? '1' : revision.trim();
  final safeJob = jobType.trim().isEmpty ? 'new_order' : jobType.trim();
  return <String>[
    restaurantId.trim(),
    orderKey.trim(),
    safeRevision,
    stationId.trim(),
    safeJob,
  ].join('|');
}

enum PrintReconcile { allowPrint, skipPrinted, holdUncertain, holdInconsistent }

class PrintJobLedger {
  PrintJobLedger._();

  static final Map<String, String> _byIdentity = <String, String>{};
  static final Map<String, String> _byOrder = <String, String>{};

  static void remember({
    required String identity,
    required String orderKey,
    required String printStatus,
  }) {
    final status = printStatus.trim();
    if (status != 'printed' && status != 'uncertain') return;
    final key = identity.trim();
    final order = orderKey.trim();
    if (key.isEmpty || order.isEmpty) return;
    _byIdentity[key] = status;
    final previous = _byOrder[order];
    if (previous == 'printed') return;
    _byOrder[order] = status;
  }

  static PrintReconcile reconcile({
    required String identity,
    required String orderKey,
  }) {
    final exact = _byIdentity[identity.trim()];
    if (exact == 'printed') return PrintReconcile.skipPrinted;
    if (exact == 'uncertain') return PrintReconcile.holdUncertain;
    final orderStatus = _byOrder[orderKey.trim()];
    if (orderStatus == 'printed' || orderStatus == 'uncertain') {
      final parts = identity.split('|');
      final station = parts.length >= 4 ? parts[3].trim() : '';
      if (station.isEmpty) return PrintReconcile.holdInconsistent;
    }
    return PrintReconcile.allowPrint;
  }

  static void clearForTest() {
    _byIdentity.clear();
    _byOrder.clear();
  }
}
