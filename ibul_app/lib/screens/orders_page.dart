import 'package:flutter/material.dart';
import '../core/constants.dart';

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

  List<Widget> _buildOrdersList() {
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
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
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Row(
                children: [
                  const Text(
                    'Sipariş Bilgi',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$itemCount ürün siparişi alındı',
            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          
          // Product Info
          Row(
            children: [
              // Product Image
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
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
                        : const Icon(Icons.image, color: Colors.grey, size: 30),
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
              const SizedBox(width: 12),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Total and Review Button
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
