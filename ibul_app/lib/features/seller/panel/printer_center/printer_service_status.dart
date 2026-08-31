import 'package:flutter/material.dart';

Color printerServiceStatusColor(bool? isAvailable) {
  return isAvailable == true
      ? const Color(0xFF16A34A)
      : isAvailable == false
      ? const Color(0xFFDC2626)
      : const Color(0xFF6B7280);
}

String printerServiceTimeAgoShort(DateTime past, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(past);
  if (diff.inSeconds < 60) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  return '${diff.inDays} gün önce';
}

class PrinterServiceSnapshot {
  const PrinterServiceSnapshot({
    required this.isAvailable,
    required this.label,
    required this.message,
    this.lastSuccessAgo,
    this.refreshing = false,
    this.testing = false,
  });

  final bool? isAvailable;
  final String label;
  final String message;
  final String? lastSuccessAgo;
  final bool refreshing;
  final bool testing;

  bool get isBusy => refreshing || testing;
  bool get isChecking => isAvailable == null;
  Color get statusColor => printerServiceStatusColor(isAvailable);
}
