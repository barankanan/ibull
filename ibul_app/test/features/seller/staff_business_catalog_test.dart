import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/seller/staff/staff_account_dialog.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/models/sub_admin.dart';

void main() {
  Set<SellerModule> modulesFor(String category) {
    return visibleSellerModules(category).toSet();
  }

  test('Teknosa category does not offer restaurant roles or permissions', () {
    final kind = resolveStaffBusinessKind(
      category: 'Elektronik',
      enabledModules: modulesFor('Elektronik'),
    );
    expect(kind, StaffBusinessKind.retail);
    final labels = staffRoleTemplates(kind).map((role) => role.label);
    expect(labels, isNot(contains('Garson')));
    final permissions = staffPermissionsForKind(kind);
    expect(permissions, isNot(contains(SellerPermission.transferTable)));
    expect(permissions, isNot(contains(SellerPermission.closeBill)));
    expect(permissions, isNot(contains(SellerPermission.splitBill)));
    expect(permissions, isNot(contains(SellerPermission.takePartialPayment)));
  });

  test('restaurant category offers waiter without close or staff rights', () {
    final kind = resolveStaffBusinessKind(
      category: 'Yemek',
      enabledModules: modulesFor('Yemek'),
    );
    expect(kind, StaffBusinessKind.restaurant);
    final waiter = staffRoleTemplates(kind)
        .singleWhere((role) => role.storedRole == 'waiter');
    expect(waiter.label, 'Garson');
    expect(waiter.suggested, isNot(contains(SellerPermission.closeBill)));
    expect(waiter.suggested, isNot(contains(SellerPermission.manageStaff)));
    expect(waiter.suggested, contains(SellerPermission.manageOrders));
    expect(
      staffTemplateSelection(
        template: waiter,
        isOwner: true,
        held: const <String>{},
      ),
      isNot(contains(SellerPermission.transferTable)),
    );
    expect(staffPermissionPersists(SellerPermission.transferTable), isTrue);
    expect(staffPermissionPersists(SellerPermission.takePartialPayment), isTrue);
    expect(staffPermissionPersists(SellerPermission.closeBill), isTrue);
    expect(
      pageFullAccessOperations(SellerModule.garson),
      containsAll(<SellerPermission>[
        SellerPermission.manageOrders,
        SellerPermission.closeBill,
        SellerPermission.transferTable,
      ]),
    );
    expect(
      pageFullAccessOperations(SellerModule.products),
      <SellerPermission>{SellerPermission.manageProducts},
    );
    expect(
      pageFullAccessOperations(SellerModule.store),
      isEmpty,
    );
    expect(staffPermissionPersists(SellerPermission.manageStaff), isTrue);
    expect(
      waiterPermissionCeiling,
      contains(SellerPermission.takePartialPayment),
    );
    expect(waiterPermissionCeiling, isNot(contains(SellerPermission.closeBill)));
    expect(waiter.suggested, isNot(contains(SellerPermission.takePartialPayment)));
    expect(staffPermissionsForKind(kind), contains(SellerPermission.closeBill));
  });

  test('category alone does not open restaurant staff without the module', () {
    final kind = resolveStaffBusinessKind(
      category: 'Yemek',
      enabledModules: const <SellerModule>{},
    );
    expect(kind, isNot(StaffBusinessKind.restaurant));
    expect(
      staffPermissionsForKind(kind),
      isNot(contains(SellerPermission.closeBill)),
    );
  });

  test('manageOrders does not imply closeBill or manageStaff', () {
    expect(
      staffGrantWithinCeiling(
        isOwner: false,
        held: const <String>{'manageOrders', 'manageStaff'},
        requested: const <String>['closeBill'],
      ),
      isFalse,
    );
  });

  testWidgets('retail dialog does not show Garson or bill permissions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.retail,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Teknosa Merkez'},
              ],
              onSubmit: (_) async {},
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Garson'), findsNothing);
    expect(find.text('Masa Aktar'), findsNothing);
    expect(find.text('Hesabı Kes'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Mağaza Müdürü'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Satış Personeli'), findsOneWidget);
    expect(find.text('Garson'), findsNothing);
  });

  testWidgets('restaurant dialog shows Garson and keeps bill permission closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.restaurant,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Salon'},
              ],
              onSubmit: (_) async {},
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Garson'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Garson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hesabı Kes'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hesabı Kes'), findsOneWidget);
    final closeTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Hesabı Kes'),
    );
    expect(closeTile.value, isFalse);
    expect(closeTile.onChanged, isNotNull);
  });

  test('role templates cannot escalate beyond waiter or sub_admin', () {
    for (final kind in StaffBusinessKind.values) {
      for (final role in staffRoleTemplates(kind)) {
        expect(role.storedRole, isIn(<String>['waiter', 'sub_admin']));
        expect(role.suggested, isNot(contains(SellerPermission.closeBill)));
        expect(role.suggested, isNot(contains(SellerPermission.manageStaff)));
        expect(role.suggested, isNot(contains(SellerPermission.transferTable)));
      }
    }
    final gallery = resolveStaffBusinessKind(
      category: 'Galerici',
      enabledModules: modulesFor('Galerici'),
    );
    expect(gallery, StaffBusinessKind.gallery);
    expect(
      staffPermissionsForKind(gallery),
      isNot(contains(SellerPermission.transferTable)),
    );
    expect(
      staffRoleTemplates(gallery).map((role) => role.label),
      isNot(contains('Garson')),
    );
  });

  testWidgets('editing a waiter does not rewrite the role as sub_admin', (
    tester,
  ) async {
    StaffAccountDraft? saved;
    final waiter = SubAdmin(
      id: 'waiter-1',
      email: 'garson@ibul.test',
      displayName: 'Ayşe',
      staffRole: 'waiter',
      branchId: 'branch-1',
      permissions: const <SellerPermission>[
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
      ],
      status: 'active',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.restaurant,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Salon'},
              ],
              editing: waiter,
              onSubmit: (draft) async => saved = draft,
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved?.staffRole, 'waiter');
    expect(saved?.permissions, isNot(contains(SellerPermission.closeBill)));
    expect(saved?.permissions, isNot(contains(SellerPermission.manageStaff)));
    expect(saved?.permissions, contains(SellerPermission.manageOrders));
  });

  testWidgets('edit keeps a stored transferTable while it is not yet persistable', (
    tester,
  ) async {
    StaffAccountDraft? saved;
    const current = <SellerPermission>[
      SellerPermission.viewOrders,
      SellerPermission.manageOrders,
      SellerPermission.manageProducts,
      SellerPermission.manageSupport,
      SellerPermission.transferTable,
    ];
    final retained = staffPermissionsRetainedOnEdit(
      kind: StaffBusinessKind.restaurant,
      current: current,
    );
    expect(retained, isEmpty);
    final waiter = SubAdmin(
      id: 'waiter-1',
      email: 'garson@ibul.test',
      displayName: 'Ayşe',
      staffRole: 'waiter',
      branchId: 'branch-1',
      permissions: current,
      status: 'active',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.restaurant,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Salon'},
              ],
              editing: waiter,
              retainedPermissions: retained,
              onSubmit: (draft) async => saved = draft,
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved?.staffRole, 'waiter');
    expect(saved?.permissions, contains(SellerPermission.transferTable));
    expect(saved?.permissions, contains(SellerPermission.manageOrders));
    expect(saved?.permissions, isNot(contains(SellerPermission.closeBill)));
    expect(saved?.permissions, isNot(contains(SellerPermission.manageStaff)));
    expect(saved?.revokedPermissions, isEmpty);
  });

  testWidgets('unchecking a stored transferTable revokes it', (tester) async {
    StaffAccountDraft? saved;
    final waiter = SubAdmin(
      id: 'waiter-1',
      email: 'garson@ibul.test',
      displayName: 'Ayşe',
      staffRole: 'waiter',
      branchId: 'branch-1',
      permissions: const <SellerPermission>[
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
        SellerPermission.transferTable,
      ],
      status: 'active',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.restaurant,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Salon'},
              ],
              editing: waiter,
              retainedPermissions: staffPermissionsRetainedOnEdit(
                kind: StaffBusinessKind.restaurant,
                current: waiter.permissions,
              ),
              onSubmit: (draft) async => saved = draft,
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(CheckboxListTile, 'Masa Aktar');
    await tester.scrollUntilVisible(
      tile,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final checkbox = tester.widget<CheckboxListTile>(tile);
    expect(checkbox.onChanged, isNotNull);
    checkbox.onChanged!(false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved?.permissions, isNot(contains(SellerPermission.transferTable)));
    expect(saved?.revokedPermissions, contains(SellerPermission.transferTable));
    expect(saved?.permissions, contains(SellerPermission.manageOrders));
    expect(saved?.revokedPermissions, isNot(contains(SellerPermission.closeBill)));
    expect(saved?.revokedPermissions, isNot(contains(SellerPermission.manageStaff)));
  });

  testWidgets('role change trims the ceiling and branch change is saved', (
    tester,
  ) async {
    StaffAccountDraft? saved;
    final manager = SubAdmin(
      id: 'lead-1',
      email: 'mudur@ibul.test',
      displayName: 'Mehmet',
      staffRole: 'sub_admin',
      branchId: 'branch-1',
      permissions: const <SellerPermission>[
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
        SellerPermission.viewFinance,
        SellerPermission.transferTable,
        SellerPermission.closeBill,
        SellerPermission.manageStaff,
      ],
      status: 'active',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStaffAccountDialog(
              context: context,
              kind: StaffBusinessKind.restaurant,
              isOwner: true,
              heldPermissions: const <String>{},
              branches: const [
                <String, dynamic>{'id': 'branch-1', 'name': 'Salon'},
                <String, dynamic>{'id': 'branch-2', 'name': 'Teras'},
              ],
              editing: manager,
              onSubmit: (draft) async => saved = draft,
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'Garson');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved?.jobTitle, 'Garson');
    expect(saved?.staffRole, 'sub_admin');
    expect(saved?.branchId, 'branch-1');
    expect(saved?.permissions, contains(SellerPermission.viewFinance));
    expect(saved?.permissions, contains(SellerPermission.closeBill));
    expect(saved?.staffRole, isNot('waiter'));
  });

  testWidgets('staff dialog fits phone and desktop without overflow', (
    tester,
  ) async {
    Future<void> openAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStaffAccountDialog(
                context: context,
                kind: StaffBusinessKind.retail,
                isOwner: true,
                heldPermissions: const <String>{},
                branches: const [
                  <String, dynamic>{'id': 'branch-1', 'name': 'Merkez'},
                ],
                onSubmit: (_) async {},
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(find.text('Personel hesabı oluştur'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }

    await openAt(const Size(390, 844));
    await openAt(const Size(1280, 800));
    await tester.binding.setSurfaceSize(null);
  });
}
