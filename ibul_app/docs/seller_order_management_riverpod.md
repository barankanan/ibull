# Satıcı Paneli -> Sipariş Yönetimi

Bu tasarım mevcut uygulamadaki legacy `public.orders` akışını bozmadan ilerlemek için izole `seller_ops` şeması kullanır. Flutter tarafında yeni modül için **Riverpod** seçildi. Mevcut uygulama `provider` ile çalışsa da bu modül kademeli geçişle entegre edilebilir.

## A) Veritabanı Şeması + SQL
Ana migration dosyası:
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/SUPABASE_SELLER_ORDER_MANAGEMENT.sql](/Users/barankananogullari/Desktop/ibul2026/ibul_app/SUPABASE_SELLER_ORDER_MANAGEMENT.sql)

İçerik:
- `seller_ops.sellers`
- `seller_ops.orders`
- `seller_ops.order_items`
- `seller_ops.payments`
- `seller_ops.shipments`
- `seller_ops.shipment_events`
- `seller_ops.returns`
- `seller_ops.refunds`
- `seller_ops.notifications`
- `seller_ops.audit_logs`
- `seller_ops.order_status_history`
- enum tipleri
- indexler
- `updated_at` trigger'ları
- transaction mantığını taşıyan RPC fonksiyonları

## B) RLS Policy'leri
Aynı SQL dosyasının içinde tam policy seti bulunur.

Temel kural:
- satıcı yalnızca kendi `seller_id` kayıtlarını görür
- alıcı yalnızca kendi `buyer_user_id` siparişlerini görür
- bildirimler yalnızca `user_id = auth.uid()`
- kritik yazma akışları Edge Function + DB RPC üzerinden yürütülür

## C) Supabase Edge Functions
Fonksiyon dizini:
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/create_order/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/create_order/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/seller_accept_order/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/seller_accept_order/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/mark_preparing/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/mark_preparing/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/create_shipment_label/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/create_shipment_label/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/mark_shipped/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/mark_shipped/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/ingest_shipment_event/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/ingest_shipment_event/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/request_return/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/request_return/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/approve_return/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/approve_return/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/receive_return/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/receive_return/index.ts)
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/refund/index.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/refund/index.ts)
- ortak yardımcılar: [/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/_shared/http.ts](/Users/barankananogullari/Desktop/ibul2026/ibul_app/supabase/functions/_shared/http.ts)

### Deployment komutları
```bash
supabase functions deploy create_order
supabase functions deploy seller_accept_order
supabase functions deploy mark_preparing
supabase functions deploy create_shipment_label
supabase functions deploy mark_shipped
supabase functions deploy ingest_shipment_event
supabase functions deploy request_return
supabase functions deploy approve_return
supabase functions deploy receive_return
supabase functions deploy refund
```

### Endpoint listesi
- `POST /functions/v1/create_order`
- `POST /functions/v1/seller_accept_order`
- `POST /functions/v1/mark_preparing`
- `POST /functions/v1/create_shipment_label`
- `POST /functions/v1/mark_shipped`
- `POST /functions/v1/ingest_shipment_event`
- `POST /functions/v1/request_return`
- `POST /functions/v1/approve_return`
- `POST /functions/v1/receive_return`
- `POST /functions/v1/refund`

### Örnek cURL: create_order
```bash
curl -X POST "$SUPABASE_URL/functions/v1/create_order" \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "seller_id": "1b3f3d6c-aaaa-bbbb-cccc-111111111111",
    "payment_provider": "iyzico",
    "provider_payment_id": "pay_123",
    "currency": "TRY",
    "subtotal": 2499.90,
    "shipping_fee": 49.90,
    "commission_rate": 0.12,
    "shipping_address": {
      "full_name": "Baran K",
      "phone": "+905555555555",
      "address_line": "Arsuz / Hatay"
    },
    "buyer_note": "Kapıya bırakmayın",
    "items": [
      {
        "product_id": "0f2db0d4-aaaa-bbbb-cccc-222222222222",
        "variant_id": null,
        "title": "iPhone 17",
        "sku": "IPH17-512-BLK",
        "quantity": 1,
        "unit_price": 2499.90,
        "total_price": 2499.90,
        "weight_gram": 220
      }
    ]
  }'
```

Başarılı response:
```json
{
  "ok": true,
  "data": {
    "order_id": "b2e73d8f-...",
    "order_no": "IBUL-1000001",
    "status": "NEW"
  }
}
```

### Örnek cURL: seller_accept_order
```bash
curl -X POST "$SUPABASE_URL/functions/v1/seller_accept_order" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"b2e73d8f-..."}'
```

### Örnek cURL: mark_preparing
```bash
curl -X POST "$SUPABASE_URL/functions/v1/mark_preparing" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"b2e73d8f-...","note":"Paketleme başladı"}'
```

### Örnek cURL: create_shipment_label
```bash
curl -X POST "$SUPABASE_URL/functions/v1/create_shipment_label" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"b2e73d8f-...","carrier":"iHiz"}'
```

### Örnek cURL: mark_shipped
```bash
curl -X POST "$SUPABASE_URL/functions/v1/mark_shipped" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id":"b2e73d8f-...",
    "carrier":"iHiz",
    "tracking_no":"IHZ123456789"
  }'
```

### Örnek cURL: ingest_shipment_event
```bash
curl -X POST "$SUPABASE_URL/functions/v1/ingest_shipment_event" \
  -H "Authorization: Bearer <SYSTEM_OR_ADMIN_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id":"b2e73d8f-...",
    "code":"DELIVERED",
    "description":"Paket alıcıya teslim edildi.",
    "location":"Arsuz Şubesi",
    "occurred_at":"2026-03-01T12:30:00Z",
    "raw_payload":{"carrier":"iHiz"}
  }'
```

### Örnek cURL: request_return
```bash
curl -X POST "$SUPABASE_URL/functions/v1/request_return" \
  -H "Authorization: Bearer <BUYER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id":"b2e73d8f-...",
    "reason":"Beklediğim ürün değil",
    "details":"Kutu açılmadı"
  }'
```

### Örnek cURL: approve_return
```bash
curl -X POST "$SUPABASE_URL/functions/v1/approve_return" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"return_id":"7cf...","approve":true,"note":"Ürünü kargoya verin"}'
```

### Örnek cURL: receive_return
```bash
curl -X POST "$SUPABASE_URL/functions/v1/receive_return" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"return_id":"7cf...","mark_shipped_back":false,"note":"Paket teslim alındı"}'
```

### Örnek cURL: refund
```bash
curl -X POST "$SUPABASE_URL/functions/v1/refund" \
  -H "Authorization: Bearer <SELLER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "return_id":"7cf...",
    "provider":"iyzico",
    "provider_refund_id":"refund_555",
    "amount":2499.90,
    "success":true,
    "raw":{"batch":"B-1"}
  }'
```

## D) Flutter UI/UX Akışı

### 1) OrdersListScreen
Bileşenler:
- üst hero header
- KPI chips: `NEW`, `PREPARING`, `READY_TO_SHIP`, `SHIPPED`, `DELIVERED`, `CANCELED`, `RETURNS`
- arama barı: `order_no`, SKU, takip no, müşteri araması
- hızlı filtre row
- sipariş kartı:
  - ürün thumb
  - başlık
  - sipariş no
  - fiyat
  - durum chip
  - tarih
  - SLA countdown
  - aksiyonlar: `Detay`, `Onayla`, `Hazırlanıyor`, `Etiket`, `Kargoya Ver`
- 30sn highlight + `NEW` badge

### 2) OrderDetailScreen / BottomSheet
- müşteri kartı
- teslimat adresi
- ürün kalemleri
- komisyon / net kazanç breakdown
- kargo bölümü:
  - carrier seçimi
  - tracking no input
  - label URL
- timeline:
  - order_status_history
  - shipment_events
- return paneli
- sağ panelde aksiyon butonları

### 3) ReturnsQueueScreen
- `RETURN_REQUESTED`, `RETURN_APPROVED`, `RETURN_SHIPPED_BACK`, `RETURN_RECEIVED`, `REFUNDED`
- reason, SLA, iade notları

### 4) ShipmentTrackingDrawer
- shipment events timeline
- polling status
- manuel tracking fallback

## E) Flutter Kod İskeleti

### Önerilen dosya yapısı
```text
lib/features/seller_orders/
  data/
    dto/
      seller_order_dto.dart
      shipment_dto.dart
      return_dto.dart
    repositories/
      seller_orders_repository.dart
      seller_orders_repository_impl.dart
    datasources/
      seller_orders_remote_ds.dart
  domain/
    models/
      seller_order.dart
      order_item.dart
      shipment.dart
      shipment_event.dart
      order_return.dart
    enums/
      order_status.dart
      shipment_status.dart
      return_status.dart
    services/
      seller_order_actions.dart
  presentation/
    providers/
      seller_orders_providers.dart
    screens/
      orders_list_screen.dart
      order_detail_screen.dart
      returns_queue_screen.dart
    widgets/
      order_kpi_strip.dart
      seller_order_card.dart
      order_status_timeline.dart
      shipment_panel.dart
      sla_badge.dart
```

### pubspec ekleri
```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0
```

### Enum örneği
```dart
enum SellerOrderStatus {
  newOrder,
  preparing,
  readyToShip,
  shipped,
  delivered,
  canceled,
  returnRequested,
  returnApproved,
  returnShippedBack,
  returnReceived,
  refunded,
}
```

### Model örneği
```dart
class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.orderNo,
    required this.sellerId,
    required this.buyerUserId,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.shippingFee,
    required this.commissionAmount,
    required this.netAmount,
    required this.createdAt,
    required this.items,
    this.shippingAddress = const {},
  });

  final String id;
  final String orderNo;
  final String sellerId;
  final String buyerUserId;
  final SellerOrderStatus status;
  final String paymentStatus;
  final double subtotal;
  final double shippingFee;
  final double commissionAmount;
  final double netAmount;
  final DateTime createdAt;
  final Map<String, dynamic> shippingAddress;
  final List<OrderItemModel> items;
}
```

### Repository interface
```dart
abstract class SellerOrdersRepository {
  Future<List<SellerOrder>> fetchOrders({String? search, SellerOrderStatus? status});
  Future<SellerOrder> fetchOrderDetail(String orderId);
  Future<void> acceptOrder(String orderId);
  Future<void> markPreparing(String orderId, {String? note});
  Future<void> createShipmentLabel(String orderId, {required String carrier});
  Future<void> markShipped(String orderId, {required String carrier, required String trackingNo});
  Future<void> requestReturn(String orderId, {required String reason, String? details});
  Future<void> approveReturn(String returnId, {required bool approve, String? note});
  Future<void> receiveReturn(String returnId, {required bool markShippedBack, String? note});
  Future<void> refundReturn(String returnId, {required String provider, required double amount});
  Stream<SellerOrderRealtimeEvent> watchRealtime(String sellerId);
}
```

### Remote datasource örneği
```dart
class SellerOrdersRemoteDataSource {
  SellerOrdersRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<void> acceptOrder(String orderId) async {
    await _client.functions.invoke(
      'seller_accept_order',
      body: {'order_id': orderId},
    );
  }
}
```

### Riverpod provider örneği
```dart
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final sellerOrdersRemoteDsProvider = Provider<SellerOrdersRemoteDataSource>((ref) {
  return SellerOrdersRemoteDataSource(ref.watch(supabaseProvider));
});

final sellerOrdersRepositoryProvider = Provider<SellerOrdersRepository>((ref) {
  return SellerOrdersRepositoryImpl(ref.watch(sellerOrdersRemoteDsProvider));
});

final sellerOrdersFilterProvider = StateProvider<SellerOrderStatus?>((ref) => null);
final sellerOrdersSearchProvider = StateProvider<String>((ref) => '');

final sellerOrdersProvider = FutureProvider.autoDispose<List<SellerOrder>>((ref) async {
  final repo = ref.watch(sellerOrdersRepositoryProvider);
  final filter = ref.watch(sellerOrdersFilterProvider);
  final search = ref.watch(sellerOrdersSearchProvider);
  return repo.fetchOrders(search: search, status: filter);
});
```

### OrdersListScreen iskeleti
```dart
class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider);
    return Scaffold(
      body: ordersAsync.when(
        data: (orders) => ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => SellerOrderCard(order: orders[index]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
```

## F) Realtime

### Amaç
- satıcı paneline yeni sipariş düştüğünde anında görünmesi
- 30 saniye highlight
- küçük badge
- local notification
- SLA countdown her saniye yenilenmeli

### Realtime subscription örneği
```dart
Stream<SellerOrderRealtimeEvent> watchRealtime(String sellerId) {
  final channel = _client
      .channel('seller-orders-$sellerId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'seller_ops',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'seller_id',
          value: sellerId,
        ),
        callback: (payload) {
          // map to domain event
        },
      )
      .subscribe();

  return _controller.stream;
}
```

### SLA Countdown
- `NEW` sipariş için `created_at + 30 dk`
- 10 dakikanın altı: turuncu
- 0 altı: kırmızı `SLA aşıldı`

### Highlight mantığı
- Realtime `INSERT` veya unseen `NEW` geldiğinde order id `Set<String>` içine alınır
- `Future.delayed(const Duration(seconds: 30))` ile setten çıkarılır

## G) Test Planı: Kritik 20 Senaryo
1. PAID olmayan ödeme ile sipariş oluşturulamıyor.
2. PAID ödeme sonrası `NEW` sipariş oluşuyor.
3. `order_no` benzersiz üretiliyor.
4. `commission_amount` doğru hesaplanıyor.
5. `net_amount` doğru hesaplanıyor.
6. Satıcı yalnızca kendi siparişlerini görebiliyor.
7. Buyer yalnızca kendi siparişlerini görebiliyor.
8. Satıcı başka satıcının siparişini update edemiyor.
9. `NEW -> PREPARING` geçişi başarılı.
10. `PREPARING -> READY_TO_SHIP` etiket üretimi başarılı.
11. `READY_TO_SHIP -> SHIPPED` tracking no zorunlu.
12. `SHIPPED -> DELIVERED` shipment event ile otomatik ilerliyor.
13. Geçersiz status geçişi `INVALID_STATUS_TRANSITION` dönüyor.
14. Buyer `RETURN_REQUESTED` oluşturabiliyor.
15. Satıcı iade talebini approve/reject edebiliyor.
16. `RETURN_RECEIVED -> REFUNDED` sonrasında payment status `REFUNDED` oluyor.
17. Her status değişiminde `audit_logs` kaydı oluşuyor.
18. `notifications` satıcı ve buyer için doğru yazılıyor.
19. Realtime insert yeni siparişi 30 sn highlight ediyor.
20. `shipment_events` insert sonrası takip ekranı otomatik güncelleniyor.

## Polling Job Taslağı
İleride kargo API için cron/edge akışı:
1. `shipment_status != DELIVERED` kayıtları çek
2. taşıyıcı API'den eventleri al
3. yeni event varsa `ingest_shipment_event` çağır
4. `DELIVERED` olduysa polling kuyruğundan düşür

## Satıcı Paneli Tasarım Notu
Mevcut seller panelde sipariş ekranı daha okunaklı hale getirildi:
- hero header
- KPI kartları
- kapsül filtreler
- kart bazlı sipariş listesi
- yeni sipariş vurgusu
- hızlı detay / akış yönetimi

Bu değişiklik doğrudan şu dosyada işlendi:
- [/Users/barankananogullari/Desktop/ibul2026/ibul_app/lib/screens/seller_panel_page.dart](/Users/barankananogullari/Desktop/ibul2026/ibul_app/lib/screens/seller_panel_page.dart)
