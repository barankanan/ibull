import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../utils/order_status_constants.dart';
import '../utils/dynamic_value_helpers.dart';
import 'package:provider/provider.dart';
import '../core/auth/user_identity.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';
import '../widgets/account_sidebar.dart';
import 'settings_page.dart';
import 'orders_page.dart';
import 'favorites_page.dart';
import 'reviews_page.dart';
import 'ai_chat_page.dart';
import 'followed_stores_page.dart';
import 'my_chats_page.dart';
import 'coupons_page.dart';
import 'addresses_page.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'seller_login_page.dart';
import '../core/app_motion.dart';
import '../services/order_service.dart';
import 'order_detail_page.dart';
import 'shipment_tracking_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<List<Map<String, dynamic>>>? _ordersFuture;
  String _ordersFutureUserId = '';

  Future<List<Map<String, dynamic>>> _getOrdersFuture(String userId) {
    if (_ordersFuture != null && _ordersFutureUserId == userId) {
      return _ordersFuture!;
    }

    _ordersFutureUserId = userId;
    _ordersFuture = OrderService.instance.getUserOrders(userId);
    return _ordersFuture!;
  }

  @override
  Widget build(BuildContext context) {
    // Watch AppState for login changes
    final appState = Provider.of<AppState>(context);
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView(appState);
    }

    return _buildMobileView(appState);
  }

  Widget _buildWebView(AppState appState) {
    if (!appState.isLoggedIn) {
      return _buildWebGuestView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}, activeMenu: 'account'),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(
                            activePage: 'Hesap Özeti',
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(child: _buildWebDashboard(appState)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebGuestView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}, activeMenu: 'account'),
          Expanded(
            child: WebStickyFooterScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              contentFooterGap: 56,
              footerBottomPadding: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 36,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.06,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_circle_outlined,
                                size: 80,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'Hesabınıza Giriş Yapın',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Siparişlerinizi takip etmek ve fırsatlardan '
                                'yararlanmak için giriş yapın.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  height: 1.45,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 36),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            const LoginPage(),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Üye Girişi / Üye Ol',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            const SellerLoginPage(),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.storefront_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Satıcı Girişi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF111827),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDashboard(AppState appState) {
    // If not logged in, show guest introduction view
    if (!appState.isLoggedIn) {
      return _buildWebGuestIntro();
    }

    final userName = UserIdentity.resolveDisplayName(
      currentUser: appState.currentUser,
    );
    final isGuestUser = UserIdentity.isGuest(appState.currentUser);

    // If it's a guest user, show empty/intro dashboard
    if (isGuestUser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner for Guest
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoş Geldin, Misafir! 👋',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'İbul dünyasını keşfetmeye hazırsın.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Stats for Guest (NOW FILLED)
          Row(
            children: [
              _buildStatCard(
                'Toplam Sipariş',
                '124',
                Icons.shopping_bag,
                Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                'Bekleyen',
                '2',
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                'İndirim Kuponu',
                '4',
                Icons.local_offer,
                Colors.purple,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                'Cüzdan',
                '1.250 TL',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Intro / Promo Section for Guest
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.star_outline_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Üye Olmanın Avantajlarını Kaçırma!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Siparişlerini takip etmek, sana özel indirimlerden yararlanmak ve çok daha fazlası için hemen üye ol.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Register/Login
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Giriş Yap / Üye Ol'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Regular User Dashboard (NOW EMPTY for new users)
    final userId = appState.currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordersFuture = _getOrdersFuture(userId);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        final waitingOrders = orders.where((order) {
          final status = (order['status'] ?? '').toString().toLowerCase();
          return status != OrderStatusConstants.ecommerceDelivered && status != OrderStatusConstants.ecommerceCancelled;
        }).length;
        final recentOrders = orders.take(3).toList(growable: false);
        final firstAddress = appState.deliveryAddresses.isNotEmpty
            ? appState.deliveryAddresses.first
            : null;

        return _buildRealUserDashboard(
          appState: appState,
          userName: userName,
          orders: orders,
          waitingOrders: waitingOrders,
          recentOrders: recentOrders,
          firstAddress: firstAddress,
        );
      },
    );
  }

  Widget _buildRealUserDashboard({
    required AppState appState,
    required String userName,
    required List<Map<String, dynamic>> orders,
    required int waitingOrders,
    required List<Map<String, dynamic>> recentOrders,
    required Map<String, String>? firstAddress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldin, $userName! 👋',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'İbul dünyasına hoş geldin.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Standart Üye',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Quick Stats (Empty for real user)
        Row(
          children: [
            _buildStatCard(
              'Toplam Sipariş',
              '${orders.length}',
              Icons.shopping_bag,
              orders.isEmpty ? Colors.grey : Colors.blue,
            ),
            const SizedBox(width: 24),
            _buildStatCard(
              'Bekleyen',
              '$waitingOrders',
              Icons.local_shipping,
              waitingOrders == 0 ? Colors.grey : Colors.orange,
            ),
            const SizedBox(width: 24),
            _buildStatCard(
              'İndirim Kuponu',
              '0',
              Icons.local_offer,
              Colors.grey,
            ),
            const SizedBox(width: 24),
            _buildStatCard(
              'Cüzdan',
              '0.00 TL',
              Icons.account_balance_wallet,
              Colors.grey,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Recent Orders Section
        const Text(
          'Son Siparişler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: recentOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz siparişiniz bulunmuyor',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: recentOrders.map((order) {
                    final items =
                        (order['items'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final firstItem = items.isNotEmpty ? items.first : null;
                    final productName = resolveOrderProductTitle(
                      primaryItem: firstItem,
                      order: order,
                      extraItems: items.skip(1),
                      fallback: 'Sipariş',
                    );
                    final orderNumber = readString(
                      order['order_number'],
                      fallback: '-',
                    );
                    final trackingNumber = readNullableString(
                      firstItem?['tracking_number'],
                    );
                    return _buildOrderRow(
                      order: order,
                      item: firstItem,
                      productName: productName,
                      orderNumber: orderNumber,
                      trackingNumber: trackingNumber,
                      productImageUrl: readNullableString(
                        firstItem?['product_image_url'],
                      ),
                      date: _formatOrderDate(order['created_at']),
                      status: _statusLabel(order['status']?.toString()),
                      price: _formatAmount(order['total_amount']),
                      statusColor: _statusColor(order['status']?.toString()),
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 32),

        // Recommended / Favorites Preview
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Favori Ürünlerin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Tümünü Gör'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Placeholder for horizontal product list
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text('Favori ürünleriniz burada görünecek'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kayıtlı Adresim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: firstAddress == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 40,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Henüz adres eklemediniz',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddressesPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Adres Ekle'),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    firstAddress['title'] ?? 'Adresim',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                firstAddress['detail'] ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddressesPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Tüm Adresler'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatOrderDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '-';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day.$month.$year / $hour:$minute';
  }

  String _formatAmount(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    return '${value.toStringAsFixed(2)} TL';
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case OrderStatusConstants.ecommerceConfirmed:
        return 'Onaylandı';
      case OrderStatusConstants.ecommercePreparing:
        return 'Hazırlanıyor';
      case OrderStatusConstants.ecommerceShipped:
        return 'Kargoda';
      case OrderStatusConstants.ecommerceDelivered:
        return 'Teslim Edildi';
      case OrderStatusConstants.ecommerceCancelled:
        return 'İptal';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case OrderStatusConstants.ecommerceConfirmed:
        return Colors.orange;
      case OrderStatusConstants.ecommercePreparing:
        return Colors.blue;
      case OrderStatusConstants.ecommerceShipped:
        return Colors.purple;
      case OrderStatusConstants.ecommerceDelivered:
        return Colors.green;
      case OrderStatusConstants.ecommerceCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method for guest intro view in WebDashboard context if needed
  Widget _buildWebGuestIntro() {
    return _buildWebGuestView();
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveShipmentStep({
    required Map<String, dynamic> order,
    Map<String, dynamic>? item,
  }) {
    final step = readNullableString(item?['shipment_step']);
    if (step != null && step.isNotEmpty) return step;
    final itemStatus = readNullableString(item?['status']);
    if (itemStatus != null && itemStatus.isNotEmpty) return itemStatus;
    return readString(order['status']);
  }

  bool _shouldShowRecentOrderTracking({
    required Map<String, dynamic> order,
    Map<String, dynamic>? item,
    String? trackingNumber,
  }) {
    if (trackingNumber == null || trackingNumber.isEmpty || trackingNumber == '-') {
      return false;
    }
    return OrderStatusConstants.isInTransitShipmentStatus(
      _resolveShipmentStep(order: order, item: item),
    );
  }

  Future<void> _openRecentOrderDetail(Map<String, dynamic> order) async {
    await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailPage(
          orderData: wrapOrderForDetailPage(order),
        ),
      ),
    );
  }

  Future<void> _openRecentOrderTracking({
    required Map<String, dynamic> order,
    required Map<String, dynamic> item,
  }) async {
    final itemId = item['id']?.toString();
    var history = const <Map<String, dynamic>>[];
    if (itemId != null && itemId.isNotEmpty) {
      history = await OrderService.instance.getOrderItemTracking(itemId);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShipmentTrackingPage(
          order: order,
          item: item,
          history: history,
        ),
      ),
    );
  }

  Widget _buildOrderRow({
    required Map<String, dynamic> order,
    Map<String, dynamic>? item,
    required String productName,
    required String orderNumber,
    String? trackingNumber,
    String? productImageUrl,
    required String date,
    required String status,
    required String price,
    required Color statusColor,
  }) {
    final hasTracking = _shouldShowRecentOrderTracking(
      order: order,
      item: item,
      trackingNumber: trackingNumber,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openRecentOrderDetail(order),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: productImageUrl != null && productImageUrl.isNotEmpty
                      ? OptimizedImage(
                          imageUrlOrPath: productImageUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (_, _, _) =>
                              _buildOrderRowImageFallback(),
                        )
                      : _buildOrderRowImageFallback(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sipariş: $orderNumber',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasTracking && item != null) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: GestureDetector(
                              onTap: () => _openRecentOrderTracking(
                                order: order,
                                item: item,
                              ),
                              child: Text(
                                'Takip: $trackingNumber',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRowImageFallback() {
    return Container(
      color: Colors.grey.shade100,
      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
    );
  }

  Widget _buildMobileView(AppState appState) {
    if (!appState.isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hesabınıza Giriş Yapın',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Siparişlerinizi takip etmek ve fırsatlardan yararlanmak için giriş yapın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const LoginPage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Üye Girişi / Üye Ol',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SellerLoginPage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text(
                        'Satıcı Girişi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isGuestUser = UserIdentity.isGuest(appState.currentUser);
    final userName = UserIdentity.resolveDisplayName(
      currentUser: appState.currentUser,
      fallback: isGuestUser ? 'Misafir Kullanıcı' : 'Kullanıcı',
    );
    final heightWeightSummary =
        UserIdentity.formatHeightWeightSummary(appState.currentUser);

    // Unified Layout for both Guest and Normal Users
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header - Profile Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildAccountProfileAvatar(
                      appState.currentUser,
                      radius: 32,
                    ),
                    const SizedBox(width: 12),
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (heightWeightSummary != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              heightWeightSummary,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Settings Button
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to Settings Page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text(
                        'Ayarlar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Adresim
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adresim',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appState.deliveryAddresses.isNotEmpty
                                  ? '${appState.deliveryAddresses.first['title']} - ${appState.deliveryAddresses.first['detail']}'
                                  : (isGuestUser
                                        ? 'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kül...'
                                        : 'Henüz kayıtlı adresiniz yok.'),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AddressesPage(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isGuestUser ||
                                            appState
                                                .deliveryAddresses
                                                .isNotEmpty
                                        ? Icons.sync
                                        : Icons.add,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isGuestUser ||
                                            appState
                                                .deliveryAddresses
                                                .isNotEmpty
                                        ? 'Değiştir'
                                        : 'Ekle',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Hoş Geldin, ${userName.split(' ')[0]}! 👋',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'İbul dünyasını keşfetmeye hazırsın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Three Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        Icons.shopping_bag_outlined,
                        'Siparişlerim',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrdersPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        Icons.favorite_border,
                        'Beğendiklerim',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FavoritesPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        Icons.chat_bubble_outline,
                        'Değerlendirmeler',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReviewsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Menu Items
              _buildMenuItem(
                Icons.lightbulb_outline,
                'Yapay Zekaya Danış',
                subtitle: 'Ne almak istediği sor , Hızlı karşılaştırmalar yap',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AIChatPage()),
                  );
                },
              ),
              _buildMenuItem(Icons.headset_mic_outlined, 'Müşteri Hizmetleri'),
              _buildMenuItem(
                Icons.access_time,
                'Eski Siparişlerim / Tekrar al',
              ),
              _buildMenuItem(Icons.credit_card_outlined, 'Kartlarım'),
              _buildMenuItem(Icons.home_outlined, 'Barana Özel İndirimler'),
              _buildMenuItem(
                Icons.local_offer_outlined,
                'Kuponlarım',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CouponsPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.bookmark_border,
                'Takip Ettiklerim',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FollowedStoresPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                Icons.chat_bubble_outline,
                'Sohbetlerim',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyChatsPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(Icons.key, 'İabul Premium'),

              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hizmetler',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              _buildMenuItem(
                Icons.local_shipping_outlined,
                'Hızlı Ürün Gönder',
              ),
              _buildMenuItem(Icons.build_outlined, 'Garantili Tamir'),
              _buildMenuItem(Icons.format_list_bulleted, 'Montaj Hizmeti'),
              _buildMenuItem(Icons.add_circle_outline, 'Mağaza Başvurusu Yap'),
              _buildMenuItem(Icons.star_border, 'Uygulama Görüşün'),
              _buildMenuItem(Icons.help_outline, 'Yardım'),

              const SizedBox(height: 24),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await appState.logout();
                      if (!mounted) return;
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        buildAppPageRoute<void>(
                          builder: (_) => const HomeScreen(initialIndex: 4),
                        ),
                        (route) => false,
                      );
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cikis yapilamadi: $error'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountProfileAvatar(
    Map<String, dynamic>? currentUser, {
    required double radius,
  }) {
    final photoUrl = UserIdentity.resolveProfilePhotoUrl(currentUser);

    if (photoUrl != null && photoUrl.startsWith('preset:')) {
      final presetId = photoUrl.substring('preset:'.length);
      return CircleAvatar(
        radius: radius,
        backgroundColor: UserIdentity.profilePresetColor(presetId),
        child: Icon(Icons.person, size: radius, color: Colors.white),
      );
    }

    if (photoUrl != null && photoUrl.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: OptimizedImage(
            imageUrlOrPath: photoUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildAccountProfileFallbackAvatar(
              currentUser,
              radius: radius,
            ),
          ),
        ),
      );
    }

    return _buildAccountProfileFallbackAvatar(currentUser, radius: radius);
  }

  Widget _buildAccountProfileFallbackAvatar(
    Map<String, dynamic>? currentUser, {
    required double radius,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        UserIdentity.initialsOf(currentUser),
        style: TextStyle(
          fontSize: radius * 0.85,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
