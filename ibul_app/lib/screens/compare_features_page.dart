import 'package:flutter/material.dart';
import '../core/constants.dart';

class CompareFeaturesPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const CompareFeaturesPage({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürün özellikleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Seçtiğin ısıtıcı ürünlerin özellik karşılaştırması',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Headers
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: products.take(2).map((product) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Icon(Icons.image, size: 30, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product['name'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Price Section
            _buildRow('', ['UFO', 'Kumtel'], isHeader: false),
            _buildRow('', ['Ufo S/2400 Duvar tipi Isıtıcı', 'kumtel Ex-25 Ecoray 2500W'], isHeader: false),
            _buildRow('', ['2.604.00 TL', '1.198,77 TL'], isPriceRow: true),
            _buildRow('', ['Gür Isı', ''], isHeader: false),
            _buildRow('', ['Ufo S/2400 Duvar tipi Isıtıcı', ''], isHeader: false),
            _buildRow('', ['2.684.46 TL', ''], isPriceRow: true),

            const SizedBox(height: 16),

            // GENEL ÖZELLİKLER
            _buildSectionHeader('GENEL ÖZELLİKLER'),
            _buildRow('Isıtıcı Tipi', ['infared ısıtıcı', 'infared ısıtıcı']),
            _buildRow('Kontrol şekli', ['Isı Ayar Düğmesi', 'ısı Ayar Düğmesi']),
            _buildRow('Etki Alanı', ['24m2', '24m2']),
            _buildRow('Kullanım pozisyonu', ['Yatay', 'Yatay']),
            _buildRow('Isıtıcı Konumu', ['Zemin duvar', 'zemin duvar']),

            const SizedBox(height: 16),

            // TASARIM
            _buildSectionHeader('TASARIM'),
            _buildRow('Yükseklik', ['88 Cm', '20 Cm']),
            _buildRow('Genişlik', ['19 Cm', '84 Cm']),
            _buildRow('Derinlik Çap', ['9 Cm', '10 Cm']),
            _buildRow('Renk Seçeneği', ['Gri', 'Siyah']),

            const SizedBox(height: 16),

            // TEKNİK ÖZELLİKLER
            _buildSectionHeader('TEKNİK ÖZELLİKLER'),
            _buildRow('Max. Isıtma Gücü', ['2400 W', '2500 W']),
            _buildRow('Flament Sayısı', ['1 Adet', '1 Adet']),
            _buildRow('Buhar Özelliği', ['yok', 'yok']),

            const SizedBox(height: 16),

            // DEĞERLENDİRİLMESİ
            _buildSectionHeader('DEĞERLENDİRİLMESİ'),
            _buildRow('Puanı', ['⭐ 4.2', '⭐ 3.2'], isStarRow: true),
            _buildRow('Görsel sayısı', ['📷 111', '📷 56'], isIconRow: true),
            _buildRow('Ortalama Kargo Hızı', ['🚚 3 Gün', '🚚 8 Saat'], isIconRow: true),
            _buildRow('Mesaja Dönme Hızı', ['🕐 1 saat', '🕐 2 Saat'], isIconRow: true),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildRow(String label, List<String> values, {bool isHeader = false, bool isPriceRow = false, bool isStarRow = false, bool isIconRow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? AppColors.primary : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (label.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHeader ? AppColors.primary : Colors.white,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
                    color: isHeader ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ...values.map((value) {
            return Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isPriceRow ? 12 : 11,
                    fontWeight: isPriceRow ? FontWeight.bold : FontWeight.normal,
                    color: isPriceRow ? AppColors.primary : (isStarRow || isIconRow ? Colors.black : Colors.grey.shade700),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
