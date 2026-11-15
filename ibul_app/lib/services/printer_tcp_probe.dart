import 'dart:io';

import 'local_print_service.dart';

/// Opens a TCP connection and closes it. No ESC/POS bytes are written.
Future<bool> probePrinterTcp({
  required String host,
  required int port,
  Duration timeout = LocalPrintService.ethernetSocketBudget,
}) async {
  final normalized = host.trim();
  if (normalized.isEmpty || port <= 0) return false;
  Socket? socket;
  try {
    socket = await Socket.connect(normalized, port, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      await socket?.close();
    } catch (_) {}
  }
}
