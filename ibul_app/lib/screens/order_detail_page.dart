import 'dart:convert';

import 'package:flutter/material.dart';
import '../utils/order_status_constants.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/order_service.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';
import 'ask_product_question_page.dart';
import 'business_detail_page.dart';
import 'order_review_page.dart';
import 'product_detail_page.dart';
import 'shipment_tracking_page.dart';

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  static const List<String> _returnReasonOptions = [
    'Ürün hasarlı geldi',
    'Yanlış ürün gönderildi',
    'Beklediğim kalite değil',
    'Eksik parça/aksesuar var',
    'Ürün açıklaması ile uyuşmuyor',
    'Diğer',
  ];
  static const List<String> _issueTagOptions = [
    'Kırık paket',
    'Çalışmıyor',
    'Eksik ürün',
    'Beden/ölçü uyumsuz',
    'Renk/model farklı',
    'Geç teslimat',
  ];
  static const List<String> _damageLevelOptions = [
    'Kırık',
    'Çatlak',
    'Parçalanmış',
    'Eksik parça',
    'Çalışmıyor',
    'Ambalaj hasarlı',
    'Diğer',
  ];

  const OrderDetailPage({super.key, this.orderData});

  Map<String, dynamic> get _rawOrder =>
      Map<String, dynamic>.from(orderData?['rawOrder'] as Map? ?? const {});

  List<Map<String, dynamic>> get _items =>
      ((_rawOrder['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Map<String, dynamic> get _firstItem =>
      _items.isNotEmpty ? _items.first : <String, dynamic>{};

  Map<String, dynamic> get _deliveryAddress => Map<String, dynamic>.from(
    _rawOrder['delivery_address'] as Map? ?? const {},
  );

  String get _orderNumber => _rawOrder['order_number']?.toString() ?? 'Sipariş';
  String get _status => _rawOrder['status']?.toString() ?? 'confirmed';
  String get _effectiveStatus {
    final itemStatuses = _items
        .map((item) => (item['status'] ?? '').toString().trim().toLowerCase())
        .where((status) => status.isNotEmpty)
        .toList();
    if (itemStatuses.isEmpty) return _status;
    if (itemStatuses.any(_isReturnFlowStatus)) return 'return_requested';
    if (itemStatuses.every((status) => status == OrderStatusConstants.ecommerceDelivered)) {
      return OrderStatusConstants.ecommerceDelivered;
    }
    if (itemStatuses.any((status) => status == OrderStatusConstants.ecommerceCancelled)) {
      return OrderStatusConstants.ecommerceCancelled;
    }
    if (itemStatuses.any(
      (status) =>
          status == OrderStatusConstants.ecommerceShipped ||
          status == OrderStatusConstants.ecommerceTransfer ||
          status == OrderStatusConstants.ecommerceBranch ||
          status == OrderStatusConstants.ecommerceOutForDelivery,
    )) {
      return OrderStatusConstants.ecommerceShipped;
    }
    if (itemStatuses.any(
      (status) => status == OrderStatusConstants.ecommercePreparing || status == OrderStatusConstants.ecommerceReadyToShip,
    )) {
      return OrderStatusConstants.ecommercePreparing;
    }
    return _status;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    return isWeb ? _buildWebView(context) : _buildMobileView(context);
  }

  Widget _buildWebView(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
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
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildContent(context, isWeb: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const WebFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Text(
          'Sipariş Detayı',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _buildContent(context, isWeb: false),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isWeb}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWeb)
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Tüm Siparişler',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _buildTopCard(),
        const SizedBox(height: 16),
        _buildShipmentCard(context, isWeb: isWeb),
        const SizedBox(height: 16),
        if (isWeb)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildAddressCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildPaymentCard()),
            ],
          )
        else ...[
          _buildAddressCard(),
          const SizedBox(height: 16),
          _buildPaymentCard(),
        ],
        const SizedBox(height: 16),
        _buildContractsSection(),
      ],
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildMeta('Sipariş no', _orderNumber)),
              Expanded(
                child: _buildMeta(
                  'Sipariş tarihi',
                  _formatCreatedAt(_rawOrder['created_at']?.toString()),
                ),
              ),
              Expanded(
                child: _buildMeta('Ürün sayısı', '${_items.length} ürün'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMeta(
            'Durum',
            _statusLabel(_effectiveStatus),
            valueColor: _statusColor(_effectiveStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentCard(BuildContext context, {required bool isWeb}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _statusColor(_effectiveStatus).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon(_effectiveStatus),
                  color: _statusColor(_effectiveStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(_effectiveStatus),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(_effectiveStatus),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_items.length} ürün için sipariş akışı oluşturuldu. Kargo firması: ihız',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip('Takip no', _trackingNo()),
              _infoChip('Kargo Firması', 'ihız'),
            ],
          ),
          const SizedBox(height: 12),
          _buildSellerBar(context),
          const SizedBox(height: 12),
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildItemCard(context, item),
            ),
          ),
          if (_items.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openTrackingPage(context, _firstItem),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Kargom Nerede?'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerBar(BuildContext context) {
    final storeName = _firstItem['store_name']?.toString() ?? 'Satıcı';
    final storeLogo = _firstItem['store_logo_url']?.toString();
    final store = {
      'id': _firstItem['seller_id'] ?? storeName,
      'name': storeName,
      'logo_url': storeLogo,
    };
    final isFollowing = AppState().isFollowingStore(store);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF3F0FF),
            backgroundImage: (storeLogo != null && storeLogo.isNotEmpty)
                ? OptimizedImage.buildProvider(
                    imageUrlOrPath: storeLogo,
                    cacheWidth: 80,
                    cacheHeight: 80,
                  )
                : null,
            child: (storeLogo != null && storeLogo.isNotEmpty)
                ? null
                : Text(
                    storeName.isNotEmpty
                        ? storeName.substring(0, 1).toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _openSellerProfile(context),
              child: Text(
                storeName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              AppState().toggleFollowStore(store);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(88, 38),
            ),
            child: Text(isFollowing ? 'Takipte' : 'Takip Et'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    final attrs = ((item['attributes'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final itemStatus = (item['status'] ?? '').toString().toLowerCase();
    final canRequestReturn = itemStatus == OrderStatusConstants.ecommerceDelivered;
    final isReturnFlow = _isReturnFlowStatus(itemStatus);
    final canScheduleReturnPickup = itemStatus == 'return_approved';
    final returnButtonLabel = canScheduleReturnPickup
        ? 'Kurye Zamanı Seç'
        : isReturnFlow
        ? 'İade Sürecinde'
        : 'İade Talebi';
    final returnButtonColor = isReturnFlow
        ? const Color(0xFFFF8A00)
        : const Color(0xFFD93E53);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openProductDetail(context, item),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImage(item['product_image_url']?.toString()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _openProductDetail(context, item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name']?.toString() ?? 'Ürün',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ürün Kodu: ${item['product_code'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['quantity'] ?? 1} adet  •  ${_money(item['unit_price'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(item['total_price']),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (attrs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attrs.map((attr) {
                final key = attr['key']?.toString() ?? '';
                final value = attr['value']?.toString() ?? '';
                if (key.isEmpty || value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$key: $value',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AskProductQuestionPage(
                        product: {
                          'productName':
                              item['product_name']?.toString() ?? 'Ürün',
                          'storeName':
                              item['store_name']?.toString() ?? 'Satıcı',
                          'sellerId': item['seller_id']?.toString() ?? '',
                          'imageUrl':
                              item['product_image_url']?.toString() ?? '',
                        },
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Soru Sor'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _buyAgain(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tekrar Satın Al'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderReviewPage(item: item, initialTab: 1),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Değerlendir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: canScheduleReturnPickup
                      ? () async {
                          final scheduled =
                              await _openReturnPickupScheduleSheet(
                                context,
                                item,
                              );
                          if (!context.mounted || !scheduled) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'İade kurye alım zamanın kaydedildi.',
                              ),
                            ),
                          );
                          Navigator.pop(context, true);
                        }
                      : isReturnFlow
                      ? null
                      : canRequestReturn
                      ? () async {
                          final created = await _openReturnRequestSheet(
                            context,
                            item,
                          );
                          if (!context.mounted || !created) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'İade talebin alındı ve iHız paneline iletildi.',
                              ),
                            ),
                          );
                          Navigator.pop(context, true);
                        }
                      : () => _showActionInfo(
                          context,
                          'İade Talebi',
                          'İade talebi yalnızca teslim edilen ürünlerde açılabilir.',
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: returnButtonColor,
                    side: BorderSide(color: returnButtonColor),
                  ),
                  child: Text(returnButtonLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final fullName = [
      _deliveryAddress['name'],
      _deliveryAddress['surname'],
    ].where((e) => (e?.toString().trim().isNotEmpty ?? false)).join(' ');
    final detailParts = [
      _deliveryAddress['building'],
      _deliveryAddress['detail'],
      _deliveryAddress['city'],
    ].where((e) => (e?.toString().trim().isNotEmpty ?? false)).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teslimat Adresi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            fullName.isEmpty ? 'İsim bilgisi yok' : fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            detailParts.isEmpty ? 'Adres bilgisi bulunamadı' : detailParts,
            style: const TextStyle(height: 1.5, color: Colors.black87),
          ),
          if ((_deliveryAddress['phone']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              _deliveryAddress['phone'].toString(),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Bilgileri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Ödeme',
            'Tek Çekim • ${_rawOrder['payment_card_last4'] != null ? '****${_rawOrder['payment_card_last4']}' : 'Kart'}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow('Ara Toplam', _money(_rawOrder['subtotal_amount'])),
          const SizedBox(height: 8),
          _buildPriceRow('Kargo', _money(_rawOrder['shipping_amount'])),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildPriceRow(
            'Toplam',
            _money(_rawOrder['total_amount']),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContractsSection() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: const [
          _ContractTile(
            title: 'Mesafeli Satış Sözleşmesi',
            body:
                'Siparişe ait mesafeli satış sözleşmesi burada görüntülenir. Gerçek metin backend kaynağına bağlandığında bu alana getirilecektir.',
          ),
          Divider(height: 1),
          _ContractTile(
            title: 'Ön Bilgilendirme Formu',
            body:
                'Ön bilgilendirme formu bu panel içinde görüntülenir. Sipariş özeti ve ödeme bilgileriniz ile birlikte doğrulama amaçlı sunulur.',
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black54),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Colors.grey,
          size: 28,
        ),
      );
    }

    if (path.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFF3F4F6),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 28,
          ),
        ),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Colors.grey,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildDataUrlImage(String dataUrl) {
    try {
      final bytes = UriData.parse(dataUrl).contentAsBytes();
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 22,
        ),
      );
    }
  }

  String _money(dynamic value) {
    if (value is num) return '${value.toStringAsFixed(2)} TL';
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return '${parsed.toStringAsFixed(2)} TL';
    return value?.toString() ?? '0.00 TL';
  }

  String _formatCreatedAt(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _trackingNo() {
    final seed = _orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return seed.isEmpty
        ? '7330029647849343'
        : '7330${seed.padRight(12, '4').substring(0, 12)}';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case OrderStatusConstants.ecommerceShipped:
        return 'Siparişiniz Kargoda';
      case OrderStatusConstants.ecommerceDelivered:
        return 'Sipariş Teslim Edildi';
      case OrderStatusConstants.ecommerceCancelled:
        return 'Sipariş İptal Edildi';
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case OrderStatusConstants.ecommerceReturns:
        return 'İade Süreci Başlatıldı';
      case OrderStatusConstants.ecommercePreparing:
      case OrderStatusConstants.ecommerceConfirmed:
      default:
        return 'Siparişiniz Hazırlanıyor';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case OrderStatusConstants.ecommerceShipped:
        return Colors.orange;
      case OrderStatusConstants.ecommerceDelivered:
        return Colors.green;
      case OrderStatusConstants.ecommerceCancelled:
        return Colors.red;
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case OrderStatusConstants.ecommerceReturns:
        return const Color(0xFFFF8A00);
      case OrderStatusConstants.ecommercePreparing:
      case OrderStatusConstants.ecommerceConfirmed:
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case OrderStatusConstants.ecommerceShipped:
        return Icons.local_shipping;
      case OrderStatusConstants.ecommerceDelivered:
        return Icons.check_circle;
      case OrderStatusConstants.ecommerceCancelled:
        return Icons.cancel;
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case OrderStatusConstants.ecommerceReturns:
        return Icons.assignment_return_rounded;
      case OrderStatusConstants.ecommercePreparing:
      case OrderStatusConstants.ecommerceConfirmed:
      default:
        return Icons.inventory_2;
    }
  }

  bool _isReturnFlowStatus(String status) {
    switch (status.toLowerCase()) {
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case OrderStatusConstants.ecommerceReturns:
        return true;
      default:
        return false;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _openReturnRequestSheet(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final noteController = TextEditingController();
    final damageController = TextEditingController();
    final issueTags = <String>{};
    final picker = ImagePicker();
    final evidenceImages = <String>[];
    var selectedReason = _returnReasonOptions.first;
    var selectedDamage = _damageLevelOptions.first;
    var isSubmitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickImage() async {
              if (evidenceImages.length >= 3) return;
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1800,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              final mime = picked.mimeType ?? 'image/jpeg';
              final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
              setSheetState(() {
                evidenceImages.add(dataUrl);
              });
            }

            Future<void> submitRequest() async {
              final appState = AppState();
              final userId = appState.currentUser?['uid']?.toString() ?? '';
              final orderId = _rawOrder['id']?.toString() ?? '';
              final orderItemId = item['id']?.toString() ?? '';
              if (userId.isEmpty || orderId.isEmpty || orderItemId.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'İade talebi için kullanıcı veya sipariş bilgisi eksik.',
                    ),
                  ),
                );
                return;
              }
              if (evidenceImages.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Hasar tespiti için en az 1 ürün görseli yüklemen gerekiyor.',
                    ),
                  ),
                );
                return;
              }
              if (issueTags.isEmpty &&
                  noteController.text.trim().isEmpty &&
                  damageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Lütfen en az bir sorun etiketi seç veya açıklama yaz.',
                    ),
                  ),
                );
                return;
              }

              setSheetState(() => isSubmitting = true);
              try {
                await OrderService.instance.submitReturnRequest(
                  userId: userId,
                  orderId: orderId,
                  orderItemId: orderItemId,
                  reason: selectedReason,
                  issueTags: issueTags.toList(growable: false),
                  detail: noteController.text.trim(),
                  damageLevel: selectedDamage,
                  damageDescription: damageController.text.trim(),
                  evidenceImageDataUrls: List<String>.from(evidenceImages),
                );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop(true);
              } catch (e) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İade ve Hasar Tespiti',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item['product_name'] ?? 'Ürün'} için iade formunu doldur. Yüklediğin görseller satıcı incelemesine gönderilecek.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'İade nedeni',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _returnReasonOptions.map((reason) {
                          final selected = selectedReason == reason;
                          return ChoiceChip(
                            label: Text(reason),
                            selected: selected,
                            onSelected: (_) =>
                                setSheetState(() => selectedReason = reason),
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFF4B5563),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDamage,
                        decoration: InputDecoration(
                          labelText: 'Hasar sınıfı',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _damageLevelOptions
                            .map(
                              (level) => DropdownMenuItem<String>(
                                value: level,
                                child: Text(level),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedDamage = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: damageController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Hasar tespit açıklaması',
                          hintText:
                              'Kırık, çatlak, parçalanma veya çalışmama gibi durumu yaz.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Hazır sorun etiketleri',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _issueTagOptions.map((tag) {
                          final selected = issueTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: selected,
                            onSelected: (_) {
                              setSheetState(() {
                                if (selected) {
                                  issueTags.remove(tag);
                                } else {
                                  issueTags.add(tag);
                                }
                              });
                            },
                            selectedColor: const Color(
                              0xFFD93E53,
                            ).withValues(alpha: 0.16),
                            checkmarkColor: const Color(0xFFD93E53),
                            labelStyle: TextStyle(
                              color: selected
                                  ? const Color(0xFFD93E53)
                                  : const Color(0xFF4B5563),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Ürün görselleri (max 3)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(3, (index) {
                          final hasImage = index < evidenceImages.length;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == 2 ? 0 : 8,
                              ),
                              child: InkWell(
                                onTap: hasImage ? null : pickImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  child: hasImage
                                      ? Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: _buildDataUrlImage(
                                                  evidenceImages[index],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: InkWell(
                                                onTap: () {
                                                  setSheetState(() {
                                                    evidenceImages.removeAt(
                                                      index,
                                                    );
                                                  });
                                                },
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo_outlined,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Fotoğraf Ekle',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Ek açıklama',
                          hintText:
                              'Satıcıya iletmek istediğin iade notunu buraya ekle.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : submitRequest,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.assignment_return_rounded),
                          label: Text(
                            isSubmitting
                                ? 'Gönderiliyor...'
                                : 'Hasar Tespiti ve İade Talebini Gönder',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD93E53),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    damageController.dispose();
    noteController.dispose();
    return created == true;
  }

  Future<bool> _openReturnPickupScheduleSheet(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final appState = AppState();
    final userId = appState.currentUser?['uid']?.toString() ?? '';
    final orderItemId = item['id']?.toString() ?? '';
    if (userId.isEmpty || orderItemId.isEmpty) {
      return false;
    }

    final request = await OrderService.instance.getLatestReturnRequestForItem(
      orderItemId: orderItemId,
    );
    if (!context.mounted) return false;
    if (request == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İade kaydı bulunamadı.')));
      return false;
    }
    final requestId = request['id']?.toString() ?? '';
    final requestStatus = request['status']?.toString().toLowerCase() ?? '';
    if (requestId.isEmpty ||
        (requestStatus != 'awaiting_customer_pickup_slot' &&
            requestStatus != 'pickup_scheduled')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kurye zamanını seçebilmek için satıcı onayı bekleniyor.',
            ),
          ),
        );
      }
      return false;
    }

    final now = DateTime.now();
    final noteController = TextEditingController();
    var selectedDate = DateTime(now.year, now.month, now.day + 1);
    var startTime = const TimeOfDay(hour: 10, minute: 0);
    var endTime = const TimeOfDay(hour: 12, minute: 0);
    var isSubmitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final windowStart = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              startTime.hour,
              startTime.minute,
            );
            final windowEnd = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              endTime.hour,
              endTime.minute,
            );

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: sheetContext,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year, now.month + 2, now.day),
                initialDate: selectedDate,
              );
              if (picked == null) return;
              setSheetState(() => selectedDate = picked);
            }

            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: startTime,
              );
              if (picked == null) return;
              setSheetState(() => startTime = picked);
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: endTime,
              );
              if (picked == null) return;
              setSheetState(() => endTime = picked);
            }

            Future<void> submitSchedule() async {
              if (!windowEnd.isAfter(windowStart)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bitiş saati başlangıç saatinden sonra olmalı.',
                    ),
                  ),
                );
                return;
              }
              if (windowStart.isBefore(DateTime.now())) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Seçilen başlangıç saati şu andan ileri bir zaman olmalı.',
                    ),
                  ),
                );
                return;
              }
              setSheetState(() => isSubmitting = true);
              try {
                await OrderService.instance.scheduleReturnPickupWindow(
                  userId: userId,
                  returnRequestId: requestId,
                  pickupWindowStart: windowStart,
                  pickupWindowEnd: windowEnd,
                  note: noteController.text.trim(),
                );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop(true);
              } catch (e) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İHız Kurye Alım Zamanı',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Satıcı iade talebini onayladı. Kurye alım günü ve saat aralığını seç.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickStartTime,
                              icon: const Icon(Icons.login_rounded),
                              label: Text(
                                'Başlangıç ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: pickEndTime,
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          'Bitiş ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seçilen aralık: ${_formatDateTime(windowStart)} - ${_formatDateTime(windowEnd)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Kurye notu (opsiyonel)',
                          hintText:
                              'Adres tarifi, bina kodu veya kurye için ek bilgi.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : submitSchedule,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.schedule_send_outlined),
                          label: Text(
                            isSubmitting
                                ? 'Kaydediliyor...'
                                : 'Kurye Alım Zamanını Onayla',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    return created == true;
  }

  Future<void> _openProductDetail(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final client = Supabase.instance.client;
    Product product = _snapshotProduct(item);

    try {
      final row = await client
          .from('products')
          .select()
          .eq('name', item['product_name']?.toString() ?? '')
          .limit(1)
          .maybeSingle();
      if (row != null) {
        product = Product.fromDBProduct(row);
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );
  }

  void _openSellerProfile(BuildContext context) {
    final business = <String, dynamic>{
      'seller_id': _firstItem['seller_id'],
      'name': _firstItem['store_name'] ?? 'Satıcı',
      'business_name': _firstItem['store_name'] ?? 'Satıcı',
      'logo_url': _firstItem['store_logo_url'],
      'category': _firstItem['category'] ?? '',
    };
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BusinessDetailPage(business: business)),
    );
  }

  Product _snapshotProduct(Map<String, dynamic> item) {
    final image = item['product_image_url']?.toString();
    return Product(
      name: item['product_name']?.toString() ?? 'Ürün',
      brand: item['brand']?.toString() ?? 'Ürün',
      price: _money(item['unit_price']),
      rating: 0,
      reviewCount: 0,
      tags: const [],
      images: [if (image != null && image.isNotEmpty) image],
      store: item['store_name']?.toString(),
      category: item['category']?.toString(),
      subCategory: item['sub_category']?.toString(),
    );
  }

  void _buyAgain(Map<String, dynamic> item) {
    AppState().addToCart(_snapshotProduct(item));
  }

  Future<void> _openTrackingPage(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final itemId = item['id']?.toString();
    List<Map<String, dynamic>> history = [];
    if (itemId != null && itemId.isNotEmpty) {
      history = await OrderService.instance.getOrderItemTracking(itemId);
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShipmentTrackingPage(
          order: _rawOrder,
          item: item,
          history: history,
        ),
      ),
    );
  }

  void _showActionInfo(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  final String title;
  final String body;

  const _ContractTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
