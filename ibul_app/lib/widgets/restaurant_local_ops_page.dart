import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/screens/seller/kitchen_print_management_page.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_cache_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/lan_staff_probe.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_control.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/services/restaurant_offline/waiter_lan_link.dart';

import 'lan_center_status_card.dart';
import 'lan_paired_devices_section.dart';
import 'restaurant_lan_waiter_page.dart';

/// Local restaurant status from the services that already own the data.
class RestaurantLocalOpsPage extends StatefulWidget {
  const RestaurantLocalOpsPage({
    super.key,
    required this.restaurantId,
    this.canManageDevices = false,
    this.staffNames = const <String, String>{},
  });

  final String restaurantId;
  final bool canManageDevices;
  final Map<String, String> staffNames;

  @override
  State<RestaurantLocalOpsPage> createState() => _RestaurantLocalOpsPageState();
}

class _RestaurantLocalOpsPageState extends State<RestaurantLocalOpsPage> {
  static const _purple = Color(0xFF7C3AED);
  bool _loading = true;
  String? _reprintNotice;
  StreamSubscription<RestaurantLocalOrderRecord>? _floorOrders;
  List<RestaurantLocalOrderRecord> _orders = const <RestaurantLocalOrderRecord>[];
  List<Map<String, dynamic>> _printers = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _floorOrders = RestaurantLanHostRegistry.ordersAccepted.stream.listen((order) {
      if (order.restaurantId == widget.restaurantId) {
        unawaited(_reload());
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _floorOrders?.cancel();
    super.dispose();
  }

  bool _centerBusy = false;
  String? _centerNotice;
  String? _pairingCode;

  Future<Map<String, dynamic>?> _readMembership(String staffId) {
    return lanStaffAuthorityReader(
      (fn, params) => Supabase.instance.client.rpc(fn, params: params),
      widget.restaurantId,
    )(staffId);
  }

  Future<void> _startCenter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu bilgisayar yerel merkez olsun mu?'),
        content: const Text(
          'Garson cihazları bu bilgisayara yerel ağdan bağlanır. Aynı restoranda '
          'yalnızca tek bilgisayar merkez olmalıdır. Güvenlik duvarı bağlantıya '
          'izin sorabilir. Bilgisayar uykuya geçerse bağlantı kesilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Merkez yap'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _centerBusy = true);
    // Same rule as Sistem > Yazıcı Merkezi: only an authorised restaurant
    // starts, and the print service comes up with the center.
    final started = await RestaurantCenterControl.start(
      restaurantId: widget.restaurantId,
      readMembership: _readMembership,
    );
    final result = started.center;
    if (!mounted) return;
    setState(() {
      _centerBusy = false;
      _centerNotice = result != null && result.isRunning
          ? 'Yerel merkez açık: ${result.address ?? ''}:${result.port}'
          : started.message;
    });
  }

  Future<void> _stopCenter() async {
    setState(() => _centerBusy = true);
    await RestaurantCenterControl.stop();
    // Same as Durdur in Yazıcı Merkezi: printing closes with the center,
    // after the ticket in progress.
    await RestaurantCenterControl.closePrintServiceSafely();
    if (!mounted) return;
    setState(() {
      _centerBusy = false;
      _pairingCode = null;
      _pairingLink = null;
      _centerNotice = 'Yerel merkez kapatıldı.';
    });
  }

  String? _pairingLink;

  /// One link (QR and text) carries where this center is, which certificate
  /// it presents and a fresh one-time code; the waiter device needs nothing
  /// else. It replaces typing an address, a fingerprint and a code.
  Future<void> _issueCode() async {
    final host = RestaurantLanHostRegistry.current;
    if (host == null || !host.listening) return;
    final link = await host.issuePairingLink();
    if (!mounted) return;
    setState(() {
      _pairingLink = link;
      _pairingCode = link == null ? host.issuePairingCode().code : null;
    });
  }

  Future<void> _reload() async {
    final orders = await RestaurantLocalOrderQueueService().list(
      widget.restaurantId,
    );
    final cache = await RestaurantLocalCacheService().read(widget.restaurantId);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _printers = cache?.printers ?? const <Map<String, dynamic>>[];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = RestaurantConnectivityService.instance;
    final host = RestaurantLanHostRegistry.current;
    final pendingOrders = _orders
        .where(
          (order) =>
              order.syncStatus == RestaurantLocalOrderSyncStatus.pendingSync ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.localOnly ||
              order.syncStatus == RestaurantLocalOrderSyncStatus.syncing,
        )
        .toList(growable: false);
    final conflicts = _orders
        .where(
          (order) =>
              order.syncStatus == RestaurantLocalOrderSyncStatus.conflict ||
              (order.syncError ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
    final uncertainOrders = _orders
        .where((order) => order.printStatus == 'uncertain')
        .toList(growable: false);
    final failedOrders = _orders
        .where(
          (order) =>
              order.printStatus == 'failed' || order.printStatus == 'not_sent',
        )
        .toList(growable: false);
    final hostMayPrint = host?.listening == true &&
        host?.printBridgeUri != null &&
        _isLoopback(host!.printBridgeUri!) &&
        deviceMayRunLocalPrintBridge(defaultTargetPlatform);
    DateTime? lastSync;
    for (final order in _orders) {
      if (order.syncStatus != RestaurantLocalOrderSyncStatus.synced) continue;
      if (lastSync == null || order.updatedAt.isAfter(lastSync)) {
        lastSync = order.updatedAt;
      }
    }

    final serverUp = host?.listening == true;
    final problemCount =
        conflicts.length + uncertainOrders.length + failedOrders.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Yerel Operasyon Merkezi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // A phone never runs a print bridge: show the computer's center.
              ListenableBuilder(
                listenable: WaiterLanLink.instance,
                builder: (context, _) =>
                    WaiterLanLink.instance.paired &&
                        !deviceMayRunLocalPrintBridge(defaultTargetPlatform)
                    ? const LanCenterStatusCard()
                    : const SizedBox.shrink(),
              ),
              _section('Merkez durumu', Icons.hub_outlined, <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusPill(
                      'İnternet',
                      connectivity.supabaseReachable ? 'var' : 'yok',
                      connectivity.supabaseReachable,
                    ),
                    _statusPill(
                      'Yerel ağ',
                      connectivity.hasNetwork ? 'var' : 'yok',
                      connectivity.hasNetwork,
                    ),
                    _statusPill(
                      'Yerel sunucu',
                      serverUp ? 'açık · port ${host!.port}' : 'kapalı',
                      serverUp,
                    ),
                  ],
                ),
                if (_centerNotice != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _centerNotice!,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: serverUp
                      ? OutlinedButton.icon(
                          onPressed: _centerBusy ? null : _stopCenter,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Yerel merkezi durdur'),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                          ),
                          onPressed: _centerBusy ? null : _startCenter,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Yerel merkezi başlat'),
                        ),
                ),
              ]),
              _section('Garson cihazları', Icons.phone_iphone_rounded, <Widget>[
                _row('Şu an bağlı', '${host?.deviceCount ?? 0}'),
                _row(
                  'Eşleştirme',
                  serverUp ? 'bu bilgisayardan yapılabilir' : 'önce merkezi başlatın',
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (serverUp)
                      FilledButton.tonalIcon(
                        onPressed: _issueCode,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Garson cihazı bağla'),
                      ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RestaurantLanWaiterPage(
                              restaurantId: widget.restaurantId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Garson cihazı'),
                    ),
                  ],
                ),
                if (_pairingLink != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Garson telefonu merkezi kendiliğinden bulamıyorsa bu bağlantı '
                    'kodunu kullanın: telefonda "Kodla bağla"ya yapıştırın. '
                    'İki dakika geçerlidir, bir kez kullanılır.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  _codeBox(
                    SelectableText(
                      _pairingLink!,
                      key: const Key('lan_pairing_link'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (_pairingCode != null) ...[
                  const SizedBox(height: 10),
                  _codeBox(
                    SelectableText(
                      'Kod: $_pairingCode  (2 dakika geçerli, tek kullanımlık)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ]),
              LanPairedDevicesSection.forHost(
                canManageDevices: widget.canManageDevices,
                staffNames: widget.staffNames,
              ),
              _section('Kayıtlı yazıcılar', Icons.print_outlined, <Widget>[
                if (_printers.isEmpty)
                  const Text(
                    'Bu cihazda kayıtlı yazıcı bilgisi yok.',
                    style: TextStyle(color: Color(0xFF475569)),
                  )
                else
                  for (final printer in _printers)
                    _printerTile(printer, ethernet: _isEthernet(printer)),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KitchenPrintManagementPage(
                            restaurantId: widget.restaurantId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Yazıcı ayarlarını aç'),
                  ),
                ),
              ]),
              _section('Senkron ve siparişler', Icons.sync_rounded, <Widget>[
                _row(
                  'Durum',
                  connectivity.isSyncing ? 'senkron sürüyor' : 'bekliyor',
                ),
                _row('Yerel kayıt', '${_orders.length}'),
                _row('Bekleyen sipariş', '${pendingOrders.length}'),
                _row(
                  'Son senkron',
                  lastSync == null ? 'kayıt yok' : lastSync.toLocal().toString(),
                ),
                const SizedBox(height: 4),
                if (conflicts.isEmpty && pendingOrders.isEmpty)
                  const Text(
                    'Bekleyen sipariş, hata veya çakışma yok.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                for (final order in conflicts)
                  Text(
                    '${order.localOrderId} · ${order.syncStatus.name}'
                    '${(order.syncError ?? '').isEmpty ? '' : ' · ${order.syncError}'}',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                for (final order in pendingOrders)
                  Text('${order.localOrderId} · ${order.syncStatus.name}'),
              ]),
              _section(
                problemCount == 0 ? 'Baskı durumu' : 'Baskı durumu ($problemCount)',
                Icons.receipt_long_outlined,
                <Widget>[
                  if (_reprintNotice != null) Text(_reprintNotice!),
                  if (uncertainOrders.isEmpty && failedOrders.isEmpty)
                    const Text(
                      'Belirsiz veya iletilmemiş fiş yok. Otomatik tekrar kapalı.',
                      style: TextStyle(color: Color(0xFF475569)),
                    )
                  else ...<Widget>[
                    for (final order in uncertainOrders)
                      _reprintRow(
                        order,
                        'belirsiz · otomatik tekrar yok',
                        enabled: hostMayPrint,
                      ),
                    for (final order in failedOrders)
                      _reprintRow(
                        order,
                        'yazıcıya iletilmedi',
                        enabled: hostMayPrint,
                      ),
                    if (!hostMayPrint)
                      const Text(
                        'Yeniden baskı yalnız yazıcı ana bilgisayarında yapılır.',
                        style: TextStyle(color: Color(0xFF475569)),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reprintRow(
    RestaurantLocalOrderRecord order,
    String label, {
    required bool enabled,
  }) {
    return Row(
      children: [
        Expanded(child: Text('${order.localOrderId} · $label')),
        TextButton(
          onPressed: !enabled || _loading
              ? null
              : () => _reprint(order.localOrderId),
          child: const Text('Yeni fiş'),
        ),
      ],
    );
  }

  Future<void> _reprint(String localOrderId) async {
    final host = RestaurantLanHostRegistry.current;
    final bridge = host?.printBridgeUri;
    if (host?.listening != true ||
        bridge == null ||
        !_isLoopback(bridge) ||
        !deviceMayRunLocalPrintBridge(defaultTargetPlatform)) {
      setState(() {
        _reprintNotice = 'Yeniden baskı yalnız yazıcı ana bilgisayarında yapılır.';
      });
      return;
    }
    final queue = RestaurantLocalPrintQueueService();
    final jobs = await queue.list(widget.restaurantId);
    final matches = jobs
        .where(
          (job) =>
              job.localOrderId == localOrderId &&
              (job.status == RestaurantLocalPrintJobStatus.uncertain ||
                  job.status == RestaurantLocalPrintJobStatus.failed),
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      setState(() => _reprintNotice = 'Yeniden basılacak yerel iş yok.');
      return;
    }
    final notices = <String>[];
    for (final job in matches) {
      final token = 'm${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final created = await queue.operatorReprint(job: job, reprintToken: token);
      final delivered = await queue.deliverToBridge(job: created, bridgeBase: bridge);
      notices.add('${created.localJobId} · ${_reprintLabel(delivered.status)}');
    }
    if (!mounted) return;
    setState(() => _reprintNotice = notices.join('\n'));
    await _reload();
  }

  String _reprintLabel(RestaurantLocalPrintJobStatus status) {
    switch (status) {
      case RestaurantLocalPrintJobStatus.forwarded:
        return 'yazıcıya iletildi; basıldığı onaylanmadı';
      case RestaurantLocalPrintJobStatus.uncertain:
        return 'belirsiz; otomatik tekrar yok';
      case RestaurantLocalPrintJobStatus.failed:
        return 'yazıcıya iletilmedi';
      default:
        return status.name;
    }
  }

  bool _isLoopback(Uri uri) {
    final host = uri.host.toLowerCase();
    return uri.scheme == 'http' && (host == '127.0.0.1' || host == 'localhost');
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _statusPill(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label: $value',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBox(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F3FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE9D5FF)),
    ),
    child: child,
  );

  Widget _printerTile(Map<String, dynamic> printer, {required bool ethernet}) {
    final name = '${printer['name'] ?? printer['label'] ?? printer['id'] ?? 'Yazıcı'}';
    final host = '${printer['host'] ?? printer['ip'] ?? printer['address'] ?? ''}'.trim();
    final port = '${printer['port'] ?? ''}'.trim();
    final backend = '${printer['backend'] ?? printer['connection'] ?? printer['transport'] ?? ''}'.trim();
    final detail = <String>[
      if (ethernet) 'Ethernet' else if (backend.isNotEmpty) backend,
      if (host.isNotEmpty) port.isEmpty ? host : '$host:$port',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.print_rounded, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isEthernet(Map<String, dynamic> printer) {
    final backend =
        '${printer['backend'] ?? ''} ${printer['connection'] ?? ''} ${printer['transport'] ?? ''}'
            .toLowerCase();
    return backend.contains('tcp') || backend.contains('ethernet');
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475569))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
