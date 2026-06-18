import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/customer_support/data/support_category_catalog.dart';
import 'package:ibul_app/features/customer_support/models/customer_support_models.dart';

void main() {
  group('customer support models', () {
    test('category catalog has eight top-level categories', () {
      expect(supportCategoryCatalog, hasLength(8));
      expect(
        supportCategoryCatalog.every((item) => item.subcategories.isNotEmpty),
        isTrue,
      );
    });

    test('create ticket validation requires category title and message', () {
      const input = CreateCustomerSupportTicketInput(
        category: '',
        subcategory: '',
        title: '',
        message: 'kısa',
        priority: CustomerSupportPriority.normal,
        contactPreference: CustomerSupportContactPreference.inApp,
      );
      expect(input.validate(), isNotNull);
    });

    test('create ticket validation passes without subcategory', () {
      const input = CreateCustomerSupportTicketInput(
        category: 'other',
        title: 'Genel destek talebi',
        message: 'Yardıma ihtiyacım var.',
        priority: CustomerSupportPriority.normal,
        contactPreference: CustomerSupportContactPreference.inApp,
      );
      expect(input.validate(), isNull);
    });

    test('create ticket validation passes with valid payload', () {
      const input = CreateCustomerSupportTicketInput(
        category: 'order_issue',
        subcategory: 'Siparişim gelmedi',
        title: 'Sipariş gecikmesi',
        message: 'Siparişim 5 gündür gelmedi, yardım istiyorum.',
        priority: CustomerSupportPriority.high,
        contactPreference: CustomerSupportContactPreference.inApp,
      );
      expect(input.validate(), isNull);
    });

    test('status parser maps legacy in_progress to reviewing', () {
      expect(
        CustomerSupportStatus.fromDb('in_progress'),
        CustomerSupportStatus.reviewing,
      );
      expect(
        CustomerSupportStatus.fromDb('waiting_user'),
        CustomerSupportStatus.waitingUser,
      );
    });

    test('ticket fromMap uses subject/description columns', () {
      final ticket = CustomerSupportTicket.fromMap({
        'id': 'ticket-1',
        'user_id': 'user-1',
        'category': 'order_issue',
        'subcategory': 'Siparişim gelmedi',
        'subject': 'Geciken sipariş',
        'description': 'Sipariş hâlâ teslim edilmedi.',
        'status': 'reviewing',
        'priority': 'normal',
        'contact_preference': 'in_app',
        'created_at': '2026-01-01T10:00:00Z',
      });
      expect(ticket.title, 'Geciken sipariş');
      expect(ticket.message, contains('teslim'));
      expect(ticket.status, CustomerSupportStatus.reviewing);
    });
  });
}
