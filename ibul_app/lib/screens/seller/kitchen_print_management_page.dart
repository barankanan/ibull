import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/printer_model.dart';
import '../../models/print_job_model.dart';
import '../../models/seller_product.dart';
import '../../models/station_model.dart';
import '../../models/station_printer_model.dart';
import '../../models/mixed_service_order.dart';
import '../../services/order_print_job_service.dart';
import '../../services/print_job_repository.dart';
import '../../services/printer_repository.dart';
import '../../services/station_repository.dart';
import '../../services/store_service.dart';

class KitchenPrintManagementPage extends StatefulWidget {
  const KitchenPrintManagementPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<KitchenPrintManagementPage> createState() =>
      _KitchenPrintManagementPageState();
}

class _KitchenPrintManagementPageState
    extends State<KitchenPrintManagementPage> {
  final StationRepository _stationRepository = StationRepository();
  final PrinterRepository _printerRepository = PrinterRepository();
  final PrintJobRepository _printJobRepository = PrintJobRepository();
  final OrderPrintJobService _orderPrintJobService = OrderPrintJobService();
  final StoreService _storeService = StoreService();

  final Map<String, String?> _productStationDraft = <String, String?>{};
  final Map<String, bool> _productRoutingDraft = <String, bool>{};
  final Map<String, String?> _stationPrinterDraft = <String, String?>{};
  bool _isSavingProductRouting = false;
  String _printStatusFilter = 'all';
  int _printersRefreshNonce = 0;
  int _assignmentsRefreshNonce = 0;
  int _productsRefreshNonce = 0;
  late Stream<List<PrinterModel>> _printersStream;
  late Future<List<dynamic>> _assignmentsFuture;
  late Future<List<dynamic>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _printersStream = _createPrintersStream();
    _assignmentsFuture = _loadAssignmentsData();
    _productsFuture = _loadProductRoutingData();
    _logPrinterSettings(
      'Init',
      'screen=KitchenPrintManagementPage openedTab=printers sellerId=${widget.restaurantId} '
          'storeId=- backendPath=printers?restaurant_id=eq.${widget.restaurantId}&order=created_at.asc',
    );
  }

  Future<List<dynamic>> _loadAssignmentsData() async {
    _logPrinterSettings(
      'Assignments',
      'fetchStart restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=- selectedAreaId=- emptyBranch=pending',
    );
    try {
      final results = await Future.wait<dynamic>([
        _stationRepository.fetchStations(widget.restaurantId),
        _printerRepository.fetchPrinters(widget.restaurantId),
        _printerRepository.fetchStationPrinterMappings(widget.restaurantId),
      ]);
      final stations = results[0] as List<StationModel>;
      final printers = (results[1] as List<PrinterModel>)
          .where((printer) => printer.isActive)
          .toList(growable: false);
      final mappings = results[2] as List<StationPrinterModel>;
      final emptyBranch = stations.isEmpty
          ? 'no_areas'
          : printers.isEmpty
          ? 'no_active_printers'
          : mappings.isEmpty
          ? 'no_assignments'
          : 'has_rows';
      _logPrinterSettings(
        'Assignments',
        'fetchSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=- selectedAreaId=- emptyBranch=$emptyBranch',
      );
      return <dynamic>[stations, printers, mappings];
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Assignments',
        'fetchFail restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=- selectedAreaId=- emptyBranch=fetch_error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<dynamic>> _loadProductRoutingData() async {
    _logPrinterSettings(
      'Products',
      'fetchStart restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=- emptyBranch=pending',
    );
    try {
      final results = await Future.wait<dynamic>([
        _storeService.getMenuProductsBySellerId(widget.restaurantId),
        _stationRepository.fetchStations(widget.restaurantId),
      ]);
      final products = (results[0] as List<dynamic>)
          .whereType<Map>()
          .map(
            (row) => SellerProduct.fromMap(
              Map<String, dynamic>.from(row),
              row['id']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
      final stations = results[1] as List<StationModel>;
      final emptyBranch = products.isEmpty
          ? 'no_products'
          : stations.isEmpty
          ? 'no_areas'
          : 'has_rows';
      _logPrinterSettings(
        'Products',
        'fetchSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} productCount=${products.length} selectedAreaId=- emptyBranch=$emptyBranch',
      );
      return <dynamic>[products, stations];
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Products',
        'fetchFail restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=- emptyBranch=fetch_error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _showStationEditor({StationModel? station}) async {
    final nameCtrl = TextEditingController(text: station?.name ?? '');
    final codeCtrl = TextEditingController(text: station?.code ?? '');
    final colorCtrl = TextEditingController(text: station?.color ?? '');
    var isActive = station?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              station == null ? 'Yeni Hazırlama Alanı' : 'Alan Düzenle',
            ),
            content: StatefulBuilder(
              builder: (ctx, setSheet) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Alan Adı',
                        ),
                      ),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kod (örn: OCAK)',
                        ),
                      ),
                      TextField(
                        controller: colorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Renk (opsiyonel)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isActive,
                        onChanged: (value) => setSheet(() => isActive = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktif'),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );

      if (saved != true) return;
      if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alan adı ve kod zorunludur.')),
        );
        return;
      }

      await _stationRepository.upsertStation(
        restaurantId: widget.restaurantId,
        stationId: station?.id,
        name: nameCtrl.text,
        code: codeCtrl.text,
        color: colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
        isActive: isActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            station == null
                ? 'Hazırlama alanı eklendi.'
                : 'Hazırlama alanı güncellendi.',
          ),
        ),
      );
      _triggerAssignmentsRefresh(reason: 'stationSaved');
      _triggerProductsRefresh(reason: 'stationSaved');
    } finally {
      nameCtrl.dispose();
      codeCtrl.dispose();
      colorCtrl.dispose();
    }
  }

  Future<void> _showPrinterEditor({PrinterModel? printer}) async {
    final initialConnectionType =
        printer?.formConnectionType ?? PrinterModel.localConnectionType;
    final nameCtrl = TextEditingController(text: printer?.name ?? '');
    final codeCtrl = TextEditingController(text: printer?.code ?? '');
    final hostCtrl = TextEditingController(
      text: initialConnectionType == PrinterModel.localConnectionType
          ? (printer?.resolvedHost ?? PrinterModel.localDefaultHost)
          : (printer?.ipAddress ?? ''),
    );
    final portCtrl = TextEditingController(
      text: initialConnectionType == PrinterModel.localConnectionType
          ? (printer?.resolvedPort ?? PrinterModel.localDefaultPort).toString()
          : (printer?.port?.toString() ?? ''),
    );
    final targetCtrl = TextEditingController(
      text: printer == null
          ? _suggestLocalPrinterRoute(
              printerName: nameCtrl.text,
              printerCode: codeCtrl.text,
            )
          : initialConnectionType == PrinterModel.localConnectionType
          ? printer.targetRoute
          : (printer.deviceIdentifier ?? ''),
    );
    final widthCtrl = TextEditingController(
      text: (printer?.paperWidthMm ?? PrinterModel.defaultPaperWidthMm)
          .toString(),
    );
    var connectionType = initialConnectionType;
    var isActive = printer?.isActive ?? true;
    String? formError;
    StateSetter? setDialogState;

    _logPrinterSettings(
      'Form',
      'open ${_printerFormLogFields(connectionType: connectionType, host: hostCtrl.text, port: portCtrl.text, route: targetCtrl.text, printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
    );

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(printer == null ? 'Yeni Yazıcı' : 'Yazıcı Düzenle'),
            content: StatefulBuilder(
              builder: (ctx, setSheet) {
                setDialogState = setSheet;
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Yazıcı Adı',
                        ),
                      ),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Kod'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: connectionType,
                        decoration: const InputDecoration(
                          labelText: 'Bağlantı Tipi',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PrinterModel.localConnectionType,
                            child: Text('Local'),
                          ),
                          DropdownMenuItem(
                            value: PrinterModel.networkConnectionType,
                            child: Text('Network'),
                          ),
                          DropdownMenuItem(
                            value: PrinterModel.usbConnectionType,
                            child: Text('USB'),
                          ),
                          DropdownMenuItem(
                            value: PrinterModel.bluetoothConnectionType,
                            child: Text('Bluetooth'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          final nextConnectionType =
                              _normalizePrinterFormConnectionType(value);
                          setSheet(() {
                            connectionType = nextConnectionType;
                            formError = null;
                            if (nextConnectionType ==
                                PrinterModel.localConnectionType) {
                              if (!_isLoopbackHost(hostCtrl.text)) {
                                hostCtrl.text = PrinterModel.localDefaultHost;
                              }
                              if (int.tryParse(portCtrl.text.trim()) !=
                                  PrinterModel.localDefaultPort) {
                                portCtrl.text = PrinterModel.localDefaultPort
                                    .toString();
                              }
                              final trimmedTarget = targetCtrl.text.trim();
                              if (!trimmedTarget.startsWith('/')) {
                                targetCtrl.text = _suggestLocalPrinterRoute(
                                  printerName: nameCtrl.text,
                                  printerCode: codeCtrl.text,
                                );
                              }
                              if (widthCtrl.text.trim().isEmpty) {
                                widthCtrl.text = PrinterModel
                                    .defaultPaperWidthMm
                                    .toString();
                              }
                            }
                          });
                          _logPrinterSettings(
                            'Form',
                            'connectionTypeChanged ${_printerFormLogFields(connectionType: connectionType, host: hostCtrl.text, port: portCtrl.text, route: targetCtrl.text, printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
                          );
                        },
                      ),
                      TextField(
                        controller: hostCtrl,
                        decoration: InputDecoration(
                          labelText:
                              connectionType == PrinterModel.localConnectionType
                              ? 'Host'
                              : 'IP Adresi',
                          helperText:
                              connectionType == PrinterModel.localConnectionType
                              ? 'Local bridge icin genelde 127.0.0.1 kullanilir.'
                              : 'Network yazici icin IP adresi girin.',
                        ),
                      ),
                      TextField(
                        controller: portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          helperText:
                              connectionType == PrinterModel.localConnectionType
                              ? 'Local bridge icin genelde 3001 kullanilir.'
                              : 'USB veya Bluetooth kullaniyorsaniz bos birakabilirsiniz.',
                        ),
                      ),
                      TextField(
                        controller: targetCtrl,
                        decoration: InputDecoration(
                          labelText:
                              connectionType == PrinterModel.localConnectionType
                              ? 'Route'
                              : 'Device Identifier',
                          helperText:
                              connectionType == PrinterModel.localConnectionType
                              ? 'Adisyon: /print/receipt, mutfak: /print/kitchen'
                              : 'USB/Bluetooth icin cihaz tanimi; gerekmiyorsa bos birakabilirsiniz.',
                        ),
                      ),
                      TextField(
                        controller: widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kağıt Genişliği (mm)',
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formError!,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: isActive,
                        onChanged: (value) => setSheet(() => isActive = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktif'),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () {
                  _logPrinterSettings(
                    'Form',
                    'savePressed ${_printerFormLogFields(connectionType: connectionType, host: hostCtrl.text, port: portCtrl.text, route: targetCtrl.text, printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
                  );
                  final validationMessage = _validatePrinterForm(
                    connectionType: connectionType,
                    printerName: nameCtrl.text,
                    printerCode: codeCtrl.text,
                    host: hostCtrl.text,
                    port: portCtrl.text,
                    route: targetCtrl.text,
                  );
                  if (validationMessage != null) {
                    _logPrinterSettings(
                      'Form',
                      'saveFail ${_printerFormLogFields(connectionType: connectionType, host: hostCtrl.text, port: portCtrl.text, route: targetCtrl.text, printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
                      error: validationMessage,
                      stackTrace: StackTrace.current,
                    );
                    final dialogState = setDialogState;
                    if (dialogState != null) {
                      dialogState(() => formError = validationMessage);
                    } else {
                      formError = validationMessage;
                    }
                    return;
                  }
                  final dialogState = setDialogState;
                  if (dialogState != null) {
                    dialogState(() => formError = null);
                  } else {
                    formError = null;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );

      if (saved != true) return;
      final normalizedConnectionType =
          connectionType == PrinterModel.localConnectionType
          ? PrinterModel.networkConnectionType
          : connectionType;
      final normalizedHost = hostCtrl.text.trim().isEmpty
          ? (connectionType == PrinterModel.localConnectionType
                ? PrinterModel.localDefaultHost
                : null)
          : hostCtrl.text.trim();
      final normalizedPort =
          int.tryParse(portCtrl.text.trim()) ??
          (connectionType == PrinterModel.localConnectionType
              ? PrinterModel.localDefaultPort
              : null);
      final normalizedDeviceIdentifier = targetCtrl.text.trim().isEmpty
          ? (connectionType == PrinterModel.localConnectionType
                ? _suggestLocalPrinterRoute(
                    printerName: nameCtrl.text,
                    printerCode: codeCtrl.text,
                  )
                : null)
          : targetCtrl.text.trim();

      try {
        final savedPrinter = await _printerRepository.upsertPrinter(
          restaurantId: widget.restaurantId,
          printerId: printer?.id,
          name: nameCtrl.text,
          code: codeCtrl.text,
          connectionType: normalizedConnectionType,
          ipAddress: normalizedHost,
          port: normalizedPort,
          deviceIdentifier: normalizedDeviceIdentifier,
          paperWidthMm:
              int.tryParse(widthCtrl.text.trim()) ??
              PrinterModel.defaultPaperWidthMm,
          isActive: isActive,
        );
        _logPrinterSettings(
          'Form',
          'saveSuccess ${_printerFormLogFields(connectionType: connectionType, host: normalizedHost ?? '', port: normalizedPort?.toString() ?? '', route: normalizedDeviceIdentifier ?? '', printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
        );
        _logPrinterSettings(
          'Printers',
          'saveSuccess restaurantId=${widget.restaurantId} printerCount=1 selectedPrinterId=${savedPrinter.id} emptyBranch=save_success',
        );
        _triggerPrintersRefresh(
          reason: 'printerSaved',
          selectedPrinterId: savedPrinter.id,
          printerCount: 1,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printer == null ? 'Yazıcı eklendi.' : 'Yazıcı güncellendi.',
            ),
          ),
        );
      } catch (error, stackTrace) {
        _logPrinterSettings(
          'Form',
          'saveFail ${_printerFormLogFields(connectionType: connectionType, host: normalizedHost ?? '', port: normalizedPort?.toString() ?? '', route: normalizedDeviceIdentifier ?? '', printerName: nameCtrl.text, printerCode: codeCtrl.text)}',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yazıcı kaydedilemedi: $error')));
      }
    } finally {
      nameCtrl.dispose();
      codeCtrl.dispose();
      hostCtrl.dispose();
      portCtrl.dispose();
      targetCtrl.dispose();
      widthCtrl.dispose();
    }
  }

  Future<void> _saveProductRouting(SellerProduct product) async {
    if (_isSavingProductRouting) return;
    final selectedStation =
        _productStationDraft[product.id] ?? product.stationId;
    final routingEnabled =
        _productRoutingDraft[product.id] ?? product.printerRoutingEnabled;

    _logPrinterSettings(
      'Products',
      'mappingChanged restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=pending productId=${product.id}',
    );
    setState(() => _isSavingProductRouting = true);
    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'station_id': selectedStation,
            'printer_routing_enabled': routingEnabled,
          })
          .eq('id', product.id)
          .eq('seller_id', widget.restaurantId);

      _logPrinterSettings(
        'Products',
        'saveSuccess restaurantId=${widget.restaurantId} areaCount=- productCount=1 selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=save_success productId=${product.id}',
      );
      _triggerProductsRefresh(
        reason: 'productMappingSaved',
        selectedAreaId: selectedStation,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} için yönlendirme kaydedildi.')),
      );
      setState(() {
        _productStationDraft.remove(product.id);
        _productRoutingDraft.remove(product.id);
      });
    } catch (error, stackTrace) {
      _logPrinterSettings(
        'Products',
        'saveFail restaurantId=${widget.restaurantId} areaCount=- productCount=1 selectedAreaId=${_logField(selectedStation ?? '')} emptyBranch=save_error productId=${product.id}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _isSavingProductRouting = false);
    }
  }

  Stream<List<PrinterModel>> _createPrintersStream() {
    _logPrinterSettings(
      'Printers',
      'fetchStart restaurantId=${widget.restaurantId} printerCount=- emptyBranch=pending',
    );
    return _printerRepository
        .watchPrinters(widget.restaurantId)
        .map((printers) {
          final emptyBranch = printers.isEmpty
              ? 'no_printers_db_rows'
              : 'has_rows';
          _logPrinterSettings(
            'Printers',
            'fetchSuccess restaurantId=${widget.restaurantId} printerCount=${printers.length} emptyBranch=$emptyBranch',
          );
          return printers;
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logPrinterSettings(
            'Printers',
            'fetchFail restaurantId=${widget.restaurantId} printerCount=- emptyBranch=fetch_error',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Widget _buildStationsTab() {
    return StreamBuilder<List<StationModel>>(
      stream: _stationRepository.watchStations(widget.restaurantId),
      builder: (context, snapshot) {
        final stations = snapshot.data ?? const <StationModel>[];
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _showStationEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Alan Ekle'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return Card(
                    child: ListTile(
                      title: Text(station.name),
                      subtitle: Text('Kod: ${station.code}'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Switch.adaptive(
                            value: station.isActive,
                            onChanged: (value) => _stationRepository
                                .setStationActive(station.id, value),
                          ),
                          IconButton(
                            onPressed: () =>
                                _showStationEditor(station: station),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrintersTab() {
    return StreamBuilder<List<PrinterModel>>(
      key: ValueKey<String>('printers-$_printersRefreshNonce'),
      stream: _printersStream,
      builder: (context, snapshot) {
        final printers = snapshot.data ?? const <PrinterModel>[];
        if (snapshot.hasError) {
          _logPrinterSettings(
            'Printers',
            'fetchFail restaurantId=${widget.restaurantId} printerCount=${printers.length} emptyBranch=stream_error',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _showPrinterEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Yazıcı Ekle'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Yazıcılar yüklenemedi.'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (printers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Kayıtlı yazıcı bulunamadı. Bu sekme veritabanındaki yazıcı kayıtlarını listeler.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: printers.length,
                    itemBuilder: (context, index) {
                      final printer = printers[index];
                      return Card(
                        child: ListTile(
                          title: Text(printer.name),
                          subtitle: Text(printer.listSubtitle),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              Switch.adaptive(
                                value: printer.isActive,
                                onChanged: (value) async {
                                  await _printerRepository.setPrinterActive(
                                    printer.id,
                                    value,
                                  );
                                  _triggerAssignmentsRefresh(
                                    reason: 'printerActiveChanged',
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _showPrinterEditor(printer: printer),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMappingTab() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<String>('assignments-$_assignmentsRefreshNonce'),
      future: _assignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Eşleştirmeler yüklenemedi.'));
        }

        final stations = snapshot.data?[0] as List<StationModel>? ?? const [];
        final printers = snapshot.data?[1] as List<PrinterModel>? ?? const [];
        final mappings =
            snapshot.data?[2] as List<StationPrinterModel>? ?? const [];

        if (stations.isEmpty) {
          return const Center(child: Text('Hazırlama alanı bulunamadı.'));
        }

        return ListView.builder(
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            final stationMappings = mappings
                .where((mapping) => mapping.stationId == station.id)
                .toList(growable: false);
            final primaryMapping = _resolvePrimaryStationMapping(
              stationMappings,
            );
            final selectedPrinterId =
                _stationPrinterDraft[station.id] ??
                _normalizeSelectedPrinterId(
                  printers: printers,
                  selectedPrinterId: primaryMapping?.printerId,
                );

            return Card(
              child: ListTile(
                title: Text(station.name),
                subtitle: Text(
                  primaryMapping == null
                      ? 'Yazıcı atanmadı'
                      : (primaryMapping.printerName ??
                            primaryMapping.printerId),
                ),
                trailing: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'station-${station.id}-printer-${selectedPrinterId ?? 'none'}-$_assignmentsRefreshNonce',
                    ),
                    initialValue: selectedPrinterId,
                    hint: const Text('Yazıcı Seç'),
                    items: printers
                        .map(
                          (printer) => DropdownMenuItem<String>(
                            value: printer.id,
                            child: Text(printer.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: printers.isEmpty
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() {
                              _stationPrinterDraft[station.id] = value;
                            });
                            _logPrinterSettings(
                              'Assignments',
                              'dropdownChanged restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=selection_changed',
                            );
                            try {
                              await _printerRepository.assignPrinterToStation(
                                stationId: station.id,
                                printerId: value,
                                isPrimary: true,
                              );
                              _logPrinterSettings(
                                'Assignments',
                                'saveSuccess restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=save_success',
                              );
                              setState(() {
                                _stationPrinterDraft.remove(station.id);
                              });
                              _triggerAssignmentsRefresh(
                                reason: 'stationPrinterSaved',
                                selectedPrinterId: value,
                                selectedAreaId: station.id,
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.maybeOf(
                                this.context,
                              )?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${station.name} için yazıcı kaydedildi.',
                                  ),
                                ),
                              );
                            } catch (error, stackTrace) {
                              _logPrinterSettings(
                                'Assignments',
                                'saveFail restaurantId=${widget.restaurantId} areaCount=${stations.length} printerCount=${printers.length} selectedPrinterId=$value selectedAreaId=${station.id} emptyBranch=save_error',
                                error: error,
                                stackTrace: stackTrace,
                              );
                              setState(() {
                                _stationPrinterDraft.remove(station.id);
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.maybeOf(
                                this.context,
                              )?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Yazıcı eşleştirilemedi: $error',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductRoutingTab() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey<String>('products-$_productsRefreshNonce'),
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Ürünler yüklenemedi.'));
        }
        final products = snapshot.data?[0] as List<SellerProduct>? ?? const [];
        final stations = snapshot.data?[1] as List<StationModel>? ?? const [];

        if (products.isEmpty) {
          return const Center(child: Text('Ürün bulunamadı.'));
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final draftStation =
                _productStationDraft[product.id] ?? product.stationId;
            final draftEnabled =
                _productRoutingDraft[product.id] ??
                product.printerRoutingEnabled;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: draftStation,
                      hint: const Text('Hazırlama Alanı Seç'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Atanmadı'),
                        ),
                        ...stations.map(
                          (station) => DropdownMenuItem<String?>(
                            value: station.id,
                            child: Text(station.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        _logPrinterSettings(
                          'Products',
                          'mappingChanged restaurantId=${widget.restaurantId} areaCount=${stations.length} productCount=${products.length} selectedAreaId=${_logField(value ?? '')} emptyBranch=selection_changed productId=${product.id}',
                        );
                        setState(() {
                          _productStationDraft[product.id] = value;
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: draftEnabled,
                      onChanged: (value) {
                        setState(() {
                          _productRoutingDraft[product.id] = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Yazıcı yönlendirmesi aktif'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isSavingProductRouting
                            ? null
                            : () async {
                                try {
                                  await _saveProductRouting(product);
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Ürün alan eşlemesi kaydedilemedi: $error',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _tableNumberFromOrder(Map<String, dynamic> order) {
    final raw = order['table_number'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  DateTime _orderCreatedAt(Map<String, dynamic> order) {
    final parsed = DateTime.tryParse(order['created_at']?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _orderItems(Map<String, dynamic> order) {
    final raw = order['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => MixedServiceOrder.normalizeOrderItem(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  double _orderTotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(0, (sum, item) {
      return sum + MixedServiceOrder.itemLineTotal(item);
    });
  }

  List<MixedServiceDisplayEntry> _itemDetailLines(Map<String, dynamic> item) {
    final lines = <MixedServiceDisplayEntry>[];
    final notes = item['notes']?.toString().trim() ?? '';
    if (notes.isNotEmpty) {
      lines.add(MixedServiceDisplayEntry.item(notes));
    }
    lines.addAll(MixedServiceOrder.childItemDisplayEntries(item));
    return lines;
  }

  String _formatMoney(double amount) {
    final safe = amount.isFinite ? amount : 0;
    final text = safe.toStringAsFixed(2);
    final parts = text.split('.');
    final whole = parts[0];
    final decimal = parts.length > 1 ? parts[1] : '00';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final idxFromRight = whole.length - i;
      buffer.write(whole[i]);
      if (idxFromRight > 1 && idxFromRight % 3 == 1) {
        buffer.write('.');
      }
    }
    return '₺${buffer.toString()},$decimal';
  }

  String _orderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'waiting':
        return 'Sipariş Bekleniliyor';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'sent':
      case 'done':
        return 'Sipariş Gönderildi';
      case 'closed':
        return 'Kapalı';
      default:
        return status.isEmpty ? 'Bilinmiyor' : status;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'waiting':
        return const Color(0xFFDC2626);
      case 'preparing':
        return const Color(0xFFD97706);
      case 'sent':
      case 'done':
        return const Color(0xFF16A34A);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildIncomingOrdersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _storeService.getTableOrdersStream(widget.restaurantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Siparişler alınamadı.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders =
            (snapshot.data ?? const <Map<String, dynamic>>[])
                .where((order) {
                  final status = (order['status']?.toString() ?? '')
                      .toLowerCase();
                  return status != 'closed';
                })
                .toList(growable: false)
              ..sort(
                (a, b) => _orderCreatedAt(b).compareTo(_orderCreatedAt(a)),
              );

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  'Henüz mutfağa düşen sipariş yok.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final status = order['status']?.toString() ?? '';
            final statusColor = _orderStatusColor(status);
            final createdAt = _orderCreatedAt(order);
            final items = _orderItems(order);
            final tableNo = _tableNumberFromOrder(order);
            final orderNo = order['order_no']?.toString().trim();
            final total = _orderTotal(items);

            // Format creation time
            final timeStr =
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
            final dateStr =
                '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Adisyon başlık ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tableNo > 0
                                      ? 'MASA $tableNo'
                                      : 'MASA BİLİNMİYOR',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${orderNo == null || orderNo.isEmpty ? '' : '#$orderNo  •  '}$dateStr  $timeStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _orderStatusLabel(status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Adisyon satır başlıkları ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Text(
                              'ÜRÜN ADI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 40,
                            child: Text(
                              'ADET',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'FİYAT',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 70,
                            child: Text(
                              'TUTAR',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 12, endIndent: 12),

                    // ── Adisyon kalemleri ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        children: items
                            .map((item) {
                              final qty =
                                  (item['quantity'] as num?)?.toInt() ?? 1;
                              final name = item['name']?.toString() ?? '-';
                              final unitPrice =
                                  (item['price'] as num?)?.toDouble() ?? 0;
                              final lineTotal = unitPrice * qty;
                              final detailLines = _itemDetailLines(item);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 40,
                                          child: Text(
                                            '$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            _formatMoney(unitPrice),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            _formatMoney(lineTotal),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (detailLines.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          top: 2,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: detailLines
                                              .take(4)
                                              .map(
                                                (entry) => Text(
                                                  entry.isGroupHeader
                                                      ? entry.label
                                                      : '· ${entry.label}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    fontWeight:
                                                        entry.isGroupHeader
                                                        ? FontWeight.w700
                                                        : FontWeight.normal,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),

                    // ── Adisyon toplam ──────────────────────────────────
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items.length} kalem',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const Text(
                            'TOPLAM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatMoney(total),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrintJobsTab() {
    final chips = const [
      ('all', 'Tümü'),
      ('pending', 'Pending'),
      ('printed', 'Printed'),
      ('failed', 'Failed'),
      ('printing', 'Printing'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: chips
              .map(
                (item) => ChoiceChip(
                  label: Text(item.$2),
                  selected: _printStatusFilter == item.$1,
                  onSelected: (_) =>
                      setState(() => _printStatusFilter = item.$1),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<PrintJobModel>>(
            stream: _printJobRepository.watchJobs(
              widget.restaurantId,
              status: _printStatusFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final jobs = snapshot.data ?? const <PrintJobModel>[];
              if (jobs.isEmpty) {
                return const Center(child: Text('Print job kaydı yok.'));
              }
              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final color = switch (job.status) {
                    'failed' => const Color(0xFFDC2626),
                    'printed' => const Color(0xFF16A34A),
                    'printing' => const Color(0xFFEA580C),
                    _ => const Color(0xFF2563EB),
                  };
                  return Card(
                    child: ListTile(
                      title: Text('${job.stationName} • ${job.printerName}'),
                      subtitle: Text(
                        'Sipariş: ${job.orderNo} • ${job.tableName}\n'
                        'Durum: ${job.status} • ${job.createdAt.toLocal()} • ${job.itemCount} kalem'
                        '${(job.lastError ?? '').trim().isEmpty ? '' : '\nHata: ${job.lastError}'}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              job.status,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () async {
                              try {
                                await _orderPrintJobService.retryPrintJob(
                                  restaurantId: widget.restaurantId,
                                  printJobId: job.id,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.maybeOf(
                                  this.context,
                                )?.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Print job yeniden yazdirildi.',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.maybeOf(
                                  this.context,
                                )?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Print job tekrar gonderilemedi: $error',
                                    ),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Yeniden Dene',
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yazıcı Ayarları'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Alanlar'),
              Tab(text: 'Yazıcılar'),
              Tab(text: 'Eşleştirme'),
              Tab(text: 'Ürün Eşleme'),
              Tab(text: 'Gelen Siparişler'),
              Tab(text: 'Print Log'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: TabBarView(
            children: [
              _buildStationsTab(),
              _buildPrintersTab(),
              _buildMappingTab(),
              _buildProductRoutingTab(),
              _buildIncomingOrdersTab(),
              _buildPrintJobsTab(),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerPrintersRefresh({
    required String reason,
    String? selectedPrinterId,
    int? printerCount,
  }) {
    if (!mounted) return;
    setState(() {
      _printersRefreshNonce += 1;
      _assignmentsRefreshNonce += 1;
      _printersStream = _createPrintersStream();
      _assignmentsFuture = _loadAssignmentsData();
    });
    _logPrinterSettings(
      'Printers',
      'refreshTriggered restaurantId=${widget.restaurantId} printerCount=${printerCount ?? -1} selectedPrinterId=${_logField(selectedPrinterId ?? '')} emptyBranch=$reason',
    );
  }

  void _triggerAssignmentsRefresh({
    required String reason,
    String? selectedPrinterId,
    String? selectedAreaId,
  }) {
    if (!mounted) return;
    setState(() {
      _assignmentsRefreshNonce += 1;
      _assignmentsFuture = _loadAssignmentsData();
    });
    _logPrinterSettings(
      'Assignments',
      'refreshTriggered restaurantId=${widget.restaurantId} areaCount=- printerCount=- selectedPrinterId=${_logField(selectedPrinterId ?? '')} selectedAreaId=${_logField(selectedAreaId ?? '')} emptyBranch=$reason',
    );
  }

  void _triggerProductsRefresh({
    required String reason,
    String? selectedAreaId,
  }) {
    if (!mounted) return;
    setState(() {
      _productsRefreshNonce += 1;
      _productsFuture = _loadProductRoutingData();
    });
    _logPrinterSettings(
      'Products',
      'refreshTriggered restaurantId=${widget.restaurantId} areaCount=- productCount=- selectedAreaId=${_logField(selectedAreaId ?? '')} emptyBranch=$reason',
    );
  }

  StationPrinterModel? _resolvePrimaryStationMapping(
    List<StationPrinterModel> mappings,
  ) {
    for (final mapping in mappings) {
      if (mapping.isPrimary) {
        return mapping;
      }
    }
    return mappings.isEmpty ? null : mappings.first;
  }

  String? _normalizeSelectedPrinterId({
    required List<PrinterModel> printers,
    required String? selectedPrinterId,
  }) {
    if (selectedPrinterId == null || selectedPrinterId.isEmpty) {
      return null;
    }
    final exists = printers.any((printer) => printer.id == selectedPrinterId);
    return exists ? selectedPrinterId : null;
  }

  void _logPrinterSettings(
    String section,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint(
      '[PrinterSettings][$section] $message${error != null ? ' exception=$error' : ''}',
    );
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _isLoopbackHost(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '127.0.0.1' || normalized == 'localhost';
  }

  String _normalizePrinterFormConnectionType(String value) {
    switch (value.trim().toLowerCase()) {
      case PrinterModel.localConnectionType:
        return PrinterModel.localConnectionType;
      case PrinterModel.usbConnectionType:
        return PrinterModel.usbConnectionType;
      case PrinterModel.bluetoothConnectionType:
        return PrinterModel.bluetoothConnectionType;
      case PrinterModel.networkConnectionType:
      default:
        return PrinterModel.networkConnectionType;
    }
  }

  String _suggestLocalPrinterRoute({
    required String printerName,
    required String printerCode,
  }) {
    final fingerprint =
        '${printerName.trim().toLowerCase()} ${printerCode.trim().toLowerCase()}';
    final isKitchenRoute =
        fingerprint.contains('mutfak') || fingerprint.contains('kitchen');
    return isKitchenRoute
        ? PrinterModel.localKitchenRoute
        : PrinterModel.localReceiptRoute;
  }

  String? _validatePrinterForm({
    required String connectionType,
    required String printerName,
    required String printerCode,
    required String host,
    required String port,
    required String route,
  }) {
    if (printerName.trim().isEmpty || printerCode.trim().isEmpty) {
      return 'Yazıcı adı ve kod zorunludur.';
    }
    if (connectionType != PrinterModel.localConnectionType) {
      return null;
    }
    if (host.trim().isEmpty) {
      return 'Host alanı boş olamaz.';
    }
    if (int.tryParse(port.trim()) == null) {
      return 'Port sayısal olmalıdır.';
    }
    if (route.trim().isEmpty) {
      return 'Route alanı boş olamaz.';
    }
    if (!route.trim().startsWith('/')) {
      return 'Route `/` ile başlamalıdır.';
    }
    return null;
  }

  String _printerFormLogFields({
    required String connectionType,
    required String host,
    required String port,
    required String route,
    required String printerName,
    required String printerCode,
  }) {
    return 'connectionType=${_logField(connectionType)} '
        'host=${_logField(host)} '
        'port=${_logField(port)} '
        'route=${_logField(route)} '
        'printerName=${_logField(printerName)} '
        'printerCode=${_logField(printerCode)}';
  }

  String _logField(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }
}
