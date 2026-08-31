import 'package:flutter/material.dart';

import '../investor_map_visual.dart';
import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorWhySection extends StatelessWidget {
  const InvestorWhySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-why',
      background: InvestorTokens.wash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '01  ·  PROBLEM',
            title: 'Yerel ticaret hâlâ parçalı.',
            subtitle:
                'İşletme müşteri bulur, ama satış, stok, ilan, teslimat ve reklam ayrı yerlerde kalır. Bu dağınıklık yalnız restoranda değil; mağaza, butik, market, oto kiralama ve emlak ofisinde de aynıdır.',
          ),
          SizedBox(height: 18),
          InvestorSplitCompare(
            leftTitle: 'Bugün',
            leftItems: [
              'Pazaryeri ayrı, vitrin ayrı',
              'Teslimat ayrı yazılımda',
              'Kasa / stok / ilan ayrı',
              'Reklam ayrı ajans veya platformda',
              'Emlak ilanı başka sitede',
              'Oto kiralama başka kanalda',
              'Butik ve market kendi başına',
            ],
            rightTitle: 'İBUL',
            rightItems: [
              'Yerel keşif, tek harita',
              'Sipariş, rezervasyon, ilan',
              'Her işletme tipi, tek panel',
              'İHIZ teslimat omurgası',
              'İBUL Reklam',
              'Mağaza, butik, market',
              'Emlak ofisi de satar',
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorEcosystemSection extends StatelessWidget {
  const InvestorEcosystemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-ecosystem',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '02  ·  ZİNCİR',
            title: 'Müşteriden kuryeye tek hat.',
            subtitle:
                'Mağaza ürün satar, emlak ilan açar, oto kiralama rezervasyon alır. Restoran da bu hatta durur; tek dikey değildir.',
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(
                icon: Icons.person_outline,
                title: 'Müşteri',
                caption: 'Arar, görür, alır',
              ),
              InvestorStepItem(
                icon: Icons.storefront_outlined,
                title: 'Pazaryeri',
                caption: 'Ürün, ilan, mağaza',
              ),
              InvestorStepItem(
                icon: Icons.store_outlined,
                title: 'İşletme',
                caption: 'Mağaza, butik, market',
              ),
              InvestorStepItem(
                icon: Icons.apartment_outlined,
                title: 'Emlak / oto',
                caption: 'İlan ve rezervasyon',
              ),
              InvestorStepItem(
                icon: Icons.delivery_dining_outlined,
                title: 'İHIZ',
                caption: 'Teslimat görevi',
              ),
              InvestorStepItem(
                icon: Icons.two_wheeler_outlined,
                title: 'Kurye',
                caption: 'Canlı teslimat',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorProductsSection extends StatelessWidget {
  const InvestorProductsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-products',
      background: InvestorTokens.wash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '03  ·  ÜRÜNLER',
            title: 'Her işletme satabilir. Katmanlar birleşir.',
            subtitle:
                'Canlı olan: pazaryeri, işletme paneli, restoran dikeyi, İHIZ, kurye, reklam. Emlakçı ilanını açar; ofis CRM ve yer yatırımı vizyon / uzun vadedir.',
          ),
          SizedBox(height: 16),
          InvestorTypeRibbon(),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.storefront_outlined,
                title: 'Pazaryeri',
                body:
                    'Mağaza, butik, market, emlak, oto kiralama ve restoran keşfi.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.business_center_outlined,
                title: 'İşletme paneli',
                body: 'Ürün, ilan, sipariş, kampanya, reklam, analiz.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.apartment_outlined,
                title: 'Emlak',
                body:
                    'Ofis konut, işyeri ve kiralık ilanını yerel müşteriye açar. Portföy CRM vizyon.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.table_bar_outlined,
                title: 'Restoran dikeyi',
                body:
                    'Masa, QR menü, garson, mutfak, yazıcı. Canlı bir dikey; tüm platform bu değil.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.delivery_dining_outlined,
                title: 'İHIZ',
                body: 'Sipariş ve paket teslimat omurgası.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.two_wheeler_outlined,
                title: 'Kurye ağı',
                body: 'Görev, kabul ve canlı teslimat.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.campaign_outlined,
                title: 'İBUL Reklam',
                body: 'İşletmeyi doğru müşteriye gösterir.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.insights_outlined,
                title: 'Veri zekâsı',
                body:
                    'Anonim, toplu talep sinyali. Gelişmiş ürünler vizyon.',
                status: InvestorStatus.vision,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
