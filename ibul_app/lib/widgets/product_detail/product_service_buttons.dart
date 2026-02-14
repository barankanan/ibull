import 'package:flutter/material.dart';

class ProductServiceButtons extends StatelessWidget {
  const ProductServiceButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildServiceCard(
          icon: Icons.local_shipping_outlined,
          title: 'KURYE TESLİMATI',
          subtitle: 'Tahmini 4 Saate adresinde',
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          icon: Icons.credit_card,
          title: 'Taksitlendirme Fırsatı', // Updated title
          subtitle: 'Ayda 325 TL den başlayan taksitle', // Kept original subtitle or can be updated
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          icon: Icons.refresh,
          title: 'İptal ve İade Koşulları', // Updated title
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6200EA), size: 24),
          const SizedBox(width: 12),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}
