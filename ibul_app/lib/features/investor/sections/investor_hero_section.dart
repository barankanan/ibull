import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../investor_visuals.dart';
import '../investor_widgets.dart';

class InvestorHeroSection extends StatelessWidget {
  const InvestorHeroSection({
    super.key,
    required this.onDeck,
    required this.onContact,
    required this.onExplore,
  });

  final VoidCallback onDeck;
  final VoidCallback onContact;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InvestorHeader(
          eyebrow: 'YATIRIMCI İLİŞKİLERİ',
          title: 'Yerel ticaretin geleceğini inşa ediyoruz.',
          subtitle:
              'Mağaza, butik, market, oto kiralama, emlak ofisi ve restoran aynı satış kanalını kullanır. Müşteri keşfeder, işletme satar, İHIZ teslim eder. İBUL bir vitrin değil; her yerel işletmenin ortak altyapısıdır.',
        ),
        const SizedBox(height: 16),
        Text(
          'Her işletme satabilir. Tek platform. Tek teslimat omurgası.',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: mobile ? 15 : 17,
            height: 1.35,
          ),
        ),
        SizedBox(height: mobile ? 22 : 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            InvestorPrimaryButton(
              label: 'Sunumu incele',
              icon: Icons.menu_book_outlined,
              onPressed: onDeck,
              expanded: mobile,
            ),
            InvestorPrimaryButton(
              label: 'İletişime geç',
              icon: Icons.mail_outline_rounded,
              onPressed: onContact,
              expanded: mobile,
            ),
            InvestorSecondaryButton(
              label: 'İBUL’u keşfet',
              icon: Icons.storefront_outlined,
              onPressed: onExplore,
              expanded: mobile,
            ),
          ],
        ),
      ],
    );

    final visual = InvestorSceneBoard(
      title: 'Kim satar?',
      nodes: const [
        (Icons.store_outlined, 'Mağaza'),
        (Icons.checkroom_outlined, 'Butik'),
        (Icons.local_grocery_store_outlined, 'Market'),
        (Icons.directions_car_outlined, 'Oto kiralama'),
        (Icons.apartment_outlined, 'Emlak'),
        (Icons.restaurant_outlined, 'Restoran'),
      ],
    );

    return InvestorSection(
      revealId: 'investor-hero',
      child: mobile
          ? Column(
              children: [copy, const SizedBox(height: 20), visual],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: copy),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: visual),
              ],
            ),
    );
  }
}
