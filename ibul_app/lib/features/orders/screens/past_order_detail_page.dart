import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../helpers/order_history_navigation.dart';
import '../helpers/order_history_status_helper.dart';
import '../services/order_history_service.dart';
import '../widgets/order_history_states.dart';

class PastOrderDetailPage extends StatefulWidget {
  const PastOrderDetailPage({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<PastOrderDetailPage> createState() => _PastOrderDetailPageState();
}

class _PastOrderDetailPageState extends State<PastOrderDetailPage> {
  final _service = OrderHistoryService.instance;
  bool _reordering = false;

  List<Map<String, dynamic>> get _items =>
      (widget.order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

  String get _resolvedStatus => OrderHistoryStatusHelper.resolveOrderStatus(
    (widget.order['status']?.toString() ?? '').toLowerCase(),
    _items,
  );

  Future<void> _reorderAll() async {
    setState(() => _reordering = true);
    try {
      final result = await _service.reorderOrder(
        order: widget.order,
        appState: context.read<AppState>(),
      );
      if (!mounted) return;
      if (result.hasAdded && result.blocked.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürünler sepete eklendi.')),
        );
      } else {
        showReorderResultSheet(context, result);
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _openProduct(Map<String, dynamic> item) {
    return OrderHistoryNavigation.openProductForReorder(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(widget.order['created_at']?.toString() ?? '');
    final status = OrderHistoryStatusHelper.statusPresentation(_resolvedStatus);
    final total = (widget.order['total_amount'] as num?)?.toDouble() ?? 0;
    final delivery = widget.order['delivery_address'] as Map?;
    final firstItem = _items.isNotEmpty ? _items.first : <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      appBar: AppBar(
        title: const Text('Sipariş Detayı'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _infoCard(
                  children: [
                    _row('Sipariş No', '#${OrderHistoryStatusHelper.shortOrderNo(widget.order)}'),
                    _row('Mağaza', firstItem['store_name']?.toString() ?? '-'),
                    _row(
                      'Tarih',
                      createdAt != null
                          ? OrderHistoryStatusHelper.formatDateTime(createdAt)
                          : '-',
                    ),
                    _row('Durum', status['label'] as String, valueColor: status['color'] as Color),
                    if (delivery != null && delivery.isNotEmpty)
                      _row('Teslimat', delivery['title']?.toString() ?? delivery['address']?.toString() ?? '-'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Ürünler', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ..._items.map(_itemTile),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Toplam', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Text(
                          '${total.toStringAsFixed(2)} TL',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _reordering ? null : _reorderAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: _reordering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Tümünü Tekrar Al'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final unit = (item['unit_price'] as num?)?.toDouble() ?? 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openProduct(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: (item['product_image_url']?.toString() ?? '').isNotEmpty
                      ? OptimizedImage(
                          imageUrlOrPath: item['product_image_url'].toString(),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : const ColoredBox(
                          color: Color(0xFFF3F4F6),
                          child: Icon(Icons.image_outlined, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name']?.toString() ?? 'Ürün',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qty adet · ${unit.toStringAsFixed(2)} TL',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openProduct(item),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Tekrar Al', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
