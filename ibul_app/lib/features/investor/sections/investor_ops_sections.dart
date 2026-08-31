import 'package:flutter/material.dart';

import '../investor_map_visual.dart';
import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorIhizSection extends StatelessWidget {
  const InvestorIhizSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-ihiz',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '04  ·  TESLİMAT',
            title: 'İHIZ: sipariş kuryeye böyle gider.',
            subtitle: 'Canlı ürün. Genişleme alanları henüz vaat değil.',
            status: InvestorStatus.live,
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(icon: Icons.receipt_long_outlined, title: 'Sipariş'),
              InvestorStepItem(icon: Icons.assignment_outlined, title: 'Görev'),
              InvestorStepItem(icon: Icons.groups_outlined, title: 'Kurye havuzu'),
              InvestorStepItem(icon: Icons.handshake_outlined, title: 'Kabul'),
              InvestorStepItem(icon: Icons.near_me_outlined, title: 'Canlı teslimat'),
            ],
          ),
          SizedBox(height: 14),
          InvestorIconCard(
            icon: Icons.timeline_outlined,
            title: 'Sonra nereye genişler?',
            body: 'İşletme gönderisi, paket, B2B, iade toplama, yerel lojistik — vizyon.',
            status: InvestorStatus.vision,
          ),
        ],
      ),
    );
  }
}

class InvestorLocalCommerceSection extends StatelessWidget {
  const InvestorLocalCommerceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    return InvestorSection(
      revealId: 'investor-local',
      background: InvestorTokens.wash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InvestorHeader(
            eyebrow: '05  ·  HARİTA',
            title: 'Haritada mağaza. Popup’ta ürün.',
            subtitle:
                'Pin’e dokunun: butik, market, emlak ofisi veya oto kiralama açılır. Popup’ta ürün, fiyat ve stok görünür. Aşağıdaki harita örnektir.',
            status: InvestorStatus.demo,
          ),
          const SizedBox(height: 18),
          if (mobile) ...[
            const InvestorStoreProductMap(),
            const SizedBox(height: 14),
            const InvestorIconCard(
              icon: Icons.touch_app_outlined,
              title: 'Mağazaya dokun',
              body: 'Popup’ta ürün, fiyat, kampanya ve teslimat seçenekleri.',
            ),
          ] else
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: InvestorStoreProductMap()),
                SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      InvestorIconCard(
                        icon: Icons.map_outlined,
                        title: 'Pin’ler mağaza',
                        body:
                            'Butik Lila, Market 7/24, oto kiralama, emlak ofisi aynı haritada.',
                      ),
                      SizedBox(height: 12),
                      InvestorIconCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Popup ürün gösterir',
                        body:
                            'Bluz, çanta, ceket — fiyatıyla. Örnek vitrin, canlı sipariş değil.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class InvestorNearbySection extends StatelessWidget {
  const InvestorNearbySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-nearby',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '06  ·  YAKINIMDA BUL',
            title: 'Ürün → mağaza → stok → kurye.',
            subtitle: 'Aşağıdaki ekran örnektir. Canlı sipariş değildir.',
            status: InvestorStatus.demo,
          ),
          SizedBox(height: 18),
          InvestorPhoneFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yakınımdaki mağazalar',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: InvestorTokens.ink,
                  ),
                ),
                SizedBox(height: 12),
                _NearbyRow(distance: '1,2 km', store: 'Mağaza A', eta: '45 dk'),
                SizedBox(height: 8),
                _NearbyRow(distance: '2,1 km', store: 'Mağaza B', eta: '55 dk'),
                SizedBox(height: 14),
                _DemoGetirButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoGetirButton extends StatelessWidget {
  const _DemoGetirButton();

  @override
  Widget build(BuildContext context) {
    return InvestorPrimaryButton(
      label: 'Şimdi getir',
      icon: Icons.bolt_outlined,
      expanded: true,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Örnek ekran. Canlı sipariş veya süre garantisi yok.'),
          ),
        );
      },
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.distance,
    required this.store,
    required this.eta,
  });

  final String distance;
  final String store;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: InvestorTokens.ink,
                  ),
                ),
                Text(
                  '$distance · Stokta',
                  style: const TextStyle(
                    color: Color(0xFF1B7F5A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            eta,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: InvestorTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class InvestorDeliveryHourSection extends StatelessWidget {
  const InvestorDeliveryHourSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-hour',
      child: InvestorIconCard(
        icon: Icons.schedule_outlined,
        title: 'En yakından al. Saatlerce bekleme.',
        body:
            'Hedef: uygun lokasyon, stok ve kurye varsa 1 saate kadar teslimat. Tüm ürünler için garanti değildir.',
        status: InvestorStatus.vision,
      ),
    );
  }
}

class InvestorPackagingSection extends StatelessWidget {
  const InvestorPackagingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-packaging',
      child: InvestorIconCard(
        icon: Icons.inventory_outlined,
        title: 'Paketleme nasıl yapılıyor?',
        body:
            'Amaç: şeffaflık ve güven. Ürün sayfasındaki bu deneyim henüz yayında değil.',
        status: InvestorStatus.vision,
      ),
    );
  }
}
