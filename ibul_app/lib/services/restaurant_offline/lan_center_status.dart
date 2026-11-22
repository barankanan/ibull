import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'restaurant_offline_models.dart';

/// Is the print bridge of the center computer really answering? A configured
/// address alone proves nothing: the bridge must name itself on `/health`.
/// Never throws; any failure or a slow answer is simply "not reachable".
Future<bool> probeLanPrintBridge(
  Uri bridge, {
  Duration timeout = const Duration(milliseconds: 1500),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client
        .getUrl(bridge.replace(path: '/health', query: ''))
        .timeout(timeout);
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(text);
    return decoded is Map && decoded['service'] == 'ibul-local-print-bridge';
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value) => int.tryParse(_text(value)) ?? 0;

/// Read-only summary of the center for an authorised paired device. It holds
/// no key, password, certificate, token or collected revenue.
///
/// [tables] must already be limited to what the asking staff member may see.
/// With [branchLimited] the orders and print jobs are limited to those tables
/// too, so a branch-limited member never counts another branch.
Future<Map<String, dynamic>> buildLanCenterStatus({
  required String machineId,
  required Uri? printBridgeUri,
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> printers,
  required List<Map<String, dynamic>> stations,
  required List<Map<String, dynamic>> stationPrinters,
  required List<RestaurantLocalOrderRecord> orders,
  required List<RestaurantLocalPrintJobRecord>? printJobs,
  bool branchLimited = false,
  Future<bool> Function(Uri bridge)? probe,
  DateTime? now,
}) async {
  final visible = <int>{
    for (final row in tables)
      if (_int(row['table_number']) > 0) _int(row['table_number']),
  };
  final ownOrders = branchLimited
      ? orders.where((o) => visible.contains(o.tableNumber)).toList()
      : orders;
  final orderIds = <String>{for (final o in ownOrders) o.localOrderId};

  final bool available = printBridgeUri != null;
  final bool reachable =
      available && await (probe ?? probeLanPrintBridge)(printBridgeUri);

  final printerRows = <Map<String, dynamic>>[
    for (final row in printers)
      if (row['is_active'] != false)
        <String, dynamic>{
          'id': _text(row['id']),
          'name': _text(row['name'] ?? row['label']),
          'connection_type': _text(
            row['connection_type'] ?? row['backend'] ?? row['connection'],
          ),
          if (_text(row['ip_address'] ?? row['host']).isNotEmpty)
            'host': _text(row['ip_address'] ?? row['host']),
          if (_int(row['port']) > 0) 'port': _int(row['port']),
        },
  ];
  final printerNames = <String, String>{
    for (final p in printerRows)
      if (_text(p['id']).isNotEmpty) _text(p['id']): _text(p['name']),
  };

  final stationRows = <Map<String, dynamic>>[];
  for (final station in stations) {
    final id = _text(station['id'] ?? station['station_id']);
    if (id.isEmpty) continue;
    String? printer;
    final links = stationPrinters.where((l) => _text(l['station_id']) == id);
    final ordered = <Map<String, dynamic>>[
      ...links.where((l) => l['is_primary'] == true),
      ...links.where((l) => l['is_primary'] != true),
    ];
    for (final link in ordered) {
      final nested = link['printers'];
      final name = printerNames[_text(link['printer_id'])] ??
          (nested is Map ? _text(nested['name']) : '');
      if (name.isNotEmpty) {
        printer = name;
        break;
      }
    }
    stationRows.add(<String, dynamic>{
      'id': id,
      'name': _text(station['name']),
      'printer': printer,
    });
  }

  int count(RestaurantLocalOrderSyncStatus s) =>
      ownOrders.where((o) => o.syncStatus == s).length;
  final unsynced = ownOrders
      .where((o) => o.syncStatus != RestaurantLocalOrderSyncStatus.synced)
      .toList(growable: false);

  final jobs = printJobs == null
      ? const <RestaurantLocalPrintJobRecord>[]
      : printJobs.where((j) => !branchLimited || orderIds.contains(j.localOrderId));
  int jobCount(Set<RestaurantLocalPrintJobStatus> s) =>
      jobs.where((j) => s.contains(j.status)).length;

  return <String, dynamic>{
    'print_center': <String, dynamic>{
      'available': available,
      'reachable': reachable,
      'status_text': !available
          ? 'Ana bilgisayarda yazıcı köprüsü yok.'
          : reachable
              ? 'Yazıcı Merkezi açık.'
              : 'Yazıcı Merkezi kapalı veya yanıt vermiyor.',
    },
    'printers': printerRows,
    'stations': stationRows,
    'sync': <String, dynamic>{
      'pending': count(RestaurantLocalOrderSyncStatus.pendingSync) +
          count(RestaurantLocalOrderSyncStatus.localOnly) +
          count(RestaurantLocalOrderSyncStatus.syncing),
      'failed': count(RestaurantLocalOrderSyncStatus.syncFailed),
      'conflict': count(RestaurantLocalOrderSyncStatus.conflict),
      'synced': count(RestaurantLocalOrderSyncStatus.synced),
    },
    'print_jobs': <String, dynamic>{
      'available': printJobs != null,
      'queued': jobCount(<RestaurantLocalPrintJobStatus>{
        RestaurantLocalPrintJobStatus.created,
        RestaurantLocalPrintJobStatus.queued,
        RestaurantLocalPrintJobStatus.dispatching,
        RestaurantLocalPrintJobStatus.retrying,
      }),
      'forwarded': jobCount(<RestaurantLocalPrintJobStatus>{
        RestaurantLocalPrintJobStatus.forwarded,
      }),
      'printed': jobCount(<RestaurantLocalPrintJobStatus>{
        RestaurantLocalPrintJobStatus.printed,
      }),
      'failed': jobCount(<RestaurantLocalPrintJobStatus>{
        RestaurantLocalPrintJobStatus.failed,
      }),
      'uncertain': jobCount(<RestaurantLocalPrintJobStatus>{
        RestaurantLocalPrintJobStatus.uncertain,
      }),
    },
    // No collected revenue: the center has no trustworthy payment data.
    'overview': <String, dynamic>{
      'tables_total': visible.length,
      'tables_with_local_orders': <int>{
        for (final o in unsynced)
          if (visible.contains(o.tableNumber)) o.tableNumber,
      }.length,
      'local_orders': unsynced.length,
      'local_provisional_total': unsynced.fold<double>(
        0,
        (sum, o) => sum + o.total,
      ),
    },
    'generated_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'machine_id': machineId,
  };
}
