import 'package:flutter/material.dart';

import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorRestaurantSection extends StatelessWidget {
  const InvestorRestaurantSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestorSection(
      revealId: 'investor-restaurant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestorHeader(
            eyebrow: '07  ·  RESTORAN DİKEYİ',
            title: 'Masadan mutfağa, tek ekran.',
            subtitle:
                'Restoran canlı dikeylerden biridir. Platformun tamamı bu değil; mağaza, butik, market, oto kiralama ve emlak da satar.',
            status: InvestorStatus.live,
          ),
          SizedBox(height: 18),
          InvestorStepStrip(
            steps: [
              InvestorStepItem(icon: Icons.table_bar_outlined, title: 'Masa'),
              InvestorStepItem(icon: Icons.qr_code_2, title: 'QR / Menü'),
              InvestorStepItem(icon: Icons.shopping_bag_outlined, title: 'Sipariş'),
              InvestorStepItem(icon: Icons.verified_outlined, title: 'Garson onayı'),
              InvestorStepItem(icon: Icons.soup_kitchen_outlined, title: 'Mutfak'),
              InvestorStepItem(icon: Icons.room_service_outlined, title: 'Servis'),
            ],
          ),
          SizedBox(height: 14),
          InvestorResponsiveGrid(
            children: [
              InvestorIconCard(
                icon: Icons.notifications_active_outlined,
                title: 'Garson çağır',
                body: 'Müşteri basar. Panelde “Masa 12 sizi çağırıyor.” görünür.',
                status: InvestorStatus.live,
              ),
              InvestorIconCard(
                icon: Icons.receipt_long_outlined,
                title: 'Onaylı mutfak hattı',
                body: 'Restoran isterse siparişi onay sonrası mutfağa yollar.',
                status: InvestorStatus.live,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
