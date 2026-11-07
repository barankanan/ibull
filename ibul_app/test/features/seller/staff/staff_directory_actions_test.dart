import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_directory_actions.dart';
import 'package:ibul_app/models/sub_admin.dart';

SubAdmin _person({
  String id = '1',
  String? email = 'garson@ibul.test',
  String? phone,
  String status = 'active',
}) {
  return SubAdmin(
    id: id,
    email: email,
    phone: phone,
    permissions: const [SellerPermission.manageOrders],
    status: status,
  );
}

void main() {
  test('active staff can be deactivated and restored', () {
    final active = _person();
    expect(nextStaffStatus(active), staffStatusInactive);
    expect(nextStaffStatus(_person(status: 'inactive')), staffStatusActive);
    expect(staffCanBeDeactivated(_person(status: 'invited')), isTrue);
  });

  test('deletion requires the exact contact', () {
    expect(
      canConfirmStaffRemoval(typed: 'garson@ibul.test', contact: 'garson@ibul.test'),
      isTrue,
    );
    expect(
      canConfirmStaffRemoval(typed: 'yanlis', contact: 'garson@ibul.test'),
      isFalse,
    );
    expect(canConfirmStaffRemoval(typed: '', contact: ''), isFalse);
  });

  test('search and status filter stay together', () {
    final people = [
      _person(id: 'a', email: 'ayse@ibul.test'),
      _person(id: 'b', email: 'mehmet@ibul.test', status: 'inactive'),
    ];
    final found = filterStaffDirectory(
      staff: people,
      query: 'ayse',
      status: 'active',
    );
    expect(found.map((person) => person.id), ['a']);
  });
}
