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
    final ethernet = _printers.where(_isEthernet).toList(growable: false);
    DateTime? lastSync;
    for (final order in _orders) {
      if (order.syncStatus != RestaurantLocalOrderSyncStatus.synced) continue;
      if (lastSync == null || order.updatedAt.isAfter(lastSync)) {
        lastSync = order.updatedAt;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _purple,
        elevation: 0,
        title: const Text('Yerel Operasyon Merkezi'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          _section('Yerel Operasyon Merkezi', <Widget>[
            _row('İnternet', connectivity.supabaseReachable ? 'ulaşılıyor' : 'yok'),
            _row('Yerel ağ', connectivity.hasNetwork ? 'var' : 'yok'),
            _row(
              'Yerel sunucu',
              host?.listening == true ? 'açık · port ${host!.port}' : 'kapalı',
            ),
            if (_centerNotice != null) Text(_centerNotice!),
            Wrap(
              spacing: 8,
              children: [
                if (host?.listening != true)
                  TextButton(
                    onPressed: _centerBusy ? null : _startCenter,
                    child: const Text('Yerel merkezi başlat'),
                  )
                else
                  TextButton(
                    onPressed: _centerBusy ? null : _stopCenter,
                    child: const Text('Yerel merkezi durdur'),
                  ),
              ],
            ),
          ]),
          _section('Garson Bağlantısı', <Widget>[
            _row('Bağlı cihaz', '${host?.deviceCount ?? 0}'),
            _row(
              'Eşleştirme',
              host?.listening == true ? 'bu bilgisayardan kod üretilebilir' : 'sunucu kapalı',
            ),
            if (host?.listening == true)
              TextButton(
                onPressed: _issueCode,
                child: const Text('Garson cihazı bağla'),
              ),
            if (_pairingLink != null) ...[
              const Text(
                'Garson telefonu merkezi kendiliğinden bulamıyorsa bu bağlantı '
                'kodunu kullanın: telefonda "Kodla bağla"ya yapıştırın. '
                'İki dakika geçerlidir, bir kez kullanılır.',
              ),
              const SizedBox(height: 8),
              SelectableText(
                _pairingLink!,
                key: const Key('lan_pairing_link'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (_pairingCode != null)
              SelectableText(
                'Kod: $_pairingCode  (2 dakika geçerli, tek kullanımlık)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RestaurantLanWaiterPage(
                        restaurantId: widget.restaurantId,
                      ),
                    ),
                  );
                },
                child: const Text('Garson cihazı'),
              ),
            ),
          ]),
          LanPairedDevicesSection.forHost(
            canManageDevices: widget.canManageDevices,
            staffNames: widget.staffNames,
          ),
          _section('Ethernet Yazıcı Yönetimi', <Widget>[
            if (ethernet.isEmpty)
              const Text('Kayıtlı Ethernet yazıcı yok.')
            else
              for (final printer in ethernet)
                Text(_printerLabel(printer)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => KitchenPrintManagementPage(
                        restaurantId: widget.restaurantId,
                      ),
                    ),
                  );
                },
                child: const Text('Mevcut yazıcı ayarları'),
              ),
            ),
          ]),
          _section('Senkronizasyon Durumu', <Widget>[
            _row('Durum', connectivity.isSyncing ? 'senkron sürüyor' : 'bekliyor'),
            _row('Kuyruk', '${_orders.length} kayıt'),
            _row(
              'Son senkron',
              lastSync == null ? 'kayıt yok' : lastSync.toLocal().toString(),
            ),
            if (conflicts.isEmpty)
              const Text('Hata veya çakışma yok.')
            else
              for (final order in conflicts)
                Text(
                  '${order.localOrderId} · ${order.syncStatus.name}'
                  '${(order.syncError ?? '').isEmpty ? '' : ' · ${order.syncError}'}',
                ),
          ]),
          _section('Bekleyen Siparişler', <Widget>[
            if (pendingOrders.isEmpty)
              const Text('Bekleyen sipariş yok.')
            else
              for (final order in pendingOrders)
                Text('${order.localOrderId} · ${order.syncStatus.name}'),
          ]),
          _section('Belirsiz Baskılar', <Widget>[
            if (_reprintNotice != null) Text(_reprintNotice!),
            if (uncertainOrders.isEmpty && failedOrders.isEmpty)
              const Text('Belirsiz veya iletilmemiş fiş yok. Otomatik tekrar kapalı.')
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
                const Text('Yeniden baskı yalnız yazıcı ana bilgisayarında yapılır.'),
            ],
          ]),
        ],
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

  String _printerLabel(Map<String, dynamic> printer) {
    final name = printer['name'] ?? printer['label'] ?? printer['id'] ?? 'Yazıcı';
    final backend = printer['backend'] ?? printer['connection'] ?? printer['transport'] ?? '';
    return '$name · $backend';
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _purple,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
