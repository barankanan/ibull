import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final stageASql = File(
    'supabase/manual_patches/20261004_p0_money_authority_stage_a_compat.sql',
  ).readAsStringSync();
  final stageBSql = File(
    'supabase/manual_patches/20261004_p0_money_authority_stage_b_enforce.sql',
  ).readAsStringSync();
  final sql = '$stageASql\n$stageBSql';
  final checkout = File('lib/services/order_service.dart').readAsStringSync();
  final createOrder = File(
    'supabase/functions/create_order/index.ts',
  ).readAsStringSync();
  final refund = File('supabase/functions/refund/index.ts').readAsStringSync();
  final visual = File(
    'supabase/functions/visual-search-analyze/index.ts',
  ).readAsStringSync();
  final categories = File('SUPABASE_CATEGORIES_STORAGE.sql').readAsStringSync();

  final marketplaceFn = sql
      .split('create or replace function public.create_marketplace_order')
      .last
      .split('comment on function public.create_marketplace_order')
      .first;
  final checkoutFn = checkout
      .split('Future<Map<String, dynamic>> _createOrderFromCheckoutImpl')
      .last
      .split('Future<Map<String, dynamic>> createSellerExternalCargoOrder')
      .first;

  test('A price=1 is rejected and not written from the client', () {
    expect(marketplaceFn, contains('CLIENT_PRICE_REJECTED'));
    expect(marketplaceFn, isNot(contains('p_subtotal')));
    expect(marketplaceFn, isNot(contains('p_shipping_amount')));
    expect(
      marketplaceFn,
      contains('coalesce(nullif(p.discount_price, 0), p.price, 0)'),
    );
    expect(checkoutFn, contains('create_marketplace_order'));
    expect(checkoutFn, contains("'p_items': lines"));
    expect(checkoutFn, isNot(contains("'unit_price':")));
    expect(checkoutFn, isNot(contains("'subtotal_amount':")));
  });

  test('B shipping=0 is ignored and the server calculates the fee', () {
    expect(sql, contains('marketplace_server_shipping_fee'));
    expect(sql, contains("- 'shipping_fee' - 'shipping_amount'"));
    expect(marketplaceFn, isNot(contains('p_shipping_amount')));
    expect(marketplaceFn, contains('v_customer_fee'));
    expect(checkout, contains('_stripClientMoneyKeys'));
    expect(checkout, contains("'shipping_fee'"));
  });

  test('C discount=99999 is rejected instead of applied from the client', () {
    expect(sql, contains('CLIENT_DISCOUNT_REJECTED'));
    expect(marketplaceFn, contains("'discount', 'discount_amount'"));
    expect(marketplaceFn, contains('coupon_quote'));
    expect(checkout, isNot(contains('CouponRepository')));
  });

  test('D another user_id cannot own the order', () {
    expect(sql, contains('CLIENT_IDENTITY_REJECTED'));
    expect(marketplaceFn, contains('v_user uuid := auth.uid()'));
    expect(marketplaceFn, contains('user_id,\n    order_number'));
    expect(checkout, contains('Sipariş başka bir kullanıcı adına oluşturulamaz.'));
  });

  test('E another seller cannot update the order', () {
    expect(sql, contains('ORDER_UPDATE_DENIED'));
    expect(sql, contains('can_access_order_as_seller'));
    expect(sql, contains('trg_orders_money_authority'));
  });

  test('F client PAID is rejected', () {
    expect(sql, contains('CLIENT_PAYMENT_STATUS_REJECTED'));
    expect(marketplaceFn, contains("'pending'"));
    expect(sql, contains("'NEW', 'PENDING', 'TRY'"));
    expect(sql, contains('drop function if exists seller_ops.create_paid_order'));
    expect(createOrder, contains('CLIENT_PRICE_REJECTED'));
    expect(createOrder, contains('seller_ops.create_pending_order'));
    expect(createOrder, isNot(contains('create_paid_order')));
    expect(createOrder, isNot(contains('p_subtotal')));
  });

  test('G client refund success=true is rejected', () {
    expect(refund, contains('CLIENT_REFUND_REJECTED'));
    expect(refund, contains("'success' in body || 'p_success' in body"));
    expect(refund, contains('seller_ops.request_return_refund'));
    expect(refund, isNot(contains('p_success:')));
    expect(refund, isNot(contains('p_amount:')));
    expect(sql, contains('request_return_refund'));
    expect(sql, contains("'PENDING'"));
    expect(sql, contains('confirm_provider_refund'));
    expect(sql, contains('CLIENT_REFUND_REJECTED'));
    expect(sql, contains('grant execute on function seller_ops.confirm_provider_refund'));
    expect(sql, contains('to service_role'));
  });

  test('H anonymous categories upload and delete are rejected', () {
    expect(sql, contains('drop policy if exists "categories_public_insert"'));
    expect(sql, contains('drop policy if exists "categories_public_delete"'));
    expect(sql, contains('categories_admin_insert'));
    expect(sql, contains('is_admin_user(auth.uid())'));
    expect(categories, contains('public.is_admin_user()'));
    expect(categories, isNot(contains('create policy "categories_public_insert"')));
    expect(categories, isNot(contains('create policy "categories_public_delete"')));
    expect(categories, contains('categories_public_read'));
  });

  test('I visual-search-analyze without JWT returns 401', () {
    expect(visual, contains('AUTH_REQUIRED'));
    expect(visual, contains('401'));
    expect(visual, contains("VISUAL_SEARCH_ALLOW_MOCK") );
    expect(visual, contains('PRODUCTION_MOCK_DISABLED'));
    expect(visual, contains('VISUAL_SEARCH_ALLOW_MOCK') );
    expect(visual, contains('const maxBodyBytes = 65536'));
    expect(visual, contains('BODY_TOO_LARGE'));
    expect(visual, contains('const maxPerMinute = 10'));
    expect(visual, contains('RATE_LIMITED'));
    expect(visual, contains('ORIGIN_NOT_ALLOWED'));
    expect(visual, contains('IMAGE_OWNER_MISMATCH'));
    expect(visual, contains('https://ibul.com.tr'));
    expect(visual, isNot(contains("Access-Control-Allow-Origin': '*'")));
    expect(visual, isNot(contains('Access-Control-Allow-Origin": "*"')));
  });

  test('direct client insert of orders is removed from checkout', () {
    expect(sql, contains('ORDERS_INSERT_RPC_ONLY'));
    expect(sql, contains('revoke insert on table public.orders from anon, authenticated'));
    expect(sql, contains('revoke insert on table public.order_items from anon, authenticated'));
    expect(sql, contains('drop function if exists public.create_order_from_cart'));
    expect(sql, contains('drop function if exists seller_ops.create_paid_order'));
    expect(sql, contains('drop function if exists seller_ops.refund_order_return'));
    expect(checkoutFn, contains('create_marketplace_order'));
    expect(checkoutFn, isNot(contains(".from('orders')")));
    expect(checkoutFn, isNot(contains(".from('order_items')")));
    expect(checkoutFn, contains('cancel_marketplace_order_if_unpaid'));
  });

  test('A seller external cargo does not send client unit_price', () {
    final external = checkout
        .split('Future<Map<String, dynamic>> createSellerExternalCargoOrder')
        .last
        .split('Future<List<Map<String, dynamic>>> getUserOrders')
        .first;
    expect(external, contains('create_seller_external_cargo_order'));
    expect(external, contains("'p_items': lines"));
    expect(external, isNot(contains("'p_unit_price'")));
    expect(external, isNot(contains("'unit_price':")));
    expect(external, isNot(contains("'subtotal_amount':")));
    expect(sql, contains('create or replace function public.create_seller_external_cargo_order'));
    expect(sql, contains('CLIENT_PRICE_REJECTED'));
  });

  test('B seller external cargo does not send client shipping', () {
    final external = checkout
        .split('Future<Map<String, dynamic>> createSellerExternalCargoOrder')
        .last
        .split('Future<List<Map<String, dynamic>>> getUserOrders')
        .first;
    expect(external, isNot(contains("'p_shipping_fee'")));
    expect(external, isNot(contains("'shipping_amount':")));
    expect(sql, contains('marketplace_server_shipping_fee(v_seller, v_address)'));
    expect(sql, isNot(contains('p_shipping_amount')));
  });

  test('C seller external cargo cannot send paid=true', () {
    final external = checkout
        .split('Future<Map<String, dynamic>> createSellerExternalCargoOrder')
        .last
        .split('Future<List<Map<String, dynamic>>> getUserOrders')
        .first;
    expect(external, isNot(contains("'payment_status':")));
    expect(external, isNot(contains("'paid':")));
    expect(sql, contains("'pending', 'external'"));
    expect(sql, contains('CLIENT_PAYMENT_STATUS_REJECTED'));
  });

  test('D and E lib services do not insert orders or order_items', () {
    final hits = <String>[];
    final pattern = RegExp(
      "from\\((?:'orders'|\"orders\"|'order_items'|\"order_items\")\\)[\\s\\S]{0,160}\\.insert",
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (pattern.hasMatch(text)) hits.add(entity.path);
    }
    expect(hits, isEmpty);
  });

  test('stage A stays compatible and stage B enforces', () {
    final stageA = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_a_compat.sql',
    ).readAsStringSync();
    final stageB = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_b_enforce.sql',
    ).readAsStringSync();
    final sellerPanel = File(
      'lib/screens/seller_panel_page.dart',
    ).readAsStringSync();
    expect(stageA, contains('create_marketplace_order'));
    expect(stageA, contains('create_seller_external_cargo_order'));
    expect(stageA, contains('request_marketplace_refund'));
    expect(stageA, isNot(contains('revoke insert on table public.orders')));
    expect(stageA, isNot(contains('drop policy if exists "orders_user_insert"')));
    expect(stageA, isNot(contains('trg_orders_money_authority')));
    expect(stageB, contains('revoke insert on table public.orders'));
    expect(stageB, contains('drop policy if exists "orders_user_insert"'));
    expect(stageB, contains('trg_orders_money_authority'));
    expect(stageB, contains('drop function if exists seller_ops.create_paid_order'));
    expect(stageB, contains("categories_public_insert"));
    expect(sellerPanel, contains('İade Talebini Onayla'));
    expect(sellerPanel, contains('requestMarketplaceRefund'));
    expect(sellerPanel, isNot(contains("status: 'refunded'")));
    expect(checkout, contains('Ödeme durumu istemciden yazılamaz'));
    final stageBRollback = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_b_rollback.sql',
    ).readAsStringSync();
    final executableRollback = stageBRollback
        .split('\n')
        .where((line) => !line.trim().startsWith('--'))
        .join('\n')
        .toLowerCase();
    expect(executableRollback, isNot(contains('create policy')));
    expect(executableRollback, isNot(contains('grant insert')));
  });

  test('production schema contract: text product id, no invented columns', () {
    final stageA = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_a_compat.sql',
    ).readAsStringSync();
    final stageB = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_b_enforce.sql',
    ).readAsStringSync();
    final precheck = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_a_precheck.sql',
    ).readAsStringSync();
    final postcheck = File(
      'supabase/manual_patches/20261004_p0_money_authority_stage_a_postcheck.sql',
    ).readAsStringSync();
    final createOrder = File(
      'supabase/functions/create_order/index.ts',
    ).readAsStringSync();
    final refund = File('supabase/functions/refund/index.ts').readAsStringSync();

    expect(stageA, isNot(contains('product_id::uuid')));
    expect(stageA, isNot(contains('billing_address')));
    expect(stageA, isNot(contains('p.store_name')));
    expect(stageA, isNot(contains('stores.id')));
    for (final chunk in stageA.split('insert into public.order_items').skip(1)) {
      expect(chunk.split(')').first, isNot(contains('main_category')));
    }
    expect(stageA, contains('marketplace_parse_station_id'));
    for (final helper in [
      'public.marketplace_payload_forbidden_key(jsonb)',
      'public.marketplace_haversine_km(double precision, double precision, double precision, double precision)',
      'public.marketplace_server_shipping_fee(uuid, jsonb)',
      'public.marketplace_parse_station_id(text)',
    ]) {
      expect(stageA, contains('revoke execute on function $helper from anon'));
      expect(stageA, contains('revoke execute on function $helper from authenticated'));
      expect(stageA, isNot(contains('grant execute on function $helper to authenticated')));
    }
    expect(stageA, contains('marketplace_server_shipping_fee(v_seller, v_address)'));
    expect(stageA, contains('INVALID_STATION_ID'));
    expect(stageA, contains('p_actor_user_id := v_user'));
    expect(stageA, contains('p_payer_mode :='));
    expect(stageA, contains('SELLER_OPS_PRODUCT_ID_TYPE_MISMATCH'));
    expect(stageB, contains('is_admin_user(auth.uid())'));
    expect(stageB, contains('categories_auth_insert'));
    expect(stageB, contains('categories_auth_delete'));

    expect(precheck, contains('ALL_REQUIRED_CHECKS_OK'));
    final precheckSql = precheck
        .split('\n')
        .where((line) => !line.trim().startsWith('--'))
        .join('\n');
    expect(';'.allMatches(precheckSql).length, 1);
    expect(RegExp(r'is_admin_user\(\s*\)').hasMatch(stageB), isFalse);
    expect(postcheck, contains('auth_orders_insert_still_false'));
    expect(postcheck, isNot(contains('orders_user_insert')));

    expect(checkout, contains("'create_marketplace_order'"));
    expect(checkout, isNot(contains("'p_billing_address'")));
    for (final name in [
      'p_items',
      'p_delivery_address',
      'p_address_id',
      'p_delivery_type',
      'p_delivery_slot',
      'p_coupon_code',
      'p_idempotency_key',
      'p_payment_card_name',
      'p_payment_card_last4',
    ]) {
      expect(checkout, contains("'$name'"));
      expect(stageA, contains(name));
    }
    for (final name in [
      'p_actor_user_id',
      'p_seller_id',
      'p_items',
      'p_shipping_address',
      'p_buyer_note',
      'p_idempotency_key',
    ]) {
      expect(createOrder, contains(name));
      expect(stageA, contains(name));
    }
    expect(refund, contains('p_actor_user_id'));
    expect(refund, contains('p_return_id'));
    expect(stageA, contains('p_return_id'));
    expect(stageA, contains('for update'));
    expect(stageA, contains("order by item.value->>'product_id'"));
    expect(stageA, contains('when unique_violation then'));
    expect(stageA, contains("'pending'"));
    expect(stageA, isNot(contains('product_id::uuid')));
    expect(createOrder, contains('Do not deploy'));
    expect(
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .any((file) => file.readAsStringSync().contains("invoke('create_order'") || file.readAsStringSync().contains('invoke("create_order"')),
      isFalse,
    );
    expect(
      File('supabase/migrations/20261004_p0_marketplace_money_authority.sql').existsSync(),
      isFalse,
    );
    expect(
      File('supabase/manual_patches/20261004_p0_marketplace_money_authority.sql').existsSync(),
      isFalse,
    );
  });

  test('cancel unpaid order restores stock once and stays owner-scoped', () {
    final cancel = stageASql
        .split('create or replace function public.cancel_marketplace_order_if_unpaid')
        .last
        .split('revoke all on function public.cancel_marketplace_order_if_unpaid')
        .first;
    final stockAt = cancel.indexOf('set stock = coalesce(stock, 0) + v_qty');
    final deleteAt = cancel.indexOf('delete from public.order_items');
    expect(stockAt, greaterThan(0));
    expect(deleteAt, greaterThan(stockAt));
    expect(cancel, contains('order by product_id'));
    expect(cancel, contains('order by oi.product_id'));
    expect(cancel, contains("sum(oi.quantity)::int"));
    expect(cancel, contains('ORDER_NOT_FOUND'));
    expect(cancel, contains('ORDER_OWNER_MISMATCH'));
    expect(cancel, contains('ORDER_NOT_CANCELLABLE'));
    expect(cancel.indexOf('ORDER_NOT_CANCELLABLE'), lessThan(stockAt));
    expect(cancel, contains("'pending', 'unpaid', ''"));
    expect(cancel, isNot(contains('stock = stock -')));
    final categoryPatch = File(
      'supabase/manual_patches/20261004_categories_authenticated_write_hardening.sql',
    ).readAsStringSync();
    expect(categoryPatch, contains('drop policy if exists "categories_auth_insert"'));
    expect(categoryPatch, contains('drop policy if exists "categories_auth_update"'));
    expect(categoryPatch, contains('drop policy if exists "categories_auth_delete"'));
    expect(categoryPatch, contains('is_admin_user(auth.uid())'));
    expect(categoryPatch, isNot(contains('drop policy if exists "categories_public_read"')));
    expect(categoryPatch, isNot(contains('public.orders')));
  });
}
