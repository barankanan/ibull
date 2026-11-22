import 'dart:async';

import 'package:flutter/material.dart';

import '../services/restaurant_offline/waiter_lan_link.dart';

/// "Ana bilgisayar · Yazıcı Merkezi" for a phone or tablet paired to the
/// restaurant computer. It shows the computer's print center, never this
/// device's own loopback bridge. The center is asked once per open and on
/// "Yeniden dene"; a slow or silent center ends in "ulaşılamıyor", not a
/// spinner. An unknown center is never reported as closed.
class LanCenterStatusCard extends StatefulWidget {
  const LanCenterStatusCard({super.key, this.link, this.fetch});

  final WaiterLanLink? link;

  /// Test seam. Defaults to the link's own [WaiterLanLink.centerStatus].
  final Future<Map<String, dynamic>> Function()? fetch;

  @override
  State<LanCenterStatusCard> createState() => _LanCenterStatusCardState();
}

class _LanCenterStatusCardState extends State<LanCenterStatusCard> {
  Map<String, dynamic>? _data;
  var _loading = true;
  var _run = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final run = ++_run;
    setState(() => _loading = true);
    Map<String, dynamic>? data;
    try {
      final fetch =
          widget.fetch ?? (widget.link ?? WaiterLanLink.instance).centerStatus;
      data = await fetch().timeout(const Duration(seconds: 8));
    } catch (_) {
      data = null;
    }
    if (!mounted || run != _run) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? <Map<String, dynamic>>[
          for (final e in v)
            if (e is Map) Map<String, dynamic>.from(e),
        ]
      : const <Map<String, dynamic>>[];

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF475569))),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  /// Real link state: bağlı / aranıyor / ulaşılamıyor.
  static String linkStateLabel(WaiterLanLink link) {
    if (link.paired) return link.centerReachable ? 'bağlı' : 'ulaşılamıyor';
    return 'aranıyor';
  }

  Widget _savedHostHeader(WaiterLanLink link) {
    if (link.centerAddress.isEmpty && !link.paired) {
      return const SizedBox.shrink();
    }
    final machine = link.centerMachineId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Bağlandığım Ana Bilgisayar',
            key: Key('lan_saved_host_title'),
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          _row('Ad', 'IBUL Merkez'),
          if (link.centerAddress.isNotEmpty) _row('Adres', link.centerAddress),
          if (machine.isNotEmpty)
            _row('Cihaz kimliği', machine.length > 8 ? machine.substring(0, 8) : machine),
          _row('Durum', linkStateLabel(link)),
          if (link.paired && !link.centerReachable)
            const Text(
              'Ana bilgisayar aranıyor. Aynı Wi-Fi ağındaysanız kendiliğinden '
              'yeniden bağlanır.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return const <Widget>[Text('Ana bilgisayara bağlanılıyor...')];
    }
    final data = _data;
    if (data == null) {
      return <Widget>[
        const Text(
          'Ana bilgisayara ulaşılamıyor. Yazıcı Merkezi\'nin durumu şu an '
          'bilinmiyor.',
          key: Key('lan_center_unreachable'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('lan_center_retry'),
            onPressed: _load,
            child: const Text('Yeniden dene'),
          ),
        ),
      ];
    }
    final center = _map(data['print_center']);
    final printers = _list(data['printers']);
    final stations = _list(data['stations']);
    final sync = _map(data['sync']);
    final jobs = _map(data['print_jobs']);
    String n(Map<String, dynamic> m, String k) => '${m[k] ?? 0}';
    return <Widget>[
      _row('Ana bilgisayar', 'erişilebilir'),
      _row(
        'Yazıcı Merkezi',
        center['available'] == false
            ? 'köprü yok'
            : center['reachable'] == true
            ? 'açık'
            : 'kapalı',
      ),
      if ((center['status_text']?.toString() ?? '').isNotEmpty)
        Text(
          center['status_text'].toString(),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      const SizedBox(height: 8),
      const Text('Kayıtlı yazıcılar',
          style: TextStyle(fontWeight: FontWeight.w600)),
      if (printers.isEmpty)
        const Text('Kayıtlı yazıcı yok.')
      else
        for (final p in printers)
          Text(
            [
              if ('${p['name'] ?? ''}'.isNotEmpty) '${p['name']}' else 'Yazıcı',
              if ('${p['connection_type'] ?? ''}'.isNotEmpty)
                '${p['connection_type']}',
              if ('${p['host'] ?? ''}'.isNotEmpty)
                '${p['host']}${p['port'] == null ? '' : ':${p['port']}'}',
            ].join(' · '),
          ),
      const SizedBox(height: 8),
      const Text('İstasyon eşleşmeleri',
          style: TextStyle(fontWeight: FontWeight.w600)),
      if (stations.isEmpty)
        const Text('İstasyon yok.')
      else
        for (final s in stations)
          Text(
            '${s['name'] ?? 'İstasyon'} → '
            '${s['printer'] ?? 'yazıcı eşleşmedi'}',
          ),
      const SizedBox(height: 8),
      _row('Senkron bekleyen', n(sync, 'pending')),
      _row('Senkron hata / çakışma',
          '${sync['failed'] ?? 0} / ${sync['conflict'] ?? 0}'),
      _row('Senkronlanan', n(sync, 'synced')),
      if (jobs['available'] == true) ...<Widget>[
        _row('Baskı kuyruğu', n(jobs, 'queued')),
        _row('Başarısız / belirsiz baskı',
            '${jobs['failed'] ?? 0} / ${jobs['uncertain'] ?? 0}'),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('lan_center_retry'),
          onPressed: _load,
          child: const Text('Yenile'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
        children: <Widget>[
          ListenableBuilder(
            listenable: widget.link ?? WaiterLanLink.instance,
            builder: (context, _) =>
                _savedHostHeader(widget.link ?? WaiterLanLink.instance),
          ),
          const Text(
            'Ana bilgisayar · Yazıcı Merkezi',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ..._body(),
        ],
      ),
    );
  }
}
