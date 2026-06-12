import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

void main() {
  group('OrderStatusConstants', () {
    test('isTerminalStatus correctly identifies terminal statuses', () {
      expect(OrderStatusConstants.isTerminalStatus('closed'), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('PAID '), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('cancelled'), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('completed'), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('delivered'), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('teslim edildi'), isTrue);
      expect(OrderStatusConstants.isTerminalStatus('iptal edildi'), isTrue);

      expect(OrderStatusConstants.isTerminalStatus('open'), isFalse);
      expect(OrderStatusConstants.isTerminalStatus('pending'), isFalse);
      expect(OrderStatusConstants.isTerminalStatus(null), isFalse);
      expect(OrderStatusConstants.isTerminalStatus(''), isFalse);
    });

    test('isCancelledStatus correctly identifies cancelled statuses', () {
      expect(OrderStatusConstants.isCancelledStatus('cancelled'), isTrue);
      expect(OrderStatusConstants.isCancelledStatus('canceled'), isTrue);
      expect(OrderStatusConstants.isCancelledStatus('iptal edildi'), isTrue);
      expect(OrderStatusConstants.isCancelledStatus('iade edildi'), isTrue);
      expect(OrderStatusConstants.isCancelledStatus('refunded'), isTrue);
      expect(OrderStatusConstants.isCancelledStatus('reddedildi'), isTrue);

      expect(OrderStatusConstants.isCancelledStatus('closed'), isFalse);
      expect(OrderStatusConstants.isCancelledStatus('paid'), isFalse);
      expect(OrderStatusConstants.isCancelledStatus('delivered'), isFalse);
      expect(OrderStatusConstants.isCancelledStatus(null), isFalse);
    });

    test('isActiveEcommerce correctly identifies active e-commerce statuses', () {
      expect(OrderStatusConstants.isActiveEcommerce('new'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('confirmed'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('preparing'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('ready_to_ship'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('shipped'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('transfer'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('branch'), isTrue);
      expect(OrderStatusConstants.isActiveEcommerce('out_for_delivery'), isTrue);

      expect(OrderStatusConstants.isActiveEcommerce('delivered'), isFalse);
      expect(OrderStatusConstants.isActiveEcommerce('cancelled'), isFalse);
      expect(OrderStatusConstants.isActiveEcommerce('returns'), isFalse);
      expect(OrderStatusConstants.isActiveEcommerce(null), isFalse);
    });

    test('isEcommerceTerminal correctly identifies terminal e-commerce statuses', () {
      expect(OrderStatusConstants.isEcommerceTerminal('delivered'), isTrue);
      expect(OrderStatusConstants.isEcommerceTerminal('cancelled'), isTrue);
      expect(OrderStatusConstants.isEcommerceTerminal('returns'), isTrue);
      
      expect(OrderStatusConstants.isEcommerceTerminal('new'), isFalse);
      expect(OrderStatusConstants.isEcommerceTerminal('shipped'), isFalse);
      expect(OrderStatusConstants.isEcommerceTerminal(null), isFalse);
    });
  });

  group('AdminApprovalStatusConstants', () {
    test('normalize correctly handles various inputs', () {
      expect(AdminApprovalStatusConstants.normalize('approved'), 'approved');
      expect(AdminApprovalStatusConstants.normalize(' APPROVED '), 'approved');
      expect(AdminApprovalStatusConstants.normalize('rejected'), 'rejected');
      expect(AdminApprovalStatusConstants.normalize(' REJECTED '), 'rejected');
      
      // Fallbacks
      expect(AdminApprovalStatusConstants.normalize('pending'), 'pending');
      expect(AdminApprovalStatusConstants.normalize(null), 'pending');
      expect(AdminApprovalStatusConstants.normalize(''), 'pending');
      expect(AdminApprovalStatusConstants.normalize('   '), 'pending');
      expect(AdminApprovalStatusConstants.normalize('unknown_status'), 'pending');
    });

    test('boolean checkers work correctly', () {
      expect(AdminApprovalStatusConstants.isPending('pending'), isTrue);
      expect(AdminApprovalStatusConstants.isPending(null), isTrue); // fallback is pending
      expect(AdminApprovalStatusConstants.isPending('approved'), isFalse);
      
      expect(AdminApprovalStatusConstants.isDecided('approved'), isTrue);
      expect(AdminApprovalStatusConstants.isDecided('rejected'), isTrue);
      expect(AdminApprovalStatusConstants.isDecided('pending'), isFalse);
      expect(AdminApprovalStatusConstants.isDecided(null), isFalse);
      
      expect(AdminApprovalStatusConstants.isApproved(' APPROVED '), isTrue);
      expect(AdminApprovalStatusConstants.isApproved('rejected'), isFalse);
      
      expect(AdminApprovalStatusConstants.isRejected('rejected'), isTrue);
      expect(AdminApprovalStatusConstants.isRejected('approved'), isFalse);
    });
  });
}
