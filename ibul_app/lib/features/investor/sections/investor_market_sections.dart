import 'package:flutter/material.dart';

import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorMarketSection extends StatelessWidget {
  const InvestorMarketSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-market',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '13  ·  PAZAR BÜYÜKLÜĞÜ',
            title: 'Türkiye e-ticareti büyüyor. İBUL payı henüz ölçülmedi.',
            subtitle: 'Rakamlar kamu kaynağıdır. İBUL GMV’si değildir.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorFigureCard(
                value: '4,57 Tn ₺',
                label: 'E-ticaret hacmi, 2025',
                note: 'Ticaret Bakanlığı / ETBİS',
              ),
              InvestorFigureCard(
                value: '2,46 Tn ₺',
                label: 'Perakende e-ticaret',
                note: 'Aynı rapor',
              ),
              InvestorFigureCard(
                value: '388,7 Mr ₺',
                label: 'Hızlı ticaret',
                note: 'Aynı rapor',
              ),
            ],
          ),
          SizedBox(height: 14),
          InvestorBarChart(
            rows: [
              ('E-ticaret', 1.0, '4,57 Tn'),
              ('Perakende e-ticaret', 0.54, '2,46 Tn'),
              ('Hızlı ticaret', 0.085, '388,7 Mr'),
            ],
            caption:
                'Ölçek karşılaştırması. Kaynak: ticaret.gov.tr, 12.05.2026. SAM/SOM tahmini yok.',
          ),
        ],
      ),
    );
  }
}

class InvestorTractionSection extends StatelessWidget {
  const InvestorTractionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-traction',
      child: InvestorIconCard(
        icon: Icons.ssid_chart_outlined,
        title: 'Canlı performans',
        body:
            'Kullanıcı, işletme, sipariş, GMV ve gelir rakamları doğrulanınca bağlanacak. Bu sayfada uydurulmaz.',
      ),
    );
  }
}

class InvestorWhyNowSection extends StatelessWidget {
  const InvestorWhyNowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-why-now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '14  ·  NEDEN ŞİMDİ?',
            title: 'Talep büyüyor. Altyapı hâlâ dağınık.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.trending_up,
                title: '%52,2 büyüme',
                body: '2025 e-ticaret hacmi. Kaynak: Ticaret Bakanlığı.',
              ),
              InvestorIconCard(
                icon: Icons.apartment_outlined,
                title: '%6,9 GSYH payı',
                body: 'E-ticaretin ekonomi içindeki yeri.',
              ),
              InvestorIconCard(
                icon: Icons.storefront_outlined,
                title: '634.611 işletme',
                body: 'E-ticaret yapan işletme sayısı, 2025.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorInvestmentSection extends StatelessWidget {
  const InvestorInvestmentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-investment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '15  ·  SERMAYE',
            title: 'Sermaye büyümeyi hızlandırmak için.',
            subtitle: 'Tutar ve değerleme bu sayfada yok.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.code_outlined,
                title: 'Ürün ve teknoloji',
                body: 'Mühendislik, altyapı, güvenlik.',
              ),
              InvestorIconCard(
                icon: Icons.rocket_launch_outlined,
                title: 'Büyüme',
                body: 'Müşteri, işletme, marka.',
              ),
              InvestorIconCard(
                icon: Icons.local_shipping_outlined,
                title: 'Operasyon',
                body: 'Teslimat ve saha.',
              ),
              InvestorIconCard(
                icon: Icons.groups_2_outlined,
                title: 'Ekip',
                body: 'Ürün, satış, operasyon.',
              ),
              InvestorIconCard(
                icon: Icons.map_outlined,
                title: 'Bölgesel genişleme',
                body: 'Yeni bölgeler ve İHIZ.',
              ),
              InvestorIconCard(
                icon: Icons.domain_outlined,
                title: 'Lokasyon denemeleri',
                body: 'Uzun vade. Fiziksel mağaza henüz yok.',
                status: InvestorStatus.longTerm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorLookingForSection extends StatelessWidget {
  const InvestorLookingForSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-looking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '16  ·  KİMİ ARIYORUZ',
            title: 'Sermaye + deneyim + ağ.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'Melek yatırımcı',
                body: 'Erken aşama ve kurucu ağı.',
              ),
              InvestorIconCard(
                icon: Icons.account_balance_outlined,
                title: 'Girişim sermayesi',
                body: 'Ölçeklenme sermayesi.',
              ),
              InvestorIconCard(
                icon: Icons.handshake_outlined,
                title: 'Stratejik yatırımcı',
                body: 'Perakende, lojistik, teknoloji.',
              ),
              InvestorIconCard(
                icon: Icons.store_mall_directory_outlined,
                title: 'İşletme ortakları',
                body: 'Yerel mağaza ve kategori derinliği.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorTeamSection extends StatelessWidget {
  const InvestorTeamSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-team',
      child: InvestorIconCard(
        icon: Icons.person_outline,
        title: 'Kurucu hikâyesi',
        body:
            'Problem → vizyon → ürün → gelecek. Parçalı yerel ticareti tek altyapıda birleştirmek. Doğrulanmış özgeçmiş bu sayfada yok.',
      ),
    );
  }
}
