import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../services/restaurant_offline/restaurant_local_cache_service.dart';
import '../../../../services/restaurant_offline/restaurant_local_order_queue_service.dart';
import '../../../../services/restaurant_offline/waiter_lan_link.dart';
import '../helpers/offline_overview.dart';
import '../helpers/offline_page_policy.dart';

/// İnternet gerektiren sayfanın yerine gösterilir. Gerçek sayfa HİÇ oluşturulmaz,
/// bu yüzden veri sorgusu ve işlem tetiklenmez; görünen yalnız bulanık bir iskelettir.
class OfflineBlockedModuleView extends StatelessWidget {
  const OfflineBlockedModuleView({super.key, required this.moduleLabel});

  final String moduleLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          height: i == 0 ? 36 : 64,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E6EA)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 32,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      moduleLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      offlineRequiresInternetMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      offlineRequiresInternetDetail,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String offlineClockLabel(DateTime? at) {
  if (at == null) return 'hiç eşitlenmedi';
  final l = at.toLocal();
  return '${_two(l.day)}.${_two(l.month)}.${l.year} ${_two(l.hour)}:${_two(l.minute)}';
}

String _tl(double v) => '₺${v.toStringAsFixed(2)}';

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.note});

  final String title;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Çevrimdışı Genel Bakış. Kaynaklar ayrı kartlarda; tahsilat rakamı GÖSTERİLMEZ.
class OfflineOverviewView extends StatelessWidget {
  const OfflineOverviewView({
    super.key,
    required this.data,
    this.fromCenter = false,
  });

  final OfflineOverviewData data;

  /// Rakamlar ana bilgisayardan geldi; bulut ve baskı kartları gösterilmez.
  final bool fromCenter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Genel Bakış — çevrimdışı',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          fromCenter
              ? 'Kaynak: Ana bilgisayardan. Rakamlar ana bilgisayardaki yerel kayıtlardır.'
              : 'Bu sayfa bu cihazdaki yerel kayıtlardan hesaplanır. İnternet gelince bulutla eşitlenir.',
          key: const Key('offline_overview_source'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Masalar',
          note: fromCenter
              ? 'Ana bilgisayardan'
              : 'Masa listesi: son bulut eşitlemesi ${offlineClockLabel(data.lastCloudSnapshotAt)}',
          children: data.tablesKnown
              ? [
                  _Row('Toplam masa', '${data.totalTables}'),
                  _Row('Dolu masa', '${data.occupiedTables}'),
                  _Row('Boş masa', '${data.freeTables}'),
                ]
              : const [
                  Text(
                    'Masa listesi bu cihaza hiç eşitlenmedi; boş/dolu sayısı gösterilemiyor.',
                  ),
                ],
        ),
        if (!fromCenter)
        _Card(
          title: 'Bulutla senkronize (son anlık görüntü)',
          note:
              'Güncel olmayabilir: ${offlineClockLabel(data.lastCloudSnapshotAt)}',
          children: [_Row('Açık sipariş', '${data.cloudOpenOrders}')],
        ),
        _Card(
          title: 'Yerel olarak kaydedilmiş',
          children: [
            _Row('Yerel kayıtlı sipariş', '${data.localOrders}'),
            if (!fromCenter) ...[
              _Row('Mutfağa iletildi', '${data.localKitchenSent}'),
              _Row('Baskı bekliyor', '${data.localPrintWaiting}'),
              _Row(
                'Baskı sonucu doğrulanamadı / başarısız',
                '${data.localPrintUnverified}',
              ),
            ],
          ],
        ),
        _Card(
          title: 'Senkronizasyon bekleyen',
          children: [
            _Row('Bulutta bekliyor', '${data.pendingSync}'),
            _Row('Hata aldı (saklanıyor)', '${data.syncFailed}'),
          ],
        ),
        _Card(
          title: 'Kesinleşmemiş tutarlar',
          note:
              'Bunlar tahsilat değildir. Ödeme doğrulanmadığı için “kazanıldı” denmez.',
          children: [
            _Row(
              'Yerel geçici toplam (senkronizasyon bekliyor)',
              _tl(data.localProvisionalTotal),
            ),
            if (!fromCenter)
              _Row(
                'Açık adisyon (son eşitlemeye göre)',
                _tl(data.cloudOpenBillTotal),
              ),
            const SizedBox(height: 4),
            const Text(
              'Tahsil edilmiş gelir internet olmadan gösterilmez.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Yerel verileri okuyup [OfflineOverviewView] gösterir. Sonsuz yükleme yok:
/// 6 sn içinde okunamazsa hata ve "Yeniden dene" gösterilir.
class OfflineOverviewLoader extends StatefulWidget {
  const OfflineOverviewLoader({
    super.key,
    required this.restaurantId,
    this.cacheService,
    this.orderQueue,
    this.link,
    this.centerStatus,
  });

  final String restaurantId;
  final WaiterLanLink? link;

  /// Test seam; varsayılan [WaiterLanLink.centerStatus].
  final Future<Map<String, dynamic>> Function()? centerStatus;
  final RestaurantLocalCacheService? cacheService;
  final RestaurantLocalOrderQueueService? orderQueue;

  @override
  State<OfflineOverviewLoader> createState() => _OfflineOverviewLoaderState();
}

class _OfflineOverviewLoaderState extends State<OfflineOverviewLoader> {
  OfflineOverviewData? _data;
  var _fromCenter = false;
  String? _error;
  var _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.restaurantId.trim();
    try {
      if (id.isEmpty) throw StateError('İşletme kimliği bulunamadı.');
      final fromCenter = await _centerOverview(id);
      if (fromCenter != null) {
        if (!mounted) return;
        setState(() {
          _data = fromCenter;
          _fromCenter = true;
          _error = null;
          _loading = false;
        });
        return;
      }
      final cache = widget.cacheService ?? RestaurantLocalCacheService();
      final queue = widget.orderQueue ?? RestaurantLocalOrderQueueService();
      final results = await Future.wait<Object?>([
        cache.read(id),
        queue.list(id),
      ]).timeout(const Duration(seconds: 6));
      final snapshot = results[0] as dynamic;
      final orders = results[1] as List<dynamic>;
      final data = buildOfflineOverview(
        tables: List<Map<String, dynamic>>.from(snapshot?.tables ?? const []),
        cloudTableOrders: List<Map<String, dynamic>>.from(
          snapshot?.tableOrderSnapshots ?? const [],
        ),
        localOrders: List.castFrom(orders),
        cachedAt: snapshot?.cachedAt as DateTime?,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _fromCenter = false;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  /// Eşleşmiş ve erişilebilir merkez varsa rakamlar oradan; her hatada null
  /// döner ve cihaz-yerel davranış aynen sürer.
  Future<OfflineOverviewData?> _centerOverview(String id) async {
    final link = widget.link ?? WaiterLanLink.instance;
    final fetch = widget.centerStatus ?? link.centerStatus;
    if (widget.centerStatus == null &&
        !(link.paired && link.centerReachable && link.restaurantId == id)) {
      return null;
    }
    try {
      final response = await fetch().timeout(const Duration(seconds: 8));
      final raw = response['overview'];
      final sync = response['sync'];
      if (raw is! Map || sync is! Map) return null;
      int n(Object? v) => int.tryParse('${v ?? 0}') ?? 0;
      final total = n(raw['tables_total']);
      final occupied = n(raw['tables_with_local_orders']);
      return OfflineOverviewData(
        totalTables: total,
        occupiedTables: occupied,
        freeTables: total > occupied ? total - occupied : 0,
        cloudOpenOrders: 0,
        localOrders: n(raw['local_orders']),
        localKitchenSent: 0,
        localPrintWaiting: 0,
        localPrintUnverified: 0,
        pendingSync: n(sync['pending']),
        syncFailed: n(sync['failed']) + n(sync['conflict']),
        localProvisionalTotal:
            double.tryParse('${raw['local_provisional_total'] ?? 0}') ?? 0,
        cloudOpenBillTotal: 0,
        lastCloudSnapshotAt: DateTime.tryParse('${response['generated_at']}'),
        tablesKnown: total > 0,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) {
      return OfflineOverviewView(data: data, fromCenter: _fromCenter);
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yerel veriler okunamadı. ${_error ?? ''}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
