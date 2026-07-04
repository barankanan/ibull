import '../models/desktop_printer_setup_models.dart';
import '../models/discovered_printer.dart';
import '../models/printer_model.dart';

/// Merge bridge scan results with saved DB printers into one normalized catalog.
class DiscoveredPrinterCatalog {
  const DiscoveredPrinterCatalog._();

  static List<DiscoveredPrinter> fromBridgeList(Object? raw) {
    if (raw is! List) return const <DiscoveredPrinter>[];
    return raw
        .whereType<Map>()
        .map(
          (entry) => DiscoveredPrinter.fromBridgeMap(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  static List<DiscoveredPrinter> fromSavedPrinters(List<PrinterModel> saved) {
    return saved
        .map(DiscoveredPrinter.fromPrinterModel)
        .toList(growable: false);
  }

  static List<DiscoveredPrinter> merge({
    required List<DiscoveredPrinter> bridgePrinters,
    required List<DiscoveredPrinter> savedPrinters,
  }) {
    final byDeviceId = <String, DiscoveredPrinter>{};

    for (final bridgePrinter in bridgePrinters) {
      byDeviceId[_mergeKey(bridgePrinter)] = bridgePrinter;
    }

    for (final saved in savedPrinters) {
      final key = _mergeKey(saved);
      final existing = byDeviceId[key];
      if (existing == null) {
        byDeviceId[key] = saved;
        continue;
      }
      byDeviceId[key] = _mergeSavedWithBridge(
        saved: saved,
        bridge: existing,
      );
    }

    return _applyDuplicateFlags(byDeviceId.values.toList(growable: false));
  }

  static List<UnifiedPrinterModel> enrichUnifiedCatalog({
    required List<UnifiedPrinterModel> printers,
    required List<PrinterModel> savedPrinters,
    required DesktopPrinterOs os,
  }) {
    final bridgeDiscovered = printers
        .where((printer) => printer.isLiveDiscovery)
        .map(DiscoveredPrinter.fromUnifiedPrinter)
        .toList(growable: false);
    final savedDiscovered = fromSavedPrinters(
      savedPrinters.where((p) => p.isEthernetConnection).toList(growable: false),
    );
    final merged = merge(
      bridgePrinters: bridgeDiscovered,
      savedPrinters: savedDiscovered,
    );
    final mergedByDeviceId = <String, DiscoveredPrinter>{
      for (final printer in merged) _mergeKey(printer): printer,
    };

    final enriched = <UnifiedPrinterModel>[];
    final seenKeys = <String>{};

    for (final printer in printers) {
      final discovered = DiscoveredPrinter.fromUnifiedPrinter(printer);
      final key = _mergeKey(discovered);
      final normalized = mergedByDeviceId[key] ?? discovered;
      seenKeys.add(key);
      enriched.add(
        _applyDiscoveredToUnified(
          printer: printer,
          discovered: normalized,
          os: os,
        ),
      );
    }

    for (final saved in savedDiscovered) {
      final key = _mergeKey(saved);
      if (seenKeys.contains(key)) continue;
      enriched.add(saved.toUnifiedPrinter(os: os));
    }

    return enriched;
  }

  static bool hasUsbCupsDuplicateConflict(List<UnifiedPrinterModel> printers) {
    return detectUsbCupsDuplicateGroups(printers).isNotEmpty;
  }

  static List<DiscoveredPrinterDuplicateGroup> detectUsbCupsDuplicateGroups(
    List<UnifiedPrinterModel> printers,
  ) {
    final usb = <DiscoveredPrinter>[];
    final cups = <DiscoveredPrinter>[];
    for (final printer in printers) {
      final discovered = DiscoveredPrinter.fromUnifiedPrinter(printer);
      if (discovered.backend == DiscoveredPrinterBackend.usbDirect &&
          _looksLikePos58Family(discovered)) {
        usb.add(discovered);
      }
      if (discovered.backend == DiscoveredPrinterBackend.cups &&
          _looksLikePos58Family(discovered)) {
        cups.add(discovered);
      }
    }
    if (usb.isEmpty || cups.isEmpty) {
      return const <DiscoveredPrinterDuplicateGroup>[];
    }
    return <DiscoveredPrinterDuplicateGroup>[
      DiscoveredPrinterDuplicateGroup(usb: usb, cups: cups),
    ];
  }

  static String usbCupsDuplicateMessage() {
    return 'Bu yazıcı iki farklı bağlantı yoluyla görünüyor (USB Direct ve CUPS). '
        'Karışıklık yaşamamak için yalnızca birini seçin.';
  }

  static String _mergeKey(DiscoveredPrinter printer) {
    final deviceId = printer.deviceId.trim().toLowerCase();
    if (deviceId.isNotEmpty) return deviceId;
    return '${printer.backend.value}:${printer.displayName.trim().toLowerCase()}';
  }

  static DiscoveredPrinter _mergeSavedWithBridge({
    required DiscoveredPrinter saved,
    required DiscoveredPrinter bridge,
  }) {
    final configuredIp = saved.configuredIp.isNotEmpty
        ? saved.configuredIp
        : saved.ip;
    final lastSeenIp = bridge.ip.isNotEmpty ? bridge.ip : bridge.configuredIp;
    final ipMismatch = configuredIp.isNotEmpty &&
        lastSeenIp.isNotEmpty &&
        configuredIp != lastSeenIp;

    return DiscoveredPrinter(
      backend: bridge.backend,
      deviceId: bridge.deviceId.isNotEmpty ? bridge.deviceId : saved.deviceId,
      displayName: bridge.displayName.isNotEmpty
          ? bridge.displayName
          : saved.displayName,
      ip: lastSeenIp.isNotEmpty ? lastSeenIp : configuredIp,
      port: bridge.port > 0 ? bridge.port : saved.port,
      queueName: bridge.queueName.isNotEmpty ? bridge.queueName : saved.queueName,
      vendorId: bridge.vendorId ?? saved.vendorId,
      productId: bridge.productId ?? saved.productId,
      isOnline: bridge.isOnline,
      source: DiscoveredPrinterSource.bridge,
      rawBridgeId: bridge.rawBridgeId.isNotEmpty
          ? bridge.rawBridgeId
          : saved.rawBridgeId,
      dbPrinterId: saved.dbPrinterId ?? bridge.dbPrinterId,
      isStaleSavedMapping: false,
      configuredIp: configuredIp,
      lastSeenIp: lastSeenIp,
      ipMismatchWarning: ipMismatch
          ? 'Bu yazıcının kayıtlı IP adresi ($configuredIp) ile bulunan IP '
                'adresi ($lastSeenIp) farklı olabilir.'
          : '',
      statusMessage: bridge.statusMessage,
    );
  }

  static List<DiscoveredPrinter> _applyDuplicateFlags(
    List<DiscoveredPrinter> printers,
  ) {
    final usbKeys = <String>{};
    final cupsKeys = <String>{};
    for (final printer in printers) {
      if (!_looksLikePos58Family(printer)) continue;
      final fingerprint = _physicalFingerprint(printer);
      if (printer.backend == DiscoveredPrinterBackend.usbDirect) {
        usbKeys.add(fingerprint);
      }
      if (printer.backend == DiscoveredPrinterBackend.cups) {
        cupsKeys.add(fingerprint);
      }
    }
    final hasOverlap = usbKeys.intersection(cupsKeys).isNotEmpty;
    if (!hasOverlap) return printers;

    return printers
        .map(
          (printer) => DiscoveredPrinter(
            backend: printer.backend,
            deviceId: printer.deviceId,
            displayName: printer.displayName,
            ip: printer.ip,
            port: printer.port,
            queueName: printer.queueName,
            vendorId: printer.vendorId,
            productId: printer.productId,
            isOnline: printer.isOnline,
            source: printer.source,
            rawBridgeId: printer.rawBridgeId,
            dbPrinterId: printer.dbPrinterId,
            isStaleSavedMapping: printer.isStaleSavedMapping,
            isDuplicateCandidate:
                _looksLikePos58Family(printer) &&
                (printer.backend == DiscoveredPrinterBackend.usbDirect ||
                    printer.backend == DiscoveredPrinterBackend.cups),
            configuredIp: printer.configuredIp,
            lastSeenIp: printer.lastSeenIp,
            ipMismatchWarning: printer.ipMismatchWarning,
            statusMessage: printer.statusMessage,
          ),
        )
        .toList(growable: false);
  }

  static UnifiedPrinterModel _applyDiscoveredToUnified({
    required UnifiedPrinterModel printer,
    required DiscoveredPrinter discovered,
    required DesktopPrinterOs os,
  }) {
    final mergedRaw = <String, dynamic>{
      ...printer.raw,
      ...discovered.toRawFields(),
      'source': discovered.source.value,
      'deviceIdentifier': discovered.deviceId,
      'device_identifier': discovered.deviceId,
      if (discovered.ip.isNotEmpty) ...<String, dynamic>{
        'host': discovered.ip,
        'ip_address': discovered.ip,
        'ipAddress': discovered.ip,
        'port': discovered.port,
      },
      'isSavedOnly': discovered.isStaleSavedMapping,
      if (discovered.statusMessage.isNotEmpty)
        'statusMessage': discovered.statusMessage,
      if (discovered.statusMessage.isNotEmpty)
        'discoveredStatusMessage': discovered.statusMessage,
    };
    return UnifiedPrinterModel.fromBridgeMap(mergedRaw, os: os).copyWith(
      printerRecordId: printer.printerRecordId ?? discovered.dbPrinterId,
      isAvailable: discovered.isOnline,
      canPrint: discovered.isOnline && !discovered.isStaleSavedMapping,
    );
  }

  static bool _looksLikePos58Family(DiscoveredPrinter printer) {
    final text =
        '${printer.displayName} ${printer.queueName} ${printer.deviceId} '
                '${printer.vendorId ?? ''} ${printer.productId ?? ''}'
            .toLowerCase();
    return text.contains('pos58') ||
        text.contains('pos-58') ||
        text.contains('stmicroelectronics') ||
        text.contains('0416');
  }

  static String _physicalFingerprint(DiscoveredPrinter printer) {
    if (printer.vendorId != null &&
        printer.productId != null &&
        printer.vendorId!.isNotEmpty &&
        printer.productId!.isNotEmpty) {
      return '${printer.vendorId}:${printer.productId}'.toLowerCase();
    }
    return printer.displayName.trim().toLowerCase();
  }
}

class DiscoveredPrinterDuplicateGroup {
  const DiscoveredPrinterDuplicateGroup({
    required this.usb,
    required this.cups,
  });

  final List<DiscoveredPrinter> usb;
  final List<DiscoveredPrinter> cups;
}
