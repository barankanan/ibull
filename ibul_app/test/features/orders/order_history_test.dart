import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/features/orders/helpers/order_history_navigation.dart';
import 'package:ibul_app/features/orders/helpers/order_history_status_helper.dart';
import 'package:ibul_app/features/orders/models/order_history_models.dart';
import 'package:ibul_app/features/orders/screens/order_history_page.dart';
import 'package:ibul_app/features/orders/services/order_history_service.dart';
import 'package:ibul_app/features/orders/widgets/order_history_order_card.dart';
import 'package:ibul_app/features/orders/widgets/order_history_states.dart';
import 'package:ibul_app/features/orders/widgets/order_history_web_cta.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/orders_page.dart';
import 'package:ibul_app/screens/product_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  test('status filter matches delivered orders', () {
    expect(
      OrderHistoryStatusHelper.matchesStatusFilter(
        'delivered',
        OrderHistoryStatusFilter.delivered,
      ),
      isTrue,
    );
    expect(
      OrderHistoryStatusHelper.matchesStatusFilter(
        'delivered',
        OrderHistoryStatusFilter.cancelled,
      ),
      isFalse,
    );
  });

  test('filter past orders by month and year', () {
    final orders = [
      {
        'id': '1',
        'status': 'delivered',
        'created_at': '2026-03-10T10:00:00Z',
        'items': [
          {'status': 'delivered'},
        ],
      },
      {
        'id': '2',
        'status': 'delivered',
        'created_at': '2025-12-01T10:00:00Z',
        'items': [
          {'status': 'delivered'},
        ],
      },
    ];

    final filtered = OrderHistoryService.instance.filterPastOrders(
      orders: orders,
      filter: const OrderHistoryFilter(month: 3, year: 2026),
    );

    expect(filtered.length, 1);
    expect(filtered.first['id'], '1');
  });

  testWidgets('order history page shows app bar title without duplicate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(size: const Size(390, 844)),
              child: child!,
            );
          },
          home: const OrderHistoryPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Eski Siparişlerim'), findsOneWidget);
    expect(
      find.text(
        'Daha önce aldıklarını burada görebilir, tekrar sipariş verebilirsin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tekrar almak çok kolay'), findsNothing);
    expect(find.text('Son Siparişi Tekrar Al'), findsNothing);
    expect(find.text('Akıllı Tekrar Al • Yakında'), findsOneWidget);
  });

  testWidgets('order history page renders empty state for guest', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(size: const Size(390, 844)),
              child: child!,
            );
          },
          home: const OrderHistoryPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Henüz eski siparişin yok'), findsOneWidget);
    expect(find.text('Alışverişe Başla'), findsOneWidget);
  });

  testWidgets('orders page web shows history CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(size: const Size(1200, 900)),
              child: child!,
            );
          },
          home: const OrdersPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(OrderHistoryWebCta), findsOneWidget);
    expect(find.text('Eski Siparişler / Tekrar Al'), findsOneWidget);
  });

  testWidgets('order history page renders error state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderHistoryErrorState(onRetry: _noop)),
      ),
    );

    expect(find.text('Siparişler yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('smart reorder footer is shown at bottom', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartReorderFooter())),
    );

    expect(find.text('Akıllı Tekrar Al • Yakında'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('order card shows compact date amount and reorder pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderHistoryOrderCard(
            order: {
              'id': '1',
              'order_number': '7056852',
              'status': 'shipped',
              'created_at': '2026-03-10T10:17:00Z',
              'total_amount': 111641.10,
              'items': [
                {
                  'store_name': 'Teknosa',
                  'status': 'shipped',
                  'product_image_url': '',
                },
              ],
            },
            onTap: () {},
            onOpenProduct: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Tarih:'), findsOneWidget);
    expect(find.textContaining('Tutar:'), findsOneWidget);
    expect(find.textContaining('No:'), findsOneWidget);
    expect(find.textContaining('111641.10 TL'), findsOneWidget);
    expect(find.text('Tekrar Al'), findsOneWidget);
  });

  test('resolveProductIdFromItem prefers product_id', () {
    final id = OrderHistoryService.instance.resolveProductIdFromItem({
      'product_id': 'abc-123',
      'product_code': 'code-456',
    });
    expect(id, 'abc-123');
  });

  test('isNavigableProduct requires id and name', () {
    expect(
      OrderHistoryService.isNavigableProduct(
        Product(
          productId: 'p-1',
          name: 'Telefon',
          brand: 'Marka',
          price: '100 TL',
          rating: 0,
          reviewCount: 0,
          tags: const [],
          images: const [],
        ),
      ),
      isTrue,
    );
    expect(
      OrderHistoryService.isNavigableProduct(
        Product(
          name: 'Telefon',
          brand: 'Marka',
          price: '100 TL',
          rating: 0,
          reviewCount: 0,
          tags: const [],
          images: const [],
        ),
      ),
      isFalse,
    );
  });

  testWidgets('openOrderHistoryProductDetail shows snackbar when product missing',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    OrderHistoryNavigation.openOrderHistoryProductDetail(
                      context,
                      const {'product_name': ''},
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ürün şu anda görüntülenemiyor.'), findsOneWidget);
    expect(find.byType(ProductDetailPage), findsNothing);
  });

  testWidgets('cancelled order card keeps badge and reorder chip aligned',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderHistoryOrderCard(
            order: {
              'id': '1',
              'order_number': '7056852',
              'status': 'cancelled',
              'created_at': '2026-03-10T10:17:00Z',
              'total_amount': 111641.10,
              'items': [
                {
                  'store_name': 'Teknosa',
                  'status': 'cancelled',
                  'product_image_url': '',
                },
              ],
            },
            onTap: () {},
            onOpenProduct: () {},
          ),
        ),
      ),
    );

    expect(find.text('İptal Edildi'), findsOneWidget);
    expect(find.text('Tekrar Al'), findsOneWidget);

    final badgeSizedBox = find.ancestor(
      of: find.text('İptal Edildi'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == kOrderHistoryActionChipHeight,
      ),
    );
    final pillSizedBox = find.ancestor(
      of: find.text('Tekrar Al'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == kOrderHistoryActionChipHeight,
      ),
    );
    expect(badgeSizedBox, findsOneWidget);
    expect(pillSizedBox, findsOneWidget);

    final badgeBox = tester.getRect(find.text('İptal Edildi'));
    final pillBox = tester.getRect(find.text('Tekrar Al'));
    expect(pillBox.left - badgeBox.right, greaterThanOrEqualTo(6));
  });

  test('reorder result does not report success when all blocked', () {
    const result = ReorderResult(
      added: [],
      blocked: [
        ReorderLineCheck(
          orderItemId: '1',
          productName: 'Ürün',
          quantity: 1,
          outcome: ReorderItemOutcome.notListed,
        ),
      ],
      priceChanged: [],
      allBlocked: true,
    );

    expect(result.hasAdded, isFalse);
    expect(result.allBlocked, isTrue);
  });
}

void _noop() {}
