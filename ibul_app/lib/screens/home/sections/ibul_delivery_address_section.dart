import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';

/// Teslimat adresi satırı — legacy web home ile aynı görünüm.
class IbulDeliveryAddressSection extends StatelessWidget {
  const IbulDeliveryAddressSection({super.key, this.onChangeTap});

  final VoidCallback? onChangeTap;

  @override
  Widget build(BuildContext context) {
    // Selector: bu satır AppState'ten yalnız teslimat adresini okuyor.
    // Consumer, AppState'in geniş notifyListeners yüzeyinde (sepete ekleme,
    // favori, arama geçmişi vb.) her seferinde rebuild oluyordu — oysa
    // gösterilen metin değişmiyordu. home_screen_sections.dart'taki adres
    // çubuğuyla aynı desen; UI ve davranış aynı.
    return Selector<AppState, String>(
      selector: (context, appState) =>
          appState.currentDeliveryAddress ?? 'Teslimat Adresi Seçin',
      builder: (context, currentAddress, _) {
        return Container(
          width: double.infinity,
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Teslimat Adresi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentAddress,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: onChangeTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text(
                  'Değiştir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
