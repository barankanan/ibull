import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/models/sub_admin.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/printer_link_status.dart';
import 'package:ibul_app/services/printer_tcp_probe.dart';
import 'package:ibul_app/services/store/close_table_rpc_args.dart';

void main() {
  test('close RPC uses only the live seven arguments', () {
    final params = closeTableWithHistoryRpcParams(
      sellerId: 'seller-1',
      tableNumber: 4,
      paymentMethod: 'cash',
      paymentNote: 'ok',
      waiterId: 'waiter-1',
      waiterName: 'Ayşe',
      sessionKey: 'session-1',
    );
    expect(params.keys, <String>[
      'p_seller_id',
      'p_table_number',
      'p_payment_method',
      'p_payment_note',
      'p_waiter_id',
      'p_waiter_name',
      'p_session_key',
    ]);
    expect(params.containsKey('p_table_name'), isFalse);
    expect(params.containsKey('p_display_table_label'), isFalse);
    expect(params.containsKey('p_table_area_name'), isFalse);
    expect(
      friendlyTableCloseError(
        Exception(
          'Could not find the function public.close_table_with_history',
        ),
      ),
      contains('Masa açık kaldı'),
    );
    expect(
      friendlyTableCloseError(
        Exception(
          'Masa kapatma yapılamadı: null value in column "original_order_id" violates not-null constraint 23502',
        ),
      ),
      contains('zorunlu sipariş numarası boş'),
    );
    expect(
      friendlyTableCloseError(Exception('Bu işlem için yetkiniz yok. 42501')),
      contains('yetkiniz yok'),
    );
    expect(
      friendlyTableTransferError(
        Exception('Aktarılacak sipariş yok. Kayıtlar yerinde kaldı. P0002'),
      ),
      'Aktarılacak açık sipariş bulunamadı. Siparişler yerinde kaldı.',
    );
    expect(
      friendlyTableTransferError(Exception('Bu işlem için yetkiniz yok. 42501')),
      contains('yetkiniz yok'),
    );
  });

  test('bridge health is not reported as a connected printer', () {
    final bridgeOnly = describePrinterLink(bridgeUp: true);
    expect(bridgeOnly.label, 'Kullanıcı müdahalesi gerekiyor');
    expect(bridgeOnly.label, isNot('Yazıcı hazır'));
    final down = describePrinterLink(bridgeUp: true, printerReachable: false);
    expect(down.label, 'Yazıcı bağlantısı kesildi');
    expect(down.detail, contains('Ethernet kablosunu'));
    final up = describePrinterLink(bridgeUp: true, printerReachable: true);
    expect(up.label, 'Yazıcı hazır');
    expect(up.detail, contains('basıldığı'));
    expect(
      printerTargetFromHealth(<String, dynamic>{
        'last_kitchen_tcp': <String, dynamic>{
          'host': '192.168.10.100',
          'port': 9100,
        },
      })?.host,
      '192.168.10.100',
    );
  });

  test('print HTTP budget covers render, socket budget stays 600 ms', () {
    expect(
      LocalPrintService.ethernetSocketBudget,
      const Duration(milliseconds: 600),
    );
    expect(
      LocalPrintService.ethernetPrintHttpTimeout,
      greaterThan(LocalPrintService.ethernetSocketBudget),
    );
    expect(
      waiterFacingPrintError(TimeoutException('TimeoutException')),
      contains('belirsiz'),
    );
    expect(
      waiterFacingPrintError(
        const LocalPrintServiceException(
          'raw',
          errorCode: 'print_outcome_unknown',
        ),
      ),
      isNot(contains('LocalPrintServiceException')),
    );
  });

  test('tcp probe reports a closed port and an accepting socket without a payload', () async {
    expect(
      await probePrinterTcp(
        host: '127.0.0.1',
        port: 1,
        timeout: const Duration(milliseconds: 300),
      ),
      isFalse,
    );
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      socket.close();
    });
    expect(
      await probePrinterTcp(host: '127.0.0.1', port: server.port),
      isTrue,
    );
    await server.close();
  });

  test('job title does not choose the security role or the pages', () {
    expect(
      securityRoleForStaffGrants(
        kind: StaffBusinessKind.restaurant,
        grants: const {SellerPermission.viewOrders, SellerPermission.manageOrders},
      ),
      'waiter',
    );
    expect(
      securityRoleForStaffGrants(
        kind: StaffBusinessKind.restaurant,
        grants: const {
          SellerPermission.viewOrders,
          SellerPermission.viewFinance,
          SellerPermission.closeBill,
        },
      ),
      'sub_admin',
    );
    expect(
      securityRoleForStaffGrants(
        kind: StaffBusinessKind.retail,
        grants: const {SellerPermission.viewOrders},
      ),
      'sub_admin',
    );
    final pages = modulesForStaff(
      modules: visibleSellerModules('Yemek'),
      isOwner: false,
      staffRole: 'sub_admin',
      permissions: const {'viewFinance', 'closeBill'},
      visibleModules: const {'garson', 'orders'},
    );
    expect(pages, contains(SellerModule.garson));
    expect(pages, contains(SellerModule.orders));
    expect(pages, isNot(contains(SellerModule.finance)));
  });

  test('unknown permission names are not promoted to manageProducts', () {
    final member = SubAdmin.fromMap(
      <String, dynamic>{
        'permissions': <String>['viewOrders', 'page:finance'],
        'job_title': 'Salon Sorumlusu',
        'visible_modules': <String>['garson'],
        'staff_role': 'waiter',
        'status': 'active',
      },
      'member-1',
    );
    expect(member.permissions, <SellerPermission>[SellerPermission.viewOrders]);
    expect(member.jobTitle, 'Salon Sorumlusu');
    expect(member.visibleModules, <String>['garson']);
  });
}
