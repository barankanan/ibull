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
