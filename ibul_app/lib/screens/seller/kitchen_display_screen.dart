import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/store_service.dart';

/// Kitchen Display Screen (KDS)
///
/// Shows live incoming orders grouped by table, color-coded by urgency.
/// Kitchen staff can mark items / full orders as "Hazırlanıyor" or "Hazır".
///
/// Navigation: Admin panel → Mutfak Ekranı
///              Waiter panel → (read-only fallback)
class KitchenDisplayScreen extends StatefulWidget {
  const KitchenDisplayScreen({
    super.key,
    required this.sellerId,
  });

  final String sellerId;

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  late final Stream<List<Map<String, dynamic>>> _ordersStream;
  final StoreService _storeService = StoreService();

  // Local status overrides so the kitchen can optimistically mark items
  // as preparing/ready before the DB stream updates.
  final Map<String, String> _localStatusOverrides = {};

  static const _kActiveStatuses = {
    'new',
    'waiting',
    'sent',
    'preparing',
    'kitchen',
    'ready',
  };

  @override
  void initState() {
    super.initState();
    _ordersStream = _storeService.getTableOrdersStream(widget.sellerId);
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
      case 'waiting':
        return const Color(0xFFEF4444); // red — urgent
      case 'sent':
      case 'kitchen':
        return const Color(0xFF16A34A); // green — mutfağa iletildi
      case 'preparing':
        return const Color(0xFFF59E0B); // amber — cooking
      case 'ready':
        return const Color(0xFF22C55E); // green — done
      default:
        return const Color(0xFF94A3B8); // grey
    }
  }

  String _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return 'Yeni';
      case 'waiting':
        return 'Bekliyor';
      case 'sent':
      case 'kitchen':
        return 'Mutfakta';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'ready':
        return 'Hazır';
      default:
        return status ?? '-';
    }
  }

  Future<void> _setOrderStatus(String orderId, String status) async {
    setState(() => _localStatusOverrides[orderId] = status);
    try {
      await _storeService.updateTableOrder(orderId, status: status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durum güncellenemedi: $e')),
      );
      setState(() => _localStatusOverrides.remove(orderId));
    }
  }

  int _tableNumber(Map<String, dynamic> order) {
    final v = order['table_number'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime _createdAt(Map<String, dynamic> order) {
    return DateTime.tryParse(order['created_at']?.toString() ?? '')
            ?.toLocal() ??
        DateTime.now();
  }

  Duration _age(Map<String, dynamic> order) =>
      DateTime.now().difference(_createdAt(order));

  Color _cardBorderColor(Map<String, dynamic> order, String status) {
    final minutes = _age(order).inMinutes;
    if (minutes >= 15) return const Color(0xFFEF4444); // very late
    if (minutes >= 8) return const Color(0xFFF59E0B); // getting late
    return _statusColor(status);
  }

  String _ageLabel(Duration age) {
    if (age.inMinutes < 1) return 'Az önce';
    if (age.inMinutes < 60) return '${age.inMinutes} dk';
    return '${age.inHours} sa';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text(
          'Mutfak Ekranı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: const [
                _LegendDot(color: Color(0xFFEF4444), label: 'Yeni'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFFF97316), label: 'Sırada'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFFF59E0B), label: 'Hazırlanıyor'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFF22C55E), label: 'Hazır'),
                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }

          final activeOrders = snapshot.data!.where((order) {
            final effectiveStatus = _localStatusOverrides[
                    order['id']?.toString() ?? ''] ??
                order['status']?.toString().toLowerCase();
            return _kActiveStatuses.contains(effectiveStatus);
          }).toList()
            ..sort((a, b) => _createdAt(a).compareTo(_createdAt(b)));

          if (activeOrders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_rounded,
                      size: 64, color: Colors.white24),
                  SizedBox(height: 12),
                  Text(
                    'Aktif sipariş yok',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          // Group by table number
          final grouped = <int, List<Map<String, dynamic>>>{};
          for (final order in activeOrders) {
            final tn = _tableNumber(order);
            grouped.putIfAbsent(tn, () => []).add(order);
          }
          final sortedTables = grouped.keys.toList()..sort();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sortedTables.map((tableNo) {
                final orders = grouped[tableNo]!;
                return _KitchenTableCard(
                  tableNumber: tableNo,
                  orders: orders,
                  localStatusOverrides: _localStatusOverrides,
                  statusColor: _statusColor,
                  statusLabel: _statusLabel,
                  cardBorderColor: _cardBorderColor,
                  ageLabel: _ageLabel,
                  age: _age,
                  onSetStatus: _setOrderStatus,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _KitchenTableCard extends StatelessWidget {
  const _KitchenTableCard({
    required this.tableNumber,
    required this.orders,
    required this.localStatusOverrides,
    required this.statusColor,
    required this.statusLabel,
    required this.cardBorderColor,
    required this.ageLabel,
    required this.age,
    required this.onSetStatus,
  });

  final int tableNumber;
  final List<Map<String, dynamic>> orders;
  final Map<String, String> localStatusOverrides;
  final Color Function(String?) statusColor;
  final String Function(String?) statusLabel;
  final Color Function(Map<String, dynamic>, String) cardBorderColor;
  final String Function(Duration) ageLabel;
  final Duration Function(Map<String, dynamic>) age;
  final Future<void> Function(String orderId, String status) onSetStatus;

  static const _cardWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_restaurant_rounded,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'Masa $tableNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${orders.length} sipariş',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          ...orders.map((order) {
            final orderId = order['id']?.toString() ?? '';
            final effectiveStatus =
                localStatusOverrides[orderId] ??
                    order['status']?.toString().toLowerCase();
            final color = statusColor(effectiveStatus);
            final borderColor = cardBorderColor(order, effectiveStatus ?? '');
            final ageD = age(order);
            final rawItems = order['items'];
            final items = rawItems is List
                ? rawItems.cast<Map<String, dynamic>>()
                : const <Map<String, dynamic>>[];

            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(
                    color: borderColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel(effectiveStatus),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          ageLabel(ageD),
                          style: TextStyle(
                            color: ageD.inMinutes >= 8
                                ? const Color(0xFFF59E0B)
                                : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Items
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                        child: Row(
                          children: [
                            Text(
                              '${(item['quantity'] as num?)?.toInt() ?? 1}×',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 6),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Row(
                      children: [
                        if (effectiveStatus != 'preparing')
                          Expanded(
                            child: _KdsButton(
                              label: 'Hazırlanıyor',
                              color: const Color(0xFFF59E0B),
                              onTap: orderId.isNotEmpty
                                  ? () => onSetStatus(orderId, 'preparing')
                                  : null,
                            ),
                          ),
                        if (effectiveStatus != 'preparing')
                          const SizedBox(width: 6),
                        Expanded(
                          child: _KdsButton(
                            label: effectiveStatus == 'ready'
                                ? '✓ Hazır'
                                : 'Hazır',
                            color: const Color(0xFF22C55E),
                            filled: effectiveStatus == 'ready',
                            onTap: orderId.isNotEmpty
                                ? () => onSetStatus(orderId, 'ready')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _KdsButton extends StatelessWidget {
  const _KdsButton({
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
