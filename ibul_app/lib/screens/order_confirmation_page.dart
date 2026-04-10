import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../core/constants.dart';
import '../widgets/web_footer.dart';
import '../widgets/web_header.dart';
import 'orders_page.dart';

class OrderConfirmationPage extends StatelessWidget {
  final double? totalPrice;
  final Map<String, dynamic>? orderData;
  final List<Map<String, dynamic>>? purchasedProducts;

  const OrderConfirmationPage({
    super.key,
    this.totalPrice,
    this.orderData,
    this.purchasedProducts,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;
    final items =
        (orderData?['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final helpful =
        (orderData?['helpful_products'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          if (isWeb) WebHeader(onSearch: (q) {}),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: _buildContent(context, items, helpful),
                          ),
                        ),
                        if (isWeb) const SizedBox(height: 32),
                        if (isWeb) const WebFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> helpful,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7E7EA)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16A34A),
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Siparişiniz Onaylandı',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sipariş No: ${orderData?['order_number'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7E7EA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sipariş Detayları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text(
                  'Sipariş kalemi bulunamadı.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...items.map((item) => _buildOrderItemCard(item)),
              const Divider(height: 26),
              _buildSummaryRow(
                'Toplam Tutar',
                _money(orderData?['total_amount'], fallback: totalPrice),
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Durum',
                _statusText(orderData?['status']?.toString()),
              ),
            ],
          ),
        ),
        if (helpful.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Aldığınız ürüne yardımcı olabilecek ürünler',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: helpful.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final p = helpful[index];
                return Container(
                  width: 165,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8E8EC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildImage(p['image_url']?.toString()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p['name']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p['brand'] ?? ''} • ${_money(p['price'])}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ana Sayfa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OrdersPage()),
                  (route) => false,
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Siparişimi Gör'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildImage(item['product_image_url']?.toString()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Satıcı: ${item['store_name'] ?? 'Bilinmeyen Mağaza'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ürün Kodu: ${item['product_code'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adet: ${item['quantity'] ?? 1}  •  ${_money(item['unit_price'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(item['total_price']),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        color: const Color(0xFFF0F0F2),
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
    if (path.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            color: const Color(0xFFF0F0F2),
            child: const Icon(Icons.broken_image),
          );
        },
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          color: const Color(0xFFF0F0F2),
          child: const Icon(Icons.broken_image),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  static String _money(dynamic amount, {double? fallback}) {
    double val;
    if (amount is num) {
      val = amount.toDouble();
    } else {
      val = fallback ?? 0;
    }
    return '${val.toStringAsFixed(2)} TL';
  }

  static String _statusText(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'confirmed':
        return 'Onaylandı';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'shipped':
        return 'Kargoda';
      case 'delivered':
        return 'Teslim edildi';
      case 'cancelled':
        return 'İptal';
      default:
        return status ?? '-';
    }
  }
}
