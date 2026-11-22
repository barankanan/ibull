/// One rule for the printer identity carried by a `print_jobs` row.
///
/// The database rejects a job whose `payload.printer_id` differs from the
/// `printer_id` column (`Baskı payload kimliği uyuşmuyor: printer_id`). The
/// canonical printer identity is the saved printer record id (a UUID). These
/// helpers keep the payload and the column on that one id; they never relax
/// the server check.
library;

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _text(Object? value) => value?.toString().trim() ?? '';

bool isPrinterRecordUuid(Object? value) => _uuidPattern.hasMatch(_text(value));

/// The saved printer record id named by [payload], or null when it names none.
String? canonicalPrinterRecordId(Map<String, dynamic> payload) {
  final record = _text(payload['printer_record_id']);
  if (isPrinterRecordUuid(record)) return record;
  final direct = _text(payload['printer_id']);
  if (isPrinterRecordUuid(direct)) return direct;
  return null;
}

/// Payload for an RPC that stores the job with an empty `printer_id` column
/// (receipt and history-reprint jobs: the print center picks the printer when
/// it claims the job). The reserved `printer_id` key is taken out so the
/// payload cannot contradict the empty column; the requested printer stays
/// available as `printer_record_id` (saved record) or `bridge_printer_id`
/// (a local queue id that is not a saved record).
Map<String, dynamic> payloadForUnboundPrinterJob(Map<String, dynamic> payload) {
  final next = Map<String, dynamic>.from(payload);
  final direct = _text(next.remove('printer_id'));
  if (direct.isEmpty) return next;
  if (isPrinterRecordUuid(direct)) {
    if (!isPrinterRecordUuid(next['printer_record_id'])) {
      next['printer_record_id'] = direct;
    }
  } else if (_text(next['bridge_printer_id']).isEmpty) {
    next['bridge_printer_id'] = direct;
  }
  return next;
}

/// Column values for a status update that also writes [payload]. When the
/// payload names a saved printer, the `printer_id` column and
/// `payload.printer_id` are written as that same id. A payload id that is not
/// a saved record is moved to `bridge_printer_id` so it never reaches the
/// reserved key. A null payload writes nothing.
Map<String, dynamic> printJobIdentityUpdate(Map<String, dynamic>? payload) {
  if (payload == null) return const <String, dynamic>{};
  final next = Map<String, dynamic>.from(payload);
  final canonical = canonicalPrinterRecordId(next);
  final direct = _text(next['printer_id']);
  if (direct.isNotEmpty && direct != canonical) {
    if (!isPrinterRecordUuid(direct) &&
        _text(next['bridge_printer_id']).isEmpty) {
      next['bridge_printer_id'] = direct;
    }
    next.remove('printer_id');
  }
  if (canonical == null) {
    return <String, dynamic>{'payload': next};
  }
  next['printer_id'] = canonical;
  next['printer_record_id'] = canonical;
  return <String, dynamic>{'printer_id': canonical, 'payload': next};
}
