import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../screens/courier_info_page.dart';

class ProductVariantSelector extends StatelessWidget {
  const ProductVariantSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variant selection removed as it is already present in ProductInfoSection (top)
        
        // Delivery info
        _buildInfoRow(Icons.local_shipping_outlined, 'KURYE TESLİMATI', 'Tahmini 4 saate adresinde', AppColors.primary, onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CourierInfoPage()));
        }),
        const SizedBox(height: 6),
        _buildInfoRow(Icons.credit_card, 'Ayda 325 TL\'den başlayan taksitle', null, AppColors.primary),
        const SizedBox(height: 6),
        _buildInfoRow(Icons.refresh, 'İptal ve iade Koşulları', null, AppColors.primary),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String? subtitle, Color iconColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
