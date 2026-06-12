import 'package:flutter/material.dart';
import '../utils/order_status_constants.dart';

class CourierInfoPage extends StatelessWidget {
  const CourierInfoPage({super.key, required this.trackingData});

  final Map<String, dynamic> trackingData;

  @override
  Widget build(BuildContext context) {
    final storeName = _readText(const ['store_name'], fallback: 'Mağaza');
    final productName = _readText(const ['product_name'], fallback: 'Ürün');
    final trackingNo = _readText(const ['tracking_number'], fallback: '-');
    final normalizedStatus = _normalizeStatus(
      _readText(const ['status', 'shipment_step'], fallback: ''),
    );

    final courierNameRaw = _readText(const [
      'courier_name',
      'courier_full_name',
      'courier_display_name',
    ], fallback: '');
    final courierPhoneRaw = _readText(const ['courier_phone'], fallback: '');
    final courierVehicleRaw = _readText(const [
      'courier_vehicle',
    ], fallback: '');
    final courierNote = _readText(const [
      'courier_note',
      'courier_message',
    ], fallback: '');
    final hasCourierInfo =
        courierNameRaw.isNotEmpty ||
        courierPhoneRaw.isNotEmpty ||
        courierVehicleRaw.isNotEmpty;

    final courierName = courierNameRaw.isEmpty
        ? 'Bilgi paylaşılmadı'
        : courierNameRaw;
    final courierPhone = courierPhoneRaw.isEmpty
        ? 'Bilgi paylaşılmadı'
        : courierPhoneRaw;
    final courierVehicle = courierVehicleRaw.isEmpty
        ? 'Bilgi paylaşılmadı'
        : courierVehicleRaw;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0),
        foregroundColor: Colors.white,
        title: const Text(
          'Kurye Bilgisi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B12F0), Color(0xFF3B0AC0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$storeName • $productName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Takip no: $trackingNo',
                    style: const TextStyle(
                      color: Color(0xFFEDE7FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.person_outline_rounded,
                    title: _courierRoleTitle(normalizedStatus),
                    value: courierName,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'Telefon',
                    value: courierPhone,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.two_wheeler_outlined,
                    title: 'Araç',
                    value: courierVehicle,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.local_shipping_outlined,
                    title: 'Sipariş Durumu',
                    value: _statusTitle(normalizedStatus),
                  ),
                ],
              ),
            ),
            if (courierNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Text(
                  'Kurye Notu: $courierNote',
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (!hasCourierInfo) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEC84B)),
                ),
                child: const Text(
                  'Kurye bilgisi henüz sisteme işlenmedi.',
                  style: TextStyle(
                    color: Color(0xFF7A2E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF5B12F0), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1),
    );
  }

  String _readText(List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final value = trackingData[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == OrderStatusConstants.ecommerceShipped) return OrderStatusConstants.ecommerceOutForDelivery;
    return value;
  }

  String _courierRoleTitle(String status) {
    if (status == OrderStatusConstants.ecommerceDelivered) return 'Teslim Eden Kurye';
    return 'Ürünü Teslim Alan Kurye';
  }

  String _statusTitle(String status) {
    switch (status) {
      case OrderStatusConstants.ecommerceOutForDelivery:
        return 'Dağıtımda';
      case OrderStatusConstants.ecommerceDelivered:
        return 'Teslim Edildi';
      case OrderStatusConstants.ecommerceCancelled:
        return 'İptal Edildi';
      default:
        return 'Güncellendi';
    }
  }
}
