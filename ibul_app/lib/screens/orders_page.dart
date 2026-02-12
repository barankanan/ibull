import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _selectedTab = 'Tümü';

  final List<String> _tabs = [
    'Tümü',
    'Devam Edenler',
    'Teslim Edilen',
    'İadeler',
    'Garantili Siparişler',
    'İptaller',
  ];

  final List<Map<String, dynamic>> _allOrders = [
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

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedTab == 'Tümü') {
      return _allOrders;
    } else if (_selectedTab == 'Devam Edenler') {
      return _allOrders.where((order) => order['statusType'] == 'devam').toList();
    } else if (_selectedTab == 'Teslim Edilen') {
      return _allOrders.where((order) => order['statusType'] == 'teslim').toList();
    } else if (_selectedTab == 'İptaller') {
      return _allOrders.where((order) => order['statusType'] == 'iptal').toList();
    } else if (_selectedTab == 'İadeler') {
      return _allOrders.where((order) => order['statusType'] == 'iade').toList();
    } else if (_selectedTab == 'Garantili Siparişler') {
      return _allOrders.where((order) => order['statusType'] == 'garantili').toList();
    }
    return _allOrders;
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar
                            const SizedBox(
                              width: 280,
                              child: AccountSidebar(activePage: 'Siparişlerim'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content
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
                                  // Search and Filter Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: Colors.grey.shade200),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Siparişlerimde ara...',
                                              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.tune, color: AppColors.primary, size: 20),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Filtrele',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Tabs
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _tabs.map((tab) {
                                        final isSelected = _selectedTab == tab;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 12),
                                          child: InkWell(
                                            onTap: () => setState(() => _selectedTab = tab),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isSelected ? AppColors.primary : Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                tab,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Orders List
                                  ..._buildOrdersList(isWeb: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const WebFooter(),
                ],
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
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
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

      widgets.add(_buildOrderCard(
        orderData: order,
        date: order['date'],
        itemCount: order['itemCount'],
        productImage: null,
        productName: order['productName'],
        statusIcon: order['statusIcon'],
        statusText: order['statusText'],
        statusColor: order['statusColor'],
        totalPrice: order['totalPrice'],
        multipleImages: order['multipleImages'],
        hasReviewButton: order['hasReviewButton'] ?? false,
        isWeb: isWeb,
      ));
      widgets.add(const SizedBox(height: 16));
    }

    widgets.add(const SizedBox(height: 16));
    return widgets;
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
    bool isWeb = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isWeb ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
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
                style: TextStyle(fontSize: isWeb ? 13 : 11, color: Colors.grey.shade600),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailPage(orderData: orderData),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Sipariş Bilgi',
                      style: TextStyle(fontSize: isWeb ? 13 : 11, color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: isWeb ? 18 : 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$itemCount ürün siparişi alındı',
            style: TextStyle(fontSize: isWeb ? 14 : 12, color: AppColors.primary, fontWeight: FontWeight.w500),
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
                            child: Image.network(
                              productImage,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.image, color: Colors.grey, size: isWeb ? 40 : 30),
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
                      style: TextStyle(fontSize: isWeb ? 15 : 12, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(statusIcon, size: isWeb ? 18 : 16, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: isWeb ? 13 : 11, color: statusColor, fontWeight: FontWeight.w500),
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
                    if (hasReviewButton) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.star, size: 16),
                        label: const Text('Değerlendir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          SizedBox(height: isWeb ? 16 : 12),
          
          // Total and Review Button (Mobile Only)
          if (!isWeb)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Toplam Tutar : ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                if (hasReviewButton)
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.star, size: 14),
                    label: const Text('Değerlendir', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
