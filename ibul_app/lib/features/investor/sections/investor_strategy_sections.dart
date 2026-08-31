import 'package:flutter/material.dart';

import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorRevenueSection extends StatelessWidget {
  const InvestorRevenueSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-revenue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '08  ·  GELİR',
            title: 'Tek ürün, birden fazla gelir katmanı.',
            subtitle: 'Kanallar tasarımdır. Gerçekleşmiş ciro bu sayfada yok.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.receipt_outlined,
                title: 'İşlem komisyonu',
                body: 'Pazaryeri siparişlerinden pay.',
              ),
              InvestorIconCard(
                icon: Icons.delivery_dining_outlined,
                title: 'Teslimat',
                body: 'İHIZ teslimat geliri.',
              ),
              InvestorIconCard(
                icon: Icons.workspace_premium_outlined,
                title: 'İşletme aboneliği',
                body: 'Premium işletme yazılımı.',
              ),
              InvestorIconCard(
                icon: Icons.campaign_outlined,
                title: 'Reklam',
                body: 'İBUL Reklam ve öne çıkarma.',
              ),
              InvestorIconCard(
                icon: Icons.table_restaurant_outlined,
                title: 'Dikey yazılım',
                body: 'Restoran masa–mutfak çözümü canlıdır. Diğer dikeyler eklenir.',
              ),
              InvestorIconCard(
                icon: Icons.hub_outlined,
                title: 'Kurumsal teslimat',
                body: 'B2B ve İHIZ altyapısı. Vizyon.',
                status: InvestorStatus.vision,
              ),
              InvestorIconCard(
                icon: Icons.analytics_outlined,
                title: 'Veri ürünleri',
                body: 'Anonim / toplu analitik. Kişisel veri satılmaz.',
                status: InvestorStatus.vision,
              ),
              InvestorIconCard(
                icon: Icons.location_city_outlined,
                title: 'Lokasyon modeli',
                body: 'Uzun vadede veri destekli yer yatırımı.',
                status: InvestorStatus.longTerm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorRealEstateSection extends StatelessWidget {
  const InvestorRealEstateSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-real-estate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '09  ·  LOKASYON',
            title: 'Verinin gösterdiği yerde dur.',
            subtitle: 'Bugün gayrimenkul portföyü yok. Bu uzun vade stratejisidir.',
            status: InvestorStatus.longTerm,
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(icon: Icons.search, title: 'Arama'),
              InvestorStepItem(icon: Icons.map_outlined, title: 'Talep haritası'),
              InvestorStepItem(icon: Icons.flag_outlined, title: 'Fırsat'),
              InvestorStepItem(icon: Icons.store_outlined, title: 'Mağaza'),
              InvestorStepItem(icon: Icons.campaign_outlined, title: 'Reklam'),
              InvestorStepItem(icon: Icons.two_wheeler_outlined, title: 'Teslimat'),
            ],
          ),
          SizedBox(height: 18),
          InvestorHeader(
            title: 'Bölge fırsatı — örnek grafik',
            subtitle: 'Sayılar canlı veri değil. Konsept gösterimidir.',
            status: InvestorStatus.demo,
          ),
          SizedBox(height: 12),
          InvestorBarChart(
            rows: [
              ('Spor', 0.91, '91%'),
              ('Elektronik', 0.78, '78%'),
              ('Kozmetik', 0.62, '62%'),
              ('Ev', 0.41, '41%'),
            ],
            caption: 'Örnek: “Bu bölgede spor kategorisinde fırsat var.”',
          ),
        ],
      ),
    );
  }
}

class InvestorFlywheelSection extends StatelessWidget {
  const InvestorFlywheelSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-flywheel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '10  ·  ÇARK',
            title: 'Kullanım artar → veri artar → deneyim iyileşir.',
            subtitle: 'Veri anonim ve topludur. Kişisel veri satılmaz.',
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(icon: Icons.search, title: 'Arama'),
              InvestorStepItem(icon: Icons.trending_up, title: 'Talep'),
              InvestorStepItem(icon: Icons.shopping_bag_outlined, title: 'Sipariş'),
              InvestorStepItem(icon: Icons.insights_outlined, title: 'Veri'),
              InvestorStepItem(icon: Icons.storefront_outlined, title: 'Daha çok işletme'),
              InvestorStepItem(icon: Icons.loop, title: 'Tekrar'),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorCompetitionSection extends StatelessWidget {
  const InvestorCompetitionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-competition',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '11  ·  PAZAR',
            title: 'Rakipler güçlü. İBUL katmanları birleştirmeyi hedefler.',
            subtitle: 'Kimseyi küçümsemiyoruz. Fark: tek ekosistem iddiası.',
          ),
          SizedBox(height: 18),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.storefront_outlined,
                title: 'Pazaryeri',
                body: 'Trendyol, Hepsiburada.',
              ),
              InvestorIconCard(
                icon: Icons.flash_on_outlined,
                title: 'Hızlı ticaret',
                body: 'Getir, Trendyol Go.',
              ),
              InvestorIconCard(
                icon: Icons.restaurant_outlined,
                title: 'Yemek / restoran',
                body: 'Yemeksepeti ve restoran yazılımları.',
              ),
              InvestorIconCard(
                icon: Icons.hub_outlined,
                title: 'İBUL hedefi',
                body: 'Keşif + her işletme + teslimat + reklam, aynı üründe.',
              ),
            ],
          ),
          SizedBox(height: 18),
          InvestorHeader(title: 'Zamanla güçlenen ağlar'),
          SizedBox(height: 12),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.store_outlined,
                title: 'İşletme ağı',
                body: 'Daha çok işletme → daha çok ürün.',
              ),
              InvestorIconCard(
                icon: Icons.people_outline,
                title: 'Müşteri ağı',
                body: 'Daha çok kullanıcı → daha çok talep.',
              ),
              InvestorIconCard(
                icon: Icons.two_wheeler_outlined,
                title: 'Kurye ağı',
                body: 'Daha çok kurye → daha iyi kapasite.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestorGrowthSection extends StatelessWidget {
  const InvestorGrowthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-growth',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '12  ·  BÜYÜME',
            title: 'Önce doğrula. Sonra genişle.',
            subtitle: 'Tarih ve şehir sayısı uydurulmaz.',
            status: InvestorStatus.vision,
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(
                icon: Icons.filter_1,
                title: 'Ürün uyumu',
                caption: 'Ürün → işletme → müşteri',
              ),
              InvestorStepItem(
                icon: Icons.filter_2,
                title: 'Bölge',
                caption: 'Kurye ve işletme ağı',
              ),
              InvestorStepItem(
                icon: Icons.filter_3,
                title: 'Türkiye',
                caption: 'Kategori ve lojistik',
              ),
              InvestorStepItem(
                icon: Icons.filter_4,
                title: 'Yurt dışı',
                caption: 'Doğrulanmış model sonrası',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
