import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final usersGuard = File(
    'supabase/migrations/20260915_users_privileged_column_guard.sql',
  ).readAsStringSync();
  final tableOrders = File(
    'supabase/migrations/20260915_table_orders_store_isolation.sql',
  ).readAsStringSync();
  final brand = File(
    'supabase/migrations/20260915_brand_verification_admin_scope.sql',
  ).readAsStringSync();
  final rental = File(
    'supabase/migrations/20260915_vehicle_rental_overlap_guard.sql',
  ).readAsStringSync();
  final auth = File('lib/services/auth_service.dart').readAsStringSync();
  final occupancy = File(
    'lib/services/store/store_table_service.dart',
  ).readAsStringSync();
  final deleteFn = File(
    'supabase/functions/delete-account/index.ts',
  ).readAsStringSync();
  final liveAudit = File(
    'supabase/diagnostics/20260915_live_security_audit.sql',
  ).readAsStringSync();

  test('NORMAL USER: cannot self-write users.role to admin', () {
    expect(usersGuard, contains('protect_users_privileged_columns'));
    expect(usersGuard, contains("new.role := 'user'"));
    expect(usersGuard, contains('new.role := old.role'));
    expect(usersGuard, contains('new.is_seller_approved := old.is_seller_approved'));
    expect(usersGuard, contains("current_setting('ibul.allow_privileged_user_update'"));
    expect(auth, isNot(contains('_writeUserRole')));
    expect(auth, contains("updates['role'] = 'user'"));
    expect(auth, contains('never treat it as an admin grant'));
    expect(auth, contains('user_metadata.role is client-controlled'));
    expect(auth, isNot(contains("updates['role'] = resolvedUser.userMetadata")));
  });

  test('NORMAL USER: cannot read another store table_orders via USING(true)', () {
    expect(tableOrders, contains("drop policy if exists \"table_orders_authenticated_all\""));
    expect(tableOrders, contains('table_orders_select_staff'));
    expect(tableOrders, contains('can_manage_table_orders'));
    expect(tableOrders, isNot(contains('USING (true)')));
    expect(tableOrders, contains('list_occupied_table_numbers'));
    expect(occupancy, contains('list_occupied_table_numbers'));
  });

  test('NORMAL USER: cannot read another store brand verification row', () {
    expect(brand, contains("drop policy if exists \"brand_verification_admin_select_all\""));
    expect(brand, contains("drop policy if exists \"brand_verification_admin_update_all\""));
    expect(brand, contains('using (public.is_admin_user())'));
    expect(brand, isNot(contains('using (true)')));
  });

  test('SELLER A: cannot change Seller B orders', () {
    expect(tableOrders, contains('table_orders_update_staff'));
    expect(tableOrders, contains('table_orders_delete_staff'));
    expect(tableOrders, contains('table_orders_require_staff_trg'));
    expect(tableOrders, contains('user_can_access_restaurant'));
  });

  test('NON ADMIN: admin helpers still require users.role after freeze', () {
    expect(usersGuard, contains('security definer'));
    expect(usersGuard, contains('set search_path = public'));
    expect(usersGuard, contains('create or replace function public.is_admin_user'));
    expect(usersGuard, contains('create or replace function public.vehicle_is_admin'));
    expect(usersGuard, contains('revoke all on function public.is_admin_user(uuid) from anon'));
    expect(
      usersGuard,
      contains("grant execute on function public.restore_own_admin_role() to authenticated"),
    );
  });

  test('RENTAL: create and draft update share listing lock + overlap exclude', () {
    expect(rental, contains('from public.vehicle_listings'));
    expect(rental, contains('for update'));
    expect(rental, contains('vehicle_reservations_no_overlap_excl'));
    expect(rental, contains('exclude using gist'));
    expect(rental, contains('vehicle_rental_window_blocked'));
    expect(rental, contains("status <> 'pending_docs'"));
  });

  test('ACCOUNT DELETE: edge function uses admin API, not client service role', () {
    expect(deleteFn, contains("auth.admin.deleteUser"));
    expect(deleteFn, contains('getAuthedContext'));
    expect(deleteFn, isNot(contains('Deno.env.get(\'SUPABASE_SERVICE_ROLE_KEY\')')));
    expect(auth, contains("functions.invoke('delete-account')"));
  });

  test('LIVE AUDIT SCRIPT is read-only', () {
    expect(liveAudit, contains('READ ONLY'));
    expect(liveAudit.toLowerCase(), isNot(contains('alter table')));
    expect(liveAudit.toLowerCase(), isNot(contains('drop policy')));
    expect(liveAudit.toLowerCase(), isNot(contains('create policy')));
    expect(liveAudit, contains('pg_policies'));
    expect(liveAudit, contains('table_orders_authenticated_all_present'));
  });
}
