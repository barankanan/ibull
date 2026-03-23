import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/common/video_player_widget.dart';

class ShipmentTrackingPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> history;

  const ShipmentTrackingPage({
    super.key,
    required this.order,
    required this.item,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final packagingVideo = _resolvePackagingVideoMeta();
    final isDesktop = _isDesktopLayout(context);
    final contentMaxWidth = _contentMaxWidth(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Kargo Takibi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              16,
              isDesktop ? 24 : 16,
              24,
            ),
            child: isDesktop
                ? _buildDesktopContent(steps, packagingVideo)
                : _buildMobileContent(steps, packagingVideo),
          ),
        ),
      ),
    );
  }

  bool _isDesktopLayout(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  double _contentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 1220;
    if (width >= 1100) return 1080;
    return double.infinity;
  }

  Widget _buildMobileContent(
    List<_TrackingStep> steps,
    _PackagingVideoMeta? packagingVideo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildSellerCard(),
        const SizedBox(height: 16),
        _buildTimelineCard(steps),
        if (packagingVideo != null) ...[
          const SizedBox(height: 16),
          _buildPackagingVideoCard(packagingVideo),
        ],
        const SizedBox(height: 16),
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildDesktopContent(
    List<_TrackingStep> steps,
    _PackagingVideoMeta? packagingVideo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSummaryCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildSellerCard()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _buildTimelineCard(steps)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildHistoryCard()),
          ],
        ),
        if (packagingVideo != null) ...[
          const SizedBox(height: 16),
          _buildPackagingVideoCard(packagingVideo),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 84,
              child: _buildImage(item['product_image_url']?.toString() ?? ''),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name']?.toString() ?? 'Ürün',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sipariş No: ${order['order_number'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Takip No: ${item['tracking_number'] ?? _fallbackTrackingNo()}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kargo Firması: ${_cargoCompanyLabel()}',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF3F0FF),
            child: Text(
              (item['store_name']?.toString().isNotEmpty ?? false)
                  ? item['store_name'].toString().substring(0, 1).toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['store_name']?.toString() ?? 'Satıcı',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(
                    item['shipment_step']?.toString() ??
                        item['status']?.toString(),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(
                      item['shipment_step']?.toString() ??
                          item['status']?.toString(),
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(List<_TrackingStep> steps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş İlerlemesi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: step.completed
                            ? AppColors.primary
                            : step.active
                            ? const Color(0xFFEDE7FF)
                            : Colors.white,
                        border: Border.all(
                          color: step.completed || step.active
                              ? AppColors.primary
                              : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.completed ? Icons.check : step.icon,
                        size: 15,
                        color: step.completed
                            ? Colors.white
                            : step.active
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 42,
                        color: step.completed
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: step.active || step.completed
                                ? Colors.black87
                                : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Hareketler',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (history.isEmpty)
            const Text(
              'Henüz detaylı kargo hareketi eklenmedi.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            ...history.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry['title']?.toString() ??
                                _statusLabel(entry['status']?.toString()),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(entry['created_at']?.toString()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _historyDescription(entry),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
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

  Widget _buildPackagingVideoCard(_PackagingVideoMeta videoMeta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Paketleme Videosu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Container(
                color: Colors.black,
                child: VideoPlayerWidget(
                  videoUrl: videoMeta.url,
                  trimStart: videoMeta.trimStart,
                  trimEnd: videoMeta.trimEnd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TrackingStep> _buildSteps() {
    if (_isIhizShipment()) {
      final step = (item['shipment_step']?.toString().isNotEmpty ?? false)
          ? item['shipment_step'].toString().toLowerCase()
          : item['status']?.toString().toLowerCase() ?? 'confirmed';
      final int activeIndex;
      if (step == 'delivered') {
        activeIndex = 3;
      } else if (step == 'out_for_delivery' ||
          step == 'branch' ||
          step == 'transfer' ||
          step == 'shipped') {
        activeIndex = 2;
      } else if (step == 'ready_to_ship' || step == 'preparing') {
        activeIndex = 1;
      } else {
        activeIndex = 0;
      }

      return [
        _TrackingStep(
          'Sipariş alındı',
          'Sipariş kaydı başarıyla oluşturuldu.',
          Icons.receipt_long,
          activeIndex >= 0,
          activeIndex == 0,
        ),
        _TrackingStep(
          'Hazırlanıyor',
          'Mağaza siparişi hazırlıyor.',
          Icons.inventory_2_outlined,
          activeIndex >= 1,
          activeIndex == 1,
        ),
        _TrackingStep(
          'İHız kuryesine verildi',
          'Kurye paketi teslim aldı ve müşteriye doğru yola çıktı.',
          Icons.delivery_dining_outlined,
          activeIndex >= 2,
          activeIndex == 2,
        ),
        _TrackingStep(
          'Teslim edildi',
          'Siparişiniz teslim edildi.',
          Icons.check_circle_outline,
          activeIndex >= 3,
          activeIndex == 3,
        ),
      ];
    }

    final step = (item['shipment_step']?.toString().isNotEmpty ?? false)
        ? item['shipment_step'].toString()
        : item['status']?.toString() ?? 'confirmed';
    const order = [
      'confirmed',
      'preparing',
      'ready_to_ship',
      'shipped',
      'transfer',
      'branch',
      'out_for_delivery',
      'delivered',
    ];
    final activeIndex = order
        .indexOf(step.toLowerCase())
        .clamp(0, order.length - 1);
    return [
      _TrackingStep(
        'Siparişiniz Alındı',
        'Ödeme ve sipariş kaydı başarıyla oluşturuldu.',
        Icons.receipt_long,
        activeIndex >= 0,
        activeIndex == 0,
      ),
      _TrackingStep(
        'Hazırlanıyor',
        'Satıcı siparişi hazırlıyor ve paketliyor.',
        Icons.inventory_2_outlined,
        activeIndex >= 1,
        activeIndex == 1,
      ),
      _TrackingStep(
        'Sevkiyat Planlandi',
        'Teslimat operasyonu secildi ve gonderim baslatildi.',
        Icons.route_outlined,
        activeIndex >= 2,
        activeIndex == 2,
      ),
      _TrackingStep(
        'Kargoya Verildi',
        'Paket kargo firmasına teslim edildi.',
        Icons.local_shipping_outlined,
        activeIndex >= 3,
        activeIndex == 3,
      ),
      _TrackingStep(
        'Transfer Aşamasında',
        'Paket transfer merkezinde hareket ediyor.',
        Icons.compare_arrows_outlined,
        activeIndex >= 4,
        activeIndex == 4,
      ),
      _TrackingStep(
        'Şubede',
        'Paket teslimat şubesine ulaştı.',
        Icons.store_mall_directory_outlined,
        activeIndex >= 5,
        activeIndex == 5,
      ),
      _TrackingStep(
        'Dağıtıma Çıktı',
        'Kurye paketi teslimat adresine getiriyor.',
        Icons.delivery_dining_outlined,
        activeIndex >= 6,
        activeIndex == 6,
      ),
      _TrackingStep(
        'Teslim Edildi',
        'Siparişiniz teslim edildi.',
        Icons.check_circle_outline,
        activeIndex >= 7,
        activeIndex == 7,
      ),
    ];
  }

  String _fallbackTrackingNo() {
    final seed = (order['order_number'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return seed.isEmpty
        ? '7330502717644444'
        : '7330${seed.padRight(12, '4').substring(0, 12)}';
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'new':
      case 'confirmed':
        return 'Siparişiniz Alındı';
      case 'preparing':
        return 'Siparişiniz Hazırlanıyor';
      case 'ready_to_ship':
        final deliveryType =
            (item['delivery_type'] ?? order['delivery_type'] ?? '')
                .toString()
                .toLowerCase();
        if (deliveryType.contains('kargo_sube_ihiz')) {
          return 'Kargo Teslim çağrısı açıldı';
        }
        if (deliveryType.contains('kargo_sube_kendim')) {
          return 'Şubeye gönderim hazırlığı tamamlandı';
        }
        if (deliveryType.contains('kargo_sube_firma')) {
          return 'Kargo firması adres alımı bekleniyor';
        }
        return _isIhizShipment()
            ? 'İHız kurye çağrısı açıldı'
            : 'Sevkiyat operasyonu başlatıldı';
      case 'shipped':
        return 'Kargoya Verildi';
      case 'transfer':
        return 'Transfer Aşamasında';
      case 'branch':
        return 'Şubede';
      case 'out_for_delivery':
        return 'Dağıtıma Çıktı';
      case 'delivered':
        return 'Teslim Edildi';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return 'Sipariş Takip Ediliyor';
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isIhizShipment() {
    final deliveryType = (item['delivery_type'] ?? order['delivery_type'] ?? '')
        .toString()
        .toLowerCase();
    if (deliveryType.contains('kargo_sube') ||
        deliveryType.contains('sube') ||
        deliveryType.contains('pickup')) {
      return false;
    }

    final cargo = (item['cargo_company'] ?? '').toString().toLowerCase();
    if (cargo.contains('ihiz') || cargo.contains('hız')) return true;

    final mode = (item['delivery_type'] ?? order['delivery_type'] ?? '')
        .toString()
        .toLowerCase();
    return mode.contains('kurye');
  }

  String _cargoCompanyLabel() {
    final cargo = (item['cargo_company'] ?? '').toString().trim();
    if (cargo.isNotEmpty) return cargo;
    return _isIhizShipment() ? 'İHız' : 'Kargo';
  }

  String _historyDescription(Map<String, dynamic> entry) {
    final description = entry['description']?.toString().trim() ?? '';
    if (description.startsWith('VIDEO_REMOVED::')) {
      return 'Satıcı paketleme videosunu kaldırdı.';
    }
    if (description.startsWith('VIDEO::')) {
      return 'Satıcı paketleme videosu yükledi.';
    }
    if (description.isNotEmpty) {
      return description;
    }
    return 'Sipariş adımı güncellendi.';
  }

  _PackagingVideoMeta? _resolvePackagingVideoMeta() {
    for (final entry in history.reversed) {
      final description = entry['description']?.toString() ?? '';
      if (description.startsWith('VIDEO_REMOVED::')) return null;
      final parsed = _parsePackagingVideoMeta(description);
      if (parsed != null) return parsed;
    }
    return null;
  }

  _PackagingVideoMeta? _parsePackagingVideoMeta(String description) {
    if (!description.startsWith('VIDEO::')) return null;
    final payload = description.replaceFirst('VIDEO::', '').trim();
    if (payload.isEmpty) return null;

    final trimSplit = payload.split('|TRIM:');
    final url = trimSplit.first.trim();
    if (url.isEmpty) return null;

    Duration? trimStart;
    Duration? trimEnd;
    if (trimSplit.length > 1) {
      final range = trimSplit[1].trim().split('-');
      if (range.length == 2) {
        final startMs = int.tryParse(range[0].trim());
        final endMs = int.tryParse(range[1].trim());
        if (startMs != null && startMs >= 0) {
          trimStart = Duration(milliseconds: startMs);
        }
        if (endMs != null && endMs > 0) {
          trimEnd = Duration(milliseconds: endMs);
        }
      }
    }

    return _PackagingVideoMeta(
      url: url,
      trimStart: trimStart,
      trimEnd: trimEnd,
    );
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) return _placeholder();
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF3F4F6),
    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}

class _TrackingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool active;

  const _TrackingStep(
    this.title,
    this.subtitle,
    this.icon,
    this.completed,
    this.active,
  );
}

class _PackagingVideoMeta {
  const _PackagingVideoMeta({required this.url, this.trimStart, this.trimEnd});

  final String url;
  final Duration? trimStart;
  final Duration? trimEnd;
}
