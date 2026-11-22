import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:ibul_app/utils/kitchen_print_dedup.dart';

void main() {
  group('kitchenTicketGarsonLabel', () {
    test('the staff member\'s own name is printed, not the title', () {
      expect(
        kitchenTicketGarsonLabel(waiterName: 'Ahmet', waiterTitle: 'Garson'),
        'Ahmet',
      );
    });

    test('the title is only a fallback when no name is known', () {
      expect(kitchenTicketGarsonLabel(waiterTitle: 'Şef Garson'), 'Şef Garson');
      expect(
        kitchenTicketGarsonLabel(waiterName: '  ', waiterTitle: 'Garson'),
        'Garson',
      );
    });

    test('nothing known prints nothing', () {
      expect(kitchenTicketGarsonLabel(), '');
    });
  });

  group('staffIdentityLabel', () {
    test('staff see "name — title"', () {
      expect(
        staffIdentityLabel(isOwner: false, name: 'Ahmet', jobTitle: 'Garson'),
        'Ahmet — Garson',
      );
    });

    test('a missing title or name degrades without a dangling dash', () {
      expect(staffIdentityLabel(isOwner: false, name: 'Ahmet'), 'Ahmet');
      expect(staffIdentityLabel(isOwner: false, jobTitle: 'Garson'), 'Garson');
      expect(staffIdentityLabel(isOwner: false), isNull);
    });

    test('the owner panel is unchanged', () {
      expect(
        staffIdentityLabel(isOwner: true, name: 'Sahip', jobTitle: 'Müdür'),
        isNull,
      );
    });
  });
}
