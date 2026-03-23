import 'package:flutter/material.dart';
import '../../screens/delivery_info_page.dart';

class ProductDeliveryInfoSection extends StatelessWidget {
  const ProductDeliveryInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DeliveryInfoPage(),
              ),
            );
          },
          child: _buildInfoTile(
            icon: Icons.local_shipping_outlined,
            title: 'KURYE TESLIMATİ',
            subtitle: 'Tahmini 4 Saate adresinde',
            color: const Color(0xFF673AB7), // Deep Purple
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          icon: Icons.credit_card,
          title: 'Ayda 325 TL den başlayan taksitle',
          color: const Color(0xFF673AB7),
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          icon: Icons.replay,
          title: 'İptal ve iade Koşulları',
          color: const Color(0xFF673AB7),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // Reduced radius
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16), // Reduced from 20
          const SizedBox(width: 10), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11, // Reduced from 13
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10, // Reduced from 11
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 16), // Reduced from 20
        ],
      ),
    );
  }
}
