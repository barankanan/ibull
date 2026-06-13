import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/address_edit_sheet.dart';

class DeliveryInfoPage extends StatefulWidget {
  const DeliveryInfoPage({super.key});

  @override
  State<DeliveryInfoPage> createState() => _DeliveryInfoPageState();
}

class _DeliveryInfoPageState extends State<DeliveryInfoPage> {
  String _selectedCourier = 'MNG';
  int _selectedAddressIndex = 0;
  final List<Map<String, String>> _addresses = [
    {'title': 'Adresleyim', 'subtitle': 'Adresini Doğrula'},
  ];

  final List<String> _couriers = ['MNG', 'Aras', 'PTT', 'İHız'];

  static const Color _surface = Color(0xFFF4F6FA);
  static const Color _cardBorder = Color(0xFFE7EAF0);
  static const Color _labelColor = Color(0xFF667085);
  static const Color _valueColor = Color(0xFF101828);
  static const Color _heroStart = Color(0xFF5A22E0);
  static const Color _heroEnd = Color(0xFF3A0CA3);

  String _getDeliveryTime() {
    if (_selectedCourier == 'İHız') {
      return '1 Saat';
    } else {
      return '3 Gün';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeroHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('Kurye ve teslimat'),
                  const SizedBox(height: 10),
                  _buildCourierCard(),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Teslimat adresi'),
                  const SizedBox(height: 10),
                  _buildAddressCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, topInset + 4, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_heroStart, _heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Kurye Bilgi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tahmini ${_getDeliveryTime()} içinde adresinizde',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_selectedCourier ile teslimat detaylarını buradan yönetin.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: _labelColor,
      ),
    );
  }

  Widget _buildCourierCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showCourierSelectionDialog(),
            child: _buildInfoRow(
              icon: Icons.local_shipping_outlined,
              title: 'Kurye',
              value: _selectedCourier,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF98A2B3),
                size: 22,
              ),
            ),
          ),
          _buildRowDivider(),
          _buildInfoRow(
            icon: Icons.delivery_dining_outlined,
            title: 'Teslimat',
            value: 'Tahmini ${_getDeliveryTime()} içinde adresinizde',
          ),
          _buildRowDivider(),
          _buildInfoRow(
            icon: Icons.phone_in_talk_outlined,
            title: 'İletişim Bilgisi',
            value: 'Bilinmiyor',
          ),
          _buildRowDivider(),
          _buildInfoRow(
            icon: Icons.two_wheeler_outlined,
            title: 'Araç',
            value: 'Bilinmiyor',
          ),
          _buildRowDivider(),
          _buildInfoRow(
            icon: Icons.payments_outlined,
            title: 'Ücretlendirme',
            value: 'Km başına 6,30 TL',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF98A2B3),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ..._addresses.asMap().entries.map((entry) {
            final index = entry.key;
            final address = entry.value;
            return Column(
              children: [
                _buildAddressRow(
                  isSelected: index == _selectedAddressIndex,
                  title: address['title']!,
                  subtitle: address['subtitle']!,
                  onToggle: (value) {
                    setState(() {
                      if (value) {
                        _selectedAddressIndex = index;
                      }
                    });
                  },
                ),
                if (index < _addresses.length - 1) _buildRowDivider(),
              ],
            );
          }),
          _buildRowDivider(),
          _buildAddAddressRow(
            onTap: () {
              _showAddAddressDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _labelColor,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _valueColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required bool isSelected,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.softPurple.withValues(alpha: 0.45) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(Icons.home_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _valueColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _labelColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isSelected,
            onChanged: onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAddAddressRow({VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adres Değiştir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _valueColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Yeni adres ekle',
                      style: TextStyle(
                        fontSize: 13,
                        color: _labelColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF98A2B3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }

  Widget _buildRowDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
    );
  }

  void _showCourierSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Kargo Firması Seç',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: RadioGroup<String>(
            groupValue: _selectedCourier,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedCourier = value;
              });
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _couriers.map((courier) {
                return RadioListTile<String>(
                  title: Text(courier),
                  value: courier,
                  activeColor: AppColors.primary,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AddressEditSheet(
            type: 'Adres',
            onSave: (Map<String, String> newAddress) {
              setState(() {
                _addresses.add({
                  'title': newAddress['title'] ?? 'Yeni Adres',
                  'subtitle': newAddress['detail'] ?? '',
                });
                _selectedAddressIndex = _addresses.length - 1;
              });

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adres başarıyla eklendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onDelete: () {},
          ),
        ),
      ),
    );
  }
}
