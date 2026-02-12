import 'package:flutter/material.dart';
import '../core/constants.dart';

class WebFooter extends StatelessWidget {
  const WebFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 24),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'iBul',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Türkiye\'nin en akıllı e-ticaret platformu.\nYapay zeka destekli ürün arama, yakın lokasyon\nve fiyat karşılaştırma özellikleriyle\naradığınız her şey burada!',
                      style: TextStyle(color: Colors.grey[400], height: 1.6, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    // Sosyal Medya İkonları
                    Row(
                      children: [
                        _buildSocialIcon(Icons.facebook),
                        const SizedBox(width: 12),
                        _buildSocialIcon(Icons.camera_alt_outlined),
                        const SizedBox(width: 12),
                        _buildSocialIcon(Icons.alternate_email),
                        const SizedBox(width: 12),
                        _buildSocialIcon(Icons.play_arrow_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Link Kolonları
              Expanded(child: _buildFooterColumn('Kurumsal', [
                'Hakkımızda',
                'Kariyer',
                'İletişim',
                'Basın Odası',
                'Yatırımcı İlişkileri',
              ])),
              Expanded(child: _buildFooterColumn('Müşteri Hizmetleri', [
                'Sıkça Sorulan Sorular',
                'Canlı Destek',
                'İade ve Değişim',
                'Kargo Takibi',
                'Güvenli Alışveriş',
              ])),
              Expanded(child: _buildFooterColumn('İş Ortaklığı', [
                'Satıcı Ol',
                'Reklam Ver',
                'API Entegrasyonu',
                'İş Birlikleri',
              ])),
            ],
          ),
          
          const SizedBox(height: 32),
          Divider(color: Colors.grey[700], height: 1),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 iBul E-Ticaret A.Ş. Tüm hakları saklıdır.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Row(
                children: [
                  _buildFooterLink('Gizlilik Politikası'),
                  const SizedBox(width: 20),
                  _buildFooterLink('Kullanım Koşulları'),
                  const SizedBox(width: 20),
                  _buildFooterLink('KVKK Aydınlatma Metni'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.grey[400], size: 18),
    );
  }

  Widget _buildFooterColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(
            link,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        )),
      ],
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[500], fontSize: 12),
    );
  }
}
