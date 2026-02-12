import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/product_card.dart';
import '../models/product_model.dart';

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic>? orderData;

  const OrderDetailPage({super.key, this.orderData});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView(context);
    }

    return _buildMobileView(context);
  }

  Widget _buildWebView(BuildContext context) {
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
                                  _buildHeader(context),
                                  const SizedBox(height: 24),
                                  _buildOrderSummaryCard(context),
                                  const SizedBox(height: 24),
                                  _buildAddressAndPaymentInfo(context),
                                  const SizedBox(height: 24),
                                  _buildTermsFooter(),
                                  const SizedBox(height: 40),
                                  _buildRecommendations(context),
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

  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Detayı', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderSummaryCard(context, isWeb: false),
            const SizedBox(height: 16),
            _buildAddressAndPaymentInfo(context, isWeb: false),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: const Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Tüm Siparişler',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.visibility_off_outlined, size: 18, color: Colors.grey),
          label: const Text('Siparişini Gizle', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryCard(BuildContext context, {bool isWeb = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Top Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Text(
                  'Sipariş özeti:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildSummaryItem('Sipariş no:', '10880225708'),
                const SizedBox(width: 32),
                _buildSummaryItem('Sipariş tarihi:', orderData?['date']?.split('/')?.first ?? '15 Ocak 2026'),
                const SizedBox(width: 32),
                _buildSummaryItem('Sipariş özeti', '${orderData?['itemCount'] ?? 1} paket, ${orderData?['itemCount'] ?? 1} ürün', valueColor: Colors.green),
                const SizedBox(width: 32),
                _buildSummaryItem('Sipariş detayı', orderData?['statusText'] ?? '1 ürün teslim edildi', valueColor: orderData?['statusColor'] ?? Colors.green),
              ],
            ),
          ),

          // Delivery & Cargo Info
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Teslimat no:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '#10144029996',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                      label: const Text('Faturayı görüntüle', style: TextStyle(color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Seller Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Satıcı: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(orderData?['sellerName'] ?? 'Fresh Life Store', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(width: 16),
                      _buildSmallButton('Siparişi değerlendir'),
                      const SizedBox(width: 8),
                      _buildSmallButton('Takip et'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Status
                Row(
                  children: [
                    Icon(orderData?['statusIcon'] ?? Icons.check, size: 20, color: orderData?['statusColor'] ?? Colors.green),
                    const SizedBox(width: 8),
                    Text(orderData?['statusText'] ?? 'Teslim edildi', style: TextStyle(fontWeight: FontWeight.bold, color: orderData?['statusColor'] ?? Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    children: [
                      TextSpan(text: 'Aşağıda gösterilen ${orderData?['itemCount'] ?? 1} ürün '),
                      TextSpan(text: orderData?['date'] ?? '19 Ocak Pazartesi', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                      const TextSpan(text: ' tarihinde işlem gördü.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cargo Tracking
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: const Text('Takip numarası: 7330029647849343', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: const Text('Kargo Firması: Trendyol Express', style: TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Kargom Nerede?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // Product Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderData?['productName'] ?? 'Ürün Adı',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // const Text('Dedantörlü Kamp Sobası Dar Musluk', style: TextStyle(fontSize: 13)), // Removed hardcoded description
                            // const SizedBox(height: 4),
                            Text('Adet: ${orderData?['itemCount'] ?? 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(orderData?['totalPrice'] ?? '0.00 TL', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: const Text('Yorum Yaz', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                    ),
                                    child: const Text('Tekrar Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _buildAddressAndPaymentInfo(BuildContext context, {bool isWeb = true}) {
    if (!isWeb) {
      return Column(
        children: [
          _buildInfoCard(
            'Teslimat adresi',
            [
              const Text('Baran Kananoğulları,', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Hatay / Arsuz , Gökmeydanı mahallesi , nazım hikmet kültür merkezi', style: TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              const Text('Hatay', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('537*****77', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Fatura adresi',
            [
              const Text('Baran Kananoğulları,', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Hatay / Arsuz , Gökmeydanı mahallesi , nazım hikmet kültür merkezi', style: TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              const Text('Hatay', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('537*****77', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Ödeme bilgileri',
            [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ödeme', style: TextStyle(fontSize: 13)),
                  Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Tek Çekim ****6309', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPriceRow('Ara toplam', orderData?['totalPrice'] ?? '539,00 TL'),
              const SizedBox(height: 8),
              _buildPriceRow('Kargo', '44,99 TL'),
              const SizedBox(height: 8),
              _buildPriceRow('300 TL ve Üzeri Kargo Bedava', '-44,99 TL'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              _buildPriceRow('Toplam', orderData?['totalPrice'] ?? '539,00 TL', isBold: true),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 11, color: AppColors.primary),
                          children: [
                            TextSpan(text: 'Toplam tutarın '),
                            TextSpan(text: '83,63 TL\'lik kısmı', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: ' Worldpuan ile ödenmiştir.'),
                          ],
                        ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildInfoCard(
            'Teslimat adresi',
            [
              const Text('Baran Kananoğulları,', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Hatay / Arsuz , Gökmeydanı mahallesi , nazım hikmet kültür merkezi', style: TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              const Text('Hatay', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('537*****77', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildInfoCard(
            'Fatura adresi',
            [
              const Text('Baran Kananoğulları,', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Hatay / Arsuz , Gökmeydanı mahallesi , nazım hikmet kültür merkezi', style: TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              const Text('Hatay', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text('537*****77', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildInfoCard(
            'Ödeme bilgileri',
            [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ödeme', style: TextStyle(fontSize: 13)),
                  Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Tek Çekim ****6309', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPriceRow('Ara toplam', orderData?['totalPrice'] ?? '539,00 TL'),
              const SizedBox(height: 8),
              _buildPriceRow('Kargo', '44,99 TL'),
              const SizedBox(height: 8),
              _buildPriceRow('300 TL ve Üzeri Kargo Bedava', '-44,99 TL'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Toplam (KDV dahil)', style: TextStyle(fontSize: 13)),
                  Text(orderData?['totalPrice'] ?? '539,00 TL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 11, color: AppColors.primary),
                          children: [
                            TextSpan(text: 'Toplam tutarın '),
                            TextSpan(text: '83,63 TL\'lik kısmı', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: ' Worldpuan ile ödenmiştir.'),
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
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      height: 320, // Fixed height for alignment
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text(
        'Şartlar ve Koşullar',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    // Dummy products for recommendation
    final List<Product> recommendations = [
      Product(
        name: 'ROBO 6 Kişilik 4 Mevsim Kamp Çadırı',
        price: '11.165 TL',
        oldPrice: '16.197 TL',
        images: [''], // Placeholder
        category: 'Outdoor',
        brand: 'ROBO',
        description: '',
        rating: 4.5,
        reviewCount: 1307,
        store: 'Outdoor Mağazası',
        tags: ['Hızlı Kargo'],
      ),
      Product(
        name: 'Kamp Sandalyesi Katlanır',
        price: '450 TL',
        oldPrice: '600 TL',
        images: [''], // Placeholder
        category: 'Outdoor',
        brand: 'NatureHike',
        description: '',
        rating: 4.8,
        reviewCount: 540,
        store: 'Outdoor Mağazası',
        tags: ['Fırsat'],
      ),
      Product(
        name: 'Termos 1.5 Litre Çelik',
        price: '890 TL',
        images: [''], // Placeholder
        category: 'Outdoor',
        brand: 'Stanley',
        description: '',
        rating: 4.9,
        reviewCount: 2100,
        store: 'Outdoor Mağazası',
        tags: ['Çok Satan'],
      ),
      Product(
        name: 'Uyku Tulumu -10 Derece',
        price: '2.500 TL',
        oldPrice: '3.200 TL',
        images: [''], // Placeholder
        category: 'Outdoor',
        brand: 'Decathlon',
        description: '',
        rating: 4.6,
        reviewCount: 320,
        store: 'Outdoor Mağazası',
        tags: [],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bu Ürünü Alanlar Bunları da Aldı',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 380,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 220,
                child: ProductCard(
                  product: recommendations[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.bold, 
            color: valueColor ?? const Color(0xFF1F2937)
          ),
        ),
      ],
    );
  }

  Widget _buildSmallButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label, 
            style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
