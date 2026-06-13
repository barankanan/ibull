import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import '../core/auth/user_identity.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';
import '../widgets/account_sidebar.dart';
import '../services/order_service.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _selectedTab = 'Tümü';
  bool _isLoading = false;
  List<Map<String, dynamic>> _realOrders = [];
  String? _lastLoadedUserId;

  final List<String> _tabs = [
    'Tümü',
    'Devam Edenler',
    'Teslim Edilen',
    'İadeler',
    'Garantili Siparişler',
    'İptaller',
  ];

  // Mock data for GUEST users only
  final List<Map<String, dynamic>> _guestOrders = [
    {
      'date': '14 Ocak 2024 / 20:52',
      'itemCount': 1,
      'productName': 'UFO City CT-23 2300W ifared Tipi Ayaklı Isıtıcı',
      'statusIcon': Icons.electric_bike,
      'statusText': 'Kurye Dağıtım',
      'statusColor': Colors.purple,
      'statusType': 'devam',
      'totalPrice': '929.00 TL',
      'dateGroup': 'Bu Ay',
      'sellerName': 'UFO Türkiye',
    },
    {
      'date': '13 Ocak 2024 / 23:31',
      'itemCount': 4,
      'productName': 'QCY Bluetooth Kulak Üstü Kulaklık ... +4 ürün',
      'statusIcon': Icons.inventory_2,
      'statusText': 'Siparişiniz Hazırlanıyor',
      'statusColor': Colors.green,
      'statusType': 'devam',
      'totalPrice': '5.299.00 TL',
      'multipleImages': 4,
      'dateGroup': 'Bu Ay',
      'sellerName': 'Teknoloji Dünyası',
    },
    {
      'date': '1 Ocak 2024 / 12:00',
      'itemCount': 1,
      'productName': 'HUAWEI Matebook D15 Intel Core i3-1115G4',
      'statusIcon': Icons.local_shipping,
      'statusText': 'Siparişiniz Kargoda',
      'statusColor': Colors.orange,
      'statusType': 'devam',
      'totalPrice': '11.999.00 TL',
      'dateGroup': 'Bu Ay',
      'sellerName': 'Huawei Türkiye',
    },
    {
      'date': '31 Aralık 2023 / 20:41',
      'itemCount': 1,
      'productName': 'Mibro Lite akıllı saat',
      'statusIcon': Icons.check_circle,
      'statusText': 'Sipariş Teslim Edildi',
      'statusColor': Colors.green,
      'statusType': 'teslim',
      'totalPrice': '999.00 TL',
      'hasReviewButton': true,
      'dateGroup': 'Aralık 2023',
      'sellerName': 'Akıllı Saat Mağazası',
    },
    {
      'date': '10 Aralık 2023 / 12:24',
      'itemCount': 1,
      'productName': 'Black Sokak Unisex Siyah Sg Baskılı Tshirt',
      'statusIcon': Icons.close,
      'statusText': 'Siparişiniz İptal Edildi',
      'statusColor': Colors.red,
      'statusType': 'iptal',
      'totalPrice': '529.90 TL',
      'dateGroup': 'Aralık 2023',
      'sellerName': 'Black Sokak',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    final userId = appState.currentUser?['uid']?.toString();
    final isGuestUser = UserIdentity.isGuest(appState.currentUser);
    if (isGuestUser || userId == null || userId.isEmpty) return;
    if (_lastLoadedUserId == userId) return;
    _lastLoadedUserId = userId;
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final appState = AppState();
    final userId = appState.currentUser?['uid']?.toString();
    final isGuestUser = UserIdentity.isGuest(appState.currentUser);
    if (userId == null || userId.isEmpty || isGuestUser) return;

    setState(() => _isLoading = true);
    try {
      final orders = await OrderService.instance.getUserOrders(userId);
      if (!mounted) return;
      setState(() {
        _lastLoadedUserId = userId;
        _realOrders = orders.map(_mapRealOrderForUi).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final appState = Provider.of<AppState>(context, listen: false);
    final isGuestUser = UserIdentity.isGuest(appState.currentUser);

    final source = isGuestUser ? _guestOrders : _realOrders;
    if (_selectedTab == 'Tümü') return source;
    if (_selectedTab == 'Devam Edenler') {
      return source.where((order) => order['statusType'] == 'devam').toList();
    }
    if (_selectedTab == 'Teslim Edilen') {
      return source.where((order) => order['statusType'] == 'teslim').toList();
    }
    if (_selectedTab == 'İptaller') {
      return source.where((order) => order['statusType'] == 'iptal').toList();
    }
    if (_selectedTab == 'İadeler') {
      return source.where((order) => order['statusType'] == 'iade').toList();
    }
    if (_selectedTab == 'Garantili Siparişler') {
      return source
          .where((order) => order['statusType'] == 'garantili')
          .toList();
    }
    return source;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }

    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
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
                            activePage: 'Siparişlerim',
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Siparişlerim',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: TextField(
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Siparişlerimde ara...',
                                                    hintStyle: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    prefixIcon: const Icon(
                                                      Icons.search,
                                                      color: Colors.grey,
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Container(
                                              height: 48,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: Colors.grey.shade200,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.tune,
                                                    color: AppColors.primary,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Filtrele',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: _tabs.map((tab) {
                                              final isSelected =
                                                  _selectedTab == tab;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 12,
                                                ),
                                                child: InkWell(
                                                  onTap: () => setState(
                                                    () => _selectedTab = tab,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? AppColors.primary
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? AppColors.primary
                                                            : Colors
                                                                  .grey
                                                                  .shade200,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      tab,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : Colors
                                                                  .grey
                                                                  .shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                              ..._buildOrdersList(isWeb: true),
                            ],
                          ),
                        ),
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

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Siparişlerim',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Arama yap',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: AppColors.primary, size: 18),
                      const SizedBox(width: 4),
                      const Text(
                        'Filtre',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Tab Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Orders List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _buildOrdersList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrdersList({bool isWeb = false}) {
    if (_isLoading) {
      return const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ];
    }
    final filteredOrders = _filteredOrders;
    if (filteredOrders.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Bu kategoride sipariş bulunamadı',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ];
    }

    List<Widget> widgets = [];
    String? currentDateGroup;

    for (var order in filteredOrders) {
      if (order['dateGroup'] != currentDateGroup) {
        currentDateGroup = order['dateGroup'];
        widgets.add(_buildDateHeader(currentDateGroup!));
      }

      widgets.add(
        _buildOrderCard(
          orderData: order,
          date: order['date'],
          itemCount: order['itemCount'],
          productImage: order['productImage'],
          productName: order['productName'],
          statusIcon: order['statusIcon'],
          statusText: order['statusText'],
          statusColor: order['statusColor'],
          totalPrice: order['totalPrice'],
          multipleImages: order['multipleImages'],
          hasReviewButton: order['hasReviewButton'] ?? false,
          canRequestReturn: order['canRequestReturn'] ?? false,
          isWeb: isWeb,
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    widgets.add(const SizedBox(height: 16));
    return widgets;
  }

  Map<String, dynamic> _mapRealOrderForUi(Map<String, dynamic> order) {
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final firstItem = items.isNotEmpty ? items.first : <String, dynamic>{};
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final status = (order['status']?.toString() ?? '').toLowerCase();
    final resolvedStatus = _resolveOrderStatus(status, items);
    final statusConfig = _mapStatus(resolvedStatus);
    final productNames = items
        .map((e) => e['product_name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return {
      'date': createdAt != null ? _formatDateTime(createdAt) : '-',
      'itemCount': items.length,
      'productName': productNames.isEmpty ? 'Sipariş' : productNames.join(', '),
      'statusIcon': statusConfig['icon'],
      'statusText': statusConfig['label'],
      'statusColor': statusConfig['color'],
      'statusType': statusConfig['type'],
      'totalPrice':
          '${(order['total_amount'] as num? ?? 0).toStringAsFixed(2)} TL',
      'dateGroup': _dateGroup(createdAt),
      'sellerName': firstItem['store_name']?.toString() ?? '-',
      'productImage': firstItem['product_image_url']?.toString(),
      'multipleImages': items.length > 1 ? items.length - 1 : null,
      'hasReviewButton': resolvedStatus == 'delivered',
      'canRequestReturn': resolvedStatus == 'delivered',
      'rawOrder': order,
    };
  }

  String _resolveOrderStatus(
    String orderStatus,
    List<Map<String, dynamic>> items,
  ) {
    final itemStatuses = items
        .map((e) => (e['status'] ?? '').toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final statuses = itemStatuses.isEmpty
        ? <String>[orderStatus]
        : itemStatuses;
    if (statuses.any(_isReturnFlowStatus)) return 'return_requested';
    if (statuses.every((s) => s == 'delivered')) return 'delivered';
    if (statuses.any((s) => s == 'cancelled')) return 'cancelled';
    if (statuses.any(
      (s) =>
          s == 'shipped' ||
          s == 'transfer' ||
          s == 'branch' ||
          s == 'out_for_delivery',
    )) {
      return 'shipped';
    }
    if (statuses.any((s) => s == 'preparing' || s == 'ready_to_ship')) {
      return 'preparing';
    }
    if (statuses.any((s) => s == 'confirmed' || s == 'new')) {
      return 'confirmed';
    }
    return orderStatus;
  }

  bool _isReturnFlowStatus(String status) {
    switch (status) {
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case 'returned':
      case 'refunded':
        return true;
      default:
        return false;
    }
  }

  Map<String, dynamic> _mapStatus(String status) {
    switch (status) {
      case 'confirmed':
      case 'preparing':
      case 'shipped':
        return {
          'label': status == 'shipped'
              ? 'Siparişiniz Kargoda'
              : 'Siparişiniz Hazırlanıyor',
          'icon': status == 'shipped'
              ? Icons.local_shipping
              : Icons.inventory_2,
          'color': status == 'shipped' ? Colors.orange : Colors.green,
          'type': 'devam',
        };
      case 'delivered':
        return {
          'label': 'Sipariş Teslim Edildi',
          'icon': Icons.check_circle,
          'color': Colors.green,
          'type': 'teslim',
        };
      case 'cancelled':
        return {
          'label': 'Siparişiniz İptal Edildi',
          'icon': Icons.close,
          'color': Colors.red,
          'type': 'iptal',
        };
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case 'returned':
      case 'refunded':
        return {
          'label': 'İade Süreci Başlatıldı',
          'icon': Icons.assignment_return_rounded,
          'color': const Color(0xFFFF8A00),
          'type': 'iade',
        };
      default:
        return {
          'label': 'Siparişiniz Onaylandı',
          'icon': Icons.receipt_long,
          'color': AppColors.primary,
          'type': 'devam',
        };
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} / ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _dateGroup(DateTime? date) {
    if (date == null) return 'Siparişler';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) return 'Bu Ay';
    return '${date.month}.${date.year}';
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        date,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required Map<String, dynamic> orderData,
    required String date,
    required int itemCount,
    required String? productImage,
    required String productName,
    required IconData statusIcon,
    required String statusText,
    required Color statusColor,
    required String totalPrice,
    int? multipleImages,
    bool hasReviewButton = false,
    bool canRequestReturn = false,
    bool isWeb = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Sipariş Bilgi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontSize: isWeb ? 13 : 11,
                  color: Colors.grey.shade600,
                ),
              ),
              GestureDetector(
                onTap: () => _openOrderDetail(orderData),
                child: Row(
                  children: [
                    Text(
                      'Sipariş Bilgi',
                      style: TextStyle(
                        fontSize: isWeb ? 13 : 11,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: isWeb ? 18 : 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$itemCount ürün siparişi alındı',
            style: TextStyle(
              fontSize: isWeb ? 14 : 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isWeb ? 16 : 12),

          // Product Info
          Row(
            children: [
              // Product Image
              Stack(
                children: [
                  Container(
                    width: isWeb ? 90 : 70,
                    height: isWeb ? 90 : 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: productImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: OptimizedImage(imageUrlOrPath: 
                              productImage,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: isWeb ? 40 : 30,
                          ),
                  ),
                  if (multipleImages != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 2),
                            right: BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+$multipleImages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: TextStyle(
                        fontSize: isWeb ? 15 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          statusIcon,
                          size: isWeb ? 18 : 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: isWeb ? 13 : 11,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price and Action for Web (Right Aligned)
              if (isWeb) ...[
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalPrice,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (hasReviewButton || canRequestReturn) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (hasReviewButton)
                            OutlinedButton.icon(
                              onPressed: () => _openOrderDetail(orderData),
                              icon: const Icon(Icons.star, size: 16),
                              label: const Text('Değerlendir'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          if (canRequestReturn)
                            OutlinedButton.icon(
                              onPressed: () => _openOrderDetail(orderData),
                              icon: const Icon(
                                Icons.assignment_return_rounded,
                                size: 16,
                              ),
                              label: const Text('İade Talebi'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD93E53),
                                side: const BorderSide(
                                  color: Color(0xFFD93E53),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          SizedBox(height: isWeb ? 16 : 12),

          // Total and Action Buttons (Mobile Only)
          if (!isWeb)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Toplam Tutar : ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        TextSpan(
                          text: totalPrice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasReviewButton || canRequestReturn)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (hasReviewButton)
                        OutlinedButton.icon(
                          onPressed: () => _openOrderDetail(orderData),
                          icon: const Icon(Icons.star, size: 14),
                          label: const Text(
                            'Değerlendir',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                      if (canRequestReturn)
                        OutlinedButton.icon(
                          onPressed: () => _openOrderDetail(orderData),
                          icon: const Icon(
                            Icons.assignment_return_rounded,
                            size: 14,
                          ),
                          label: const Text(
                            'İade Talebi',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD93E53),
                            side: const BorderSide(color: Color(0xFFD93E53)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openOrderDetail(Map<String, dynamic> orderData) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailPage(orderData: orderData),
      ),
    );
    final changed =
        result == true || (result is Map && result['refresh'] == true);
    final focusReturns = result is Map && result['focus_returns'] == true;
    if (changed) {
      await _loadOrders();
      if (mounted) {
        setState(() {
          if (focusReturns) {
            _selectedTab = 'İadeler';
          }
        });
      }
    }
  }
}
