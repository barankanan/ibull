import 'package:flutter/material.dart';
import '../core/constants.dart';

class CheckoutPage extends StatefulWidget {
  final double totalPrice;
  final List<Map<String, dynamic>> selectedProducts;
  const CheckoutPage({
    super.key, 
    required this.totalPrice,
    required this.selectedProducts,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _acceptTerms = false;
  String _selectedPayment = 'single';

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
          'Güvenli Alışveriş',
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teslim Adresim
                  _buildSection(
                    title: 'Teslim Adresim',
                    trailing: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Yeni Ekle', style: TextStyle(fontSize: 12)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Radio(
                              value: true,
                              groupValue: true,
                              onChanged: (value) {},
                              activeColor: AppColors.primary,
                            ),
                            const Text(
                              'Adresime Gönder',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Prefabrik Ev / ARSUZ',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('Düzenle', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 26),
                                child: Text(
                                  'Gökmeydan Mahallesi sokak no;',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              const Text(
                                'Fatura Bilgilerim ; ',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              InkWell(
                                onTap: () {},
                                child: const Text(
                                  'Prefabrik Ev / Arsuz',
                                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {},
                                child: const Text(
                                  'Düzenle',
                                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // Ödeme Seçenekleri
                  _buildSection(
                    title: 'Ödeme Seçenekleri',
                    trailing: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Yeni Ekle', style: TextStyle(fontSize: 12)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Kart bilgisi
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Baran Kart',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Row(
                                        children: [
                                          const Text(
                                            '536455*******5677',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 24,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'M',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Düzenle', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tek Çekim
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPayment = 'single';
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'single',
                                    groupValue: _selectedPayment,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPayment = value!;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  const Expanded(
                                    child: Text('Tek Çekim (Peşin)', style: TextStyle(fontSize: 13)),
                                  ),
                                  const Text(
                                    '929.00 TL',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 32, bottom: 12),
                            child: Text(
                              'Ödenecek tutarın tamamı Karttan çekilecektir',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                          // Diğer Ödeme Seçenekleri
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
                            leading: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
                            title: const Text(
                              'Diğer Ödeme Seçenekleri',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            children: const [
                              Text(
                                'Anında Havale ,çoklu Kredi Kartı , Dijital Ödeme',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          // Taksitli Alışveriş
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Taksitli Alışveriş',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Ayda ${(widget.totalPrice / 12).toStringAsFixed(2)} TL den Başlayan 12 taksitle',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                  ),
                  const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // Teslimat Seçeneklerim
                  _buildSection(
                    title: 'Teslimat Seçeneklerim',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seçili Ürünler (${widget.selectedProducts.length})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          ...widget.selectedProducts.map((product) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    image: product['image'] != null
                                        ? DecorationImage(
                                            image: AssetImage(product['image']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: product['image'] == null
                                      ? const Icon(Icons.image, color: Colors.grey, size: 30)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? '',
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Kurye Teslimat (Mesafeye Bağlı)',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                              const Text(
                                                'Tahmini teslim: Bugün',
                                                style: TextStyle(fontSize: 11, color: AppColors.primary),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${product['price']} TL',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),
                  
                  // Cayma Hakkı, Sözleşmeler
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildExpandableTile('Cayma Hakkı'),
                        _buildExpandableTile('Ön Bilgilendirme Formu'),
                        _buildExpandableTile('Mesafeli Satış sözleşmesi'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Onay checkbox
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value!;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Ön Bilgilendirme formunu ve mesafeli satış sözleşmesini, cayma hakkını onaylıyorum.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showPriceDetails(context),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Toplam:',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                '${(widget.totalPrice >= 300 ? widget.totalPrice : widget.totalPrice + 59.99).toStringAsFixed(2)} TL',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '%10 İndirimli',
                                style: TextStyle(fontSize: 10, color: Colors.red.shade400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Alışverişi Tamamla',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildExpandableTile(String title) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
      children: const [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'İçerik burada görünecek...',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  void _showPriceDetails(BuildContext context) {
    const double shippingCost = 59.99;
    final bool isFreeShipping = widget.totalPrice >= 300;
    final double finalTotal = isFreeShipping ? widget.totalPrice : widget.totalPrice + shippingCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ara Toplam
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ara Toplam', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  Text(
                    '${widget.totalPrice.toStringAsFixed(2)} TL',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Kargo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kargo', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  Text('${shippingCost.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              // Kargo İndirimi
              if (isFreeShipping)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '300 TL ve Üzeri Kargo Bedava (Satıcı Karşılar)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      '-${shippingCost.toStringAsFixed(2)} TL',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Toplam
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Toplam:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${finalTotal.toStringAsFixed(2)} TL',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
