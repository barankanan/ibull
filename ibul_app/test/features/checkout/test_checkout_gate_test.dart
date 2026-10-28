import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/features/checkout/test_checkout_action.dart';

void main() {
  final root = Directory.current.path.endsWith('ibul_app')
      ? Directory.current.path
      : '${Directory.current.path}/ibul_app';

  String read(String relative) => File('$root/$relative').readAsStringSync();

  tearDown(() {
    AppRuntimeConfig.setEnableTestCheckoutOverrideForTest(null);
  });

  test('client test checkout flag defaults off', () {
    AppRuntimeConfig.setEnableTestCheckoutOverrideForTest(null);
    expect(AppRuntimeConfig.enableTestCheckout, isFalse);
  });

  testWidgets('test area is hidden when the gate is off', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TestCheckoutAction(visible: false, onPressed: _noop),
        ),
      ),
    );
    expect(find.text('TEST MODU'), findsNothing);
    expect(find.text('TEST ALIŞVERİŞİNİ TAMAMLA'), findsNothing);
    expect(find.text('İHIZ ve sipariş sistemi testi'), findsNothing);
  });

  testWidgets('test button is active without a card when the gate is on', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestCheckoutAction(
            visible: true,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    expect(find.text('TEST MODU'), findsOneWidget);
    expect(find.text('İHIZ ve sipariş sistemi testi'), findsOneWidget);
    expect(
      find.text('Gerçek tahsilat yapılmadan test siparişi oluşturur.'),
      findsOneWidget,
    );
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('TEST ALIŞVERİŞİNİ TAMAMLA'));
    await tester.pump();
    expect(pressed, isTrue);
  });

  test('test RPC stays off unless the server flag is on', () {
    final sql = read(
      'supabase/manual_patches/20261007_marketplace_test_checkout.sql',
    );
    expect(sql, contains("values ('test_checkout', false)"));
    expect(sql, contains("raise exception 'TEST_CHECKOUT_DISABLED'"));
    expect(sql, contains('marketplace_test_checkout_enabled()'));
    expect(sql, isNot(contains('create or replace function public.create_marketplace_order')));
  });

  test('test order is pending and marked is_test, never paid', () {
    final sql = read(
      'supabase/manual_patches/20261007_marketplace_test_checkout.sql',
    );
    expect(sql, contains('is_test boolean not null default false'));
    expect(sql, contains('set is_test = true'));
    expect(sql, contains("and payment_status = 'pending'"));
    expect(sql, contains("'payment_status', 'pending'"));
    expect(sql, contains("raise exception 'CLIENT_PAYMENT_STATUS_REJECTED'"));
    expect(sql, contains("raise exception 'TEST_ORDER_PAYMENT_LOCKED'"));
    expect(sql, contains("raise exception 'TEST_ORDER_NOT_PENDING'"));
    expect(sql, contains('public.create_marketplace_order('));
    expect(sql, isNot(contains('payment_method')));
    expect(sql, contains("raise exception 'IDEMPOTENCY_KEY_NOT_TEST'"));
    expect(sql, contains("raise exception 'CLIENT_TEST_FLAG_REJECTED'"));
    expect(sql.toLowerCase(), isNot(contains("set payment_status = 'paid'")));
    expect(sql, contains('revoke all on table public.marketplace_runtime_flags from authenticated'));
  });

  test('normal checkout still calls create_marketplace_order', () {
    final service = read('lib/services/order_service.dart');
    final checkout = read('lib/screens/checkout_page.dart');
    expect(service, contains("'create_marketplace_order'"));
    expect(service, contains('create_marketplace_test_order'));
    expect(service, contains('isServerTestCheckoutEnabled'));
    expect(service, isNot(contains("if (!AppRuntimeConfig.enableTestCheckout)")));
    expect(
      service,
      contains("_maybeEnsureIhizDeliveryTask(orderId, deliveryType)"),
    );
    expect(checkout, contains('Test siparişi oluşturuldu'));
    expect(checkout, contains('bool get _showTestCheckout => _serverTestCheckoutEnabled'));
    expect(checkout, contains('[TEST_CHECKOUT] test CTA tapped'));
    expect(checkout, contains('[CHECKOUT] normal CTA tapped'));
    final testFlow = checkout
        .split('Future<void> _completeTestOrder()')
        .last
        .split('Future<void> _completeOrder()')
        .first;
    final normalFlow = checkout
        .split('Future<void> _completeOrder()')
        .last
        .split('Widget _buildStepItem(')
        .first;
    expect(testFlow, contains('createTestOrderFromCheckout'));
    expect(testFlow, isNot(contains('_hasValidPaymentMethod')));
    expect(normalFlow, contains('_hasValidPaymentMethod()'));
    expect(normalFlow, contains('isChargeProviderReady'));
    expect(normalFlow, contains('createOrderFromCheckout'));
    expect(normalFlow, isNot(contains('createTestOrderFromCheckout')));
  });

  test('seller row carries is_test for the existing order card', () {
    final service = read('lib/services/order_service.dart');
    final seller = read('lib/screens/seller_panel_page.dart');
    expect(service, contains("'is_test': order['is_test'] == true"));
    expect(seller, contains('TEST SİPARİŞİ'));
  });

  test('ihiz task uniqueness is unchanged', () {
    final sql = read('supabase/migrations/20260825_ihiz_delivery_core.sql');
    expect(sql, contains('uq_ihiz_delivery_tasks_order_id'));
    expect(sql, contains('ensure_ihiz_delivery_task_for_order'));
  });
}

void _noop() {}
