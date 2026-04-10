import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../models/product_model.dart';
import 'navigation_page.dart';

class DeliveryOptionsPage extends StatefulWidget {
  final Product? product;
  
  const DeliveryOptionsPage({super.key, this.product});

  @override
  State<DeliveryOptionsPage> createState() => _DeliveryOptionsPageState();
}

class _DeliveryOptionsPageState extends State<DeliveryOptionsPage> {
  final AppState _appState = AppState();
  
  @override
  Widget build(BuildContext context) {
    final bool hasFastDelivery = widget.product != null ? _appState.hasFastDelivery(widget.product!) : false;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 16,
              left: 8,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Standart Teslimat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Standart Teslimat Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kargo Ücreti
                        _buildDeliveryInfoRow(
                          Icons.payments,
                          'Kargo Ücreti',
                          'Mesafeye Bağlı Ücret',
                          showInfoIcon: true,
                        ),
                        const Divider(height: 32),
                        // Kargo Şirketi
                        _buildDeliveryInfoRow(
                          Icons.business,
                          'Kargo Şirketi',
                          'İHİZ',
                        ),
                        const Divider(height: 32),
                        // Şehir
                        _buildDeliveryInfoRow(
                          Icons.location_city,
                          'Şehir',
                          'Hatay (yakın lokasyon)',
                        ),
                        const Divider(height: 32),
                        // Kargoya Verilme Tarihi
                        _buildDeliveryInfoRow(
                          Icons.calendar_today,
                          'Kargoya Verilme Tarihi',
                          hasFastDelivery 
                              ? 'En geç 8 eylül (Hızlı teslimat seçildi)'
                              : 'En geç 8 eylül (Bugün Kuryeye verilir)',
                          showInfoIcon: true,
                        ),
                        const Divider(height: 32),
                        // Ürünün Geliş Noktası
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ürünün Geliş Noktası',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NavigationPage(
                                      startLocation: 'konumunuz',
                                      endLocation: 'MediaMarkt',
                                      startCoordinates: LatLng(41.0082, 28.9784),
                                      endCoordinates: LatLng(41.0385, 28.9845),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                children: [
                                  Text(
                                    'Göz At',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Hızlı Teslimat Option (Premium)
                  InkWell(
                    onTap: () {
                      if (widget.product != null) {
                        setState(() {
                          _appState.toggleFastDelivery(widget.product!);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _appState.hasFastDelivery(widget.product!)
                                  ? 'Hızlı Teslimat seçildi'
                                  : 'Hızlı Teslimat kaldırıldı',
                            ),
                            duration: const Duration(seconds: 1),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.deepOrange.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasFastDelivery ? Colors.white : Colors.orange.shade400,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hızlı Teslimat',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '2 Saat İçinde',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Premium kuryemiz ürününüzü aynı gün içinde kapınıza teslim eder.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // +200 TL Ekle Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.product != null) {
                                final bool newState = !hasFastDelivery;
                                setState(() {
                                  _appState.setFastDelivery(widget.product!, newState);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(newState ? '200TL eklendi' : '200TL çıkarıldı'),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: newState ? Colors.green.shade600 : Colors.red.shade600,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasFastDelivery ? Colors.white.withValues(alpha: 0.9) : Colors.white,
                              foregroundColor: hasFastDelivery ? Colors.green.shade700 : Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.9),
                              disabledForegroundColor: Colors.green.shade700,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasFastDelivery)
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                  ),
                                if (hasFastDelivery)
                                  SizedBox(width: 8),
                                Text(
                                  hasFastDelivery ? 'Eklendi' : '+200 TL Ekle',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildDeliveryInfoRow(
    IconData icon,
    String title,
    String value, {
    bool showInfoIcon = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (showInfoIcon) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
