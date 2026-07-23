// Android garson sipariş (adisyon) baskısı — direct TCP.
//
// Masaüstünde adisyon, local print bridge veya Supabase print-station
// kuyruğu üzerinden basılır. Android telefonda ikisi de yoktur: kuyruğa
// düşen işleri basacak istasyon çalışmaz. Bu servis, kayıtlı Ethernet
// yazıcısını Supabase'ten çözümler, garson adisyon payload'ını ESC/POS
// byte'larına çevirir ve test fişiyle AYNI transport'tan
// ([MobileEthernetPrinterService.sendBytes]) gönderir.
//
// Sorumluluk ayrımı:
//   - Routing:   [resolveReceiptPrinter] (rol → aktif Ethernet fallback)
//   - Builder:   [MobileEscPosOrderReceipt] (saf, testlenebilir)
//   - Transport: [MobileEthernetPrinterService] (test fişiyle ortak)
//   - Yönetim:   [printReceiptPayload] (boş liste guard'ı, duplicate engeli)

import 'package:flutter/foundation.dart';

import '../models/printer_model.dart';
import '../models/printer_profile.dart';
import 'mobile_ethernet_printer_service.dart';
import 'printer_error_messages.dart';
import 'printer_repository.dart';

class MobileOrderPrintService {
  MobileOrderPrintService({
    MobileEthernetPrinterService? transport,
    Future<List<PrinterModel>> Function(String restaurantId)? fetchPrinters,
    DateTime Function()? now,
  })  : _transport = transport ?? MobileEthernetPrinterService(),
        _fetchPrinters =
            fetchPrinters ?? ((id) => PrinterRepository().fetchPrinters(id)),
        _now = now ?? DateTime.now;

  final MobileEthernetPrinterService _transport;
  final Future<List<PrinterModel>> Function(String restaurantId) _fetchPrinters;
  final DateTime Function() _now;

  /// Direct TCP sipariş baskısının etkin olduğu platform: yalnız Android.
  /// Web agent yoluyla, masaüstü bridge ile basar; iOS mevcut kuyruk
  /// davranışını korur.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Aynı sipariş kısa aralıkta ikinci kez basılmasın (çift dokunma vb.).
  static final Map<String, DateTime> _recentPrints = <String, DateTime>{};
  static const Duration _duplicateWindow = Duration(seconds: 8);

  @visibleForTesting
  static void resetDuplicateGuardForTest() => _recentPrints.clear();

  /// Adisyon için kullanılacak kayıtlı yazıcıyı çözer.
  ///
  /// Sıra: aktif + Ethernet + `receipt` rolü → rolü boş (atanmamış) aktif
  /// Ethernet → herhangi bir aktif Ethernet. Uygulama yeniden başlasa da
  /// çalışır; kayıt Supabase `printers` tablosundadır.
  Future<PrinterModel?> resolveReceiptPrinter(String restaurantId) async {
    final printers = await _fetchPrinters(restaurantId);
    final candidates = <PrinterModel>[
      for (final printer in printers)
        if (printer.isActive && printer.isEthernetConnection) printer,
    ];
    if (candidates.isEmpty) return null;
    for (final printer in candidates) {
      if (printer.assignedRoles.contains(PrinterRole.receipt)) return printer;
    }
    for (final printer in candidates) {
      if (printer.assignedRoles.isEmpty) return printer;
    }
    return candidates.first;
  }

  /// Garson adisyon payload'ını basar. Payload sözleşmesi
  /// `_buildGarsonReceiptPayload` çıktısıdır (items/store_name/table...).
  ///
  /// Asla sessizce "başarılı" dönmez: boş ürün listesi, yazıcı yokluğu ve
  /// transport hataları açık diagnostic ile döner; socket yalnız gerçek
  /// içerik varken açılır.
  Future<EthernetConnectionDiagnostic> printReceiptPayload({
    required String restaurantId,
    required Map<String, dynamic> payload,
    required String orderId,
    String flowName = 'waiter_receipt',
  }) async {
    final normalizedOrderId = orderId.trim();
    final dedupeKey = '$restaurantId|$normalizedOrderId|$flowName';
    if (normalizedOrderId.isNotEmpty) {
      final lastPrint = _recentPrints[dedupeKey];
      if (lastPrint != null &&
          _now().difference(lastPrint) < _duplicateWindow) {
        _logRoute(
          orderId: normalizedOrderId,
          printer: null,
          totalItems: -1,
          printableItems: -1,
          note: 'duplicate_suppressed',
        );
        return const EthernetConnectionDiagnostic(
          ok: false,
          errorCode: 'duplicate_print_suppressed',
          title: 'Baskı zaten gönderildi',
          message: 'Bu adisyon az önce yazdırıldı. Lütfen bekleyin.',
        );
      }
    }

    final items = MobileEscPosOrderReceipt.extractItems(payload);
    if (items.isEmpty) {
      _logRoute(
        orderId: normalizedOrderId,
        printer: null,
        totalItems: 0,
        printableItems: 0,
        note: 'empty_items_no_socket',
      );
      return const EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'empty_items',
        title: 'Basılacak ürün yok',
        message:
            'Adisyonda basılacak ürün bulunamadı. Siparişi yenileyip tekrar '
            'deneyin.',
      );
    }

    final PrinterModel? printer;
    try {
      printer = await resolveReceiptPrinter(restaurantId);
    } catch (error) {
      return EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'printer_lookup_failed',
        title: 'Yazıcı bilgisi alınamadı',
        message:
            'Kayıtlı yazıcı bilgisi alınamadı. İnternet bağlantısını kontrol '
            'edip tekrar deneyin.',
        technicalDetail: error.toString(),
      );
    }
    if (printer == null) {
      _logRoute(
        orderId: normalizedOrderId,
        printer: null,
        totalItems: items.length,
        printableItems: items.length,
        note: 'no_active_ethernet_printer',
      );
      return const EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'printer_not_found',
        title: 'Adisyon yazıcısı bulunamadı',
        message:
            'Kayıtlı aktif Ethernet yazıcı yok. Yazıcı Ayarları\'ndan '
            'Ethernet yazıcı ekleyin.',
      );
    }

    _logRoute(
      orderId: normalizedOrderId,
      printer: printer,
      totalItems: items.length,
      printableItems: items.length,
      note: 'dispatch',
    );

    final profile = PrinterProfile.byId(printer.printerProfileId) ??
        PrinterProfile.fallbackFor(printer);
    final bytes = MobileEscPosOrderReceipt.build(
      payload: payload,
      items: items,
      charsPerLine: profile.charsPerLine,
      autoCut: printer.supportsCut && profile.supportsCut,
    );

    if (kDebugMode) {
      debugPrint(
        '[AndroidPrinter][transport] orderId=$normalizedOrderId '
        'byteLength=${bytes.length} connectStarted=true '
        'target=${printer.ethernetHost}:${printer.ethernetPort}',
      );
    }
    final result = await _transport.sendBytes(
      host: printer.ethernetHost,
      port: printer.ethernetPort,
      bytes: bytes,
    );
    if (kDebugMode) {
      debugPrint(
        '[AndroidPrinter][transport] orderId=$normalizedOrderId '
        'connectSuccess=${result.ok} sendSuccess=${result.ok} '
        'socketClosed=true errorType=${result.ok ? '-' : result.errorCode}',
      );
    }
    if (result.ok && normalizedOrderId.isNotEmpty) {
      _recentPrints[dedupeKey] = _now();
      // Haritayı sınırla; eski girdileri temizle.
      if (_recentPrints.length > 32) {
        final cutoff = _now().subtract(_duplicateWindow);
        _recentPrints.removeWhere((_, at) => at.isBefore(cutoff));
      }
    }
    return result;
  }

  void _logRoute({
    required String orderId,
    required PrinterModel? printer,
    required int totalItems,
    required int printableItems,
    required String note,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[AndroidPrinter][route] orderId=$orderId '
      'printerId=${printer?.id ?? '-'} '
      'printerIp=${printer?.ethernetHost ?? '-'} '
      'printerPort=${printer?.ethernetPort ?? '-'} '
      'printerType=${printer == null ? '-' : 'ethernet_tcp'} '
      'active=${printer?.isActive ?? '-'} '
      'assignedRoles=${printer?.assignedRoles.map((r) => r.value).join(',') ?? '-'} '
      'totalOrderItems=$totalItems '
      'filteredPrintableItems=$printableItems '
      'note=$note',
    );
  }
}

/// Garson adisyon payload'ını ESC/POS byte'larına çeviren SAF builder.
/// Alan adları farklı kaynaklardan güvenli okunur; Türkçe CP857 ile basılır.
class MobileEscPosOrderReceipt {
  MobileEscPosOrderReceipt._();

  static const List<int> _init = <int>[0x1B, 0x40];
  static const List<int> _codepageCp857 = <int>[0x1B, 0x74, 13];
  static const List<int> _alignCenter = <int>[0x1B, 0x61, 1];
  static const List<int> _alignLeft = <int>[0x1B, 0x61, 0];
  static const List<int> _boldOn = <int>[0x1B, 0x45, 1];
  static const List<int> _boldOff = <int>[0x1B, 0x45, 0];
  static const List<int> _doubleSize = <int>[0x1D, 0x21, 0x11];
  static const List<int> _normalSize = <int>[0x1D, 0x21, 0x00];
  static const List<int> _lf = <int>[0x0A];

  static String? _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return null;
  }

  /// Ürün adını farklı alan adlarından güvenli okur.
  @visibleForTesting
  static String resolveItemName(Map<String, dynamic> item) {
    return _firstNonEmpty(item, const <String>[
          'display_label',
          'name',
          'product_name',
          'productName',
          'title',
          'item_name',
        ]) ??
        '-';
  }

  /// Adet: int, double veya string olabilir; 0/negatif → 1.
  @visibleForTesting
  static int resolveQuantity(Map<String, dynamic> item) {
    for (final key in const <String>['qty', 'quantity', 'count', 'amount']) {
      final raw = item[key];
      if (raw == null) continue;
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '.'));
      if (parsed != null && parsed > 0) return parsed.round().clamp(1, 9999);
    }
    return 1;
  }

  static double _resolveMoney(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final raw = item[key];
      if (raw == null) continue;
      final parsed = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  /// Sipariş payload'ından ürün listesini güvenli çıkarır; farklı alan
  /// adlarını dener ve Map olmayan girdileri atlar.
  static List<Map<String, dynamic>> extractItems(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'items',
      'order_items',
      'orderItems',
      'cart_items',
      'cartItems',
    ]) {
      final raw = payload[key];
      if (raw is List) {
        final items = <Map<String, dynamic>>[
          for (final entry in raw)
            if (entry is Map) Map<String, dynamic>.from(entry),
        ];
        if (items.isNotEmpty) return items;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static List<int> _line(String text) =>
      <int>[...MobileEscPosTestReceipt.encodeCp857(text), ..._lf];

  /// Sol metin + sağa hizalı tutar tek satırda; sığmazsa ad kısaltılır.
  @visibleForTesting
  static String formatLine(String left, String right, int width) {
    final safeWidth = width.clamp(16, 64);
    if (right.isEmpty) {
      return left.length <= safeWidth ? left : left.substring(0, safeWidth);
    }
    final available = safeWidth - right.length - 1;
    if (available <= 0) return right;
    final trimmedLeft =
        left.length <= available ? left : left.substring(0, available);
    return '$trimmedLeft${' ' * (safeWidth - trimmedLeft.length - right.length)}$right';
  }

  static String _money(double value) => value.toStringAsFixed(2);

  /// Adisyon fişi ESC/POS payload'ı. [items] önceden [extractItems] ile
  /// çıkarılmış olmalı; boş listeyle çağrılmamalıdır (guard üst katmanda).
  static List<int> build({
    required Map<String, dynamic> payload,
    required List<Map<String, dynamic>> items,
    int charsPerLine = 32,
    bool autoCut = true,
  }) {
    final width = charsPerLine.clamp(16, 64);
    final divider = '-' * width;
    final storeName = _firstNonEmpty(payload, const ['store_name']) ?? 'Mağaza';
    final branch = _firstNonEmpty(payload, const ['branch']);
    final phone = _firstNonEmpty(payload, const ['phone']);
    final tableLabel = _firstNonEmpty(payload, const [
          'display_table_label',
          'table_display_name',
          'table_name',
        ]) ??
        'Masa ${_firstNonEmpty(payload, const ['table_no']) ?? '-'}';
    final headerNote = _firstNonEmpty(payload, const [
      'header_note',
      'reprint_label',
    ]);
    final footerNote = _firstNonEmpty(payload, const ['footer_note']);
    final createdAtRaw = _firstNonEmpty(payload, const [
      'order_created_at',
      'created_at',
      'datetime',
    ]);
    final createdAt =
        DateTime.tryParse(createdAtRaw ?? '')?.toLocal() ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final dateLine =
        '${two(createdAt.day)}.${two(createdAt.month)}.${createdAt.year} '
        '${two(createdAt.hour)}:${two(createdAt.minute)}';

    var computedTotal = 0.0;
    final itemBytes = <int>[];
    for (final item in items) {
      final name = resolveItemName(item);
      final qty = resolveQuantity(item);
      final lineTotal = _resolveMoney(item, const [
        'total',
        'line_total',
        'lineTotal',
      ]);
      final effectiveTotal = lineTotal != 0
          ? lineTotal
          : _resolveMoney(item, const ['price', 'unit_price', 'unitPrice']) *
              qty;
      computedTotal += effectiveTotal;
      itemBytes.addAll(
        _line(formatLine('$qty x $name', _money(effectiveTotal), width)),
      );
      final amountLabel = _firstNonEmpty(item, const ['amount_label']);
      if (amountLabel != null) {
        itemBytes.addAll(_line('   $amountLabel'));
      }
      final note = _firstNonEmpty(item, const [
        'note',
        'item_note',
        'itemNote',
        'customer_note',
        'customerNote',
      ]);
      if (note != null) {
        itemBytes.addAll(_line('   Not: $note'));
      }
      if (kDebugMode) {
        debugPrint(
          '[AndroidPrinter][item] productName=$name quantity=$qty '
          'included=true exclusionReason=-',
        );
      }
    }

    final grandTotal = _resolveMoney(payload, const ['grand_total']) != 0
        ? _resolveMoney(payload, const ['grand_total'])
        : computedTotal;

    return <int>[
      ..._init,
      ..._codepageCp857,
      ..._alignCenter,
      ..._doubleSize,
      ..._boldOn,
      ..._line(storeName),
      ..._normalSize,
      ..._boldOff,
      if (branch != null) ..._line(branch),
      if (phone != null) ..._line('Tel: $phone'),
      if (headerNote != null) ...[
        ..._lf,
        ..._boldOn,
        ..._line(headerNote),
        ..._boldOff,
      ],
      ..._lf,
      ..._alignLeft,
      ..._line(divider),
      ..._boldOn,
      ..._line(tableLabel),
      ..._boldOff,
      ..._line('Tarih: $dateLine'),
      ..._line(divider),
      ...itemBytes,
      ..._line(divider),
      ..._boldOn,
      ..._line(formatLine('TOPLAM', '${_money(grandTotal)} TL', width)),
      ..._boldOff,
      if (footerNote != null) ...[
        ..._line(divider),
        ..._alignCenter,
        ..._line(footerNote),
        ..._alignLeft,
      ],
      ..._lf,
      ..._lf,
      ..._lf,
      if (autoCut) ...MobileEscPosTestReceipt.cutCommand,
    ];
  }
}
