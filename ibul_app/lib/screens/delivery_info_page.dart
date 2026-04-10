import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/address_edit_sheet.dart';

class DeliveryInfoPage extends StatefulWidget {
  const DeliveryInfoPage({super.key});

  @override
  State<DeliveryInfoPage> createState() => _DeliveryInfoPageState();
}

class _DeliveryInfoPageState extends State<DeliveryInfoPage> {
  String _selectedCourier = 'MNG'; // Varsayılan kargo firması
  int _selectedAddressIndex = 0;
  final List<Map<String, String>> _addresses = [
    {'title': 'Adresleyim', 'subtitle': 'Adresini Doğrula'},
  ];
  
  // Kargo firması seçenekleri
  final List<String> _couriers = ['MNG', 'Aras', 'PTT', 'İHız'];
  
  // Teslimat süresini hesapla
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Kurye Bilgi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kurye Bilgileri Bölümü
            _buildSectionHeader('Kurye'),
            GestureDetector(
              onTap: () => _showCourierSelectionDialog(),
              child: _buildSimpleInfoCard(
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.primary,
                title: 'Kurye',
                subtitle: _selectedCourier,
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ),
            ),
            const Divider(height: 1, indent: 60),
            _buildSimpleInfoCard(
              icon: Icons.delivery_dining,
              iconColor: AppColors.primary,
              title: 'Teslimat',
              subtitle: 'Tahmini ${_getDeliveryTime()} içinde adresinizde',
            ),
            const Divider(height: 1, indent: 60),
            _buildSimpleInfoCard(
              icon: Icons.phone_outlined,
              iconColor: AppColors.primary,
              title: 'İletişim Bilgisi',
              subtitle: 'Bilinmiyor',
            ),
            const Divider(height: 1, indent: 60),
            _buildSimpleInfoCard(
              icon: Icons.two_wheeler_outlined,
              iconColor: AppColors.primary,
              title: 'Araç',
              subtitle: 'Bilinmiyor',
            ),
            const Divider(height: 1, indent: 60),
            _buildSimpleInfoCard(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
              title: 'Ücretlendirme',
              subtitle: 'Km başına 6,30 TL',
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            
            const SizedBox(height: 20),
            
            // Adres Bölümü
            _buildSectionHeader('Adres'),
            ..._addresses.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, String> address = entry.value;
              return Column(
                children: [
                  _buildAddressCard(
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
                  if (index < _addresses.length - 1)
                    const Divider(height: 1, indent: 60),
                ],
              );
            }),
            const Divider(height: 1, indent: 60),
            _buildAddAddressCard(
              onTap: () {
                _showAddAddressDialog();
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Basit bilgi kartı (arka plan yok, sadece ikon)
  Widget _buildSimpleInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildAddressCard({
    required bool isSelected,
    required String title,
    required String subtitle,
    required Function(bool) onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.home_outlined,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: onToggle,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAddAddressCard({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.add,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adres Değiştir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Yeni adres ekle',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Kargo firması seçim dialog
  void _showCourierSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kargo Firması Seç'),
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
  
  // Adres ekleme dialog
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
                // Yeni eklenen adresi seç
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
            onDelete: () {}, // Yeni adres ekleme için silme işlemi yok
          ),
        ),
      ),
    );
  }
}
