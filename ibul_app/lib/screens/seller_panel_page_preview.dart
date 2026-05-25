part of 'seller_panel_page.dart';

enum SellerPanelGarsonPreviewScenario {
  productsEmptyDraft,
  productsWithDraft,
  ordersWithDraftOnly,
  ordersWithDraft,
  ordersEmptyDraft,
  postSubmitActiveOrder,
}

class SellerPanelGarsonPreview extends StatelessWidget {
  const SellerPanelGarsonPreview({
    super.key,
    required this.scenario,
    this.enableLocalSubmit = false,
    this.debugPrintSystemEnabledOverride,
    this.viewportSize = const Size(430, 932),
  });

  final SellerPanelGarsonPreviewScenario scenario;
  final bool enableLocalSubmit;
  final bool? debugPrintSystemEnabledOverride;
  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    final data = _SellerPanelGarsonPreviewData.forScenario(scenario);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: AppColors.primary, useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: viewportSize,
          devicePixelRatio: 1,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: _MobileGarsonTableFlowPage(
          sellerId: 'preview-seller',
          tableNumber: 12,
          products: data.products,
          initialTabIndex: data.initialTabIndex,
          initialDraftItems: data.initialDraftItems,
          configureProductItem:
              (context, product, [existingItem, replaceIndex]) async =>
                  [_previewDraftItemFromProduct(product)],
          editItemSettings: (context, item, onSave) async =>
              onSave(Map<String, dynamic>.from(item)),
          onDraftChanged: (_, _) {},
          onOrderSubmitted: (_, _, _) {},
          debugDisableLiveSync: true,
          debugUseLocalSubmit: enableLocalSubmit,
          debugPrintSystemEnabledOverride: debugPrintSystemEnabledOverride,
          debugInitialTableOrders: data.tableOrders,
          debugSubmitFeedbackMessage: data.submitFeedbackMessage,
          debugSubmitFeedbackIsWarning: false,
        ),
      ),
    );
  }
}

class SellerPanelGarsonOperationHarness extends StatefulWidget {
  const SellerPanelGarsonOperationHarness({
    super.key,
    required this.scenario,
    this.showTableSummary = false,
    this.viewportSize = const Size(430, 932),
  });

  final SellerPanelGarsonPreviewScenario scenario;
  final bool showTableSummary;
  final Size viewportSize;

  @override
  State<SellerPanelGarsonOperationHarness> createState() =>
      _SellerPanelGarsonOperationHarnessState();
}

class _SellerPanelGarsonOperationHarnessState
    extends State<SellerPanelGarsonOperationHarness> {
  late final List<SellerProduct> _products;
  late List<Map<String, dynamic>> _draftItems;
  late List<Map<String, dynamic>> _tableOrders;
  late int _initialTabIndex;
  bool _showFlow = true;
  int _flowVersion = 0;

  @override
  void initState() {
    super.initState();
    final data = _SellerPanelGarsonPreviewData.forScenario(widget.scenario);
    _products = data.products;
    _draftItems = _clonePreviewItems(data.initialDraftItems);
    _tableOrders = _clonePreviewOrders(data.tableOrders);
    _initialTabIndex = data.initialTabIndex;
  }

  void _closeFlow() {
    setState(() => _showFlow = false);
  }

  void _openFlow() {
    setState(() {
      _showFlow = true;
      _flowVersion += 1;
      _initialTabIndex = _tableOrders.isNotEmpty || _draftItems.isNotEmpty
          ? 2
          : 0;
    });
  }

  void _handleDraftChanged(int tableNumber, List<Map<String, dynamic>> items) {
    setState(() {
      _draftItems = _clonePreviewItems(items);
    });
  }

  void _handleOrderSubmitted(
    int tableNumber,
    List<Map<String, dynamic>> submittedItems,
    Map<String, dynamic> submittedOrder,
  ) {
    setState(() {
      _draftItems = const <Map<String, dynamic>>[];
      final normalizedOrder = Map<String, dynamic>.from(submittedOrder)
        ..['items'] = _clonePreviewItems(submittedItems);
      final submittedOrderId = normalizedOrder['id']?.toString();
      final remainingOrders =
          submittedOrderId == null || submittedOrderId.isEmpty
          ? _tableOrders
          : _tableOrders.where(
              (order) => order['id']?.toString() != submittedOrderId,
            );
      _tableOrders = <Map<String, dynamic>>[
        normalizedOrder,
        ...remainingOrders,
      ];
    });
  }

  Widget _buildTableSummaryCard() {
    final effectiveOrder = _draftItems.isNotEmpty
        ? <String, dynamic>{
            'status': 'draft',
            'created_at': DateTime.now().toIso8601String(),
            'items': _draftItems,
          }
        : (_tableOrders.isNotEmpty ? _tableOrders.first : null);
    final items = effectiveOrder == null
        ? const <Map<String, dynamic>>[]
        : _previewExtractItems(effectiveOrder['items']);
    final sortedItems = List<Map<String, dynamic>>.from(items)
      ..sort((a, b) {
        final left = (a['name']?.toString() ?? '').toLowerCase();
        final right = (b['name']?.toString() ?? '').toLowerCase();
        return left.compareTo(right);
      });
    final visibleItems = sortedItems.take(3).toList(growable: false);
    final remainingCount = sortedItems.length - visibleItems.length;
    final total = items.fold<double>(
      0,
      (sum, item) => sum + MixedServiceOrder.itemLineTotal(item),
    );

    return Container(
      key: const ValueKey<String>('table-summary-card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masa Kartı Özeti',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (visibleItems.isEmpty)
            Text(
              'Sipariş yok',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else ...[
            ...visibleItems.map((item) {
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final name = item['name']?.toString() ?? '-';
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '$qty x $name',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
            if (remainingCount > 0)
              Text(
                '+$remainingCount ürün',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            _previewFormatMoney(total),
            key: const ValueKey<String>('table-summary-total'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: AppColors.primary, useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: widget.viewportSize,
          devicePixelRatio: 1,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    OutlinedButton(
                      key: const ValueKey<String>('close-flow'),
                      onPressed: _showFlow ? _closeFlow : null,
                      child: const Text('Kapat'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const ValueKey<String>('open-flow'),
                      onPressed: _showFlow ? null : _openFlow,
                      child: const Text('Aç'),
                    ),
                  ],
                ),
              ),
              if (widget.showTableSummary) _buildTableSummaryCard(),
              Expanded(
                child: _showFlow
                    ? _MobileGarsonTableFlowPage(
                        key: ValueKey<int>(_flowVersion),
                        sellerId: 'preview-seller',
                        tableNumber: 12,
                        products: _products,
                        initialTabIndex: _initialTabIndex,
                        initialDraftItems: _draftItems,
                        configureProductItem:
                            (context, product, [existingItem, replaceIndex]) async =>
                                [_previewDraftItemFromProduct(product)],
                        editItemSettings: (context, item, onSave) async =>
                            onSave(Map<String, dynamic>.from(item)),
                        onDraftChanged: _handleDraftChanged,
                        onOrderSubmitted: _handleOrderSubmitted,
                        debugDisableLiveSync: true,
                        debugUseLocalSubmit: true,
                        debugInitialTableOrders: _tableOrders,
                      )
                    : const Center(
                        child: Text(
                          'Flow Closed',
                          key: ValueKey<String>('flow-closed'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerPanelGarsonPreviewData {
  const _SellerPanelGarsonPreviewData({
    required this.initialTabIndex,
    required this.products,
    required this.initialDraftItems,
    required this.tableOrders,
    this.submitFeedbackMessage,
  });

  final int initialTabIndex;
  final List<SellerProduct> products;
  final List<Map<String, dynamic>> initialDraftItems;
  final List<Map<String, dynamic>> tableOrders;
  final String? submitFeedbackMessage;

  static _SellerPanelGarsonPreviewData forScenario(
    SellerPanelGarsonPreviewScenario scenario,
  ) {
    final products = _previewProducts();
    final ciger = products[0];
    final kuzu = products[1];
    final tavuk = products[2];
    final ayran = products[3];
    final draftItems = <Map<String, dynamic>>[
      _previewDraftItem(id: 'draft-ciger', product: ciger, quantity: 1),
      _previewDraftItem(id: 'draft-kuzu', product: kuzu, quantity: 1),
      _previewDraftItem(id: 'draft-tavuk', product: tavuk, quantity: 2),
      _previewDraftItem(id: 'draft-ayran', product: ayran, quantity: 1),
      _previewDraftItem(id: 'draft-ayran-2', product: ayran, quantity: 1),
    ];
    final compactDraftItems = draftItems.take(3).toList(growable: false);
    final activeOrders = <Map<String, dynamic>>[
      _previewTableOrder(
        id: 'order-preview-1',
        status: 'sent',
        createdAt: DateTime(2026, 4, 6, 14, 10),
        items: <Map<String, dynamic>>[
          _previewDraftItem(id: 'order-ciger', product: ciger, quantity: 1),
          _previewDraftItem(id: 'order-ayran', product: ayran, quantity: 2),
        ],
      ),
    ];

    switch (scenario) {
      case SellerPanelGarsonPreviewScenario.productsEmptyDraft:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 0,
          products: products,
          initialDraftItems: const <Map<String, dynamic>>[],
          tableOrders: const <Map<String, dynamic>>[],
        );
      case SellerPanelGarsonPreviewScenario.productsWithDraft:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 0,
          products: products,
          initialDraftItems: draftItems,
          tableOrders: const <Map<String, dynamic>>[],
        );
      case SellerPanelGarsonPreviewScenario.ordersWithDraftOnly:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 2,
          products: products,
          initialDraftItems: compactDraftItems,
          tableOrders: const <Map<String, dynamic>>[],
        );
      case SellerPanelGarsonPreviewScenario.ordersWithDraft:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 2,
          products: products,
          initialDraftItems: compactDraftItems,
          tableOrders: activeOrders,
        );
      case SellerPanelGarsonPreviewScenario.ordersEmptyDraft:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 2,
          products: products,
          initialDraftItems: const <Map<String, dynamic>>[],
          tableOrders: const <Map<String, dynamic>>[],
        );
      case SellerPanelGarsonPreviewScenario.postSubmitActiveOrder:
        return _SellerPanelGarsonPreviewData(
          initialTabIndex: 2,
          products: products,
          initialDraftItems: const <Map<String, dynamic>>[],
          tableOrders: <Map<String, dynamic>>[
            _previewTableOrder(
              id: 'order-preview-submit',
              status: 'sent',
              createdAt: DateTime(2026, 4, 6, 14, 35),
              items: compactDraftItems,
            ),
          ],
          submitFeedbackMessage:
              'Sipariş masaya yansıtıldı. Aktif siparişler aşağıda hazır.',
        );
    }
  }
}

List<SellerProduct> _previewProducts() {
  final createdAt = DateTime(2026, 4, 6, 12);
  return <SellerProduct>[
    SellerProduct(
      id: 'p-ciger',
      name: 'Ciğer Şiş',
      brand: 'Ocakbaşı',
      mainCategory: 'Izgara',
      subCategory: 'Şiş',
      price: 280,
      stock: 20,
      sku: 'CGR-001',
      status: 'Aktif',
      createdAt: createdAt,
    ),
    SellerProduct(
      id: 'p-kuzu',
      name: 'Kuzu Pirzola',
      brand: 'Ocakbaşı',
      mainCategory: 'Izgara',
      subCategory: 'Pirzola',
      price: 420,
      stock: 12,
      sku: 'KZP-001',
      status: 'Aktif',
      createdAt: createdAt,
    ),
    SellerProduct(
      id: 'p-tavuk',
      name: 'Tavuk Bonfile',
      brand: 'Ocakbaşı',
      mainCategory: 'Izgara',
      subCategory: 'Tavuk',
      price: 220,
      stock: 18,
      sku: 'TVK-001',
      status: 'Aktif',
      createdAt: createdAt,
    ),
    SellerProduct(
      id: 'p-ayran',
      name: 'Yayık Ayran',
      brand: 'Ocakbaşı',
      mainCategory: 'İçecek',
      subCategory: 'Soğuk',
      price: 40,
      stock: 50,
      sku: 'AYR-001',
      status: 'Aktif',
      createdAt: createdAt,
    ),
    SellerProduct(
      id: 'p-salata',
      name: 'Gavurdağı Salata',
      brand: 'Ocakbaşı',
      mainCategory: 'Meze',
      subCategory: 'Salata',
      price: 130,
      stock: 14,
      sku: 'SLT-001',
      status: 'Aktif',
      createdAt: createdAt,
    ),
  ];
}

Map<String, dynamic> _previewDraftItemFromProduct(SellerProduct product) {
  return _previewDraftItem(
    id: 'preview-${product.id}',
    product: product,
    quantity: 1,
  );
}

Map<String, dynamic> _previewDraftItem({
  required String id,
  required SellerProduct product,
  required int quantity,
}) {
  final lineTotal = product.price * quantity;
  return <String, dynamic>{
    'id': id,
    'product_id': product.id,
    'productId': product.id,
    'name': product.name,
    'item_name': product.name,
    'quantity': quantity,
    'price': product.price,
    'total_price': lineTotal,
    'line_total': lineTotal,
    'amount_label': quantity > 1 ? '$quantity adet' : '',
    'notes': '',
    'note': '',
    'item_type': 'product',
    'product_type': 'product',
    'source_product_type': 'product',
    'attributes': const <String>[],
    'printer_routing_enabled': true,
  };
}

Map<String, dynamic> _previewTableOrder({
  required String id,
  required String status,
  required DateTime createdAt,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    'id': id,
    'seller_id': 'preview-seller',
    'table_number': 12,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'items': items,
  };
}

List<Map<String, dynamic>> _clonePreviewItems(
  List<Map<String, dynamic>> items,
) {
  return items
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<Map<String, dynamic>> _clonePreviewOrders(
  List<Map<String, dynamic>> orders,
) {
  return orders
      .map((order) {
        final cloned = Map<String, dynamic>.from(order);
        cloned['items'] = _previewExtractItems(order['items']);
        return cloned;
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _previewExtractItems(dynamic raw) {
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

String _previewFormatMoney(double amount) {
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
