import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/seller_dashboard_service.dart';

void main() {
  group('DashboardOrderMetric', () {
    test('fromOnlineOrder parses correctly and flags cancelled status', () {
      final order = {
        'id': '123',
        'status': 'iptal edildi',
        'total_amount': 150.5,
        'created_at': '2026-06-09T10:00:00Z',
      };

      final metric = DashboardOrderMetric.fromOnlineOrder(order);

      expect(metric.id, '123');
      expect(metric.source, 'online');
      expect(metric.status, 'iptal edildi');
      expect(metric.totalAmount, 150.5);
      expect(metric.isCancelled, isTrue);
      expect(metric.isPaidOrRevenueEligible, isFalse);
    });

    test('fromTableOrder parses correctly and flags valid status', () {
      final order = {
        'id': '456',
        'status': 'closed',
        'table_number': 5,
        'created_at': '2026-06-09T10:00:00Z',
      };

      final metric = DashboardOrderMetric.fromTableOrder(
        order,
        computedTotal: 200.0,
      );

      expect(metric.id, '456');
      expect(metric.source, 'table');
      expect(metric.status, 'closed');
      expect(metric.totalAmount, 200.0);
      expect(metric.isCancelled, isFalse);
      expect(metric.isPaidOrRevenueEligible, isTrue);
      expect(metric.tableName, 'Masa 5');
    });
  });

  group('SellerDashboardService - build', () {
    test(
      'ignores cancelled orders in both revenue and average-order count',
      () {
        final orders = [
          {
            'id': '1',
            'status': 'delivered',
            'total_amount': 100,
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '2',
            'status': 'iptal edildi',
            'total_amount': 500,
            'created_at': DateTime.now().toIso8601String(),
          },
        ];

        final metrics = SellerDashboardService.build(
          orders: orders,
          products: [],
          supportTickets: [],
          sellerQuestions: [],
          campaigns: [],
          rangeStart: DateTime.now().subtract(const Duration(days: 1)),
          rangeEnd: DateTime.now().add(const Duration(days: 1)),
          storeRating: 4.5,
        );

        // Only the 100 amount from the delivered order should be summed
        expect(metrics.selectedRevenue, 100);
        expect(metrics.selectedOrderCount, 1);
        expect(metrics.averageOrderValue, 100);
      },
    );
  });
}
