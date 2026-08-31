import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../investor_widgets.dart';

class InvestorFaqSection extends StatelessWidget {
  const InvestorFaqSection({super.key});

  static const _items = [
    (
      'İBUL nedir?',
      'Yerel işletmelere satış kanalı açan ticaret altyapısı. Mağaza, butik, market, oto kiralama, emlak ofisi ve restoran aynı pazaryerinde durur. Müşteri keşfeder, işletme satar, İHIZ teslim eder.',
    ),
    (
      'Nasıl para kazanır?',
      'Komisyon, teslimat, abonelik, reklam ve dikey yazılımlar. Restoran yazılımı bunlardan biridir. Ciro bu sayfada yok.',
    ),
    (
      'İHIZ nedir?',
      'Teslimat omurgası: sipariş → görev → kurye havuzu → kabul → canlı teslimat.',
    ),
    (
      'Rakiplerden farkı?',
      'Trendyol, Hepsiburada, Getir, Yemeksepeti güçlü. İBUL katmanları tek üründe birleştirmeyi hedefler.',
    ),
    (
      'İşletme neden kullanır?',
      'Yalnız vitrin değil: sipariş, ilan, teslimat ve reklam. Butik de, emlakçı da, market de aynı paneli kullanır.',
    ),
    (
      'Nasıl büyüyecek?',
      'Önce ürün uyumu, sonra bölge, sonra Türkiye. Tarih uydurulmaz.',
    ),
    (
      'Kurye nasıl çalışır?',
      'Görev havuza düşer, kurye kabul eder, canlı teslimat başlar. 1 saat SLA yoktur.',
    ),
    (
      'Restoran dikeyi nedir?',
      'Masa, QR, sipariş, garson onayı, mutfak, servis. Canlı bir dikeydir; İBUL yalnız restoran platformu değildir.',
    ),
    (
      'Gayrimenkul stratejisi nedir?',
      'Uzun vade. Anonim talep ile yer seçimi. Bugün portföy yok.',
    ),
    (
      'Veri nasıl kullanılır?',
      'Anonim ve toplu. Kişisel veri satılmaz. Hukuki garanti verilmez.',
    ),
    (
      'Yatırım nereye gider?',
      'Ürün, büyüme, operasyon, ekip, İHIZ. Tutar yok.',
    ),
    (
      'Hangi pazarlar?',
      'Önce Türkiye. Yurt dışı, doğrulanmış model sonrası.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InvestorSection(
      revealId: 'investor-faq',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InvestorHeader(
            eyebrow: '17  ·  SORULAR',
            title: 'Yatırımcının sorduğu sorular',
            subtitle:
                'Kısa, dürüst cevaplar. Traction ve ciro bu sayfada uydurulmaz.',
          ),
          const SizedBox(height: 18),
          InvestorCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              children: [
                for (final item in _items)
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: AppColors.softPurple,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: Text(
                        item.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: InvestorTokens.ink,
                          fontSize: 15,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.$2,
                            style: const TextStyle(
                              color: InvestorTokens.muted,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
