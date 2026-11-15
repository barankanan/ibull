import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/core/secure_local_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_browser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_discovery.dart';
import 'package:ibul_app/services/restaurant_offline/paired_lan_transport.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pairing_guard.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

/// Waiter device flow against the existing local host.
/// Success is shown only after the host confirms a durable save.
class RestaurantLanWaiterPage extends StatefulWidget {
  const RestaurantLanWaiterPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantLanWaiterPage> createState() =>
      _RestaurantLanWaiterPageState();
}

class _RestaurantLanWaiterPageState extends State<RestaurantLanWaiterPage> {
  static const _purple = Color(0xFF7C3AED);
  static const _sessionKey = 'ibul_lan_waiter_session';
  final _hostController = TextEditingController();
  final _qrController = TextEditingController();
  final _codeController = TextEditingController();
  String? _trustedMachine;
  bool _qrAccepted = false;
  final _pinController = TextEditingController();
  final _staffController = TextEditingController();
  LanClientCertificate? _certificate;
  int _seq = 0;
  String _status = 'Eşleştirme bekleniyor.';
  List<Map<String, dynamic>> _tables = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _products = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _table;
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  String? _localOrderId;
  int _revision = 1;
  List<LanCenterRecord> _found = const <LanCenterRecord>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restore();
    RestaurantConnectivityService.instance.addListener(_onNetwork);
  }

  @override
  void dispose() {
    RestaurantConnectivityService.instance.removeListener(_onNetwork);
    _hostController.dispose();
    _codeController.dispose();
    _qrController.dispose();
    _pinController.dispose();
    _staffController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final stored = await SecureLocalStore.instance.readJson(_sessionKey);
    if (!mounted || stored is! Map) return;
    final path = stored['cert_dir']?.toString() ?? '';
    if (path.isNotEmpty) {
      final directory = Directory(path);
      final savedKey = await SecureLocalStore.instance.readString(_keyName);
      if (savedKey != null && savedKey.contains('PRIVATE KEY')) {
        if (!directory.existsSync()) directory.createSync(recursive: true);
        await File('${directory.path}/client.key').writeAsString(savedKey);
      }
      _certificate = await LanClientCertificate.load(directory: directory);
    }
    if (!mounted) return;
    setState(() {
      _hostController.text = stored['host']?.toString() ?? '';
      _pinController.text = stored['server_fingerprint']?.toString() ?? '';
      _staffController.text = stored['staff_id']?.toString() ?? '';
      _trustedMachine = stored['machine_id']?.toString();
      _qrAccepted = stored['qr_accepted'] == true;
      _seq = (stored['seq'] as num?)?.toInt() ?? 0;
    });
    _bindTransport();
  }

  String get _keyName => 'ibul_lan_waiter_key_${widget.restaurantId}';

  Future<Directory> _certDirectory() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}/ibul-lan-waiter/${widget.restaurantId}');
    }
    return Directory(
      lanMaterialDirectory(
        operatingSystem: Platform.operatingSystem,
        environment: Platform.environment,
        restaurantId: 'waiter-${widget.restaurantId}',
      ),
    );
  }

  RestaurantLanClient? _client() {
    final certificate = _certificate;
    final pin = LanTlsMaterial.normalizeFingerprint(_pinController.text);
    final text = _hostController.text.trim();
    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (certificate == null ||
        pin.isEmpty ||
        uri == null ||
        uri.host.isEmpty ||
        uri.scheme != 'https') {
      return null;
    }
    return RestaurantLanClient(
      uri,
      securityContext: certificate.context,
      pinnedServerFingerprint: pin,
      staffId: _staffController.text.trim(),
    )..seq = _seq;
  }

  Future<void> _remember(RestaurantLanClient client) async {
    _seq = client.seq;
    await SecureLocalStore.instance.writeJson(_sessionKey, <String, Object?>{
      'host': _hostController.text.trim(),
      'server_fingerprint': _pinController.text.trim(),
      'staff_id': _staffController.text.trim(),
      'machine_id': _trustedMachine,
      'qr_accepted': _qrAccepted,
      'cert_dir': _certificate?.directory.path,
      'restaurant_id': widget.restaurantId,
      'seq': client.seq,
    });
  }

  RestaurantLanClient? _anonymous() {
    final pin = LanTlsMaterial.normalizeFingerprint(_pinController.text);
    final text = _hostController.text.trim();
    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (pin.isEmpty || uri == null || uri.host.isEmpty || uri.scheme != 'https') {
      return null;
    }
    return RestaurantLanClient(
      uri,
      securityContext: SecurityContext(withTrustedRoots: false),
      pinnedServerFingerprint: pin,
      staffId: _staffController.text.trim(),
    );
  }

  void _bindTransport() {
    final client = _client();
    RestaurantLanPairing.transport = client == null
        ? null
        : PairedLanTransport.fromClient(client);
  }

  void _onNetwork() {
    if (!mounted) return;
    setState(() {
      _status = 'Wi-Fi değişti. Kayıtlı merkez kimliği yeniden doğrulanacak.';
    });
    if (_trustedMachine != null) unawaited(_findCenter());
  }

  Future<void> _findCenter() async {
    setState(() {
      _busy = true;
      _status = 'Yerel merkez aranıyor';
    });
    try {
      final found = await LanCenterBrowser().browse();
      SavedLanCenter? trusted;
      final machine = _trustedMachine?.trim() ?? '';
      final pin = LanTlsMaterial.normalizeFingerprint(_pinController.text);
      if (machine.isNotEmpty && pin.isNotEmpty) {
        trusted = SavedLanCenter(
          restaurantId: widget.restaurantId,
          machineId: machine,
          fingerprint: pin,
        );
      }
      final decision = chooseLanCenter(
        restaurantId: widget.restaurantId,
        found: found,
        trusted: trusted,
        fromQr: false,
      );
      if (!mounted) return;
      final record = decision.record;
      if (decision.choice == LanCenterChoice.selected && record != null) {
        setState(() {
          _found = found;
          _hostController.text = record.httpsUri;
          _status = _certificate == null
              ? 'İBUL merkezi bulundu. QR eşleştirmesi gerekiyor.'
              : 'İBUL merkezi bulundu';
        });
        return;
      }
      setState(() {
        _found = found;
        _status = decision.choice == LanCenterChoice.needsQr || found.isEmpty
            ? 'Merkeze ulaşılamıyor. QR eşleştirmesi gerekiyor.'
            : decision.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanQr() async {
    if (!Platform.isIOS) {
      setState(() => _status = 'QR kamerası bu derlemede iPhone içindir. Metni yapıştırabilirsiniz.');
      return;
    }
    try {
      final raw = await const MethodChannel(lanCenterChannelName).invokeMethod<String>('scanQr');
      if (!mounted || raw == null || raw.trim().isEmpty) return;
      _qrController.text = raw.trim();
      _applyQr();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message ?? 'QR okunamadı.');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _status = 'QR kamerası bu derlemede yok. Metni yapıştırın.');
    }
  }

  void _applyQr() {
    final record = decodeLanQr(_qrController.text);
    if (record == null) {
      setState(() => _status = 'QR metni yerel bir İBUL merkezine ait değil.');
      return;
    }
    final decision = chooseLanCenter(
      restaurantId: widget.restaurantId,
      found: <LanCenterRecord>[record],
      fromQr: true,
    );
    if (decision.choice != LanCenterChoice.selected || decision.record == null) {
      setState(() => _status = decision.message);
      return;
    }
    setState(() {
      _hostController.text = decision.record!.httpsUri;
      _pinController.text = decision.record!.fingerprint;
      _trustedMachine = decision.record!.machineId;
      _qrAccepted = true;
      _status = 'QR kimliği alındı. Eşleştirme kodunu girin.';
    });
  }

  Future<void> _pair() async {
    setState(() => _busy = true);
    try {
      final anonymous = _anonymous();
      final uri = Uri.tryParse(
        _hostController.text.trim().startsWith('http')
            ? _hostController.text.trim()
            : 'https://${_hostController.text.trim()}',
      );
      if (anonymous == null ||
          _staffController.text.trim().isEmpty ||
          uri == null ||
          uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.port != lanOrderPort ||
          LanTlsMaterial.normalizeFingerprint(_pinController.text).isEmpty) {
        setState(() {
          _status = 'Adres, personel ve Mac ekranındaki sunucu parmak izi gerekli. QR gerekmez.';
        });
        return;
      }
      final discovered = await anonymous.get('/lan/discover');
      final announcedRestaurant = discovered['restaurant_id']?.toString() ?? '';
      final announcedMachine = discovered['machine_id']?.toString() ?? '';
      final announcedFingerprint = discovered['fingerprint']?.toString() ?? '';
      final pin = LanTlsMaterial.normalizeFingerprint(_pinController.text);
      final knownMachine = _trustedMachine?.trim() ?? '';
      if (discovered['service'] != 'ibul-lan' ||
          announcedRestaurant != widget.restaurantId ||
          announcedMachine.isEmpty ||
          announcedFingerprint.isEmpty ||
          (knownMachine.isNotEmpty && announcedMachine != knownMachine) ||
          LanTlsMaterial.normalizeFingerprint(announcedFingerprint) != pin) {
        setState(() => _status = 'Yerel servis doğrulanamadı.');
        return;
      }
      _trustedMachine = announcedMachine;
      final request = await LanClientRequest.generate(
        directory: await _certDirectory(),
        commonName: 'ibul-waiter',
      );
      final privateKey = await File('${request.directory.path}/client.key').readAsString();
      final stored = privateKey.contains('PRIVATE KEY')
          ? await SecureLocalStore.instance.writeSecret(_keyName, privateKey)
          : false;
      if (!stored) {
        final keyFile = File('${request.directory.path}/client.key');
        if (keyFile.existsSync()) await keyFile.delete();
        setState(() => _status = 'Anahtar güvenli saklanamadı. Eşleştirme durduruldu.');
        return;
      }
      final redeemed = await anonymous.post('/lan/pair/redeem', <String, Object?>{
        'code': _codeController.text.trim(),
        'staff_id': _staffController.text.trim(),
        'csr': request.csr,
      });
      final certificate = redeemed['certificate']?.toString() ?? '';
      if (redeemed['ok'] != true || certificate.isEmpty) {
        setState(() => _status = 'Eşleştirme kodu geçersiz veya süresi doldu.');
        return;
      }
      await File('${request.directory.path}/client.pem').writeAsString(certificate);
      _certificate = await LanClientCertificate.load(directory: request.directory);
      final client = _client();
      if (client == null) {
        setState(() => _status = 'Cihaz sertifikası kurulamadı.');
        return;
      }
      client.seq = 0;
      await _remember(client);
      _bindTransport();
      setState(() => _status = 'Güvenli bağlantı kuruldu');
      await _reloadCatalog();
    } on SocketException {
      setState(() => _status = 'Merkeze ulaşılamıyor');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadCatalog() async {
    final client = _client();
    if (client == null) {
      setState(() => _status = 'Yerel sunucu eşleşmesi yok.');
      return;
    }
    try {
      final tables = await client.postAuthorized('/lan/tables', const <String, Object?>{});
      final products = await client.postAuthorized(
        '/lan/products',
        const <String, Object?>{},
      );
      await _remember(client);
      if (!mounted) return;
      setState(() {
        _tables = _maps(tables['tables']);
        _products = _maps(products['products']);
        _status = 'Masa ve ürün listesi alındı.';
      });
    } on SocketException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    }
  }

  Future<void> _send({required bool edit}) async {
    final client = _client();
    final table = _table;
    if (client == null || table == null || _items.isEmpty) {
      setState(() => _status = 'Masa ve ürün seçilmeden sipariş gönderilmez.');
      return;
    }
    final localId = _localOrderId ?? 'lan-${DateTime.now().microsecondsSinceEpoch}';
    final revision = edit ? _revision + 1 : _revision;
    setState(() => _busy = true);
    try {
      final response = await client.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': localId,
        'restaurant_id': widget.restaurantId,
        'table_number': table['table_number'] ?? table['number'] ?? table['id'],
        'table_name': table['name'] ?? table['table_name'] ?? '',
        'revision': '$revision',
        'station_id': _items.first['station_id'] ?? '',
        'items': _items,
      });
      await _remember(client);
      if (response['status'] == 401) {
        setState(() {
          _status = response['error']?.toString() ??
              'Cihaz eşleşmesi yok veya iptal edildi.';
        });
        return;
      }
      final decision = decideLanOrderSubmit(
        paired: true,
        hostReachable: true,
        hostSaved: response['saved'] == true,
      );
      if (!mounted) return;
      if (!decision.showSuccess) {
        setState(() => _status = decision.error ?? 'Sipariş gönderilmedi.');
        return;
      }
      setState(() {
        _localOrderId = localId;
        _revision = revision;
        _status = 'Yerel sipariş kaydedildi';
      });
    } on SocketException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Merkeze ulaşılamıyor. Sipariş kaydedilmedi.');
      debugPrint(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _purple,
        elevation: 0,
        title: const Text('Garson cihazı'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kIsWeb)
            Text(
              lanDiscoveryUnavailableMessage(
                isWeb: true,
                operatingSystem: 'web',
              ),
            ),
          Text(_status),
          if (!RestaurantConnectivityService.instance.supabaseReachable)
            const Text('İnternet yok, yerel ağ çalışıyor'),
          for (final record in _found)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.restaurantId),
              subtitle: Text('${record.machineId} · ${record.host}'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _qrController,
            decoration: const InputDecoration(
              labelText: 'QR metni',
              helperText: 'Mac ekranındaki ibul-lan bağlantısını yapıştırın.',
            ),
          ),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Ana bilgisayar adresi',
              hintText: 'https://192.168.1.20:port',
            ),
          ),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: 'Sunucu parmak izi',
              helperText: 'Mac ekranındaki parmak iziyle karşılaştırın.',
            ),
          ),
          TextField(
            controller: _staffController,
            decoration: const InputDecoration(labelText: 'Personel kimliği'),
          ),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: 'Eşleştirme kodu'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => unawaited(_findCenter()),
                child: const Text('Merkezi ara'),
              ),
              TextButton(
                onPressed: _busy ? null : () => unawaited(_scanQr()),
                child: const Text('QR oku'),
              ),
              TextButton(
                onPressed: _busy ? null : _applyQr,
                child: const Text('QR kimliğini al'),
              ),
              TextButton(
                onPressed: _busy ? null : _pair,
                child: const Text('Eşleştir'),
              ),
              TextButton(
                onPressed: _busy ? null : _reloadCatalog,
                child: const Text('Yeniden bağlan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Masalar', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final table in _tables)
            ListTile(
              title: Text('${table['name'] ?? table['table_name'] ?? table['id']}'),
              selected: _table != null && _table!['id'] == table['id'],
              onTap: () => setState(() => _table = table),
            ),
          const Text('Ürünler', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final product in _products)
            ListTile(
              title: Text('${product['name'] ?? product['title'] ?? 'Ürün'}'),
              onTap: () {
                setState(() {
                  _items.add(<String, dynamic>{
                    'name': product['name'] ?? product['title'] ?? 'Ürün',
                    'quantity': 1,
                    'station_id': product['station_id'] ?? '',
                    'service_children': <Map<String, dynamic>>[],
                  });
                });
              },
            ),
          for (var index = 0; index < _items.length; index++)
            ListTile(
              title: Text('${_items[index]['name']}'),
              subtitle: Text(
                'Karışık servis: ${(_items[index]['service_children'] as List).length}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final children = _items[index]['service_children'];
                  if (children is List) {
                    children.add(<String, dynamic>{'name': 'Ek servis'});
                    setState(() {});
                  }
                },
              ),
            ),
          TextButton(
            onPressed: _busy ? null : () => _send(edit: false),
            child: const Text('Siparişi kaydet ve mutfak fişi iste'),
          ),
          TextButton(
            onPressed: _busy || _localOrderId == null
                ? null
                : () => _send(edit: true),
            child: const Text('Siparişi düzenle'),
          ),
        ],
      ),
    );
  }
}
