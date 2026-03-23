import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/printer_model.dart';
import '../../models/print_job_model.dart';
import '../../models/seller_product.dart';
import '../../models/station_model.dart';
import '../../models/station_printer_model.dart';
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
  final StoreService _storeService = StoreService();

  final Map<String, String?> _productStationDraft = <String, String?>{};
  final Map<String, bool> _productRoutingDraft = <String, bool>{};
  bool _isSavingProductRouting = false;
  String _printStatusFilter = 'all';

  Future<List<SellerProduct>> _fetchProducts() {
    return _storeService
        .getProductsBySellerId(widget.restaurantId)
        .then(
          (rows) => rows
              .map(
                (row) =>
                    SellerProduct.fromMap(row, row['id']?.toString() ?? ''),
              )
              .toList(growable: false),
        );
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
    } finally {
      nameCtrl.dispose();
      codeCtrl.dispose();
      colorCtrl.dispose();
    }
  }

  Future<void> _showPrinterEditor({PrinterModel? printer}) async {
    final nameCtrl = TextEditingController(text: printer?.name ?? '');
    final codeCtrl = TextEditingController(text: printer?.code ?? '');
    final ipCtrl = TextEditingController(text: printer?.ipAddress ?? '');
    final portCtrl = TextEditingController(
      text: printer?.port?.toString() ?? '9100',
    );
    final deviceCtrl = TextEditingController(
      text: printer?.deviceIdentifier ?? '',
    );
    final widthCtrl = TextEditingController(
      text: (printer?.paperWidthMm ?? 80).toString(),
    );
    var connectionType = printer?.connectionType ?? 'network';
    var isActive = printer?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(printer == null ? 'Yeni Yazıcı' : 'Yazıcı Düzenle'),
            content: StatefulBuilder(
              builder: (ctx, setSheet) {
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
                            value: 'network',
                            child: Text('Network'),
                          ),
                          DropdownMenuItem(value: 'usb', child: Text('USB')),
                          DropdownMenuItem(
                            value: 'bluetooth',
                            child: Text('Bluetooth'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheet(() => connectionType = value);
                        },
                      ),
                      TextField(
                        controller: ipCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IP Adresi',
                        ),
                      ),
                      TextField(
                        controller: portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port'),
                      ),
                      TextField(
                        controller: deviceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Device Identifier',
                        ),
                      ),
                      TextField(
                        controller: widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kağıt Genişliği (mm)',
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
          const SnackBar(content: Text('Yazıcı adı ve kod zorunludur.')),
        );
        return;
      }

      await _printerRepository.upsertPrinter(
        restaurantId: widget.restaurantId,
        printerId: printer?.id,
        name: nameCtrl.text,
        code: codeCtrl.text,
        connectionType: connectionType,
        ipAddress: ipCtrl.text.trim().isEmpty ? null : ipCtrl.text.trim(),
        port: int.tryParse(portCtrl.text.trim()),
        deviceIdentifier: deviceCtrl.text.trim().isEmpty
            ? null
            : deviceCtrl.text.trim(),
        paperWidthMm: int.tryParse(widthCtrl.text.trim()) ?? 80,
        isActive: isActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printer == null ? 'Yazıcı eklendi.' : 'Yazıcı güncellendi.',
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
      codeCtrl.dispose();
      ipCtrl.dispose();
      portCtrl.dispose();
      deviceCtrl.dispose();
      widthCtrl.dispose();
    }
  }

  Future<void> _saveProductRouting(SellerProduct product) async {
    if (_isSavingProductRouting) return;
    final selectedStation =
        _productStationDraft[product.id] ?? product.stationId;
    final routingEnabled =
        _productRoutingDraft[product.id] ?? product.printerRoutingEnabled;

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} için yönlendirme kaydedildi.')),
      );
      setState(() {
        _productStationDraft.remove(product.id);
        _productRoutingDraft.remove(product.id);
      });
    } finally {
      if (mounted) setState(() => _isSavingProductRouting = false);
    }
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
      stream: _printerRepository.watchPrinters(widget.restaurantId),
      builder: (context, snapshot) {
        final printers = snapshot.data ?? const <PrinterModel>[];
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
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  final printer = printers[index];
                  return Card(
                    child: ListTile(
                      title: Text(printer.name),
                      subtitle: Text(
                        '${printer.connectionType.toUpperCase()} • ${printer.ipAddress ?? '-'}:${printer.port ?? '-'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Switch.adaptive(
                            value: printer.isActive,
                            onChanged: (value) => _printerRepository
                                .setPrinterActive(printer.id, value),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMappingTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _stationRepository.fetchStations(widget.restaurantId),
        _printerRepository.fetchPrinters(widget.restaurantId),
        _printerRepository.fetchStationPrinterMappings(widget.restaurantId),
      ]),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final stations = loading
            ? const <StationModel>[]
            : (snapshot.data?[0] as List<StationModel>? ??
                  const <StationModel>[]);
        final printers = loading
            ? const <PrinterModel>[]
            : (snapshot.data?[1] as List<PrinterModel>? ??
                  const <PrinterModel>[]);
        final mappings = loading
            ? const <StationPrinterModel>[]
            : (snapshot.data?[2] as List<StationPrinterModel>? ??
                  const <StationPrinterModel>[]);

        return Column(
          children: [
            if (loading) const LinearProgressIndicator(),
            if (!loading)
              ...stations.map((station) {
                final stationMappings = mappings
                    .where((m) => m.stationId == station.id)
                    .toList(growable: false);
                final selectedPrinterId = stationMappings.isEmpty
                    ? null
                    : stationMappings.first.printerId;
                return Card(
                  child: ListTile(
                    title: Text(station.name),
                    subtitle: Text(
                      stationMappings.isEmpty
                          ? 'Yazıcı atanmadı'
                          : stationMappings
                                .map((m) => m.printerName ?? m.printerId)
                                .join(', '),
                    ),
                    trailing: SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPrinterId,
                        hint: const Text('Yazıcı Seç'),
                        items: printers
                            .map(
                              (printer) => DropdownMenuItem(
                                value: printer.id,
                                child: Text(printer.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) async {
                          if (value == null) return;
                          await _printerRepository.assignPrinterToStation(
                            stationId: station.id,
                            printerId: value,
                            isPrimary: true,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(
                            SnackBar(
                              content: Text('${station.name} eşleştirildi.'),
                            ),
                          );
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildProductRoutingTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _fetchProducts(),
        _stationRepository.fetchStations(widget.restaurantId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data?[0] as List<SellerProduct>? ?? const [];
        final stations = snapshot.data?[1] as List<StationModel>? ?? const [];

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
                    DropdownButtonFormField<String>(
                      initialValue: draftStation,
                      hint: const Text('Hazırlama Alanı Seç'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Atanmadı'),
                        ),
                        ...stations.map(
                          (station) => DropdownMenuItem<String>(
                            value: station.id,
                            child: Text(station.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
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
                            : () => _saveProductRouting(product),
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
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  double _parseMoney(dynamic raw) {
    if (raw is num) return raw.toDouble();
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return 0;
    var normalized = text.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.isEmpty) return 0;
    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');
    if (hasComma && hasDot) {
      if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (hasComma) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized) ?? 0;
  }

  double _orderTotal(List<Map<String, dynamic>> items) {
    return items.fold<double>(0, (sum, item) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = _parseMoney(item['price']);
      return sum + (qty * unitPrice);
    });
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
          return Center(child: Text('Siparişler alınamadı: ${snapshot.error}'));
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
          return const Center(child: Text('Henüz mutfağa düşen sipariş yok.'));
        }

        return ListView.builder(
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

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tableNo > 0 ? 'Masa $tableNo' : 'Masa bilinmiyor',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
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
                    const SizedBox(height: 6),
                    Text(
                      'Sipariş: ${orderNo == null || orderNo.isEmpty ? '-' : orderNo} • ${createdAt.toString()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.take(5).map((item) {
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final name = item['name']?.toString() ?? '-';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$qty x $name',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                    if (items.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+${items.length - 5} ürün daha',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Toplam: ${_formatMoney(total)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                        'Durum: ${job.status} • ${job.createdAt.toLocal()}'
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
                              await _printJobRepository.retryJob(job.id);
                              if (!mounted) return;
                              ScaffoldMessenger.maybeOf(
                                this.context,
                              )?.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Print job yeniden kuyruğa alındı.',
                                  ),
                                ),
                              );
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
}
