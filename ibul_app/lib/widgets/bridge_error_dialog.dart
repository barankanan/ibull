import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/local_print_service.dart';

class BridgeStructuredError {
  const BridgeStructuredError({
    required this.errorCode,
    required this.message,
    required this.suggestedAction,
    required this.activeJobIds,
    required this.queueStatus,
    required this.queueMessage,
    required this.lpCommand,
    required this.lpOutput,
    required this.raw,
  });

  final String errorCode;
  final String message;
  final String suggestedAction;
  final List<String> activeJobIds;
  final String queueStatus;
  final String queueMessage;
  final String lpCommand;
  final String lpOutput;
  final Map<String, dynamic> raw;

  bool get canClearQueue => suggestedAction == 'clear_queue';

  static BridgeStructuredError? tryParse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final code = (raw['errorCode'] ?? raw['error_code'])?.toString().trim() ?? '';
    if (code.isEmpty) return null;
    final suggested =
        (raw['suggested_action'] ?? raw['suggestedAction'])?.toString().trim() ??
            '';
    final jobsRaw = raw['active_job_ids'] ?? raw['activeJobIds'];
    final jobs = jobsRaw is List
        ? jobsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
    final queueStatus = (raw['queue_status'] ??
                raw['queueStatus'] ??
                raw['queue_status_snapshot'])
            ?.toString()
            .trim() ??
        '';
    final queueMessage =
        (raw['queue_message'] ?? raw['queueMessage'])?.toString().trim() ?? '';
    final lpCommand = (raw['lp_command'] ?? raw['lpCommand'])?.toString().trim() ?? '';
    final lpOutput = (raw['lp_output'] ?? raw['lpOutput'])?.toString().trim() ?? '';
    final message =
        (raw['error'] ?? raw['message'])?.toString().trim() ??
            'İşlem başarısız.';
    return BridgeStructuredError(
      errorCode: code,
      message: message,
      suggestedAction: suggested,
      activeJobIds: jobs,
      queueStatus: queueStatus,
      queueMessage: queueMessage,
      lpCommand: lpCommand,
      lpOutput: lpOutput,
      raw: raw,
    );
  }
}

Future<void> showBridgeStructuredErrorDialog(
  BuildContext context, {
  required String title,
  required String primaryMessage,
  required BridgeStructuredError error,
  required Future<void> Function() onAfterRefresh,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primaryMessage),
                if (error.activeJobIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Bekleyen işler: ${error.activeJobIds.join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Teknik detaylar'),
                  children: [
                    _kv('errorCode', error.errorCode),
                    _kv('queue_status', error.queueStatus),
                    _kv('queue_message', error.queueMessage),
                    _kv('lp_command', error.lpCommand),
                    _kv('lp_output', error.lpOutput),
                    const SizedBox(height: 8),
                    Text(
                      const JsonEncoder.withIndent('  ').convert(error.raw),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
          if (error.canClearQueue)
            FilledButton(
              onPressed: () async {
                final svc = LocalPrintService();
                Map<String, dynamic> refresh;
                try {
                  refresh = await svc.clearQueueAndRefresh();
                } finally {
                  svc.dispose();
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                // After-clear app refresh (queue/status/health/printers already re-read in bridge call).
                await onAfterRefresh();

                final queue = refresh['queue_status'];
                final normalizedQueue = queue is Map<String, dynamic>
                    ? queue
                    : (queue is Map ? Map<String, dynamic>.from(queue) : null);
                final queuePayload = normalizedQueue?['queue'];
                final queueMap = queuePayload is Map<String, dynamic>
                    ? queuePayload
                    : (queuePayload is Map
                        ? Map<String, dynamic>.from(queuePayload)
                        : null);
                final hasJob = queueMap?['queue_has_active_job'] == true;
                final ids = queueMap?['active_job_ids'];
                final jobList = ids is List ? ids.join(', ') : '';

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      hasJob
                          ? (jobList.isNotEmpty
                              ? 'Kuyruk hâlâ dolu. Bekleyen işler: $jobList'
                              : 'Kuyruk hâlâ dolu. Bekleyen işler var.')
                          : 'Kuyruk temizlendi. Tekrar test edebilirsiniz.',
                    ),
                  ),
                );
              },
              child: const Text('Kuyruğu Temizle'),
            ),
        ],
      );
    },
  );
}

Widget _kv(String k, String v) {
  if (v.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    ),
  );
}

