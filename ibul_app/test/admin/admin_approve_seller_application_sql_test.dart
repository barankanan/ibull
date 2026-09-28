import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin approve SQL creates definer RPC and insert policy', () {
    final sql = File(
      'supabase/migrations/20260902_admin_approve_seller_application.sql',
    ).readAsStringSync();

    expect(sql.contains('admin_approve_seller_application'), isTrue);
    expect(sql.contains('security definer'), isTrue);
    expect(sql.contains('Admins can insert stores'), isTrue);
    expect(sql.contains('admin_can_manage_users'), isTrue);
    expect(sql.contains("raise exception 'not authorized'"), isTrue);
    expect(sql.contains('grant execute'), isTrue);
    expect(sql.contains('vehicle_galleries'), isTrue);
    expect(sql.contains('store_is_gallery_category'), isTrue);
    expect(sql.contains("then public.users.role"), isTrue);
    expect(sql.contains("else 'seller'"), isTrue);
  });

  test('admin restore SQL targets auth user and public.users', () {
    final sql = File(
      '../SUPABASE_FIX_RESTORE_ADMIN_ROLE.sql',
    ).readAsStringSync();
    expect(sql.contains('baran.kan@gmail.com'), isTrue);
    expect(sql.contains('on conflict (id) do update'), isTrue);
    expect(sql.contains("role = 'admin'"), isTrue);
    expect(sql.contains('raw_user_meta_data'), isTrue);
    expect(sql.contains('restore_own_admin_role'), isTrue);
  });

  test('store vertical auth safety SQL is category-independent', () {
    final sql = File(
      'supabase/migrations/20260910_store_vertical_auth_safety.sql',
    ).readAsStringSync();
    expect(sql.contains('store_is_gallery_category'), isTrue);
    expect(sql.contains('restore_own_admin_role'), isTrue);
    expect(sql.contains('vehicle_galleries'), isTrue);
    expect(sql, isNot(contains("role = 'restaurant'")));
  });

  test('store serial hotfix reaches pgcrypto via extensions search_path', () {
    final sql = File(
      'supabase/migrations/20260909_store_serial_pgcrypto_search_path.sql',
    ).readAsStringSync();

    expect(sql.contains('create extension if not exists pgcrypto'), isTrue);
    expect(sql.contains('set search_path = public, extensions'), isTrue);
    expect(sql.contains('gen_random_bytes(6)'), isTrue);
    expect(sql.contains('ihiz_generate_business_serial'), isTrue);
  });
}
