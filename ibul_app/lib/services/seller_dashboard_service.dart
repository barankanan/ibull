import '../models/seller_product.dart';
import 'campaign_service.dart';
import 'support_service.dart';

class SellerDashboardSeriesPoint {
  const SellerDashboardSeriesPoint({
    required this.label,
    required this.revenue,
    required this.orderCount,
  });

  final String label;
  final double revenue;
  final int orderCount;
}

class SellerDashboardActivity {
  const SellerDashboardActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final String type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
}

class SellerDashboardMetrics {
  const SellerDashboardMetrics({
    required this.rangeStart,
    required this.rangeEnd,
    required this.previousRangeStart,
    required this.previousRangeEnd,
    required this.todayRevenue,
    required this.todayRevenueChangePercent,
    required this.monthRevenue,
    required this.monthRevenueChangePercent,
    required this.pendingOrders,
    required this.totalProducts,
    required this.activeProducts,
    required this.lowStockProducts,
    required this.selectedRevenue,
    required this.previousRevenue,
    required this.selectedOrderCount,
    required this.previousOrderCount,
    required this.averageOrderValue,
    required this.fulfillmentRate,
    required this.storeRating,
    required this.openSupportTickets,
    required this.unansweredQuestions,
    required this.activeCampaigns,
    required this.chartPoints,
    required this.recentOrders,
    required this.activities,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime previousRangeStart;
  final DateTime previousRangeEnd;
  final double todayRevenue;
  final double todayRevenueChangePercent;
  final double monthRevenue;
  final double monthRevenueChangePercent;
  final int pendingOrders;
  final int totalProducts;
  final int activeProducts;
  final int lowStockProducts;
  final double selectedRevenue;
  final double previousRevenue;
  final int selectedOrderCount;
  final int previousOrderCount;
  final double averageOrderValue;
  final double fulfillmentRate;
  final double storeRating;
  final int openSupportTickets;
  final int unansweredQuestions;
  final int activeCampaigns;
  final List<SellerDashboardSeriesPoint> chartPoints;
  final List<Map<String, dynamic>> recentOrders;
  final List<SellerDashboardActivity> activities;

  double get selectedRevenueChangePercent =>
      SellerDashboardService.calculateChangePercent(
        current: selectedRevenue,
        previous: previousRevenue,
      );
}

class SellerDashboardService {
  const SellerDashboardService._();

  static SellerDashboardMetrics build({
    required List<Map<String, dynamic>> orders,
    required List<SellerProduct> products,
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> sellerQuestions,
    required List<StoreCampaign> campaigns,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required double storeRating,
  }) {
    final normalizedStart = _startOfDay(rangeStart);
    final normalizedEnd = _endOfDay(rangeEnd);
    final periodLength = normalizedEnd.difference(normalizedStart).inDays + 1;
    final previousRangeEnd = normalizedStart.subtract(
      const Duration(seconds: 1),
    );
    final previousRangeStart = _startOfDay(
      normalizedStart.subtract(Duration(days: periodLength)),
    );

    final todayStart = _startOfDay(DateTime.now());
    final todayEnd = _endOfDay(DateTime.now());
    final yesterdayStart = _startOfDay(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final yesterdayEnd = _endOfDay(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthEnd = _endOfDay(DateTime.now());
    final previousMonthEnd = monthStart.subtract(const Duration(seconds: 1));
    final previousMonthStart = DateTime(
      previousMonthEnd.year,
      previousMonthEnd.month,
      1,
    );

    final recentOrders = [...orders]
      ..sort((a, b) {
        final left =
            _parseOrderDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right =
            _parseOrderDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

    final selectedOrders = _ordersBetween(
      orders,
      normalizedStart,
      normalizedEnd,
    );
    final previousOrders = _ordersBetween(
      orders,
      previousRangeStart,
      previousRangeEnd,
    );
    final todayOrders = _ordersBetween(orders, todayStart, todayEnd);
    final yesterdayOrders = _ordersBetween(
      orders,
      yesterdayStart,
      yesterdayEnd,
    );
    final monthOrders = _ordersBetween(orders, monthStart, monthEnd);
    final previousMonthOrders = _ordersBetween(
      orders,
      previousMonthStart,
      previousMonthEnd,
    );

    final pendingOrders = orders.where((order) {
      final status = _normalizedStatus(order['status']);
      return !_isClosedStatus(status);
    }).length;

    final activeProducts = products.where((product) {
      final status = product.status.trim().toLowerCase();
      return status == 'aktif' || status == 'active';
    }).length;
    final lowStockProducts = products
        .where((product) => product.stock <= 5)
        .length;

    final selectedRevenue = _sumRevenue(selectedOrders);
    final previousRevenue = _sumRevenue(previousOrders);
    final selectedOrderCount = selectedOrders.length;
    final deliveredOrders = selectedOrders.where((order) {
      final status = _normalizedStatus(order['status']);
      return status == 'delivered' || status == 'teslim edildi';
    }).length;

    final openSupportTickets = supportTickets.where((ticket) {
      return ticket.status == TicketStatus.open ||
          ticket.status == TicketStatus.in_progress;
    }).length;

    final unansweredQuestions = sellerQuestions.where((question) {
      return (question['answer']?.toString().trim().isEmpty ?? true);
    }).length;

    final now = DateTime.now();
    final activeCampaigns = campaigns.where((campaign) {
      return campaign.status.toLowerCase() == 'active' &&
          !campaign.endDate.isBefore(now);
    }).length;

    return SellerDashboardMetrics(
      rangeStart: normalizedStart,
      rangeEnd: normalizedEnd,
      previousRangeStart: previousRangeStart,
      previousRangeEnd: previousRangeEnd,
      todayRevenue: _sumRevenue(todayOrders),
      todayRevenueChangePercent: calculateChangePercent(
        current: _sumRevenue(todayOrders),
        previous: _sumRevenue(yesterdayOrders),
      ),
      monthRevenue: _sumRevenue(monthOrders),
      monthRevenueChangePercent: calculateChangePercent(
        current: _sumRevenue(monthOrders),
        previous: _sumRevenue(previousMonthOrders),
      ),
      pendingOrders: pendingOrders,
      totalProducts: products.length,
      activeProducts: activeProducts,
      lowStockProducts: lowStockProducts,
      selectedRevenue: selectedRevenue,
      previousRevenue: previousRevenue,
      selectedOrderCount: selectedOrderCount,
      previousOrderCount: previousOrders.length,
      averageOrderValue: selectedOrderCount == 0
          ? 0
          : selectedRevenue / selectedOrderCount,
      fulfillmentRate: selectedOrderCount == 0
          ? 0
          : (deliveredOrders / selectedOrderCount) * 100,
      storeRating: storeRating,
      openSupportTickets: openSupportTickets,
      unansweredQuestions: unansweredQuestions,
      activeCampaigns: activeCampaigns,
      chartPoints: _buildSeriesPoints(
        orders: orders,
        start: normalizedStart,
        end: normalizedEnd,
      ),
      recentOrders: recentOrders.take(5).toList(growable: false),
      activities: _buildActivities(
        recentOrders: recentOrders,
        supportTickets: supportTickets,
        sellerQuestions: sellerQuestions,
      ),
    );
  }

  static double calculateChangePercent({
    required double current,
    required double previous,
  }) {
    if (previous <= 0 && current <= 0) return 0;
    if (previous <= 0) return 100;
    return ((current - previous) / previous) * 100;
  }

  static List<Map<String, dynamic>> _ordersBetween(
    List<Map<String, dynamic>> orders,
    DateTime start,
    DateTime end,
  ) {
    return orders
        .where((order) {
          final createdAt = _parseOrderDate(order);
          if (createdAt == null) return false;
          return !createdAt.isBefore(start) && !createdAt.isAfter(end);
        })
        .toList(growable: false);
  }

  static List<SellerDashboardSeriesPoint> _buildSeriesPoints({
    required List<Map<String, dynamic>> orders,
    required DateTime start,
    required DateTime end,
  }) {
    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 31) {
      return List.generate(totalDays, (index) {
        final day = _startOfDay(start.add(Duration(days: index)));
        final dailyOrders = _ordersBetween(orders, day, _endOfDay(day));
        return SellerDashboardSeriesPoint(
          label: _dayLabel(day),
          revenue: _sumRevenue(dailyOrders),
          orderCount: dailyOrders.length,
        );
      });
    }

    final monthStarts = <DateTime>[];
    var cursor = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(lastMonth)) {
      monthStarts.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return monthStarts
        .map((monthStart) {
          final monthEnd = _endOfDay(
            DateTime(monthStart.year, monthStart.month + 1, 0),
          );
          final scopedStart = monthStart.isBefore(start) ? start : monthStart;
          final scopedEnd = monthEnd.isAfter(end) ? end : monthEnd;
          final monthlyOrders = _ordersBetween(orders, scopedStart, scopedEnd);
          return SellerDashboardSeriesPoint(
            label: _monthLabel(monthStart),
            revenue: _sumRevenue(monthlyOrders),
            orderCount: monthlyOrders.length,
          );
        })
        .toList(growable: false);
  }

  static List<SellerDashboardActivity> _buildActivities({
    required List<Map<String, dynamic>> recentOrders,
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> sellerQuestions,
  }) {
    final activities = <SellerDashboardActivity>[
      ...recentOrders
          .take(4)
          .map(
            (order) => SellerDashboardActivity(
              type: 'order',
              title:
                  'Yeni siparis #${order['order_id'] ?? order['orderId'] ?? order['id'] ?? '-'}',
              subtitle:
                  '${order['product_name'] ?? order['productName'] ?? 'Urun'} • ${_normalizedStatus(order['status'])}',
              timestamp: _parseOrderDate(order) ?? DateTime.now(),
            ),
          ),
      ...supportTickets
          .take(3)
          .map(
            (ticket) => SellerDashboardActivity(
              type: 'support',
              title: ticket.subject.isEmpty ? 'Destek kaydi' : ticket.subject,
              subtitle: 'Destek talebi • ${ticket.status.name}',
              timestamp: ticket.updatedAt ?? ticket.createdAt,
            ),
          ),
      ...sellerQuestions
          .take(3)
          .map(
            (question) => SellerDashboardActivity(
              type: 'question',
              title: question['productName']?.toString().isNotEmpty == true
                  ? question['productName'].toString()
                  : 'Urun sorusu',
              subtitle: question['answer']?.toString().trim().isEmpty ?? true
                  ? 'Yanit bekliyor'
                  : 'Yanitlandi',
              timestamp:
                  DateTime.tryParse(question['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          ),
    ];

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(6).toList(growable: false);
  }

  static double _sumRevenue(List<Map<String, dynamic>> orders) {
    return orders.fold<double>(0, (sum, order) {
      final amount =
          order['total_price'] ??
          order['totalPrice'] ??
          order['total_amount'] ??
          order['totalAmount'] ??
          0;
      return sum + (amount as num).toDouble();
    });
  }

  static DateTime? _parseOrderDate(Map<String, dynamic> order) {
    final raw = order['created_at'] ?? order['createdAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String _normalizedStatus(dynamic status) {
    return (status ?? '').toString().trim().toLowerCase();
  }

  static bool _isClosedStatus(String status) {
    return status == 'delivered' ||
        status == 'teslim edildi' ||
        status == 'cancelled' ||
        status == 'iptal edildi';
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static String _dayLabel(DateTime value) {
    const labels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    return labels[value.weekday - 1];
  }

  static String _monthLabel(DateTime value) {
    const labels = [
      'Oca',
      'Sub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Agu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return labels[value.month - 1];
  }
}
