import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../services/seller_dashboard_service.dart';
import 'seller_dashboard_overview_widgets.dart';

typedef SellerDashboardOrderLabelResolver =
    String Function(Map<String, dynamic> order);
typedef SellerDashboardOrderColorResolver =
    Color Function(Map<String, dynamic> order);
typedef SellerDashboardOrderCustomerResolver =
    String Function(Map<String, dynamic> order);
typedef SellerDashboardOrderDateResolver =
    DateTime? Function(Map<String, dynamic> order);
typedef SellerDashboardCurrencyFormatter = String Function(double value);
typedef SellerDashboardNumberFormatter = String Function(num value);

class SellerDashboardDistributionCard extends StatelessWidget {
  const SellerDashboardDistributionCard({
    super.key,
    required this.statusCounts,
    required this.totalOrderCount,
    required this.completionRate,
    this.isFoodBusiness = false,
  });

  final Map<String, int> statusCounts;
  final int totalOrderCount;
  final double completionRate;
  final bool isFoodBusiness;

  @override
  Widget build(BuildContext context) {
    // Restaurant businesses show table/kitchen statuses instead of cargo statuses.
    final List<Map<String, dynamic>> rows;
    if (isFoodBusiness) {
      rows = [
        {
          'label': 'Açık Masa',
          'value': statusCounts['open_tables'] ?? 0,
          'color': const Color(0xFF3B82F6),
        },
        {
          'label': 'Mutfağa İletilen',
          'value': statusCounts['sent_to_kitchen'] ?? 0,
          'color': const Color(0xFFF59E0B),
        },
        {
          'label': 'Bugün Kapanan',
          'value': statusCounts['closed_today'] ?? 0,
          'color': const Color(0xFF10B981),
        },
        {
          'label': 'İptal',
          'value': statusCounts['restaurant_cancelled'] ?? 0,
          'color': const Color(0xFFEF4444),
        },
      ];
    } else {
      rows = [
        {
          'label': 'Yeni',
          'value': statusCounts['new'] ?? 0,
          'color': const Color(0xFF3B82F6),
        },
        {
          'label': 'Hazırlıyor',
          'value': statusCounts['preparing'] ?? 0,
          'color': const Color(0xFFF59E0B),
        },
        {
          'label': 'Kargoya Hazır',
          'value': statusCounts['ready_to_ship'] ?? 0,
          'color': const Color(0xFF22C55E),
        },
        {
          'label': 'Kargoda',
          'value': statusCounts['shipped'] ?? 0,
          'color': const Color(0xFF8B5CF6),
        },
        {
          'label': 'Teslim Edildi',
          'value': statusCounts['delivered'] ?? 0,
          'color': const Color(0xFF10B981),
        },
      ];
    }

    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFoodBusiness ? 'Masa & Sipariş Dağılımı' : 'Sipariş Dağılımı',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...rows.map((row) {
            final value = row['value'] as int;
            final base = isFoodBusiness
                ? ((statusCounts['open_tables'] ?? 0) +
                    (statusCounts['closed_today'] ?? 0) +
                    (statusCounts['restaurant_cancelled'] ?? 0))
                : totalOrderCount;
            final total = base == 0 ? 1 : base;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SellerDashboardProgressRow(
                label: row['label'] as String,
                valueLabel: '$value / ${isFoodBusiness ? base : totalOrderCount}',
                progress: value / total,
                color: row['color'] as Color,
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          const Text(
            'Tamamlanma Oranı',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: completionRate / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '%${completionRate.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SellerDashboardProgressRow extends StatelessWidget {
  const SellerDashboardProgressRow({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class SellerDashboardRecentOrdersCard extends StatelessWidget {
  const SellerDashboardRecentOrdersCard({
    super.key,
    required this.metrics,
    required this.onViewAll,
    required this.statusLabelForOrder,
    required this.statusColorForOrder,
    required this.customerNameForOrder,
    required this.orderDateForOrder,
    required this.formatCurrency,
  });

  final SellerDashboardMetrics metrics;
  final VoidCallback onViewAll;
  final SellerDashboardOrderLabelResolver statusLabelForOrder;
  final SellerDashboardOrderColorResolver statusColorForOrder;
  final SellerDashboardOrderCustomerResolver customerNameForOrder;
  final SellerDashboardOrderDateResolver orderDateForOrder;
  final SellerDashboardCurrencyFormatter formatCurrency;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Son Siparişler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          if (metrics.recentOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Henüz sipariş bulunmuyor.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ...metrics.recentOrders.map((order) {
              final status = statusLabelForOrder(order);
              final statusColor = statusColorForOrder(order);
              final orderId =
                  (order['order_id'] ?? order['orderId'] ?? order['id'] ?? '-')
                      .toString();
              final customerName = customerNameForOrder(order);
              final quantity =
                  int.tryParse((order['quantity'] ?? 1).toString()) ?? 1;
              final total =
                  ((order['total_price'] ??
                              order['totalPrice'] ??
                              order['total_amount'] ??
                              order['totalAmount'] ??
                              0)
                          as num)
                      .toDouble();
              final createdAt = orderDateForOrder(order);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        quantity > 1
                            ? Icons.star_rounded
                            : Icons.inventory_2_outlined,
                        color: statusColor,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                orderId,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$customerName · $quantity ürün',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(total),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt == null
                              ? '--:--'
                              : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

class SellerDashboardPendingTasksCard extends StatelessWidget {
  const SellerDashboardPendingTasksCard({super.key, required this.tasks});

  final List<Map<String, dynamic>> tasks;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text(
                  'Bekleyen İşlemler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          ...tasks.map((task) {
            final background = task['background'] as Color;
            final accent = task['accent'] as Color;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(color: background),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(task['icon'] as IconData, color: accent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task['title'] as String,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: task['onTap'] as VoidCallback,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: accent,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      task['actionLabel'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

class SellerDashboardTopProductsCard extends StatelessWidget {
  const SellerDashboardTopProductsCard({
    super.key,
    required this.products,
    required this.formatNumber,
    required this.formatCurrency,
  });

  final List<Map<String, dynamic>> products;
  final SellerDashboardNumberFormatter formatNumber;
  final SellerDashboardCurrencyFormatter formatCurrency;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  Icons.whatshot_outlined,
                  size: 16,
                  color: Color(0xFFF97316),
                ),
                SizedBox(width: 8),
                Text(
                  'En Çok Satan Ürünler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '- bu ay',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Bu ay için satış verisi bulunmuyor.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final stock = product['stock'] as int;
              final stockColor = stock <= 5
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF64748B);
              final trendUp = stock > 5;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index == 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] as String,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product['code'] as String,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 66,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatNumber(product['quantity'] as int),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Text(
                            'satış',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(product['revenue'] as double),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Text(
                            'gelir',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stock',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: stockColor,
                            ),
                          ),
                          const Text(
                            'stok',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      trendUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: trendUp
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
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

class SellerDashboardCargoSummaryCard extends StatelessWidget {
  const SellerDashboardCargoSummaryCard({
    super.key,
    required this.items,
    required this.totalOrderBase,
  });

  final List<Map<String, dynamic>> items;
  final int totalOrderBase;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 8),
              Text(
                'Kargo Özeti',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final success = item['success'] as double;
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${item['count']} paket',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '%${success.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: success >= 90
                              ? const Color(0xFF10B981)
                              : success >= 80
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value:
                          (item['count'] as int) / math.max(1, totalOrderBase),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text(
            'Zamanında teslimat oranları',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
