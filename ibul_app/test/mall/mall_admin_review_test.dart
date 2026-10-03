import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/admin/panel/models/admin_menu_registry.dart';
import 'package:ibul_app/features/mall/admin/mall_admin_repository.dart';
import 'package:ibul_app/features/mall/admin/mall_application_admin_page.dart';
import 'package:ibul_app/features/mall/models/mall_application.dart';
import 'package:ibul_app/models/admin_permissions.dart';

void main() {
  test('admin status labels do not leak database values', () {
    expect(
      mallAdminStatusLabel(MallApplicationStatus.needsInfo),
      'Bilgi Bekleniyor',
    );
    expect(
      mallAdminStatusLabel(MallApplicationStatus.pendingReview),
      'İncelemede',
    );
    expect(mallAdminStatusLabel(MallApplicationStatus.approved), 'Onaylandı');
  });

  test('rpc parameter maps match backend signatures', () {
    expect(
      MallAdminCommands.approve('app-1', '  not '),
      {'p_application_id': 'app-1', 'p_admin_note': 'not'},
    );
    expect(
      MallAdminCommands.reject(
        applicationId: 'app-1',
        rejectionReason: ' eksik ',
        adminNote: '',
      ),
      {
        'p_application_id': 'app-1',
        'p_rejection_reason': 'eksik',
        'p_admin_note': null,
      },
    );
    expect(
      MallAdminCommands.requestInfo(
        applicationId: 'app-1',
        adminNote: 'kaşe yok',
      )['p_admin_note'],
      'kaşe yok',
    );
  });

  test('action gates follow application status', () {
    expect(mallAdminCanApprove(MallApplicationStatus.pendingReview), isTrue);
    expect(mallAdminCanApprove(MallApplicationStatus.approved), isFalse);
    expect(mallAdminCanRequestInfo(MallApplicationStatus.needsInfo), isFalse);
    expect(mallAdminCanReject(MallApplicationStatus.needsInfo), isTrue);
    expect(mallAdminCanReject(MallApplicationStatus.approved), isFalse);
  });

  test('concurrency and auth errors stay readable', () {
    expect(
      mallAdminErrorMessage(Exception('mall_application_invalid_state')),
      contains('değiştirilmiş'),
    );
    expect(
      mallAdminErrorMessage(Exception('not authorized')),
      'Bu işlem için yetkiniz yok.',
    );
    expect(
      mallAdminErrorMessage(Exception('22000 something')),
      isNot(contains('22000')),
    );
  });

  test('menu uses mall_review instead of a hardcoded admin role', () {
    final item = ibulAdminMenuDefinitions
        .where((entry) => entry.title == 'AVM Başvuruları')
        .single;
    expect(item.moduleKey, AdminModules.mallReview);
    expect(AdminModules.all, contains(AdminModules.mallReview));
    expect(
      defaultAdminRoleCatalog
          .firstWhere((role) => role.roleKey == 'admin')
          .modules,
      contains(AdminModules.mallReview),
    );
    expect(
      const AdminAccessBundle(
        roleKey: 'super_admin',
        roleTitle: 'Super Admin',
        allowedModules: [],
        deniedModules: [],
      ).canAccess(AdminModules.mallReview),
      isTrue,
    );
    expect(
      const AdminAccessBundle(
        roleKey: 'admin_support',
        roleTitle: 'Destek',
        allowedModules: [AdminModules.support],
        deniedModules: [],
      ).canAccess(AdminModules.mallReview),
      isFalse,
    );
  });

  testWidgets('queue renders title and empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MallApplicationAdminPage(repository: _EmptyAdminRepo()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AVM Başvuruları'), findsOneWidget);
    expect(find.text('Bekleyen AVM başvurusu bulunmuyor.'), findsOneWidget);
  });
}

class _EmptyAdminRepo extends MallAdminRepository {
  @override
  Future<MallAdminQueueCounts> counts() async {
    return const MallAdminQueueCounts(
      pending: 0,
      needsInfo: 0,
      approved: 0,
      rejected: 0,
    );
  }

  @override
  Future<List<MallApplication>> getApplications({
    String? status,
    String? search,
    int limit = 40,
    int offset = 0,
  }) async {
    return const [];
  }
}
