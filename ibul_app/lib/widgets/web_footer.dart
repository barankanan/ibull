import 'package:flutter/material.dart';
import '../core/constants.dart';

class WebFooter extends StatelessWidget {
  const WebFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo ve Hakkımızda
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'iBul',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Türkiye\'nin en hızlı büyüyen e-ticaret platformu. Aradığınız her şey burada!',
                      style: TextStyle(color: Colors.grey[600], height: 1.5),
                    ),
                  ],
                ),
              ),
              
              // Link Kolonları
              Expanded(child: _buildFooterColumn('Kurumsal', ['Hakkımızda', 'Kariyer', 'İletişim'])),
              Expanded(child: _buildFooterColumn('Müşteri Hizmetleri', ['Sıkça Sorulan Sorular', 'Canlı Destek', 'İade Koşulları'])),
              Expanded(child: _buildFooterColumn('Sosyal Medya', ['Instagram', 'Twitter', 'LinkedIn'])),
            ],
          ),
          
          const Divider(height: 64),
          
          Text(
            '© 2026 iBul E-Ticaret A.Ş. Tüm hakları saklıdır.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            link,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        )),
      ],
    );
  }
}
